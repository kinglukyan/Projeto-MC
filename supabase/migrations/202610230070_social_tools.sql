begin;
create table public.guild_posts(id uuid primary key default gen_random_uuid(),guild_id uuid not null references public.guilds(id) on delete cascade,author_id uuid not null references public.profiles(id),body text not null,deck_id uuid references public.community_decks(id),pinned boolean not null default false,created_at timestamptz not null default now());
create table public.guild_events(id uuid primary key default gen_random_uuid(),guild_id uuid not null references public.guilds(id) on delete cascade,author_id uuid not null references public.profiles(id),title text not null,details text not null default '',starts_at timestamptz not null,ends_at timestamptz not null,check(ends_at>starts_at));
create table public.guild_event_rsvps(event_id uuid references public.guild_events(id) on delete cascade,player_id uuid references public.profiles(id),response text not null check(response in('yes','maybe','no')),primary key(event_id,player_id));
create table public.community_comments(id uuid primary key default gen_random_uuid(),deck_id uuid not null references public.community_decks(id) on delete cascade,author_id uuid not null references public.profiles(id),body text not null,hidden boolean not null default false,created_at timestamptz not null default now());
create table public.community_comment_reports(comment_id uuid references public.community_comments(id) on delete cascade,player_id uuid references public.profiles(id),reason text not null,resolved boolean not null default false,created_at timestamptz not null default now(),primary key(comment_id,player_id));
create table public.shared_match_reports(code text primary key,player_id uuid not null references public.profiles(id),match_id uuid not null,report jsonb not null,created_at timestamptz not null default now(),unique(player_id,match_id));
create table public.pack_gifts(id uuid primary key default gen_random_uuid(),sender_id uuid not null references public.profiles(id),recipient_id uuid not null references public.profiles(id),request_id uuid not null,purchase_id uuid not null references public.basic_pack_purchases(id),pack_id text not null,created_at timestamptz not null default now(),unique(sender_id,request_id));
create index guild_posts070 on public.guild_posts(guild_id,pinned desc,created_at desc);
create index guild_events070 on public.guild_events(guild_id,starts_at);
create index community_comments070 on public.community_comments(deck_id,created_at);
create index pack_gifts_sender070 on public.pack_gifts(sender_id,created_at desc);
create index pack_gifts_recipient070 on public.pack_gifts(recipient_id,created_at desc);
do $$declare t text;begin foreach t in array array['guild_posts','guild_events','guild_event_rsvps','community_comments','community_comment_reports','shared_match_reports','pack_gifts'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant all on public.%I to service_role',t);end loop;end $$;
create function public.player_social_tools(p_action text,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();g uuid;role_name text;v uuid;r jsonb;t record;
begin
 if u is null then raise exception 'Entre na sua conta.';end if;perform public._assert_account_active();perform public._security_rpc_gate('player_social_tools',100);
 select guild_id,role into g,role_name from public.guild_members where player_id=u;
 if p_action in('guild','post','event','rsvp','training','delete_post','pin','delete_event') and g is null then raise exception 'Entre em uma guilda.';end if;
 case p_action
 when 'guild' then return jsonb_build_object('role',role_name,'posts',coalesce((select jsonb_agg(to_jsonb(p)||jsonb_build_object('author',coalesce(pr.nickname,pr.display_name),'mine',p.author_id=u,'deck_title',d.title) order by p.pinned desc,p.created_at desc) from public.guild_posts p join public.profiles pr on pr.id=p.author_id left join public.community_decks d on d.id=p.deck_id where p.guild_id=g),'[]'),'events',coalesce((select jsonb_agg(to_jsonb(e)||jsonb_build_object('response',(select response from public.guild_event_rsvps where event_id=e.id and player_id=u),'attendees',coalesce((select jsonb_agg(jsonb_build_object('name',coalesce(p.nickname,p.display_name),'response',r.response)) from public.guild_event_rsvps r join public.profiles p on p.id=r.player_id where r.event_id=e.id),'[]')) order by e.starts_at) from public.guild_events e where e.guild_id=g and e.ends_at>now()-interval '7 days'),'[]'));
 when 'post' then
 if length(btrim(p_data->>'body')) not between 3 and 3000 then raise exception 'Use 3 a 3000 caracteres.';end if;
 if (select count(*) from public.guild_posts where author_id=u and created_at>now()-interval '1 hour')>=20 then raise exception 'Aguarde para publicar novamente.';end if;
 insert into public.guild_posts(guild_id,author_id,body,deck_id) values(g,u,btrim(p_data->>'body'),nullif(p_data->>'deck','')::uuid);return '{}';
 when 'delete_post' then delete from public.guild_posts where id=(p_data->>'id')::uuid and guild_id=g and(author_id=u or role_name in('leader','officer'));return '{}';
 when 'pin' then if role_name not in('leader','officer') then raise exception 'Sem permissão.';end if;update public.guild_posts set pinned=coalesce((p_data->>'pinned')::boolean,false) where id=(p_data->>'id')::uuid and guild_id=g;return '{}';
 when 'event' then
 if role_name not in('leader','officer') then raise exception 'Somente líderes e oficiais organizam eventos.';end if;
 if length(btrim(p_data->>'title')) not between 3 and 100 or length(coalesce(p_data->>'details',''))>2000 then raise exception 'Dados inválidos.';end if;
 if(select count(*) from public.guild_events where guild_id=g and ends_at>now())>=50 then raise exception 'Limite de 50 eventos futuros.';end if;
 insert into public.guild_events(guild_id,author_id,title,details,starts_at,ends_at) values(g,u,btrim(p_data->>'title'),coalesce(p_data->>'details',''),(p_data->>'start')::timestamptz,(p_data->>'end')::timestamptz);return '{}';
 when 'delete_event' then if role_name not in('leader','officer') then raise exception 'Sem permissão.';end if;delete from public.guild_events where guild_id=g and id=(p_data->>'id')::uuid;return '{}';
 when 'rsvp' then
 v:=(p_data->>'id')::uuid;perform 1 from public.guild_events where id=v and guild_id=g and ends_at>now();if not found then raise exception 'Evento indisponível.';end if;
 insert into public.guild_event_rsvps values(v,u,p_data->>'response') on conflict(event_id,player_id) do update set response=excluded.response;return '{}';
 when 'training' then
 v:=(p_data->>'player')::uuid;if v=u or not exists(select 1 from public.guild_members where guild_id=g and player_id=v) then raise exception 'Escolha outro membro da guilda.';end if;
 r:=public.custom_room_create('{"max_cards":35,"starting_hand":5,"turn_seconds":45}');
 -- Existing lobby handles readiness, deck validation and the invitation inbox.
 insert into public.custom_room_invitations(room_id,sender_id,recipient_id,lobby_slot) values((r->>'id')::uuid,u,v,2);return r;
 when 'community_decks' then return coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'code',deck_code,'description',description)) from(select id,title,deck_code,description from public.community_decks order by created_at desc limit 100)d),'[]');
 when 'comments' then
 v:=(p_data->>'deck')::uuid;perform 1 from public.community_decks where id=v;if not found then raise exception 'Deck não encontrado.';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'author',coalesce(p.nickname,p.display_name),'mine',c.author_id=u,'body',c.body,'created_at',c.created_at) order by c.created_at) from public.community_comments c join public.profiles p on p.id=c.author_id where c.deck_id=v and not c.hidden),'[]');
 when 'comment' then
 if length(btrim(p_data->>'body')) not between 3 and 1500 then raise exception 'Use 3 a 1500 caracteres.';end if;
 if(select count(*) from public.community_comments where author_id=u and created_at>now()-interval '1 hour')>=30 then raise exception 'Aguarde para comentar novamente.';end if;
 insert into public.community_comments(deck_id,author_id,body) values((p_data->>'deck')::uuid,u,btrim(p_data->>'body'));return '{}';
 when 'delete_comment' then delete from public.community_comments where id=(p_data->>'id')::uuid and author_id=u;return '{}';
 when 'report_comment' then
 if length(btrim(p_data->>'reason')) not between 5 and 500 then raise exception 'Descreva o motivo.';end if;
 insert into public.community_comment_reports values((p_data->>'id')::uuid,u,btrim(p_data->>'reason'),false,now()) on conflict do nothing;return '{}';
 when 'share' then
 v:=(p_data->>'match')::uuid;select report,code into r,role_name from public.shared_match_reports where player_id=u and match_id=v;if found then return jsonb_build_object('code',role_name,'report',r);end if;
 r:=public.get_match_report(v);if r->>'finished_at' is null then raise exception 'Compartilhe somente partidas encerradas.';end if;
 -- Explicit allowlist: never serialize the live game state, hands or deck lists.
 r:=jsonb_build_object('mode',r->'mode','participants',(select jsonb_agg(jsonb_build_object('name',x->>'name','team',x->>'team')) from jsonb_array_elements(coalesce(r->'participants','[]'))x),'rounds',r->'rounds','round_wins',r->'round_wins','cards',(select jsonb_agg(jsonb_build_object('card_id',x->>'card_id','count',x->'count')) from jsonb_array_elements(coalesce(r->'cards','[]'))x),'effects',(select jsonb_agg(jsonb_build_object('round',x->'round','text',x->>'text')) from jsonb_array_elements(coalesce(r->'effects','[]'))x),'finished_at',r->'finished_at');
 r:=r||jsonb_build_object('plays',coalesce((select jsonb_agg(jsonb_build_object('player',coalesce(p.nickname,p.display_name),'type',a.action_type,'card',case when a.action_type='play' then a.card_id else null end,'round',a.round_number,'at',a.played_at) order by a.played_at) from public.match_report_actions a join public.profiles p on p.id=a.actor_id where a.match_id=v),'[]'));
 role_name:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,20));insert into public.shared_match_reports values(role_name,u,v,r,now());return jsonb_build_object('code',role_name,'report',r);
 when 'gifts' then return coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'pack',p.name,'sent',f.sender_id=u,'person',coalesce(pr.nickname,pr.display_name),'created_at',f.created_at) order by f.created_at desc) from public.pack_gifts f join public.basic_card_packs p on p.id=f.pack_id join public.profiles pr on pr.id=case when f.sender_id=u then f.recipient_id else f.sender_id end where f.sender_id=u or f.recipient_id=u),'[]');
 when 'friend' then
 select p.id,coalesce(p.nickname,p.display_name) name into t from public.profiles p join public.friendships f on ((f.user_a=u and f.user_b=p.id) or(f.user_b=u and f.user_a=p.id)) and f.status='accepted' where upper(p.friend_code)=upper(btrim(p_data->>'code'));
 if not found then raise exception 'Código não encontrado entre seus amigos.';end if;return to_jsonb(t);
 else raise exception 'Operação inválida.';end case;
