-- 069: serviços do jogador. Aplicar depois de 068.
begin;
create table public.player_wallet_activity(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id),currency text not null check(currency in('mythic','trixx')),delta bigint not null,balance_after bigint,operation text not null default 'Movimentação de saldo',reference text,tx bigint not null default txid_current(),created_at timestamptz not null default now());
create index on public.player_wallet_activity(player_id,created_at desc);
create function public._wallet_activity069() returns trigger language plpgsql security definer set search_path='' as $$
declare a bigint;b bigint;u uuid;c text;
begin
 if tg_table_name='profiles' then a:=old.mythic_coins;b:=new.mythic_coins;u:=new.id;c:='mythic';else a:=case when tg_op='INSERT' then 0 else old.clash_bits end;b:=new.clash_bits;u:=new.player_id;c:='trixx';end if;
 if b<>coalesce(a,0) then insert into public.player_wallet_activity(player_id,currency,delta,balance_after) values(u,c,b-coalesce(a,0),b);end if;return new;
end $$;
create trigger wallet_profile069 after update of mythic_coins on public.profiles for each row execute function public._wallet_activity069();
create trigger wallet_premium069 after insert or update of clash_bits on public.premium_wallets for each row execute function public._wallet_activity069();
create function public._wallet_label069() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.player_wallet_activity set operation=new.product,reference=new.source where id=(select id from public.player_wallet_activity where player_id=new.player_id and currency=new.currency and tx=txid_current() and reference is null order by created_at desc limit 1);return new;
end $$;
create trigger wallet_label069 after insert on public.store_accounting for each row execute function public._wallet_label069();
create table public.player_service_install(id boolean primary key default true,installed_at timestamptz not null default now());insert into public.player_service_install values(true,now());
create table public.player_tool_preferences(player_id uuid primary key references public.profiles(id),settings jsonb not null default '{}',updated_at timestamptz not null default now());
create table public.player_wishlist(player_id uuid references public.profiles(id),card_id text not null,created_at timestamptz not null default now(),primary key(player_id,card_id));
create table public.player_deck_notes(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id),kind text not null check(kind in('version','experiment')),name text not null,counts jsonb not null,created_at timestamptz not null default now());
create table public.player_look_sets(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id),name text not null,look jsonb not null,created_at timestamptz not null default now());
alter table public.profiles add column if not exists equipped_frame text not null default 'classic';
create table public.player_updates(id uuid primary key default gen_random_uuid(),category text not null check(category in('news','balance','issue','event')),title text not null,body text not null,starts_at timestamptz not null default now(),ends_at timestamptz,revision integer not null default 1,published boolean not null default false,updated_at timestamptz not null default now(),check(ends_at is null or ends_at>starts_at));
insert into public.player_updates(category,title,body,published) values('news','Uma central para sua jornada','A Central do jogador reúne suporte, transações, ferramentas de baralho, coleção, comunidade e acessibilidade. Novos comunicados, mudanças de balanceamento e problemas conhecidos serão publicados aqui.',true);
create table public.player_update_reads(player_id uuid references public.profiles(id),update_id uuid references public.player_updates(id) on delete cascade,revision integer not null,primary key(player_id,update_id));
create table public.support_tickets(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id),subject text not null,match_id text,status text not null default 'open' check(status in('open','investigating','waiting','resolved')),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.support_messages(id uuid primary key default gen_random_uuid(),ticket_id uuid not null references public.support_tickets(id),author_id uuid not null references public.profiles(id),body text not null,screenshot text,created_at timestamptz not null default now());
create table public.game_health_events(id bigint generated always as identity primary key,player_id uuid not null references public.profiles(id),kind text not null check(kind in('disconnect','resource','action','response')),phase text not null,duration integer,status boolean not null default false,created_at timestamptz not null default now());
create index on public.game_health_events(created_at);
create index support_owner069 on public.support_tickets(player_id,updated_at desc);
create index support_messages069 on public.support_messages(ticket_id,created_at);
create table public.admin_player_access_log(id bigint generated always as identity primary key,actor_id uuid not null references public.profiles(id),player_id uuid not null references public.profiles(id),created_at timestamptz not null default now());
do $$declare t text;begin foreach t in array array['player_wallet_activity','player_service_install','player_tool_preferences','player_wishlist','player_deck_notes','player_look_sets','player_updates','player_update_reads','support_tickets','support_messages','game_health_events','admin_player_access_log'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant all on public.%I to service_role',t);end loop;end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('support-screenshots','support-screenshots',false,5242880,array['image/png','image/jpeg','image/webp']) on conflict(id) do nothing;
create policy support_upload069 on storage.objects for insert to authenticated with check(bucket_id='support-screenshots' and (storage.foldername(name))[1]=auth.uid()::text);
create policy support_read069 on storage.objects for select to authenticated using(bucket_id='support-screenshots' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_site_admin()));
create policy support_delete069 on storage.objects for delete to authenticated using(bucket_id='support-screenshots' and (storage.foldername(name))[1]=auth.uid()::text);
create function public.player_services(p_action text,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();r jsonb;v uuid;k text;item record;ct integer;
begin
 if u is null then raise exception 'Entre na sua conta.';end if;perform public._assert_account_active();perform public._security_rpc_gate('player_services',180);
 case p_action
 when 'wallet' then
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.id desc),'[]') into r from (
 select * from (
 select id::text,currency,delta,balance_after,operation,coalesce(reference,id::text) reference,created_at from public.player_wallet_activity where player_id=u and (coalesce(p_data->>'currency','')='' or currency=p_data->>'currency')
 union all select id::text,currency,case when kind='purchase' then -abs(amount) else amount end,null,product,source,created_at from public.store_accounting where player_id=u and created_at<(select installed_at from public.player_service_install limit 1) and (coalesce(p_data->>'currency','')='' or currency=p_data->>'currency')
 )x where(nullif(p_data->>'before','')is null or (x.created_at,x.id)<((p_data->>'before')::timestamptz,coalesce(p_data->>'before_id','ffffffff-ffff-ffff-ffff-ffffffffffff'))) order by created_at desc,id desc limit 100
 )page;return r;
 when 'preferences' then
 if p_data ? 'settings' then
 r:=jsonb_build_object('text',greatest(100,least(150,coalesce((p_data#>>'{settings,text}')::int,100))),'contrast',coalesce((p_data#>>'{settings,contrast}')::boolean,false),'symbols',coalesce((p_data#>>'{settings,symbols}')::boolean,false),'clickMove',coalesce((p_data#>>'{settings,clickMove}')::boolean,true));
 insert into public.player_tool_preferences values(u,r,now()) on conflict(player_id) do update set settings=excluded.settings,updated_at=now();end if;
 return coalesce((select settings from public.player_tool_preferences where player_id=u),'{}');
 when 'wishlist' then
 if p_data ? 'card' then k:=p_data->>'card';if length(k)>100 or public._r_card(k)->>'id' is distinct from k then raise exception 'Carta inválida.';end if;
 if coalesce((p_data->>'remove')::boolean,false) then delete from public.player_wishlist where player_id=u and card_id=k;else insert into public.player_wishlist values(u,k,now()) on conflict do nothing;end if;end if;
 return coalesce((select jsonb_agg(card_id) from public.player_wishlist where player_id=u),'[]');
 when 'wishlist_sources' then
 return coalesce((select jsonb_agg(jsonb_build_object('card',c.card_id,'source','Tesouro do Atlas · marco '||r.milestone,'claimed',r.granted_at is not null)) from public.guardian_campaign_rewards r join public.shop_catalog c on c.item_id=r.item_id and c.kind='card' where r.player_id=u),'[]');
 when 'decks' then
 if p_data ? 'delete' then delete from public.player_deck_notes where player_id=u and id=(p_data->>'delete')::uuid;end if;
 if p_data ? 'counts' then
 if p_data->>'kind' not in('version','experiment') or length(btrim(p_data->>'name')) not between 1 and 70 or jsonb_typeof(p_data->'counts')<>'object' then raise exception 'Dados inválidos.';end if;
 if (select count(*) from public.player_deck_notes where player_id=u)>=60 then raise exception 'Limite de 60 registros. Exclua uma versão antiga.';end if;
 ct:=0;for item in select key,value from jsonb_each_text(p_data->'counts') loop if item.value!~'^[0-9]{1,2}$' or item.value::int>35 or public._r_card(item.key)->>'id' is distinct from item.key then raise exception 'Carta ou quantidade inválida.';end if;ct:=ct+item.value::int;end loop;
 if ct>70 then raise exception 'Limite de 70 cartas para planejamento.';end if;
 insert into public.player_deck_notes(player_id,kind,name,counts) values(u,p_data->>'kind',btrim(p_data->>'name'),p_data->'counts');end if;
 return coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('results',coalesce((select jsonb_build_object('games',games_played,'wins',victories,'losses',defeats,'draws',draws) from public.player_deck_usage where player_id=u and card_counts=d.counts limit 1),'{}')) order by created_at desc) from public.player_deck_notes d where player_id=u),'[]');
 when 'updates' then
 if coalesce((p_data->>'visit')::boolean,false) then insert into public.player_update_reads select u,id,revision from public.player_updates where published and starts_at<=now() and(ends_at is null or ends_at>now()) on conflict(player_id,update_id) do update set revision=excluded.revision;end if;
 if p_data ? 'read' then insert into public.player_update_reads select u,id,revision from public.player_updates where id=(p_data->>'read')::uuid and published and starts_at<=now() on conflict(player_id,update_id) do update set revision=excluded.revision;end if;
 return coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('unread',coalesce(r.revision,0)<n.revision) order by n.starts_at desc) from public.player_updates n left join public.player_update_reads r on r.player_id=u and r.update_id=n.id where n.published and n.starts_at<=now() and(n.ends_at is null or n.ends_at>now())),'[]');
 when 'tickets' then
 return coalesce((select jsonb_agg(to_jsonb(t)||jsonb_build_object('messages',(select jsonb_agg(jsonb_build_object('id',m.id,'body',m.body,'screenshot',m.screenshot,'staff',m.author_id<>t.player_id,'created_at',m.created_at) order by m.created_at) from public.support_messages m where m.ticket_id=t.id)) order by updated_at desc) from public.support_tickets t where player_id=u),'[]');
 when 'ticket' then
 if length(btrim(coalesce(p_data->>'body',''))) not between 5 and 4000 then raise exception 'Descreva o problema em 5 a 4000 caracteres.';end if;
 if nullif(p_data->>'screenshot','') is not null and (p_data->>'screenshot' not like u::text||'/%' or length(p_data->>'screenshot')>200) then raise exception 'Captura inválida.';end if;
 if nullif(p_data->>'screenshot','') is not null and not exists(select 1 from storage.objects where bucket_id='support-screenshots' and name=p_data->>'screenshot') then raise exception 'Captura não encontrada. Envie o arquivo novamente.';end if;
 if p_data ? 'id' then v:=(p_data->>'id')::uuid;perform 1 from public.support_tickets where id=v and player_id=u for update;if not found then raise exception 'Chamado não encontrado.';end if;
 else if length(btrim(coalesce(p_data->>'subject',''))) not between 3 and 100 then raise exception 'Informe o assunto.';end if;
 if (select count(*) from public.support_tickets where player_id=u and created_at>now()-interval '1 hour')>=5 then raise exception 'Aguarde para abrir outro chamado.';end if;
 insert into public.support_tickets(player_id,subject,match_id) values(u,btrim(p_data->>'subject'),left(p_data->>'match',100)) returning id into v;end if;
 insert into public.support_messages(ticket_id,author_id,body,screenshot) values(v,u,btrim(p_data->>'body'),nullif(p_data->>'screenshot',''));
 update public.support_tickets set updated_at=now(),status='open' where id=v;return jsonb_build_object('id',v);
 when 'telemetry' then
 if jsonb_typeof(p_data->'events')<>'array' or jsonb_array_length(p_data->'events')>20 then raise exception 'Lote inválido.';end if;
 delete from public.game_health_events where player_id=u and created_at<now()-interval '14 days';
 for r in select value from jsonb_array_elements(p_data->'events') loop
 k:=r->>'phase';if k not in('network','image','script','style','server','animation','snapshot') then k:='server';end if;
 if r->>'kind' in('disconnect','resource','action','response') then insert into public.game_health_events(player_id,kind,phase,duration,status) values(u,r->>'kind',k,greatest(0,least(120000,coalesce((r->>'duration')::int,0))),coalesce((r->>'ok')::boolean,false));end if;end loop;return '{}';
 when 'looks' then
 if p_data ? 'delete' then delete from public.player_look_sets where player_id=u and id=(p_data->>'delete')::uuid;end if;
 if p_data ? 'name' then
 if length(btrim(p_data->>'name')) not between 1 and 60 or(select count(*) from public.player_look_sets where player_id=u)>=20 then raise exception 'Nome inválido ou limite de 20 conjuntos.';end if;
 insert into public.player_look_sets(player_id,name,look) select u,btrim(p_data->>'name'),jsonb_build_object('avatar',equipped_avatar,'battlefield',equipped_battlefield,'hand',equipped_hand,'frame',equipped_frame,'title',h.title_id,'medals',coalesce(to_jsonb(h.medals),'[]')) from public.profiles p left join public.player_honor_display h on h.player_id=p.id where p.id=u;end if;
 return coalesce((select jsonb_agg(to_jsonb(l) order by created_at desc) from public.player_look_sets l where player_id=u),'[]');
 when 'frame' then
 if p_data->>'frame' not in('classic','silver','violet','none') then raise exception 'Moldura inválida.';end if;update public.profiles set equipped_frame=p_data->>'frame' where id=u;return '{}';
 when 'look_apply' then
 select look into r from public.player_look_sets where player_id=u and id=(p_data->>'id')::uuid;if r is null then raise exception 'Conjunto não encontrado.';end if;
 foreach k in array array['avatar','battlefield','hand'] loop
 if r->>k is not null and exists(select 1 from public.player_inventory where player_id=u and item_id=r->>k) then perform public.equip_shop_item(r->>k);
 elsif k='avatar' and r->>k='default' then update public.profiles set equipped_avatar='default' where id=u;
 elsif k='battlefield' and r->>k='battle-forest' then update public.profiles set equipped_battlefield='battle-forest' where id=u;
 elsif k='hand' and r->>k='hand-heaven' then update public.profiles set equipped_hand='hand-heaven' where id=u;
 elsif (select to_jsonb(p)->>('equipped_'||k) from public.profiles p where id=u) is distinct from r->>k then raise exception 'Uma aparência deste conjunto não está disponível.';end if;end loop;
 perform public.equip_player_honors(r->>'title',array(select jsonb_array_elements_text(coalesce(r->'medals','[]'))));update public.profiles set equipped_frame=coalesce(r->>'frame','classic') where id=u;return r;
 else raise exception 'Operação inválida.';end case;
end $$;
revoke all on function public._wallet_activity069(),public._wallet_label069(),public.player_services(text,jsonb) from public,anon,authenticated;
grant execute on function public.player_services(text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
