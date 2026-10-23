-- 066: disponibilidade central de modos. Aplicar após 065 revisado.
begin;
create table if not exists public.game_mode_settings(
 mode_id text primary key check(mode_id in('atlas','training','normal','ranked','custom','tournament','tiebreak')),
 enabled boolean not null default true,updated_by uuid references public.profiles(id),updated_at timestamptz not null default now());
alter table public.game_mode_settings enable row level security;
revoke all on public.game_mode_settings from public,anon,authenticated;
grant all on public.game_mode_settings to service_role;
insert into public.game_mode_settings(mode_id) values('atlas'),('training'),('normal'),('ranked'),('custom'),('tournament') on conflict do nothing;
insert into public.game_mode_settings(mode_id,enabled) select 'tiebreak',coalesce((select enabled from public.solo_mode_settings where id='tiebreak'),false) on conflict do nothing;
create or replace function public.get_game_modes() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(mode_id,enabled and case when mode_id='tiebreak' then coalesce((select s.enabled from public.solo_mode_settings s where id='tiebreak'),false) else true end),'{}') from public.game_mode_settings;
$$;
create or replace function public._assert_mode_available066(p_mode text) returns void language plpgsql security definer set search_path='' as $$
declare flag boolean;
begin
 select enabled into flag from public.game_mode_settings where mode_id=p_mode for share;
 if not coalesce(flag,false) then raise exception 'Este modo de jogo está indisponível no momento.';end if;
end $$;
create or replace function public.admin_set_game_mode(p_mode text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.is_site_admin() then raise exception 'Sem permissão.';end if;
 if p_enabled is null then raise exception 'Informe a disponibilidade.';end if;
 update public.game_mode_settings set enabled=p_enabled,updated_by=auth.uid(),updated_at=now() where mode_id=p_mode;
 if not found then raise exception 'Modo inválido.';end if;
 if p_mode='tiebreak' then
  update public.solo_mode_settings set enabled=p_enabled,updated_at=now() where id='tiebreak';
  if not p_enabled then delete from public.tiebreak_pvp_queue where match_id is null;end if;
 end if;
 if not p_enabled and p_mode in('normal','ranked') then
  delete from public.matchmaking_queue where mode=p_mode and status='waiting';
  update public.duo_queue_parties set status='ready' where mode=p_mode and status='queued';
 end if;
 perform public._security_event('game_mode_availability','info',null,jsonb_build_object('mode',p_mode,'enabled',p_enabled));
 return public.get_game_modes();
end $$;
-- Inject the guard into existing entry points, preserving their signatures,
-- defaults, return types and current implementations. Reapplication is safe.
do $guards$
declare r record; definition text; guard text;
begin
 for r in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in('join_matchmaking','create_duo_queue','start_duo_lobby_queue','try_match_duo_queue','custom_room_create','custom_room_start','start_guardian_campaign','join_tiebreak_queue','enter_player_tournament','start_tournament_match','create_game_invite','join_game_invite')
 loop
  guard:=case
   when r.proname in('join_matchmaking','create_duo_queue') then 'perform public._assert_mode_available066(p_mode);'
   when r.proname in('start_duo_lobby_queue','try_match_duo_queue') then 'perform public._assert_mode_available066((select mode from public.duo_queue_parties where id=p_party_id));'
   when r.proname in('custom_room_create','custom_room_start') then 'perform public._assert_mode_available066(''custom'');'
   when r.proname='start_guardian_campaign' then 'perform public._assert_mode_available066(''atlas'');'
   when r.proname='join_tiebreak_queue' then 'perform public._assert_mode_available066(''tiebreak'');'
   when r.proname in('enter_player_tournament','start_tournament_match') then 'perform public._assert_mode_available066(''tournament'');'
   when r.proname='create_game_invite' then 'perform public._assert_mode_available066(case when p_mode=''friend'' then ''custom'' else p_mode end);'
   when r.proname='join_game_invite' then 'perform public._assert_mode_available066((select case when mode=''friend'' then ''custom'' else mode end from public.game_invites where code=upper(btrim(p_code))));'
   else 'perform public._assert_mode_available066(''custom'');' end;
  definition:=pg_get_functiondef(r.oid);
  if position('_assert_mode_available066' in definition)=0 then
   if definition !~* '\mBEGIN\M' then raise exception 'Revisar função de entrada: %',r.proname;end if;
   execute regexp_replace(definition,'\mBEGIN\M','BEGIN'||chr(10)||' '||guard,'i');
  end if;
 end loop;
end $guards$;
revoke all on function public._assert_mode_available066(text) from public,anon,authenticated;
revoke all on function public.get_game_modes(),public.admin_set_game_mode(text,boolean) from public,anon;
grant execute on function public.get_game_modes(),public.admin_set_game_mode(text,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
