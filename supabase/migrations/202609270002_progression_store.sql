-- Mythic Clash expansion: player details, progression, history, saved decks and store.
begin;

alter table public.profiles add column if not exists nickname text;
update public.profiles set nickname=display_name where nickname is null or nickname='';
alter table public.profiles alter column nickname set default 'Lenda';
alter table public.profiles alter column nickname set not null;
alter table public.profiles add column if not exists phone text not null default '';
alter table public.profiles add column if not exists age smallint;
do $$ begin
  if not exists(select 1 from pg_constraint where conname='profiles_age_range') then
    alter table public.profiles add constraint profiles_age_range check (age is null or age between 13 and 120);
  end if;
end $$;
alter table public.profiles add column if not exists xp integer not null default 0 check (xp >= 0);
alter table public.profiles add column if not exists mythic_coins integer not null default 0 check (mythic_coins >= 0);
alter table public.profiles add column if not exists tutorial_completed boolean not null default false;
alter table public.profiles add column if not exists equipped_avatar text not null default 'default';
alter table public.profiles add column if not exists equipped_battlefield text not null default 'battle-forest';
alter table public.profiles add column if not exists equipped_hand text not null default 'hand-heaven';
create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare generated_code text; public_nick text; player_age smallint;
begin
  loop
    generated_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists(select 1 from public.profiles where friend_code = generated_code);
  end loop;
  public_nick:=coalesce(nullif(trim(new.raw_user_meta_data->>'nickname'),''),nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Lenda');
  begin player_age:=nullif(new.raw_user_meta_data->>'age','')::smallint; exception when others then player_age:=null; end;
  if player_age is not null and player_age not between 13 and 120 then player_age:=null; end if;
  insert into public.profiles(id,display_name,nickname,friend_code,phone,age)
  values(new.id,public_nick,public_nick,generated_code,coalesce(new.raw_user_meta_data->>'phone',''),player_age);
  return new;
end;
$$;

create table if not exists public.player_saved_decks (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  slot smallint not null check (slot between 1 and 5),
  name text not null check (char_length(name) between 1 and 24),
  card_counts jsonb not null check (jsonb_typeof(card_counts)='object'),
  updated_at timestamptz not null default now(),
  unique(player_id,slot)
);
alter table public.player_saved_decks enable row level security;
drop policy if exists "Players manage their five deck slots" on public.player_saved_decks;
create policy "Players manage their five deck slots" on public.player_saved_decks for all to authenticated
  using (player_id=auth.uid()) with check (player_id=auth.uid());
grant select,insert,update,delete on public.player_saved_decks to authenticated;

create table if not exists public.match_history (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.game_matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  opponent_name text not null,
  mode text not null check (mode in ('normal','ranked','friend')),
  outcome text not null check (outcome in ('victory','defeat','draw')),
  player_points integer not null default 0,
  opponent_points integer not null default 0,
  xp_earned integer not null default 0,
  coins_earned integer not null default 0,
  completed_at timestamptz not null default now(),
  unique(match_id,player_id)
);
alter table public.match_history enable row level security;
drop policy if exists "Players read their own match history" on public.match_history;
create policy "Players read their own match history" on public.match_history for select to authenticated using (player_id=auth.uid());
grant select on public.match_history to authenticated;

create or replace function public.reward_completed_match()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  one_score integer := coalesce((new.state->'totalPoints'->>'player_one')::integer,0);
  two_score integer := coalesce((new.state->'totalPoints'->>'player_two')::integer,0);
  one_name text; two_name text;
  one_outcome text; two_outcome text;
  one_xp integer; two_xp integer; one_coins integer; two_coins integer;
  inserted_rows integer;
begin
  if new.status <> 'completed' or old.status = 'completed' then return new; end if;
  select coalesce(nickname,display_name) into one_name from public.profiles where id=new.player_one;
  select coalesce(nickname,display_name) into two_name from public.profiles where id=new.player_two;
  if new.winner_id is null then
    one_outcome:='draw';two_outcome:='draw';one_xp:=15;two_xp:=15;one_coins:=10;two_coins:=10;
  elsif new.winner_id=new.player_one then
    one_outcome:='victory';two_outcome:='defeat';one_xp:=30;two_xp:=20;one_coins:=20;two_coins:=10;
  else
    one_outcome:='defeat';two_outcome:='victory';one_xp:=20;two_xp:=30;one_coins:=10;two_coins:=20;
  end if;
  insert into public.match_history(match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)
  values(new.id,new.player_one,two_name,new.mode,one_outcome,one_score,two_score,one_xp,one_coins),
        (new.id,new.player_two,one_name,new.mode,two_outcome,two_score,one_score,two_xp,two_coins)
  on conflict(match_id,player_id) do nothing;
  get diagnostics inserted_rows = row_count;
  if inserted_rows > 0 then
    update public.profiles set xp=xp+one_xp,mythic_coins=mythic_coins+one_coins where id=new.player_one;
    update public.profiles set xp=xp+two_xp,mythic_coins=mythic_coins+two_coins where id=new.player_two;
  end if;
  return new;
end;
$$;
drop trigger if exists reward_completed_game_match on public.game_matches;
create trigger reward_completed_game_match after update of status on public.game_matches
for each row execute function public.reward_completed_match();

create table if not exists public.shop_catalog (
  item_id text primary key,
  title text not null,
  description text not null,
  kind text not null check(kind in ('avatar','battlefield','hand','card')),
  price integer not null check(price >= 0),
  asset_path text not null,
  card_id text,
  active boolean not null default true
);
insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id) values
 ('card-athena','Atena, Guardiã','Uma cópia extra de Atena para montar seu deck.','card',200,'assets/card-back.svg','athena'),
 ('ares-helm','Capacete de Ares','Um ornamento de perfil inspirado no deus da guerra.','avatar',120,'assets/ares-helm.svg',null),
 ('battle-forest','Bosque da Convergência','Textura de floresta para seu campo de batalha.','battlefield',180,'assets/battlefield-forest.png',null),
 ('battle-mud','Pântano Antigo','Uma textura de pântano para o campo de batalha.','battlefield',180,'assets/battlefield-mud.png',null),
 ('hand-heaven','Jardins Celestes','Textura dourada para a sua mão.','hand',150,'assets/hand-heaven.png',null),
 ('hand-forest','Folhas da Convergência','Uma textura de floresta para a sua mão.','hand',150,'assets/battlefield-forest.png',null)
