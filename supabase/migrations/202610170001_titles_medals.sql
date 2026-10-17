-- Permanent cosmetic honors, calculated from server records. Run after prior migrations.
begin;
create table if not exists public.honor_catalog (
 id text primary key, kind text not null check(kind in ('title','medal')),
 name text not null, description text not null, icon text not null,
 metric text not null, target integer not null check(target>=0), position integer not null
);
create table if not exists public.player_honors (
 player_id uuid not null references public.profiles(id) on delete cascade,
 honor_id text not null references public.honor_catalog(id), earned_at timestamptz not null default now(),
 primary key(player_id,honor_id)
);
create table if not exists public.player_honor_display (
 player_id uuid primary key references public.profiles(id) on delete cascade,
 title_id text references public.honor_catalog(id), medals text[] not null default '{}',
 check(cardinality(medals)<=3)
);
alter table public.honor_catalog enable row level security;
alter table public.player_honors enable row level security;
alter table public.player_honor_display enable row level security;
revoke all on public.honor_catalog,public.player_honors,public.player_honor_display from anon,authenticated;

insert into public.honor_catalog(id,kind,name,description,icon,metric,target,position) values
 ('traveler','title','Viajante da Convergência','Comece sua jornada.','✦','matches',0,1),
 ('initiate','title','Iniciado da Arena','Conclua o tutorial.','⚔','tutorial',1,2),
 ('victor','title','Portador da Vitória','Vença sua primeira partida.','♜','wins',1,3),
 ('veteran','title','Veterano da Arena','Conclua 25 partidas.','⛨','matches',25,4),
 ('ranked-champion','title','Campeão Ranqueado','Vença 10 partidas ranqueadas.','♛','ranked_wins',10,5),
 ('duelist','title','Duelista Lendário','Vença 10 desafios X1.','⚔','friend_wins',10,6),
 ('conqueror','title','Conquistador de Mundos','Some 50 vitórias.','♔','wins',50,7),
 ('immortal','title','Lenda Imortal','Some 100 vitórias.','☀','wins',100,8),
 ('first-step','medal','Primeiros Passos','Conclua o tutorial.','✦','tutorial',1,11),
 ('first-victory','medal','Primeira Vitória','Vença uma partida.','⚔','wins',1,12),
 ('ten-wins','medal','Glória de Bronze','Some 10 vitórias.','⛨','wins',10,13),
 ('fifty-wins','medal','Glória de Prata','Some 50 vitórias.','♜','wins',50,14),
 ('hundred-wins','medal','Glória de Ouro','Some 100 vitórias.','♛','wins',100,15),
 ('twenty-five','medal','Explorador da Arena','Conclua 25 partidas.','◇','matches',25,16),
 ('hundred-games','medal','Cem Batalhas','Conclua 100 partidas.','♔','matches',100,17),
 ('ranked-ten','medal','Ascensão Competitiva','Vença 10 partidas ranqueadas.','✧','ranked_wins',10,18),
 ('friend-ten','medal','Rival Respeitado','Vença 10 desafios X1.','⚔','friend_wins',10,19),
 ('guardian-ten','medal','Guardião Superado','Vença o Guardião 10 vezes.','♜','guardian_wins',10,20)
on conflict(id) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,metric=excluded.metric,target=excluded.target,position=excluded.position;

create or replace function public.get_player_honors(p_player_id uuid default auth.uid())
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_metrics jsonb; v_result jsonb;
begin
 if v_uid is null then raise exception 'Entre na sua conta.'; end if;
 if p_player_id is null or not exists(select 1 from public.profiles where id=p_player_id) then raise exception 'Jogador não encontrado.'; end if;
 if p_player_id<>v_uid and not exists(select 1 from public.friendships f where f.status='accepted' and ((f.user_a=v_uid and f.user_b=p_player_id) or (f.user_b=v_uid and f.user_a=p_player_id))) then
   raise exception 'Você só pode consultar as conquistas de um amigo.';
 end if;
 select jsonb_build_object('matches',count(*),'wins',count(*) filter(where outcome='victory'),
   'ranked_wins',count(*) filter(where outcome='victory' and mode='ranked'),
   'friend_wins',count(*) filter(where outcome='victory' and mode='friend'),
   'guardian_wins',count(*) filter(where outcome='victory' and mode='guardian'))
 into v_metrics from public.match_history where player_id=p_player_id;
 v_metrics:=v_metrics||jsonb_build_object('tutorial',case when (select tutorial_completed from public.profiles where id=p_player_id) then 1 else 0 end);
 insert into public.player_honors(player_id,honor_id)
 select p_player_id,c.id from public.honor_catalog c where coalesce((v_metrics->>c.metric)::bigint,0)>=c.target
 on conflict do nothing;
 insert into public.player_honor_display(player_id) values(p_player_id) on conflict do nothing;
 select jsonb_build_object('player_id',p_player_id,'title_id',d.title_id,'medals',to_jsonb(d.medals),
   'catalog',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'kind',c.kind,'name',c.name,'description',c.description,'icon',c.icon,
      'target',c.target,'progress',least(coalesce((v_metrics->>c.metric)::bigint,0),c.target),
      'unlocked',h.honor_id is not null,'earned_at',h.earned_at) order by c.position),'[]'::jsonb)
    from public.honor_catalog c left join public.player_honors h on h.honor_id=c.id and h.player_id=p_player_id))
 into v_result from public.player_honor_display d where d.player_id=p_player_id;
 return v_result;
end; $$;

create or replace function public.equip_player_honors(p_title text default null,p_medals text[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'Entre na sua conta.'; end if;
 perform public.get_player_honors(v_uid);
 p_medals:=coalesce(p_medals,'{}'::text[]);
 if cardinality(p_medals)>3 or array_position(p_medals,null) is not null or cardinality(p_medals)<>(select count(distinct x) from unnest(p_medals) x) then raise exception 'Escolha até três medalhas diferentes.'; end if;
 if p_title is not null and not exists(select 1 from public.player_honors h join public.honor_catalog c on c.id=h.honor_id where h.player_id=v_uid and c.id=p_title and c.kind='title') then raise exception 'Título ainda bloqueado.'; end if;
 if exists(select 1 from unnest(p_medals) x where not exists(select 1 from public.player_honors h join public.honor_catalog c on c.id=h.honor_id where h.player_id=v_uid and c.id=x and c.kind='medal')) then raise exception 'Medalha ainda bloqueada.'; end if;
 update public.player_honor_display set title_id=p_title,medals=p_medals where player_id=v_uid;
 return public.get_player_honors(v_uid);
end; $$;
revoke all on function public.get_player_honors(uuid),public.equip_player_honors(text,text[]) from public,anon;
grant execute on function public.get_player_honors(uuid),public.equip_player_honors(text,text[]) to authenticated;
commit;