end $$;
create function public.get_shared_match(p_code text) returns jsonb language sql stable security definer set search_path='' as $$select report from public.shared_match_reports where code=upper(btrim(p_code)) and length(p_code)=20$$;
create function public.gift_basic_pack(p_pack text,p_recipient uuid,p_price integer,p_request uuid,p_test boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p public.basic_card_packs%rowtype;v uuid;items jsonb;cid text;balance bigint;prior public.pack_gifts%rowtype;
begin
 if u is null then raise exception 'Entre na conta.';end if;perform public._assert_account_active();perform public._security_rpc_gate('gift_basic_pack',15);
 if p_request is null or p_recipient=u or not exists(select 1 from public.friendships where status='accepted' and((user_a=u and user_b=p_recipient)or(user_b=u and user_a=p_recipient))) then raise exception 'Destinatário inválido. Escolha um amigo.';end if;
 perform 1 from public.profiles where id in(u,p_recipient) order by id for update;
 if p_test is distinct from public._store_test_enabled() then raise exception 'O modo de teste mudou. Confirme novamente.';end if;
 select * into prior from public.pack_gifts where sender_id=u and request_id=p_request;if found then if prior.pack_id<>p_pack or prior.recipient_id<>p_recipient then raise exception 'Solicitação já utilizada.';end if;return jsonb_build_object('id',prior.id,'delivered',true);end if;
 select * into p from public.basic_card_packs where id=p_pack and enabled for share;if not found or p.price is distinct from p_price then raise exception 'Pacote indisponível ou preço atualizado.';end if;
 select jsonb_agg(jsonb_build_object('id',card_id,'name',card_name,'art',art) order by ordinal) into items from public.basic_pack_cards where pack_id=p.id;if items is null then raise exception 'Pacote sem conteúdo.';end if;
 for cid in select x->>'id' from jsonb_array_elements(items)x loop if public._r_card(cid)->>'id' is distinct from cid then raise exception 'Carta aguarda atualização.';end if;end loop;
 if p_test then return jsonb_build_object('test_mode',true,'delivered',false,'cards',items);end if;
 update public.premium_wallets set clash_bits=clash_bits-p.price,updated_at=now() where player_id=u and clash_bits>=p.price returning clash_bits into balance;if not found then raise exception 'Saldo insuficiente de Trixx Coins.';end if;
 insert into public.basic_pack_purchases(player_id,request_id,pack_id,price_paid,cards) values(p_recipient,gen_random_uuid(),p.id,p.price,items) returning id into v;
 insert into public.premium_spend_ledger values(v,u,p.price,now());
 for cid in select x->>'id' from jsonb_array_elements(items)x loop insert into public.player_card_copies(player_id,card_id,copies) values(p_recipient,cid,1) on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;end loop;
 insert into public.player_inventory(player_id,item_id) select p_recipient,item_id from public.shop_catalog where kind='card' and card_id in(select x->>'id' from jsonb_array_elements(items)x) on conflict do nothing;
 insert into public.pack_gifts(sender_id,recipient_id,request_id,purchase_id,pack_id) values(u,p_recipient,p_request,v,p.id) returning id into v;return jsonb_build_object('id',v,'delivered',true,'balance',balance);
end $$;
revoke all on function public.player_social_tools(text,jsonb),public.get_shared_match(text),public.gift_basic_pack(text,uuid,integer,uuid,boolean) from public,anon,authenticated;
grant execute on function public.player_social_tools(text,jsonb),public.gift_basic_pack(text,uuid,integer,uuid,boolean) to authenticated;
grant execute on function public.get_shared_match(text) to anon,authenticated;
notify pgrst,'reload schema';commit;