on conflict(item_id) do update set title=excluded.title,description=excluded.description,kind=excluded.kind,price=excluded.price,asset_path=excluded.asset_path,card_id=excluded.card_id,active=true;
alter table public.shop_catalog enable row level security;
drop policy if exists "Anyone can view active shop items" on public.shop_catalog;
create policy "Anyone can view active shop items" on public.shop_catalog for select using(active);
grant select on public.shop_catalog to anon,authenticated;
create table if not exists public.player_inventory (
  player_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.shop_catalog(item_id),
  acquired_at timestamptz not null default now(),
  primary key(player_id,item_id)
);
alter table public.player_inventory enable row level security;
drop policy if exists "Players view their own inventory" on public.player_inventory;
create policy "Players view their own inventory" on public.player_inventory for select to authenticated using(player_id=auth.uid());
grant select on public.player_inventory to authenticated;
update public.profiles set equipped_battlefield='battle-forest' where equipped_battlefield='forest';
update public.profiles set equipped_hand='hand-heaven' where equipped_hand='heaven';
insert into public.player_inventory(player_id,item_id) select id,'battle-forest' from public.profiles on conflict do nothing;
insert into public.player_inventory(player_id,item_id) select id,'hand-heaven' from public.profiles on conflict do nothing;

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); item public.shop_catalog%rowtype; balance integer;
begin
  if uid is null then raise exception 'Entre na conta para comprar.'; end if;
  select * into item from public.shop_catalog where item_id=p_item_id and active for update;
  if not found then raise exception 'Este item não está disponível.'; end if;
  if item.kind<>'card' and exists(select 1 from public.player_inventory where player_id=uid and item_id=p_item_id) then raise exception 'Você já possui este item.'; end if;
  update public.profiles set mythic_coins=mythic_coins-item.price where id=uid and mythic_coins>=item.price returning mythic_coins into balance;
  if not found then raise exception 'Você ainda não tem Mythic Coins suficientes.'; end if;
  insert into public.player_inventory(player_id,item_id) values(uid,p_item_id) on conflict do nothing;
  if item.kind='card' and item.card_id is not null then insert into public.player_card_copies(player_id,card_id,copies) values(uid,item.card_id,1) on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1; end if;
  return jsonb_build_object('item_id',item.item_id,'balance',balance);
