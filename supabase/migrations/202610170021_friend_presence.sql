-- Aplicar após 020. Presença visível somente para amigos aceitos.
begin;
create table if not exists public.player_presence(
 player_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null,status text not null check(status in('online','away','offline')),
 touched_at timestamptz not null default clock_timestamp(),primary key(player_id,client_id)
);
alter table public.player_presence enable row level security;
revoke all on public.player_presence from public,anon,authenticated;
create index if not exists player_presence_touched on public.player_presence(touched_at);
create or replace function public.touch_player_presence(p_client_id uuid,p_status text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_client_id is null or p_status is null or p_status not in('online','away','offline') then raise exception 'Presença inválida.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 delete from public.player_presence where player_id=auth.uid() and touched_at<clock_timestamp()-interval '5 minutes';
 if not exists(select 1 from public.player_presence where player_id=auth.uid() and client_id=p_client_id) and (select count(*) from public.player_presence where player_id=auth.uid())>=24 then raise exception 'Limite de conexões atingido.';end if;
 insert into public.player_presence(player_id,client_id,status) values(auth.uid(),p_client_id,p_status)
 on conflict(player_id,client_id) do update set status=excluded.status,touched_at=clock_timestamp();
end $$;
create or replace function public.get_friend_presence() returns jsonb
language sql security definer set search_path='' stable as $$
 select coalesce(jsonb_agg(jsonb_build_object('friend_id',q.friend_id,'status',q.status)),'[]'::jsonb)
 from(select f.friend_id,case when bool_or(p.status='online') then 'online' when bool_or(p.status='away') then 'away' else 'offline' end status
 from(select case when user_a=auth.uid() then user_b else user_a end friend_id from public.friendships where status='accepted' and auth.uid() in(user_a,user_b)) f
 left join public.player_presence p on p.player_id=f.friend_id and p.touched_at>now()-interval '90 seconds'
 group by f.friend_id) q;
$$;
revoke all on function public.touch_player_presence(uuid,text),public.get_friend_presence() from public,anon;
grant execute on function public.touch_player_presence(uuid,text),public.get_friend_presence() to authenticated;
notify pgrst,'reload schema';
commit;
