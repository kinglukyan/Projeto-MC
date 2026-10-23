-- 068: melhorias do Atlas, partidas, administração e pacotes. Aplicar após 066/067.
begin;
-- One round trip: preserve existing action validation and return only the
-- filtered snapshot already used by get_online_match, never raw match state.
create or replace function public.submit_game_action_snapshot(p_match_id uuid,p_action jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare result public.game_matches;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 select * into result from public.submit_game_action(p_match_id,p_action);
 if result.state ? '_securityError' then return jsonb_build_object('accepted',false,'message',result.state#>>'{_securityError,message}');end if;
 return jsonb_build_object('accepted',true,'snapshot',public.get_online_match(p_match_id));
end $$;
revoke all on function public.submit_game_action_snapshot(uuid,jsonb) from public,anon;
grant execute on function public.submit_game_action_snapshot(uuid,jsonb) to authenticated;

alter table public.game_mode_settings add column if not exists reason text not null default '' check(char_length(reason)<=200);
create table if not exists public.game_mode_change_log(
 id bigint generated always as identity primary key,mode_id text not null references public.game_mode_settings(mode_id),
 actor_id uuid references public.profiles(id) on delete set null,old_enabled boolean not null,new_enabled boolean not null,
 old_reason text not null,new_reason text not null,created_at timestamptz not null default now());
alter table public.game_mode_change_log enable row level security;
revoke all on public.game_mode_change_log from public,anon,authenticated;
grant all on public.game_mode_change_log to service_role;
create or replace function public.get_game_mode_details() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(s.mode_id,jsonb_build_object('enabled',(public.get_game_modes()->>s.mode_id)::boolean,'reason',s.reason,'updated_at',s.updated_at)),'{}') from public.game_mode_settings s;
$$;
do $$ begin
 if to_regprocedure('public._admin_set_game_mode_before068(text,boolean)') is null then alter function public.admin_set_game_mode(text,boolean) rename to _admin_set_game_mode_before068;end if;
end $$;
revoke all on function public._admin_set_game_mode_before068(text,boolean) from public,anon,authenticated;
create or replace function public.admin_set_game_mode_details(p_mode text,p_enabled boolean,p_reason text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior public.game_mode_settings%rowtype;mode_reason text:=btrim(coalesce(p_reason,''));
begin
 perform public._assert_account_active();if auth.uid() is null or not public.is_site_admin() then raise exception 'Sem permissão.';end if;
 perform public._security_rpc_gate('admin_set_game_mode',30);
 if char_length(mode_reason)>200 then raise exception 'Use um motivo com até 200 caracteres.';end if;
 select * into prior from public.game_mode_settings where mode_id=p_mode for update;
 if not found then raise exception 'Modo inválido.';end if;
 perform public._admin_set_game_mode_before068(p_mode,p_enabled);
 update public.game_mode_settings set reason=btrim(coalesce(p_reason,'')) where mode_id=p_mode;
 if prior.enabled is distinct from p_enabled or prior.reason is distinct from mode_reason then
  insert into public.game_mode_change_log(mode_id,actor_id,old_enabled,new_enabled,old_reason,new_reason) values(p_mode,auth.uid(),prior.enabled,p_enabled,prior.reason,mode_reason);
 end if;
 return public.get_game_mode_details();
end $$;
create or replace function public.admin_set_game_mode(p_mode text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.admin_set_game_mode_details(p_mode,p_enabled,coalesce((select reason from public.game_mode_settings where mode_id=p_mode),''));return public.get_game_modes();
end $$;
create or replace function public.admin_game_mode_history() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.is_site_admin() then raise exception 'Sem permissão.';end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.id desc) from (select l.id,l.mode_id,l.old_enabled,l.new_enabled,l.old_reason,l.new_reason,l.created_at,coalesce(p.nickname,p.display_name,'Administrador') actor_name from public.game_mode_change_log l left join public.profiles p on p.id=l.actor_id order by l.id desc limit 100) q),'[]');
end $$;
create or replace function public._assert_mode_available066(p_mode text) returns void language plpgsql security definer set search_path='' as $$
declare flag boolean;why text;
begin
 select s.enabled,s.reason into flag,why from public.game_mode_settings s where s.mode_id=p_mode for share;
 if not coalesce(flag,false) then raise exception '%',case when nullif(why,'') is null then 'Este modo de jogo está indisponível no momento.' else 'Modo indisponível: '||why end;end if;
end $$;
revoke all on function public.get_game_mode_details(),public.admin_set_game_mode_details(text,boolean,text),public.admin_set_game_mode(text,boolean),public.admin_game_mode_history() from public,anon;
grant execute on function public.get_game_mode_details(),public.admin_set_game_mode_details(text,boolean,text),public.admin_set_game_mode(text,boolean),public.admin_game_mode_history() to authenticated;

-- Snapshot duplicates BEFORE granting the pack. Historical purchases remain
-- null because their previous collection cannot be reconstructed reliably.
alter table public.basic_pack_purchases add column if not exists duplicate_cards jsonb;
create or replace function public._pack_duplicates068() returns trigger language plpgsql security definer set search_path='' as $$
begin
 select coalesce(jsonb_agg(c->>'id'),'[]') into new.duplicate_cards from jsonb_array_elements(new.cards) c
 where exists(select 1 from public.player_card_copies p where p.player_id=new.player_id and p.card_id=c->>'id' and p.copies>0);
 return new;
end $$;
revoke all on function public._pack_duplicates068() from public,anon,authenticated;
drop trigger if exists pack_duplicates068 on public.basic_pack_purchases;
create trigger pack_duplicates068 before insert on public.basic_pack_purchases for each row execute function public._pack_duplicates068();
create or replace function public._basic_pack_receipt(p_id uuid) returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_build_object('id',b.id,'request_id',b.request_id,'pack_id',b.pack_id,'name',p.name,'edition',p.edition,'front',p.front_asset,'back',p.back_asset,
 'price_paid',b.price_paid,'cards',b.cards,'revealed_count',b.revealed_count,'opened_at',b.opened_at,'purchased_at',b.purchased_at,'duplicate_cards',b.duplicate_cards)
 from public.basic_pack_purchases b join public.basic_card_packs p on p.id=b.pack_id where b.id=p_id
$$;
create or replace function public.reveal_all_basic_pack_cards(p_purchase_id uuid,p_expected_count integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.basic_pack_purchases%rowtype;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform public._security_rpc_gate('reveal_all_basic_pack_cards',30);
 select b.* into p from public.basic_pack_purchases b where b.id=p_purchase_id and b.player_id=auth.uid() for update;
 if not found then raise exception 'Pacote indisponível para esta conta.';end if;
 if p_expected_count is null or p_expected_count<0 or p_expected_count>p.revealed_count then raise exception 'Reabra o pacote para atualizar a abertura.';end if;
 update public.basic_pack_purchases set revealed_count=jsonb_array_length(cards),opened_at=coalesce(opened_at,now()) where id=p.id;
 return public._basic_pack_receipt(p.id);
end $$;
revoke all on function public._basic_pack_receipt(uuid) from public,anon,authenticated;
revoke all on function public.reveal_all_basic_pack_cards(uuid,integer) from public,anon;
grant execute on function public.reveal_all_basic_pack_cards(uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