end;
$$;
revoke all on function public.purchase_shop_item(text) from public,anon;
grant execute on function public.purchase_shop_item(text) to authenticated;

create or replace function public.equip_shop_item(p_item_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); item public.shop_catalog%rowtype;
begin
  if uid is null then raise exception 'Entre na conta para equipar itens.'; end if;
  select c.* into item from public.shop_catalog c join public.player_inventory i on i.item_id=c.item_id where c.item_id=p_item_id and i.player_id=uid;
  if not found then raise exception 'Você ainda não possui este item.'; end if;
  if item.kind='avatar' then update public.profiles set equipped_avatar=item.item_id where id=uid;
  elsif item.kind='battlefield' then update public.profiles set equipped_battlefield=item.item_id where id=uid;
  elsif item.kind='hand' then update public.profiles set equipped_hand=item.item_id where id=uid;
  end if;
end;
$$;
revoke all on function public.equip_shop_item(text) from public,anon;
grant execute on function public.equip_shop_item(text) to authenticated;

create table if not exists public.redeem_codes (
  code text primary key check(code=upper(code)),
  reward_type text not null check(reward_type in ('coins','item','card')),
  reward_amount integer not null default 0 check(reward_amount>=0),
  item_id text references public.shop_catalog(item_id),
  card_id text,
  max_uses integer not null default 1 check(max_uses>0),
  uses integer not null default 0 check(uses>=0),
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.redeem_codes enable row level security;
revoke all on public.redeem_codes from anon,authenticated;
create table if not exists public.gift_claims (
  player_id uuid not null references public.profiles(id) on delete cascade,
  code text not null references public.redeem_codes(code),
  claimed_at timestamptz not null default now(),
  primary key(player_id,code)
);
alter table public.gift_claims enable row level security;
drop policy if exists "Players read their own gifts" on public.gift_claims;
create policy "Players read their own gifts" on public.gift_claims for select to authenticated using(player_id=auth.uid());
grant select on public.gift_claims to authenticated;
create table if not exists public.player_card_copies (
  player_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  copies integer not null default 0 check(copies>=0),
  primary key(player_id,card_id)
);
alter table public.player_card_copies enable row level security;
drop policy if exists "Players read their own card copies" on public.player_card_copies;
create policy "Players read their own card copies" on public.player_card_copies for select to authenticated using(player_id=auth.uid());
grant select on public.player_card_copies to authenticated;

create or replace function public.claim_gift_code(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); gift public.redeem_codes%rowtype;
begin
  if uid is null then raise exception 'Entre para resgatar presentes.'; end if;
  select * into gift from public.redeem_codes where code=upper(trim(p_code)) and active and (expires_at is null or expires_at>now()) for update;
  if not found then raise exception 'Código inválido ou expirado.'; end if;
  if gift.uses>=gift.max_uses then raise exception 'Este código já atingiu o limite de resgates.'; end if;
  insert into public.gift_claims(player_id,code) values(uid,gift.code) on conflict do nothing;
  if not found then raise exception 'Você já resgatou este código.'; end if;
  update public.redeem_codes set uses=uses+1 where code=gift.code;
  if gift.reward_type='coins' then update public.profiles set mythic_coins=mythic_coins+gift.reward_amount where id=uid;
  elsif gift.reward_type='item' then insert into public.player_inventory(player_id,item_id) values(uid,gift.item_id) on conflict do nothing;
  elsif gift.reward_type='card' then insert into public.player_card_copies(player_id,card_id,copies) values(uid,gift.card_id,greatest(1,gift.reward_amount)) on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+excluded.copies;
  end if;
  return jsonb_build_object('reward_type',gift.reward_type,'amount',gift.reward_amount,'item_id',gift.item_id,'card_id',gift.card_id);
end;
$$;
revoke all on function public.claim_gift_code(text) from public,anon;
grant execute on function public.claim_gift_code(text) to authenticated;

create or replace function public.complete_tutorial_once()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); new_xp integer; new_coins integer;
begin
  if uid is null then raise exception 'Entre para salvar seu tutorial.'; end if;
  update public.profiles set tutorial_completed=true,xp=xp+40,mythic_coins=mythic_coins+30 where id=uid and tutorial_completed=false returning xp,mythic_coins into new_xp,new_coins;
  if not found then return jsonb_build_object('already_completed',true); end if;
  return jsonb_build_object('xp',new_xp,'coins',new_coins);
