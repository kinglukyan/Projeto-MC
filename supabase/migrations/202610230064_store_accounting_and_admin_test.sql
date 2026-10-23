begin;
do $$ begin
 if to_regprocedure('public.get_basic_pack_shop()') is null or to_regprocedure('public._claim_gift_before056(text)') is null then raise exception 'Aplique primeiro as migrações até a 063.';end if;
end $$;
create table if not exists public.store_test_settings(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 enabled boolean not null default false,updated_at timestamptz not null default now());
create table if not exists public.store_accounting(
 id uuid primary key default gen_random_uuid(),source text not null unique,
 player_id uuid not null references public.profiles(id),actor_id uuid,
 currency text not null check(currency in('mythic','trixx')),
 kind text not null check(kind in('purchase','credit','reward','adjustment')),
 amount bigint not null,product text not null default '',created_at timestamptz not null default now());
create index if not exists store_accounting_date on public.store_accounting(created_at desc,id);
alter table public.store_test_settings enable row level security;
alter table public.store_accounting enable row level security;
revoke all on public.store_test_settings,public.store_accounting from public,anon,authenticated;
grant all on public.store_test_settings,public.store_accounting to service_role;

create or replace function public._store_test_enabled() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(public.is_site_admin() and (select enabled from public.store_test_settings where player_id=auth.uid()),false)
$$;
revoke all on function public._store_test_enabled() from public,anon,authenticated;

