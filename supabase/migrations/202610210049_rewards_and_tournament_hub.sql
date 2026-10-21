begin;

alter table public.redeem_codes add column if not exists rewards jsonb not null default '[]'::jsonb;
alter table public.redeem_codes drop constraint if exists redeem_codes_reward_type_check;
alter table public.redeem_codes add constraint redeem_codes_reward_type_check check(reward_type in('coins','item','card','bundle'));
alter table public.gift_claims add column if not exists receipt jsonb;

-- Resolve only server catalog entries. Client titles, images and prices are ignored.
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
revoke all on function public._normalize_reward_bundle(jsonb) from public,anon,authenticated;

create or replace function public.admin_create_reward_code(p_code text,p_rewards jsonb,p_max_uses integer default 1,p_expires_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare contents jsonb; normalized text:=upper(btrim(p_code));
begin
 perform public._assert_account_active();perform public._security_rpc_gate('admin_create_reward_code',20);
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if normalized is null or normalized !~ '^[A-Z0-9-]{3,32}$' or p_max_uses is null or p_max_uses not between 1 and 100000 or (p_expires_at is not null and p_expires_at<=now()) then raise exception 'Confira o código, a validade e o limite de resgates.';end if;
 contents:=public._normalize_reward_bundle(p_rewards);
 insert into public.redeem_codes(code,reward_type,rewards,max_uses,expires_at) values(normalized,'bundle',contents,p_max_uses,p_expires_at);
 perform public._security_event('reward_code_created','info',null,jsonb_build_object('code_hash',md5(normalized),'items',jsonb_array_length(contents),'max_uses',p_max_uses));
 return jsonb_build_object('code',normalized,'rewards',contents);
end $$;

create or replace function public.admin_list_reward_codes()
returns jsonb language plpgsql security definer set search_path='' as $$
declare gift public.redeem_codes%rowtype; contents jsonb; rows jsonb:='[]'; invalid boolean;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 for gift in select * from public.redeem_codes order by created_at desc limit 100 loop
  invalid:=false;
  begin
   contents:=public._normalize_reward_bundle(case when gift.reward_type='bundle' then gift.rewards else jsonb_build_array(jsonb_build_object('kind',gift.reward_type,'id',coalesce(gift.item_id,gift.card_id),'amount',case when gift.reward_type='item' then 1 else greatest(1,gift.reward_amount) end)) end);
  exception when others then contents:='[]';invalid:=true;end;
  rows:=rows||jsonb_build_array(jsonb_build_object('code',gift.code,'rewards',contents,'uses',gift.uses,'max_uses',gift.max_uses,'active',gift.active,'expires_at',gift.expires_at,'invalid',invalid));
 end loop;return rows;
end $$;

create or replace function public.admin_set_reward_code_active(p_code text,p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if p_active is null then raise exception 'Estado inválido.';end if;
 update public.redeem_codes set active=p_active where code=upper(btrim(p_code));if not found then raise exception 'Código não encontrado.';end if;
 perform public._security_event('reward_code_availability','info',null,jsonb_build_object('code_hash',md5(upper(btrim(p_code))),'active',p_active));
end $$;

create or replace function public.claim_gift_code(p_code text)
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
  elsif entry->>'kind'='card' then
   -- Copies first: the inventory trigger must not add another copy to the grant.
   insert into public.player_card_copies(player_id,card_id,copies) values(who,entry->>'id',(entry->>'amount')::integer)
    on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+excluded.copies;
   insert into public.player_inventory(player_id,item_id) values(who,entry->>'item_id') on conflict do nothing;
  else
   insert into public.player_inventory(player_id,item_id) values(who,entry->>'id') on conflict do nothing;
   get diagnostics changed=row_count;entry:=entry||jsonb_build_object('already_owned',changed=0);
  end if;
  delivered:=delivered||jsonb_build_array(entry);
 end loop;
 update public.redeem_codes set uses=uses+1 where code=gift.code;
 update public.gift_claims set receipt=delivered where player_id=who and code=gift.code;
 perform public._security_event('reward_code_claimed','info',null,jsonb_build_object('code_hash',md5(gift.code),'items',jsonb_array_length(delivered)));
 return jsonb_build_object('already_claimed',false,'rewards',delivered);
end $$;

alter table public.player_tournaments add column if not exists description text not null default '';
alter table public.player_tournaments add column if not exists published boolean not null default true;
alter table public.player_tournaments add column if not exists max_players integer not null default 32;
alter table public.player_tournaments add column if not exists ends_at timestamptz;
alter table public.player_tournaments drop constraint if exists tournament_capacity_v49;
alter table public.player_tournaments add constraint tournament_capacity_v49 check(max_players between 2 and 128);
drop policy if exists "Read open tournaments" on public.player_tournaments;
create policy "Read open tournaments" on public.player_tournaments for select to authenticated using(public.is_site_admin() or (published and status in('registration','in_progress','completed')));

create or replace function public.admin_save_tournament(p_title text,p_format text,p_starts_at timestamptz,p_description text default '',p_max_players integer default 32,p_published boolean default true,p_ends_at timestamptz default null,p_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 perform public._assert_account_active();perform public._security_rpc_gate('admin_save_tournament',20);
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if length(btrim(coalesce(p_title,''))) not between 3 and 64 or p_format is null or p_format not in('single_elimination','swiss') or p_starts_at is null or p_starts_at<now()+interval '10 minutes' or length(coalesce(p_description,''))>1000 or p_max_players is null or p_max_players not between 2 and 128 or p_published is null or (p_ends_at is not null and p_ends_at<=p_starts_at) then raise exception 'Confira os dados. Agende o início com pelo menos dez minutos de antecedência.';end if;
 if p_id is null then
  insert into public.player_tournaments(host_id,title,format,starts_at,description,max_players,published,ends_at) values(auth.uid(),btrim(p_title),p_format,p_starts_at,btrim(coalesce(p_description,'')),p_max_players,p_published,p_ends_at) returning id into result;
 else
  perform 1 from public.player_tournaments where id=p_id and status='registration' for update;if not found then raise exception 'Somente torneios em inscrição podem ser editados.';end if;
  if (select count(*) from public.tournament_entries where tournament_id=p_id)>p_max_players then raise exception 'O limite não pode ser menor que as inscrições atuais.';end if;
  update public.player_tournaments set title=btrim(p_title),format=p_format,starts_at=p_starts_at,description=btrim(coalesce(p_description,'')),max_players=p_max_players,published=p_published,ends_at=p_ends_at where id=p_id returning id into result;
 end if;
 perform public._security_event('tournament_saved','info',null,jsonb_build_object('tournament_id',result,'published',p_published));return result;
end $$;

create or replace function public.admin_tournament_action(p_id uuid,p_action text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.player_tournaments%rowtype;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 select * into t from public.player_tournaments where id=p_id for update;if not found then raise exception 'Torneio não encontrado.';end if;
 if p_action='cancel' then
  if t.status not in('registration','in_progress') then raise exception 'Este torneio já foi encerrado.';end if;
  if exists(select 1 from public.player_tournament_rounds where tournament_id=p_id and status='active') then raise exception 'Aguarde as partidas em andamento terminarem antes de cancelar.';end if;
  update public.player_tournaments set status='cancelled',published=false where id=p_id;
 elsif p_action in('publish','hide') then
  if t.status not in('registration','in_progress') or (p_action='publish' and t.ends_at is not null and t.ends_at<=now()) then raise exception 'Este torneio não está disponível.';end if;
  update public.player_tournaments set published=(p_action='publish') where id=p_id;
 else raise exception 'Ação inválida.';end if;
 perform public._security_event('tournament_availability','info',null,jsonb_build_object('tournament_id',p_id,'action',p_action));
end $$;

create or replace function public.enter_player_tournament(p_tournament_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t public.player_tournaments%rowtype;
begin
 perform public._assert_account_active();perform public._security_rpc_gate('enter_player_tournament',20);
 select * into t from public.player_tournaments where id=p_tournament_id for update;
 if not found or not t.published or t.status<>'registration' or t.starts_at<=now() or (t.ends_at is not null and t.ends_at<=now()) then raise exception 'As inscrições deste torneio não estão abertas.';end if;
 if not public._player_pvp_unlocked(auth.uid()) then raise exception 'Conclua o treinamento para disputar um torneio.';end if;
 if exists(select 1 from public.tournament_entries where tournament_id=t.id and player_id=auth.uid()) then return;end if;
 if (select count(*) from public.tournament_entries where tournament_id=t.id)>=t.max_players then raise exception 'Todas as vagas foram preenchidas.';end if;
 insert into public.tournament_entries(tournament_id,player_id) values(t.id,auth.uid());
end $$;

-- Existing bracket RPCs cannot open a duel after an event was hidden or cancelled.
create or replace function public._tournament_round_availability_v49()
returns trigger language plpgsql security definer set search_path='' as $$
declare event_row public.player_tournaments%rowtype;
begin
 if new.status='active' then
  if tg_op='UPDATE' and old.status='active' then return new;end if;
  select * into event_row from public.player_tournaments where id=new.tournament_id for update;
  if not found or event_row.status<>'in_progress' or not event_row.published or (event_row.ends_at is not null and event_row.ends_at<=now()) then raise exception 'Este torneio não está disponível para novos duelos.';end if;
 end if;return new;
end $$;
revoke all on function public._tournament_round_availability_v49() from public,anon,authenticated;
drop trigger if exists tournament_round_availability_v49 on public.player_tournament_rounds;
create trigger tournament_round_availability_v49 before insert or update of status on public.player_tournament_rounds for each row execute function public._tournament_round_availability_v49();

create or replace function public.get_tournament_hub(p_admin boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public._assert_account_active();
 if p_admin and not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.starts_at),'[]') into result from(
  select t.id,t.host_id,t.title,t.description,t.format,t.starts_at,t.ends_at,t.status,t.published,t.max_players,
   (select count(*) from public.tournament_entries e where e.tournament_id=t.id) as entrants,
   exists(select 1 from public.tournament_entries e where e.tournament_id=t.id and e.player_id=auth.uid()) as registered,
   coalesce((select jsonb_agg(to_jsonb(rr) order by rr.round_number,rr.created_at) from(
    select r.id,r.round_number,r.status,r.match_id,r.player_one,r.player_two,r.winner_id,r.created_at,
     coalesce(p1.nickname,p1.display_name,'A definir') as player_one_name,coalesce(p2.nickname,p2.display_name,'A definir') as player_two_name
    from public.player_tournament_rounds r left join public.profiles p1 on p1.id=r.player_one left join public.profiles p2 on p2.id=r.player_two
    where r.tournament_id=t.id order by r.round_number,r.created_at limit 512) rr),'[]') as rounds
  from public.player_tournaments t where p_admin or (t.published and t.status in('registration','in_progress') and (t.ends_at is null or t.ends_at>now()))
  order by t.created_at desc limit 50) q;
 return result;
end $$;

do $$ declare signature text;begin
 foreach signature in array array['admin_create_reward_code(text,jsonb,integer,timestamptz)','admin_list_reward_codes()','admin_set_reward_code_active(text,boolean)','claim_gift_code(text)','admin_save_tournament(text,text,timestamptz,text,integer,boolean,timestamptz,uuid)','admin_tournament_action(uuid,text)','enter_player_tournament(uuid)','get_tournament_hub(boolean)'] loop
  execute 'revoke all on function public.'||signature||' from public,anon';execute 'grant execute on function public.'||signature||' to authenticated';
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
