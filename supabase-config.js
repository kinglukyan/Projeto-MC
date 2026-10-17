-- Registra cartas jogadas e decks utilizados em partidas online; libera o resumo apenas ao jogador e a amigos aceitos.
begin;

create table if not exists public.player_card_usage (
  player_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  plays bigint not null default 0 check (plays >= 0),
  last_played_at timestamptz not null default now(),
  primary key (player_id, card_id)
);
alter table public.player_card_usage enable row level security;
drop policy if exists "Players read their own card usage" on public.player_card_usage;
create policy "Players read their own card usage" on public.player_card_usage for select to authenticated using (player_id=auth.uid());
revoke all on public.player_card_usage from public, anon;
grant select on public.player_card_usage to authenticated;

create table if not exists public.player_deck_usage (
  player_id uuid not null references public.profiles(id) on delete cascade,
  deck_key text not null,
  deck_name text not null,
  card_counts jsonb not null check (jsonb_typeof(card_counts)='object'),
  games_played bigint not null default 0,
  victories bigint not null default 0,
  defeats bigint not null default 0,
  draws bigint not null default 0,
  last_used_at timestamptz not null default now(),
  primary key (player_id, deck_key)
);
alter table public.player_deck_usage enable row level security;
drop policy if exists "Players read their own deck usage" on public.player_deck_usage;
create policy "Players read their own deck usage" on public.player_deck_usage for select to authenticated using (player_id=auth.uid());
revoke all on public.player_deck_usage from public, anon;
grant select on public.player_deck_usage to authenticated;

create table if not exists public.player_match_decks (
  match_id uuid not null references public.game_matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  deck_key text not null,
  primary key (match_id, player_id)
);
alter table public.player_match_decks enable row level security;
revoke all on public.player_match_decks from public, anon, authenticated;

create or replace function public.track_player_match_usage()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_player uuid;
  v_side text;
  v_all_cards jsonb;
  v_counts jsonb;
  v_key text;
  v_name text;
  v_old_hand jsonb;
  v_new_hand jsonb;
  v_card text;
  v_before integer;
  v_after integer;
  v_amount integer;
begin
  if tg_op='INSERT' then
    for v_player,v_side in
      select new.player_one,'player_one'::text union all select new.player_two,'player_two'::text
    loop
      v_all_cards:=coalesce(new.state->v_side->'hand','[]'::jsonb)||coalesce(new.state->v_side->'deck','[]'::jsonb);
      select coalesce(jsonb_object_agg(card_id,quantity),'{}'::jsonb) into v_counts
      from (select card_id,count(*)::integer quantity from jsonb_array_elements_text(v_all_cards) e(card_id) group by card_id) counts;
      if v_counts='{}'::jsonb then continue; end if;
      v_key:=md5(v_counts::text);
      select name into v_name from public.player_saved_decks where player_id=v_player and card_counts=v_counts order by updated_at desc limit 1;
      v_name:=coalesce(v_name,'Baralho · '||upper(substr(v_key,1,5)));
      insert into public.player_deck_usage(player_id,deck_key,deck_name,card_counts,games_played,last_used_at)
      values(v_player,v_key,v_name,v_counts,1,now())
      on conflict(player_id,deck_key) do update set games_played=public.player_deck_usage.games_played+1,last_used_at=now();
      insert into public.player_match_decks(match_id,player_id,deck_key) values(new.id,v_player,v_key) on conflict do nothing;
    end loop;
    return new;
  end if;

  for v_player,v_side in
    select new.player_one,'player_one'::text union all select new.player_two,'player_two'::text
  loop
    v_old_hand:=coalesce(old.state->v_side->'hand','[]'::jsonb);
    v_new_hand:=coalesce(new.state->v_side->'hand','[]'::jsonb);
    if v_old_hand=v_new_hand then continue; end if;
    for v_card in select distinct e.card_id from jsonb_array_elements_text(v_old_hand) e(card_id)
    loop
      select count(*) into v_before from jsonb_array_elements_text(v_old_hand) e(card_id) where e.card_id=v_card;
      select count(*) into v_after from jsonb_array_elements_text(v_new_hand) e(card_id) where e.card_id=v_card;
      v_amount:=v_before-v_after;
      if v_amount>0 then
        insert into public.player_card_usage(player_id,card_id,plays,last_played_at) values(v_player,v_card,v_amount,now())
        on conflict(player_id,card_id) do update set plays=public.player_card_usage.plays+excluded.plays,last_played_at=now();
      end if;
    end loop;
  end loop;
  return new;
