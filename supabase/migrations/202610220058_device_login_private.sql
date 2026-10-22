begin;
-- Credentials are only accessible to the Vercel server. No public REST policy.
create table if not exists public.device_login_requests(
 id uuid primary key,
 request_hash text not null,
 approval_hash text not null,
 pairing_code text not null,
 device_label text not null,
 status text not null default 'pending' check(status in ('pending','approved','issuing','ready','consumed','cancelled')),
 approved_by uuid references public.profiles(id) on delete cascade,
 token_hash text,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '3 minutes')
);
create index if not exists device_login_expiry on public.device_login_requests(expires_at);
create table if not exists public.device_login_rate_limits(bucket text primary key,attempts integer not null default 1,expires_at timestamptz not null);
alter table public.device_login_requests enable row level security;
alter table public.device_login_rate_limits enable row level security;
revoke all on public.device_login_requests,public.device_login_rate_limits from public,anon,authenticated;
grant all on public.device_login_requests,public.device_login_rate_limits to service_role;
create or replace function public.device_login_rate_limit(p_bucket text) returns void
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 delete from public.device_login_requests d where d.expires_at<now()-interval '1 hour';
 delete from public.device_login_rate_limits r where r.expires_at<now();
 insert into public.device_login_rate_limits(bucket,expires_at) values(left(p_bucket,120),now()+interval '6 minutes')
 on conflict(bucket) do update set attempts=public.device_login_rate_limits.attempts+1 returning attempts into n;
 if n>10 then raise exception 'Aguarde alguns minutos antes de gerar outro QR Code.';end if;
end $$;
revoke all on function public.device_login_rate_limit(text) from public,anon,authenticated;
grant execute on function public.device_login_rate_limit(text) to service_role;
notify pgrst,'reload schema';
commit;