create or replace function public.get_store_wallet() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 return jsonb_build_object('balance',coalesce((select clash_bits from public.premium_wallets where player_id=auth.uid()),0),'test_mode',public._store_test_enabled());
end $$;
create or replace function public.admin_set_store_test(p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if p_enabled is null then raise exception 'Escolha o estado do modo teste.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 insert into public.store_test_settings(player_id,enabled) values(auth.uid(),p_enabled)
 on conflict(player_id) do update set enabled=excluded.enabled,updated_at=now();
 perform public._security_event('store_test_mode','info',null,jsonb_build_object('enabled',p_enabled));
 return public.get_store_wallet();
end $$;

-- Keep existing validation and delivery logic behind private, revoked entry points.
do $$ begin
 if to_regprocedure('public._purchase_shop_before064(text)') is null then alter function public.purchase_shop_item(text) rename to _purchase_shop_before064;end if;
 if to_regprocedure('public._buy_pack_before064(text,uuid,integer)') is null then alter function public.buy_basic_pack(text,uuid,integer) rename to _buy_pack_before064;end if;
end $$;
revoke all on function public._purchase_shop_before064(text),public._buy_pack_before064(text,uuid,integer) from public,anon,authenticated;

create or replace function public.purchase_shop_item(p_item_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare item public.shop_catalog%rowtype; result jsonb;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into item from public.shop_catalog where item_id=p_item_id and active for update;
 if not found then raise exception 'Este item não está disponível.';end if;
 if public._store_test_enabled() then
  perform public._security_rpc_gate('store_test_item',60);
  return jsonb_build_object('test_mode',true,'item',jsonb_build_object('name',item.title,'art',item.asset_path,'kind',item.kind));
 end if;
 result:=public._purchase_shop_before064(p_item_id);
 insert into public.store_accounting(source,player_id,currency,kind,amount,product)
 values('shop:'||gen_random_uuid()::text,auth.uid(),'mythic','purchase',item.price,item.title);
 return result;
end $$;

create or replace function public.buy_basic_pack(p_pack_id text,p_request_id uuid,p_expected_price integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare pack public.basic_card_packs%rowtype; cards jsonb;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if public._store_test_enabled() then
  perform public._security_rpc_gate('store_test_pack',60);
  select * into pack from public.basic_card_packs where id=p_pack_id and enabled;
  if not found or p_expected_price is distinct from pack.price or p_request_id is null then raise exception 'Confira o pacote e o preço.';end if;
  select jsonb_agg(jsonb_build_object('id',card_id,'name',card_name,'art',art) order by ordinal) into cards from public.basic_pack_cards where pack_id=pack.id;
  if cards is null then raise exception 'Pacote sem cartas.';end if;
  return jsonb_build_object('test_mode',true,'balance',coalesce((select clash_bits from public.premium_wallets where player_id=auth.uid()),0),
   'purchase',jsonb_build_object('id',gen_random_uuid(),'test_mode',true,'pack_id',pack.id,'name',pack.name,'edition',pack.edition,'front',pack.front_asset,'back',pack.back_asset,'cards',cards,'revealed_count',0,'opened_at',null));
 end if;
 return public._buy_pack_before064(p_pack_id,p_request_id,p_expected_price);
end $$;

-- Only committed real premium transactions reach this trigger. Simulations never insert rows.
create or replace function public._store_premium_accounting() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='premium_spend_ledger' then
  insert into public.store_accounting(source,player_id,currency,kind,amount,product,created_at)
  select 'pack:'||new.purchase_id::text,new.player_id,'trixx','purchase',new.amount,p.name,new.spent_at
   from public.basic_pack_purchases b join public.basic_card_packs p on p.id=b.pack_id where b.id=new.purchase_id on conflict(source) do nothing;
 else
  insert into public.store_accounting(source,player_id,currency,kind,amount,product,created_at)
  values('credit:'||new.external_reference,new.player_id,'trixx','credit',new.amount,'Crédito de serviço',new.credited_at) on conflict(source) do nothing;
 end if;return new;
end $$;
revoke all on function public._store_premium_accounting() from public,anon,authenticated;
drop trigger if exists store_premium_spend on public.premium_spend_ledger;
create trigger store_premium_spend after insert on public.premium_spend_ledger for each row execute function public._store_premium_accounting();
drop trigger if exists store_premium_credit on public.premium_credit_ledger;
create trigger store_premium_credit after insert on public.premium_credit_ledger for each row execute function public._store_premium_accounting();
insert into public.store_accounting(source,player_id,currency,kind,amount,product,created_at)
select 'pack:'||s.purchase_id::text,s.player_id,'trixx','purchase',s.amount,p.name,s.spent_at from public.premium_spend_ledger s
join public.basic_pack_purchases b on b.id=s.purchase_id join public.basic_card_packs p on p.id=b.pack_id on conflict(source) do nothing;
insert into public.store_accounting(source,player_id,currency,kind,amount,product,created_at)
select 'credit:'||external_reference,player_id,'trixx','credit',amount,'Crédito de serviço',credited_at from public.premium_credit_ledger on conflict(source) do nothing;


do $$ begin
 if to_regprocedure('public._adjust_rewards_before064(uuid,integer,integer)') is null then alter function public.admin_adjust_player_rewards(uuid,integer,integer) rename to _adjust_rewards_before064;end if;
end $$;
revoke all on function public._adjust_rewards_before064(uuid,integer,integer) from public,anon,authenticated;
create or replace function public.admin_adjust_player_rewards(p_user_id uuid,p_coins_delta integer,p_xp_delta integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 result:=public._adjust_rewards_before064(p_user_id,p_coins_delta,p_xp_delta);
 if p_coins_delta<>0 then insert into public.store_accounting(source,player_id,actor_id,currency,kind,amount,product)
 values('adjust:'||gen_random_uuid()::text,p_user_id,auth.uid(),'mythic','adjustment',p_coins_delta,'Ajuste administrativo');end if;
 return result;
end $$;
revoke all on function public.admin_adjust_player_rewards(uuid,integer,integer) from public,anon;
grant execute on function public.admin_adjust_player_rewards(uuid,integer,integer) to authenticated;

create or replace function public.admin_adjust_store_rewards(p_user_id uuid,p_coins_delta integer,p_xp_delta integer,p_trixx_delta integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; value bigint;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if p_trixx_delta is null or p_trixx_delta not between -5000 and 5000 then raise exception 'Ajuste de Trixx Coins fora do limite.';end if;
 result:=public.admin_adjust_player_rewards(p_user_id,p_coins_delta,p_xp_delta);
 insert into public.premium_wallets(player_id) values(p_user_id) on conflict do nothing;
 update public.premium_wallets set clash_bits=clash_bits+p_trixx_delta,updated_at=now() where player_id=p_user_id and clash_bits+p_trixx_delta>=0 returning clash_bits into value;
 if not found then raise exception 'O ajuste deixaria Trixx Coins negativas.';end if;
 if p_trixx_delta<>0 then insert into public.store_accounting(source,player_id,actor_id,currency,kind,amount,product) values('adjust:'||gen_random_uuid()::text,p_user_id,auth.uid(),'trixx','adjustment',p_trixx_delta,'Ajuste administrativo');end if;

 perform public._security_event('trixx_reward_adjustment','info',null,jsonb_build_object('player_id',p_user_id,'delta',p_trixx_delta));
 return result||jsonb_build_object('trixx_coins',value);
end $$;

create or replace function public._normalize_reward_bundle(p_rewards jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare entry jsonb; result jsonb:='[]'; k text; ident text; qty integer; product public.shop_catalog%rowtype;
begin
 if jsonb_typeof(p_rewards) is distinct from 'array' or jsonb_array_length(p_rewards) not between 1 and 30 or octet_length(p_rewards::text)>24000 then raise exception 'Escolha entre 1 e 30 recompensas.';end if;
 for entry in select value from jsonb_array_elements(p_rewards) loop
  k:=entry->>'kind';ident:=nullif(btrim(entry->>'id'),'');
  if coalesce(entry->>'amount','1') !~ '^[0-9]{1,6}$' then raise exception 'Quantidade inválida.';end if;
  qty:=coalesce(entry->>'amount','1')::integer;
  if qty<1 or qty>100000 then raise exception 'Quantidade fora do limite.';end if;
  if k='coins' then
   result:=result||jsonb_build_array(jsonb_build_object('kind','coins','amount',qty,'name','Mythic Coins','asset','assets/identity-v2/coin.webp'));
  elsif k='trixx_coins' then
   result:=result||jsonb_build_array(jsonb_build_object('kind','trixx_coins','amount',qty,'name','Trixx Coins','asset','assets/currency/trixx-coins.webp'));
  elsif k in('card','item','avatar','battlefield','hand') then
   if k='card' then select * into product from public.shop_catalog where kind='card' and card_id=ident order by active desc,item_id limit 1;
   else select * into product from public.shop_catalog where item_id=ident;end if;
   if not found then raise exception 'Uma das recompensas não existe no catálogo: %',ident;end if;
   if product.kind='card' then
    if qty>100 or coalesce((public._r_card(product.card_id)->>'specialOnly')::boolean,false) then raise exception 'Esta carta ou quantidade não pode ser distribuída.';end if;
    result:=result||jsonb_build_array(jsonb_build_object('kind','card','id',product.card_id,'item_id',product.item_id,'amount',qty,'name',product.title,'asset',product.asset_path));
   else
    if qty<>1 then raise exception 'Ícones e aparências devem ter quantidade 1.';end if;
    result:=result||jsonb_build_array(jsonb_build_object('kind',product.kind,'id',product.item_id,'amount',1,'name',product.title,'asset',product.asset_path));
   end if;
  else raise exception 'Tipo de recompensa inválido.';end if;
 end loop;
 return result;
end $$;
create or replace function public._claim_gift_before056(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); gift public.redeem_codes%rowtype; contents jsonb; entry jsonb; delivered jsonb:='[]'; previous jsonb; duplicated boolean; changed integer;
begin
 perform public._assert_account_active();perform public._security_rpc_gate('claim_gift_code',20);
 if who is null then raise exception 'Entre para resgatar presentes.';end if;
 if p_code is null or length(btrim(p_code)) not between 1 and 32 then raise exception 'Digite um código válido.';end if;
 -- Profile lock serializes grants to the same account. Code lock protects its quota.
 perform 1 from public.profiles where id=who for update;if not found then raise exception 'Seu perfil ainda está carregando.';end if;
 select * into gift from public.redeem_codes where code=upper(btrim(p_code)) for update;
 if not found then raise exception 'Código inválido.';end if;
 select c.receipt into previous from public.gift_claims c where c.player_id=who and c.code=gift.code;
 duplicated:=found;
 if duplicated and previous is not null then return jsonb_build_object('already_claimed',true,'rewards',previous);end if;
 if not duplicated and (not gift.active or (gift.expires_at is not null and gift.expires_at<=now()) or gift.uses>=gift.max_uses) then raise exception 'Código expirado, desativado ou com limite de resgates atingido.';end if;
 contents:=public._normalize_reward_bundle(case when gift.reward_type='bundle' then gift.rewards else jsonb_build_array(jsonb_build_object('kind',gift.reward_type,'id',coalesce(gift.item_id,gift.card_id),'amount',case when gift.reward_type='item' then 1 else greatest(1,gift.reward_amount) end)) end);
 if duplicated then
  perform public._ensure_player_inventory(who);
  update public.gift_claims set receipt=contents where player_id=who and code=gift.code;
  return jsonb_build_object('already_claimed',true,'rewards',contents);
 end if;
 insert into public.gift_claims(player_id,code) values(who,gift.code);
 for entry in select value from jsonb_array_elements(contents) loop
  if entry->>'kind'='coins' then
   update public.profiles set mythic_coins=mythic_coins+(entry->>'amount')::integer where id=who;
  elsif entry->>'kind'='trixx_coins' then
   insert into public.premium_wallets(player_id,clash_bits) values(who,(entry->>'amount')::bigint)
    on conflict(player_id) do update set clash_bits=public.premium_wallets.clash_bits+excluded.clash_bits,updated_at=now();
  elsif entry->>'kind'='card' then
   -- Copies first: the inventory trigger must not add another copy to the grant.
   insert into public.player_card_copies(player_id,card_id,copies) values(who,entry->>'id',(entry->>'amount')::integer)
    on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+excluded.copies;
   insert into public.player_inventory(player_id,item_id) values(who,entry->>'item_id') on conflict do nothing;
  else
   insert into public.player_inventory(player_id,item_id) values(who,entry->>'id') on conflict do nothing;
   get diagnostics changed=row_count;entry:=entry||jsonb_build_object('already_owned',changed=0);
  end if;
  if entry->>'kind' in('coins','trixx_coins') then
   insert into public.store_accounting(source,player_id,currency,kind,amount,product)
    values('gift:'||gift.code||':'||who::text||':'||jsonb_array_length(delivered)::text,who,case when entry->>'kind'='coins' then 'mythic' else 'trixx' end,'reward',(entry->>'amount')::bigint,'Código de recompensa');
  end if;
  delivered:=delivered||jsonb_build_array(entry);
 end loop;
 update public.redeem_codes set uses=uses+1 where code=gift.code;
 update public.gift_claims set receipt=delivered where player_id=who and code=gift.code;
 perform public._security_event('reward_code_claimed','info',null,jsonb_build_object('code_hash',md5(gift.code),'items',jsonb_array_length(delivered)));
 return jsonb_build_object('already_claimed',false,'rewards',delivered);
end $$;
revoke all on function public._normalize_reward_bundle(jsonb),public._claim_gift_before056(text) from public,anon,authenticated;

create or replace function public.admin_store_accounting(p_from timestamptz default null,p_to timestamptz default null,p_currency text default null,p_offset integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare rows jsonb; totals jsonb; count_rows bigint;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if p_offset is null or p_offset<0 or p_currency is not null and p_currency not in('mythic','trixx') or p_from>p_to then raise exception 'Filtros inválidos.';end if;
 select jsonb_agg(to_jsonb(t)) into totals from (
  select currency,kind,count(*) as operations,sum(amount) as amount from public.store_accounting
  where (p_from is null or created_at>=p_from) and (p_to is null or created_at<p_to) and (p_currency is null or currency=p_currency) group by currency,kind) t;
 select count(*) into count_rows from public.store_accounting where (p_from is null or created_at>=p_from) and (p_to is null or created_at<p_to) and (p_currency is null or currency=p_currency);
 select jsonb_agg(to_jsonb(t)) into rows from (
  select a.*,coalesce(p.nickname,p.display_name,'Jogador') as player_name from public.store_accounting a left join public.profiles p on p.id=a.player_id
  where (p_from is null or a.created_at>=p_from) and (p_to is null or a.created_at<p_to) and (p_currency is null or a.currency=p_currency)
  order by a.created_at desc,a.id limit 50 offset p_offset) t;
 return jsonb_build_object('rows',coalesce(rows,'[]'),'totals',coalesce(totals,'[]'),'count',count_rows);
end $$;
revoke all on function public.get_store_wallet(),public.admin_set_store_test(boolean),public.purchase_shop_item(text),public.buy_basic_pack(text,uuid,integer),public.admin_adjust_store_rewards(uuid,integer,integer,integer),public.admin_store_accounting(timestamptz,timestamptz,text,integer) from public,anon;
grant execute on function public.get_store_wallet(),public.admin_set_store_test(boolean),public.purchase_shop_item(text),public.buy_basic_pack(text,uuid,integer),public.admin_adjust_store_rewards(uuid,integer,integer,integer),public.admin_store_accounting(timestamptz,timestamptz,text,integer) to authenticated;

-- An explicit purchase intent prevents a stale test confirmation from charging money.
create or replace function public.purchase_shop_item_checked(p_item_id text,p_test_mode boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if p_test_mode is distinct from public._store_test_enabled() then raise exception 'O modo da loja mudou. Atualize e confirme novamente.';end if;
 return public.purchase_shop_item(p_item_id);
end $$;
create or replace function public.buy_basic_pack_checked(p_pack_id text,p_request_id uuid,p_expected_price integer,p_test_mode boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if p_test_mode is distinct from public._store_test_enabled() then raise exception 'O modo da loja mudou. Atualize e confirme novamente.';end if;
 return public.buy_basic_pack(p_pack_id,p_request_id,p_expected_price);
end $$;
revoke all on function public.purchase_shop_item_checked(text,boolean),public.buy_basic_pack_checked(text,uuid,integer,boolean) from public,anon;
grant execute on function public.purchase_shop_item_checked(text,boolean),public.buy_basic_pack_checked(text,uuid,integer,boolean) to authenticated;

notify pgrst,'reload schema';
commit;
