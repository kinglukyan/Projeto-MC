begin;
alter table public.guilds add column if not exists discoverable boolean not null default true;
create table if not exists public.guild_requests(
 id uuid primary key default gen_random_uuid(),
 guild_id uuid not null references public.guilds(id) on delete cascade,
 player_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 kind text not null check(kind in ('application','invitation')),
 status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now(),
 unique(guild_id,player_id,kind)
);
create table if not exists public.community_deck_favorites(
 deck_id uuid not null references public.community_decks(id) on delete cascade,
 player_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(deck_id,player_id)
);
alter table public.guild_requests enable row level security;
alter table public.community_deck_favorites enable row level security;
revoke all on public.guild_requests,public.community_deck_favorites from anon,authenticated;
create index if not exists guild_requests_pending on public.guild_requests(guild_id,status);
create index if not exists community_decks_date on public.community_decks(created_at desc,id);

create or replace function public.guild_social_hub(p_search text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gid uuid; my_role text; result jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 select m.guild_id,m.role into gid,my_role from public.guild_members m where m.player_id=uid;
 select jsonb_build_object('guild',case when gid is null then null else
  (select to_jsonb(g)||jsonb_build_object('role',my_role) from public.guilds g where g.id=gid) end,
  'members',coalesce((select jsonb_agg(jsonb_build_object('id',m.player_id,'name',coalesce(p.nickname,p.display_name,'Jogador'),'avatar',p.equipped_avatar,'role',m.role) order by m.joined_at)
   from public.guild_members m join public.profiles p on p.id=m.player_id where m.guild_id=gid),'[]'),
  'requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'kind',q.kind,'guild',g.name,'player',coalesce(p.nickname,p.display_name,'Jogador'),'created_at',q.created_at) order by q.created_at desc)
   from public.guild_requests q join public.guilds g on g.id=q.guild_id join public.profiles p on p.id=q.player_id
   where q.status='pending' and (q.player_id=uid or (q.guild_id=gid and my_role in ('leader','officer')))),'[]'),
  'directory',coalesce((select jsonb_agg(x.payload) from (
   select jsonb_build_object('id',g.id,'name',g.name,'description',g.description,'members',(select count(*) from public.guild_members m where m.guild_id=g.id),
    'applied',exists(select 1 from public.guild_requests q where q.guild_id=g.id and q.player_id=uid and q.kind='application' and q.status='pending')) as payload
   from public.guilds g where g.discoverable and (p_search='' or g.name ilike '%'||left(p_search,80)||'%') order by g.created_at desc limit 40)x),'[]')) into result;
 return result;
end $$;