end;
$$;
revoke all on function public.complete_tutorial_once() from public,anon;
grant execute on function public.complete_tutorial_once() to authenticated;

-- PII remains private to its account; expose only the currently supported editable fields.
grant update(nickname,phone,age,settings,equipped_avatar,equipped_battlefield,equipped_hand) on public.profiles to authenticated;

-- Guardião is local gameplay, so the client can report its outcome once per match.
-- A small per-day cap keeps repeated calls from becoming an unlimited currency source.
alter table public.match_history alter column match_id drop not null;
alter table public.match_history drop constraint if exists match_history_mode_check;
alter table public.match_history add constraint match_history_mode_check check(mode in ('normal','ranked','friend','guardian'));
alter table public.match_history add column if not exists guardian_match_id uuid;
create unique index if not exists match_history_guardian_unique on public.match_history(guardian_match_id,player_id) where guardian_match_id is not null;
create table if not exists public.guardian_match_claims (
  match_id uuid not null,
  player_id uuid not null references public.profiles(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key(match_id,player_id)
);
alter table public.guardian_match_claims enable row level security;
revoke all on public.guardian_match_claims from anon,authenticated;
create or replace function public.record_guardian_match(p_match_id uuid,p_outcome text,p_player_points integer,p_opponent_points integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); earned_xp integer; earned_coins integer; inserted integer;
begin
  if uid is null then raise exception 'Entre na conta para registrar a partida.'; end if;
  if p_match_id is null or p_outcome not in ('victory','defeat','draw') or p_player_points not between 0 and 5000 or p_opponent_points not between 0 and 5000 then raise exception 'Resultado de partida inválido.'; end if;
  if (p_outcome='victory' and p_player_points<=p_opponent_points) or (p_outcome='defeat' and p_player_points>=p_opponent_points) or (p_outcome='draw' and p_player_points<>p_opponent_points) then raise exception 'O resultado não corresponde aos pontos.'; end if;
  if (select count(*) from public.guardian_match_claims where player_id=uid and claimed_at >= date_trunc('day',now()))>=5 then raise exception 'Limite diário de partidas recompensadas contra o Guardião atingido.'; end if;
  insert into public.guardian_match_claims(match_id,player_id) values(p_match_id,uid) on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted=0 then return jsonb_build_object('already_recorded',true); end if;
  if p_outcome='victory' then earned_xp:=30;earned_coins:=20; update public.profiles set wins=wins+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;
  elsif p_outcome='defeat' then earned_xp:=20;earned_coins:=10; update public.profiles set losses=losses+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;
  else earned_xp:=15;earned_coins:=10; update public.profiles set xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid; end if;
  insert into public.match_history(match_id,guardian_match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)
  values(null,p_match_id,uid,'Guardião da Arena','guardian',p_outcome,p_player_points,p_opponent_points,earned_xp,earned_coins);
  return jsonb_build_object('xp_earned',earned_xp,'coins_earned',earned_coins);
end;
$$;
revoke all on function public.record_guardian_match(uuid,text,integer,integer) from public,anon;
grant execute on function public.record_guardian_match(uuid,text,integer,integer) to authenticated;


-- Keep server-authoritative matchmaking compatible with the additional terrain card.
create or replace function public._new_online_game_state(p_one uuid,p_two uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  counts jsonb;
  shuffled text[];
  one_state jsonb;
  two_state jsonb;
begin
  for counts in select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2}'::jsonb)
    from (select 1) seed left join public.player_decks d on d.player_id=p_one
  loop
    if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then
      raise exception 'Os dois jogadores precisam de um baralho entre 12 e 20 cartas.';
    end if;
    if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia') or value !~ '^(0|[1-9]|1[0-9]|20)$') then
      raise exception 'O baralho contém quantidade ou carta inválida.';
    end if;
    select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
    one_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:5]),'deck',to_jsonb(shuffled[6:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',1,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  end loop;
  select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2}'::jsonb) into counts
    from (select 1) seed left join public.player_decks d on d.player_id=p_two;
  if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then raise exception 'O baralho do segundo jogador precisa ter entre 12 e 20 cartas.'; end if;
  if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia') or value !~ '^(0|[1-9]|1[0-9]|20)$') then raise exception 'O segundo baralho contém quantidade ou carta inválida.'; end if;
  select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
  two_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:4]),'deck',to_jsonb(shuffled[5:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',0,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  return jsonb_build_object('player_one',one_state,'player_two',two_state,'round',1,'roundCycles',0,'current_turn',p_one,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),'totalPoints',jsonb_build_object('player_one',0,'player_two',0),'roundWins',jsonb_build_object('player_one',0,'player_two',0),'finished',false,'winner_id',null,'log',jsonb_build_array('A batalha online começou.'));
end;
$$;
revoke all on function public._new_online_game_state(uuid,uuid) from public,anon,authenticated;
create or replace function public._online_unit_power(p_side jsonb,p_unit jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path = '' stable as $$
declare cid text:=p_unit->>'cardId'; base_power integer; soldiers integer; faction text; bonus integer:=coalesce((p_unit->>'bonus')::integer,0); total integer;
begin
  select count(*) into soldiers from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='soldado-esparta';
  base_power:=case cid when 'soldado-esparta' then 3*(2^greatest(soldiers-1,0))::integer when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 else 0 end;
  faction:=case when cid in ('soldado-esparta','athena','grecia') then 'greek' when cid in ('guardiao-nordico','mjolnir','runas-nordicas') then 'norse' else '' end;
  total:=base_power+bonus;
  if faction='greek' then total:=total+coalesce((p_side->>'greekAura')::integer,0)+case when p_zones->>'local'='grecia' then 1 else 0 end+case when p_zones->>'terrain'='campo-troia' then 1 else 0 end; end if;
  if faction='norse' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
  return greatest(0,total);
end;
$$;
revoke all on function public._online_unit_power(jsonb,jsonb,jsonb) from public,anon,authenticated;
create or replace function public.submit_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql security definer set search_path = '' as $$
declare
  g public.game_matches%rowtype; s jsonb; side_key text; other_key text; side jsonb; other_side jsonb;
  action_type text:=p_action->>'type'; card_id text; card_idx integer; lane integer; hand_array jsonb; deck_array jsonb; field_array jsonb; unit jsonb;
  target_idx integer; target_power integer; candidate_power integer; best_bonus integer; zones jsonb;
  current_player uuid; next_player uuid; one_score integer; two_score integer; one_total integer; two_total integer; next_round integer;
  one_state jsonb; two_state jsonb; winner uuid; finished boolean:=false; round_advanced boolean:=false; i integer; j integer; ids jsonb;
begin
  if auth.uid() is null then raise exception 'Faça login para jogar.'; end if;
  select * into g from public.game_matches where id=p_match_id for update;
  if not found or g.status<>'active' then raise exception 'Partida não encontrada ou encerrada.'; end if;
  if auth.uid() not in (g.player_one,g.player_two) then raise exception 'Você não participa desta partida.'; end if;
  if g.turn_user<>auth.uid() then raise exception 'Aguarde a sua vez.'; end if;
  s:=g.state; side_key:=case when auth.uid()=g.player_one then 'player_one' else 'player_two' end;
  other_key:=case when side_key='player_one' then 'player_two' else 'player_one' end;
  side:=s->side_key; other_side:=s->other_key; zones:=s->'sharedZones';
  if coalesce((side->>'passed')::boolean,false) then raise exception 'Você já passou nesta rodada.'; end if;

  if action_type='play' then
    if coalesce((side->>'playedThisTurn')::boolean,false) then raise exception 'Você já jogou uma carta neste turno.'; end if;
    card_id:=p_action->>'card_id';
    if card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia') then raise exception 'Carta inválida.'; end if;
    hand_array:=coalesce(side->'hand','[]'::jsonb);
    select ordinality::integer into card_idx from jsonb_array_elements_text(hand_array) with ordinality h(value,ordinality) where h.value=card_id limit 1;
    if card_idx is null then raise exception 'Essa carta não está na sua mão.'; end if;
    select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into hand_array from jsonb_array_elements(hand_array) with ordinality e(value,ordinality) where ordinality<>card_idx;
    field_array:=coalesce(side->'field','[]'::jsonb); deck_array:=coalesce(side->'deck','[]'::jsonb);
    if card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico') then
      lane:=greatest(0,least(2,coalesce((p_action->>'lane')::integer,0)));
      unit:=jsonb_build_object('cardId',card_id,'bonus',case when card_id='lobo-alfa' then 1 else 0 end,'lane',lane,'slot',jsonb_array_length(field_array));
      field_array:=field_array||jsonb_build_array(unit);
      if card_id='athena' and jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1; end if;
    elsif card_id='mjolnir' then
      if jsonb_array_length(field_array)=0 then raise exception 'Jogue um personagem antes de usar Mjölnir.'; end if;
      target_idx:=0;best_bonus:=-100000; i:=0;
      for unit in select value from jsonb_array_elements(field_array) loop
        candidate_power:=public._online_unit_power(side,unit,zones);
        if candidate_power>best_bonus then best_bonus:=candidate_power;target_idx:=i;end if;
        i:=i+1;
      end loop;
      select coalesce(jsonb_agg(case when ordinality=target_idx+1 then jsonb_set(value,'{bonus}',to_jsonb(coalesce((value->>'bonus')::integer,0)+2),true) else value end order by ordinality),'[]'::jsonb) into field_array from jsonb_array_elements(field_array) with ordinality e(value,ordinality);
    elsif card_id='runas-nordicas' then side:=jsonb_set(side,'{norseAura}',to_jsonb(coalesce((side->>'norseAura')::integer,0)+2),true);
    elsif card_id='grecia' then
      if zones->>'local' is not null then raise exception 'O espaço compartilhado de Local já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{local}','"grecia"'::jsonb,true);
    elsif card_id='eclipse' then
      if zones->>'climate' is not null then raise exception 'O espaço compartilhado de Clima já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{climate}','"eclipse"'::jsonb,true);
      other_side:=jsonb_set(other_side,'{roundPenalty}',to_jsonb(coalesce((other_side->>'roundPenalty')::integer,0)+3),true);
    elsif card_id='campo-troia' then
      if zones->>'terrain' is not null then raise exception 'O espaço compartilhado de Terreno já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{terrain}','"campo-troia"'::jsonb,true);
    end if;
    side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{field}',field_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);
    side:=jsonb_set(side,'{playedThisTurn}','true'::jsonb,true);
    if jsonb_array_length(hand_array)=0 and jsonb_array_length(deck_array)=0 then side:=jsonb_set(side,'{passed}','true'::jsonb,true);end if;
  elsif action_type='pass' then
    side:=jsonb_set(side,'{passed}','true'::jsonb,true);
  else
    raise exception 'Ação de jogo inválida.';
  end if;

  s:=jsonb_set(s,ARRAY[side_key],side,true);s:=jsonb_set(s,ARRAY[other_key],other_side,true);s:=jsonb_set(s,'{sharedZones}',zones,true);
  if (coalesce((side->>'passed')::boolean,false) or (jsonb_array_length(side->'hand')=0 and jsonb_array_length(side->'deck')=0))
     and (coalesce((other_side->>'passed')::boolean,false) or (jsonb_array_length(other_side->'hand')=0 and jsonb_array_length(other_side->'deck')=0)) then
    one_state:=s->'player_one';two_state:=s->'player_two';one_score:=public._online_side_score(one_state,zones);two_score:=public._online_side_score(two_state,zones);
    one_total:=coalesce((s#>>'{totalPoints,player_one}')::integer,0)+one_score;two_total:=coalesce((s#>>'{totalPoints,player_two}')::integer,0)+two_score;
    s:=jsonb_set(s,'{totalPoints,player_one}',to_jsonb(one_total),true);s:=jsonb_set(s,'{totalPoints,player_two}',to_jsonb(two_total),true);
    if one_score>two_score then one_state:=jsonb_set(one_state,'{trixx}',to_jsonb(greatest(0,(one_state->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_one}',to_jsonb(coalesce((s#>>'{roundWins,player_one}')::integer,0)+1),true);
    elsif two_score>one_score then two_state:=jsonb_set(two_state,'{trixx}',to_jsonb(greatest(0,(two_state->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_two}',to_jsonb(coalesce((s#>>'{roundWins,player_two}')::integer,0)+1),true);end if;
    for unit in select value from jsonb_array_elements(coalesce(one_state->'field','[]'::jsonb)) loop one_state:=jsonb_set(one_state,'{underworld}',coalesce(one_state->'underworld','[]'::jsonb)||jsonb_build_array(unit->>'cardId'),true);end loop;
    for unit in select value from jsonb_array_elements(coalesce(two_state->'field','[]'::jsonb)) loop two_state:=jsonb_set(two_state,'{underworld}',coalesce(two_state->'underworld','[]'::jsonb)||jsonb_build_array(unit->>'cardId'),true);end loop;
    one_state:=jsonb_set(one_state,'{field}','[]'::jsonb,true);two_state:=jsonb_set(two_state,'{field}','[]'::jsonb,true);
    for i in 1..2 loop
      ids:=case when i=1 then one_state else two_state end;
      ids:=jsonb_set(ids,'{roundPenalty}','0'::jsonb,true);ids:=jsonb_set(ids,'{greekAura}','0'::jsonb,true);ids:=jsonb_set(ids,'{norseAura}','0'::jsonb,true);
      ids:=jsonb_set(ids,'{playedThisTurn}','false'::jsonb,true);ids:=jsonb_set(ids,'{passed}','false'::jsonb,true);ids:=jsonb_set(ids,'{turnsTaken}','0'::jsonb,true);
      deck_array:=coalesce(ids->'deck','[]'::jsonb);hand_array:=coalesce(ids->'hand','[]'::jsonb);
      for j in 1..2 loop if jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;end if;end loop;
      ids:=jsonb_set(ids,'{hand}',hand_array,true);ids:=jsonb_set(ids,'{deck}',deck_array,true);
      if i=1 then one_state:=ids;else two_state:=ids;end if;
    end loop;
    s:=jsonb_set(s,'{player_one}',one_state,true);s:=jsonb_set(s,'{player_two}',two_state,true);s:=jsonb_set(s,'{sharedZones}',jsonb_build_object('local',null,'terrain',null,'climate',null),true);
    next_round:=(s->>'round')::integer+1;
    if next_round<=2 or (next_round=3 and one_total=two_total) then
      round_advanced:=true;s:=jsonb_set(s,'{round}',to_jsonb(next_round),true);current_player:=g.player_one;
    else
      finished:=true;winner:=case when one_total>two_total then g.player_one when two_total>one_total then g.player_two else null end;
      s:=jsonb_set(s,'{finished}','true'::jsonb,true);s:=jsonb_set(s,'{winner_id}',coalesce(to_jsonb(winner),'null'::jsonb),true);s:=jsonb_set(s,'{lastRoundPoints}',jsonb_build_object('player_one',one_score,'player_two',two_score),true);
    end if;
  end if;

  if not finished and round_advanced then
    side_key:='player_one';side:=s->side_key;side:=jsonb_set(side,'{turnsTaken}','1'::jsonb,true);side:=jsonb_set(side,'{playedThisTurn}','false'::jsonb,true);
    deck_array:=coalesce(side->'deck','[]'::jsonb);hand_array:=coalesce(side->'hand','[]'::jsonb);
    if jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;end if;
    side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);s:=jsonb_set(s,ARRAY[side_key],side,true);
  elsif not finished then
    s:=jsonb_set(s,ARRAY[side_key],side,true);s:=jsonb_set(s,ARRAY[other_key],other_side,true);
    if coalesce((s#>>ARRAY[other_key,'passed'])::boolean,false) then current_player:=auth.uid();else current_player:=case when side_key='player_one' then g.player_two else g.player_one end;end if;
    next_player:=current_player;
    side_key:=case when next_player=g.player_one then 'player_one' else 'player_two' end;side:=s->side_key;
    if not coalesce((side->>'passed')::boolean,false) then
      side:=jsonb_set(side,'{playedThisTurn}','false'::jsonb,true);side:=jsonb_set(side,'{turnsTaken}',to_jsonb(coalesce((side->>'turnsTaken')::integer,0)+1),true);
      if mod((side->>'turnsTaken')::integer,2)=1 and jsonb_array_length(coalesce(side->'deck','[]'::jsonb))>0 then
        deck_array:=side->'deck';hand_array:=coalesce(side->'hand','[]'::jsonb)||jsonb_build_array(deck_array->0);
        select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;
        side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);
      end if;
      if jsonb_array_length(coalesce(side->'hand','[]'::jsonb))=0 and jsonb_array_length(coalesce(side->'deck','[]'::jsonb))=0 then side:=jsonb_set(side,'{passed}','true'::jsonb,true);end if;
    end if;
    s:=jsonb_set(s,ARRAY[side_key],side,true);
    if coalesce((s#>>'{player_one,passed}')::boolean,false) and coalesce((s#>>'{player_two,passed}')::boolean,false) then
      -- Both sides exhausted during an automatic turn start; the next action closes the round.
      current_player:=case when side_key='player_one' then g.player_two else g.player_one end;
    end if;
  end if;

  update public.game_matches set state=s,turn_user=case when finished then null else current_player end,
    status=case when finished then 'completed' else 'active' end,winner_id=winner,finished_at=case when finished then now() else null end
    where id=p_match_id returning * into g;
  if finished and winner is not null then
    update public.profiles set wins=wins+1,rating_points=rating_points+case when g.mode='ranked' then 25 else 0 end where id=winner;
    update public.profiles set losses=losses+1,rating_points=greatest(0,rating_points-case when g.mode='ranked' then 25 else 0 end) where id in (g.player_one,g.player_two) and id<>winner;
  end if;
  return g;
end;
$$;
revoke all on function public.submit_game_action(uuid,jsonb) from public,anon;
grant execute on function public.submit_game_action(uuid,jsonb) to authenticated;

commit;


