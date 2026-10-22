begin;
create table if not exists public.solo_mode_settings(id text primary key check(id='tiebreak'),enabled boolean not null default false,updated_at timestamptz not null default now());
insert into public.solo_mode_settings(id) values('tiebreak') on conflict do nothing;
create table if not exists public.solo_tiebreak_runs(player_id uuid not null references public.profiles(id) on delete cascade,request_id uuid not null,payload jsonb not null,created_at timestamptz not null default now(),primary key(player_id,request_id));
alter table public.solo_mode_settings enable row level security;
alter table public.solo_tiebreak_runs enable row level security;
revoke all on public.solo_mode_settings,public.solo_tiebreak_runs from public,anon,authenticated;
create or replace function public.get_solo_modes() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('tiebreak',coalesce((select s.enabled from public.solo_mode_settings s where s.id='tiebreak'),false))
$$;
create or replace function public.admin_set_solo_tiebreak(p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.is_site_admin() then raise exception 'Sem permissão.';end if;
 update public.solo_mode_settings s set enabled=p_enabled,updated_at=now() where s.id='tiebreak';
end $$;
create or replace function public.start_solo_tiebreak(p_slot integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();counts jsonb;pool jsonb;enemy jsonb;result jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 perform 1 from public.profiles p where p.id=uid for update;
 select r.payload into result from public.solo_tiebreak_runs r where r.player_id=uid and r.request_id=p_request_id;
 if result is not null then return result;end if;
 if not coalesce((select s.enabled from public.solo_mode_settings s where s.id='tiebreak'),false) then raise exception 'O modo Desempate não está disponível agora.';end if;
 if exists(select 1 from public.solo_tiebreak_runs r where r.player_id=uid and r.created_at>now()-interval '3 seconds') then raise exception 'Aguarde a revelação atual.';end if;
 select d.card_counts into counts from public.player_saved_decks d where d.player_id=uid and d.slot=p_slot;
 if counts is null then raise exception 'Escolha um baralho salvo.';end if;
 perform public._assert_owned_deck(uid,counts);
 select coalesce(jsonb_agg(e.key),'[]') into pool from jsonb_each_text(counts) e cross join lateral generate_series(1,e.value::integer) n
 where public._r_card(e.key)->>'kind'='unit' and not coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false);
 if jsonb_array_length(pool)=0 then raise exception 'O baralho precisa de personagens para a puxada.';end if;
 select coalesce(jsonb_agg(c->>'id'),'[]') into enemy from jsonb_array_elements(public._r_data()->'cards') c
 where c->>'kind'='unit' and not coalesce((c->>'specialOnly')::boolean,false) and not coalesce((c->>'previewOnly')::boolean,false);
 result:=public._tb_random_result(pool,enemy)||jsonb_build_object('standalone',true,'match_id',p_request_id,'my_side','player_one','player_one_name','Você','player_two_name','Guardião do Destino');
 insert into public.solo_tiebreak_runs(player_id,request_id,payload) values(uid,p_request_id,result);
 return result;
end $$;
revoke all on function public.get_solo_modes(),public.admin_set_solo_tiebreak(boolean),public.start_solo_tiebreak(integer,uuid) from public,anon;
grant execute on function public.get_solo_modes(),public.admin_set_solo_tiebreak(boolean),public.start_solo_tiebreak(integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