create or replace function public.guild_social_action(p_action text,p_guild_id uuid default null,p_request_id uuid default null,p_code text default '',p_accept boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gid uuid; my_role text; target uuid; req public.guild_requests%rowtype;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 perform 1 from public.profiles p where p.id=uid for update;
 select m.guild_id,m.role into gid,my_role from public.guild_members m where m.player_id=uid;
 if p_action='apply' then
  if gid is not null then raise exception 'Você já participa de uma guilda.';end if;
  if not exists(select 1 from public.guilds g where g.id=p_guild_id and g.discoverable) then raise exception 'Guilda indisponível.';end if;
  insert into public.guild_requests(guild_id,player_id,actor_id,kind) values(p_guild_id,uid,uid,'application')
   on conflict(guild_id,player_id,kind) do update set status='pending',created_at=now();
 elsif p_action='invite' then
  if gid is null or my_role not in ('leader','officer') then raise exception 'Somente líderes e oficiais podem convidar.';end if;
  select p.id into target from public.profiles p where p.friend_code=upper(trim(p_code));
  if target is null or target=uid then raise exception 'Código de jogador inválido.';end if;
  if exists(select 1 from public.guild_members m where m.player_id=target) then raise exception 'O jogador já participa de uma guilda.';end if;
  insert into public.guild_requests(guild_id,player_id,actor_id,kind) values(gid,target,uid,'invitation')
   on conflict(guild_id,player_id,kind) do update set status='pending',actor_id=uid,created_at=now();
 elsif p_action='respond' then
  select q.* into req from public.guild_requests q where q.id=p_request_id for update;
  if req.id is null or req.status<>'pending' then raise exception 'Solicitação já respondida ou indisponível.';end if;
  if req.kind='invitation' and req.player_id<>uid then raise exception 'Este convite pertence a outro jogador.';end if;
  if req.kind='application' and (gid is distinct from req.guild_id or my_role not in ('leader','officer')) then raise exception 'Sem permissão para aprovar.';end if;
  if p_accept then
   perform 1 from public.profiles p where p.id=req.player_id for update;
   if exists(select 1 from public.guild_members m where m.player_id=req.player_id) then raise exception 'O jogador já participa de uma guilda.';end if;
   insert into public.guild_members(guild_id,player_id) values(req.guild_id,req.player_id);
   update public.guild_requests q set status='cancelled' where q.player_id=req.player_id and q.status='pending' and q.id<>req.id;
  end if;
  update public.guild_requests q set status=case when p_accept then 'accepted' else 'declined' end where q.id=req.id;
 elsif p_action='cancel' then
  update public.guild_requests q set status='cancelled' where q.id=p_request_id and q.player_id=uid and q.kind='application' and q.status='pending';
 elsif p_action='visibility' then
  if gid is null or my_role<>'leader' then raise exception 'Somente o líder pode alterar a visibilidade.';end if;
  update public.guilds g set discoverable=p_accept where g.id=gid;
 elsif p_action='leave' then
  if gid is null then return;end if;
  if my_role='leader' then
   if (select count(*) from public.guild_members m where m.guild_id=gid)>1 then raise exception 'O líder deve permanecer enquanto houver outros membros.';end if;
   delete from public.guilds g where g.id=gid;
  else delete from public.guild_members m where m.player_id=uid;end if;
 else raise exception 'Ação indisponível.';end if;
end $$;

create or replace function public.community_deck_hub(p_search text default '',p_favorites boolean default false,p_sort text default 'recent',p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); result jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 select coalesce(jsonb_agg(x.payload),'[]') into result from (
  select jsonb_build_object('id',d.id,'player_id',d.player_id,'title',d.title,'description',d.description,'deck_code',d.deck_code,'created_at',d.created_at,
   'author',jsonb_build_object('id',p.id,'name',coalesce(p.nickname,p.display_name,'Jogador'),'avatar',p.equipped_avatar,'rating',p.rating_points,'wins',p.wins,'losses',p.losses),
   'votes',(select count(*) from public.community_deck_votes v where v.deck_id=d.id),
   'voted',exists(select 1 from public.community_deck_votes v where v.deck_id=d.id and v.player_id=uid),
   'favorite',exists(select 1 from public.community_deck_favorites f where f.deck_id=d.id and f.player_id=uid)) as payload
  from public.community_decks d join public.profiles p on p.id=d.player_id
  where (p_search='' or d.title||' '||d.description||' '||coalesce(p.nickname,p.display_name,'') ilike '%'||left(p_search,80)||'%')
   and (not p_favorites or exists(select 1 from public.community_deck_favorites f where f.deck_id=d.id and f.player_id=uid))
  order by case when p_sort='votes' then (select count(*) from public.community_deck_votes v where v.deck_id=d.id) else 0 end desc,d.created_at desc,d.id
  limit 24 offset greatest(0,least(p_offset,2400))) x;
 return result;
end $$;

create or replace function public.community_deck_react(p_deck_id uuid,p_kind text,p_enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 if not exists(select 1 from public.community_decks d where d.id=p_deck_id) then raise exception 'Deck indisponível.';end if;
 if p_kind='vote' then
  if p_enabled then insert into public.community_deck_votes(deck_id,player_id) values(p_deck_id,uid) on conflict do nothing;
  else delete from public.community_deck_votes v where v.deck_id=p_deck_id and v.player_id=uid;end if;
 elsif p_kind='favorite' then
  if p_enabled then insert into public.community_deck_favorites(deck_id,player_id) values(p_deck_id,uid) on conflict do nothing;
  else delete from public.community_deck_favorites f where f.deck_id=p_deck_id and f.player_id=uid;end if;
 else raise exception 'Reação inválida.';end if;
end $$;
revoke all on function public.guild_social_hub(text),public.guild_social_action(text,uuid,uuid,text,boolean),public.community_deck_hub(text,boolean,text,integer),public.community_deck_react(uuid,text,boolean) from public,anon;
grant execute on function public.guild_social_hub(text),public.guild_social_action(text,uuid,uuid,text,boolean),public.community_deck_hub(text,boolean,text,integer),public.community_deck_react(uuid,text,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