end;
$$;
drop trigger if exists track_player_match_usage on public.game_matches;
create trigger track_player_match_usage after insert or update of state on public.game_matches for each row execute function public.track_player_match_usage();

create or replace function public.track_player_deck_result()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.match_id is null then return new; end if;
  update public.player_deck_usage d set
    victories=d.victories+case when new.outcome='victory' then 1 else 0 end,
    defeats=d.defeats+case when new.outcome='defeat' then 1 else 0 end,
    draws=d.draws+case when new.outcome='draw' then 1 else 0 end
  from public.player_match_decks md
  where md.match_id=new.match_id and md.player_id=new.player_id and d.player_id=md.player_id and d.deck_key=md.deck_key;
  return new;
end;
$$;
drop trigger if exists track_player_deck_result on public.match_history;
create trigger track_player_deck_result after insert on public.match_history for each row execute function public.track_player_deck_result();

create or replace function public.get_player_profile_stats(p_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid:=auth.uid();
  v_profile jsonb;
  v_stats jsonb;
  v_modes jsonb;
  v_cards jsonb;
  v_decks jsonb;
  v_recent jsonb;
begin
  if v_uid is null then raise exception 'Faça login para consultar o perfil.'; end if;
  if p_player_id is null then raise exception 'Jogador não informado.'; end if;
  if p_player_id<>v_uid and not exists(
    select 1 from public.friendships f where f.status='accepted'
      and ((f.user_a=v_uid and f.user_b=p_player_id) or (f.user_b=v_uid and f.user_a=p_player_id))
  ) then raise exception 'Você só pode consultar o perfil de um amigo.'; end if;

  select jsonb_build_object('id',p.id,'display_name',coalesce(nullif(p.nickname,''),p.display_name),
      'rating_points',p.rating_points,'wins',p.wins,'losses',p.losses,'xp',p.xp,
      'level',greatest(case when p.tutorial_completed then 2 else 1 end,floor(coalesce(p.xp,0)::numeric/100)::integer+1),
      'equipped_avatar',p.equipped_avatar)
  into v_profile from public.profiles p where p.id=p_player_id;
  if v_profile is null then raise exception 'Perfil não encontrado.'; end if;

  select jsonb_build_object('matches',count(*),'victories',count(*) filter(where outcome='victory'),
      'defeats',count(*) filter(where outcome='defeat'),'draws',count(*) filter(where outcome='draw'),
      'win_rate',case when count(*)=0 then 0 else round(100.0*count(*) filter(where outcome='victory')/count(*)) end)
  into v_stats from public.match_history where player_id=p_player_id;
  select coalesce(jsonb_object_agg(mode,jsonb_build_object('matches',matches,'victories',victories,'defeats',defeats,'draws',draws)), '{}'::jsonb)
  into v_modes from (select mode,count(*) matches,count(*) filter(where outcome='victory') victories,
      count(*) filter(where outcome='defeat') defeats,count(*) filter(where outcome='draw') draws
    from public.match_history where player_id=p_player_id group by mode) by_mode;
  select coalesce(jsonb_agg(jsonb_build_object('card_id',card_id,'plays',plays) order by plays desc), '[]'::jsonb)
  into v_cards from (select card_id,plays from public.player_card_usage where player_id=p_player_id order by plays desc,last_played_at desc limit 6) top_cards;
  select coalesce(jsonb_agg(jsonb_build_object('deck_key',d.deck_key,'name',d.deck_name,'games',d.games_played,
      'victories',d.victories,'win_rate',case when d.games_played=0 then 0 else round(100.0*d.victories/d.games_played) end)
      order by d.games_played desc,d.last_used_at desc), '[]'::jsonb)
  into v_decks from (select * from public.player_deck_usage where player_id=p_player_id order by games_played desc,last_used_at desc limit 5) d;
  select coalesce(jsonb_agg(jsonb_build_object('opponent',opponent_name,'mode',mode,'outcome',outcome,
      'player_points',player_points,'opponent_points',opponent_points,'completed_at',completed_at) order by completed_at desc), '[]'::jsonb)
  into v_recent from (select opponent_name,mode,outcome,player_points,opponent_points,completed_at from public.match_history
    where player_id=p_player_id order by completed_at desc limit 8) recent;
  return jsonb_build_object('profile',v_profile,'stats',v_stats,'modes',v_modes,'top_cards',v_cards,'top_decks',v_decks,'recent_matches',v_recent);
end;
$$;
revoke all on function public.get_player_profile_stats(uuid) from public,anon;
grant execute on function public.get_player_profile_stats(uuid) to authenticated;

commit;
