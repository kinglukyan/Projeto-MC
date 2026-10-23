begin;
alter table public.shop_catalog add column if not exists available_from timestamptz,add column if not exists available_until timestamptz;
alter table public.basic_card_packs add column if not exists available_from timestamptz,add column if not exists available_until timestamptz;
alter table public.game_mode_settings add column if not exists available_from timestamptz,add column if not exists available_until timestamptz;
create function public._window071(a timestamptz,b timestamptz) returns boolean language sql stable set search_path='' as $$select(a is null or a<=now())and(b is null or b>now())$$;
create or replace function public.get_game_modes() returns jsonb language sql stable security definer set search_path='' as $$select coalesce(jsonb_object_agg(mode_id,enabled and public._window071(available_from,available_until) and case when mode_id='tiebreak' then coalesce((select enabled from public.solo_mode_settings where id='tiebreak'),false)else true end),'{}') from public.game_mode_settings$$;
create or replace function public._assert_mode_available066(p_mode text) returns void language plpgsql security definer set search_path='' as $$begin if not coalesce((public.get_game_modes()->>p_mode)::boolean,false) then raise exception 'Este modo está fora do período de disponibilidade.';end if;end$$;
create function public.get_scheduled_shop() returns jsonb language sql stable security definer set search_path='' as $$select coalesce(jsonb_agg(jsonb_build_object('item_id',item_id,'title',title,'description',description,'kind',kind,'price',price,'asset_path',asset_path,'card_id',card_id) order by price),'[]') from public.shop_catalog where active and public._window071(available_from,available_until)$$;
create function public._assert_shop_window071(p_id text,p_pack boolean) returns void language plpgsql security definer set search_path='' as $$begin
 if p_pack then if not exists(select 1 from public.basic_card_packs where id=p_id and enabled and public._window071(available_from,available_until))then raise exception 'Pacote fora do período de venda.';end if;
 else if not exists(select 1 from public.shop_catalog where item_id=p_id and active and public._window071(available_from,available_until))then raise exception 'Item fora do período de venda.';end if;end if;end$$;
-- Guards also cover older clients calling the original purchase RPC.
do $$declare f record;d text;g text;begin
 for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('purchase_shop_item','buy_basic_pack','gift_basic_pack') loop
 d:=pg_get_functiondef(f.oid);g:=case f.proname when 'purchase_shop_item' then 'perform public._assert_shop_window071(p_item_id,false);' when 'buy_basic_pack' then 'perform public._assert_shop_window071(p_pack_id,true);' else 'perform public._assert_shop_window071(p_pack,true);'end;
 if position('_assert_shop_window071' in d)=0 then execute regexp_replace(d,'\mBEGIN\M','BEGIN '||g,'i');end if;end loop;
 -- Hide scheduled packs in the authoritative catalog too.
 select pg_get_functiondef('public.get_basic_pack_shop()'::regprocedure) into d;d:=replace(d,'where p.enabled;','where p.enabled and public._window071(p.available_from,p.available_until);');execute d;
end$$;
create function public.reconcile_game_action(p_match uuid,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s jsonb;r boolean;
begin
 if auth.uid() is null then raise exception 'Entre na conta.';end if;perform public._security_rpc_gate('reconcile_game_action',60);
 -- The snapshot RPC checks participant membership and filters private information.
 s:=public.get_online_match(p_match);
 select accepted into r from public.security_action_requests where actor_id=auth.uid() and match_id=p_match and request_id=p_request;
 return jsonb_build_object('accepted',coalesce(r,false),'known',r is not null,'snapshot',s);
end$$;
create function public.admin_player_tools(p_action text,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();v uuid;r jsonb;k text;st timestamptz;en timestamptz;
begin
 if u is null or not public.is_site_admin() then raise exception 'Sem permissão.';end if;perform public._security_rpc_gate('admin_player_tools',120);
 case p_action
 when 'players' then return coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',coalesce(nickname,display_name),'code',friend_code)) from(select * from public.profiles where nickname ilike '%'||left(p_data->>'search',60)||'%' or friend_code ilike '%'||left(p_data->>'search',60)||'%' order by nickname limit 30)p),'[]');
 when 'player' then
 v:=(p_data->>'id')::uuid;insert into public.admin_player_access_log(actor_id,player_id) values(u,v);
 return jsonb_build_object('profile',(select jsonb_build_object('name',coalesce(nickname,display_name),'mythic',mythic_coins,'xp',xp,'trixx',coalesce((select clash_bits from public.premium_wallets where player_id=v),0))from public.profiles where id=v),'wallet',coalesce((select jsonb_agg(to_jsonb(x))from(select id,currency,delta,balance_after,operation,reference,created_at from public.player_wallet_activity where player_id=v order by created_at desc limit 100)x),'[]'),'accounting',coalesce((select jsonb_agg(to_jsonb(x))from(select id,currency,kind,amount,product,created_at from public.store_accounting where player_id=v order by created_at desc limit 100)x),'[]'),'matches',coalesce((select jsonb_agg(to_jsonb(x)) from(select match_id,mode,outcome,xp_earned,coins_earned,completed_at from public.match_history where player_id=v order by completed_at desc limit 30)x),'[]'),'tickets',coalesce((select jsonb_agg(to_jsonb(t)) from public.support_tickets t where player_id=v),'[]'));
 when 'tickets' then return coalesce((select jsonb_agg(to_jsonb(t)||jsonb_build_object('player',coalesce(p.nickname,p.display_name),'messages',(select jsonb_agg(to_jsonb(m) order by m.created_at)from public.support_messages m where m.ticket_id=t.id))order by updated_at desc)from public.support_tickets t join public.profiles p on p.id=t.player_id where p_data->>'status' is null or t.status=p_data->>'status'),'[]');
 when 'ticket_reply' then
 v:=(p_data->>'id')::uuid;perform 1 from public.support_tickets where id=v for update;if not found then raise exception 'Chamado inválido.';end if;
 if p_data->>'status' not in('open','investigating','waiting','resolved') then raise exception 'Situação inválida.';end if;
 if length(btrim(coalesce(p_data->>'body','')))not between 3 and 4000 then raise exception 'Escreva uma resposta.';end if;
 insert into public.support_messages(ticket_id,author_id,body)values(v,u,btrim(p_data->>'body'));update public.support_tickets set status=p_data->>'status',updated_at=now()where id=v;return '{}';
 when 'moderation' then return coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'body',c.body,'hidden',c.hidden,'author',coalesce(p.nickname,p.display_name),'reports',(select jsonb_agg(jsonb_build_object('reason',r.reason,'created_at',r.created_at))from public.community_comment_reports r where r.comment_id=c.id and not resolved)))from public.community_comments c join public.profiles p on p.id=c.author_id where exists(select 1 from public.community_comment_reports where comment_id=c.id and not resolved)),'[]');
 when 'moderate' then v:=(p_data->>'id')::uuid;update public.community_comments set hidden=coalesce((p_data->>'hide')::boolean,false) where id=v;update public.community_comment_reports set resolved=true where comment_id=v;perform public._security_event('comment_moderation','info',null,jsonb_build_object('comment',v,'hide',p_data->'hide'));return '{}';
 when 'health' then return jsonb_build_object('hours',24,'groups',coalesce((select jsonb_agg(to_jsonb(x))from(select kind,phase,count(*) events,count(*)filter(where not status) failures,round(avg(duration)) avg_ms,percentile_disc(.95)within group(order by duration) p95_ms,count(distinct player_id) players from public.game_health_events where created_at>now()-interval '24 hours' group by kind,phase)x),'[]'));
 when 'schedule_list' then return jsonb_build_object('updates',coalesce((select jsonb_agg(to_jsonb(n)order by starts_at desc)from public.player_updates n),'[]'),'shop',coalesce((select jsonb_agg(jsonb_build_object('id',item_id,'title',title,'start',available_from,'end',available_until,'enabled',active))from public.shop_catalog),'[]'),'packs',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',name,'start',available_from,'end',available_until,'enabled',enabled))from public.basic_card_packs),'[]'),'modes',coalesce((select jsonb_agg(jsonb_build_object('id',mode_id,'title',mode_id,'start',available_from,'end',available_until,'enabled',enabled))from public.game_mode_settings),'[]'));
 when 'schedule' then
 k:=p_data->>'kind';st:=nullif(p_data->>'start','')::timestamptz;en:=nullif(p_data->>'end','')::timestamptz;
 if en is not null and st is not null and en<=st then raise exception 'O término deve ser posterior ao início.';end if;
 if k in('news','balance','issue','event')then
 if length(btrim(p_data->>'title'))not between 3 and 120 or length(btrim(p_data->>'body'))not between 3 and 8000 then raise exception 'Preencha título e conteúdo.';end if;
 v:=coalesce(nullif(p_data->>'id','')::uuid,gen_random_uuid());insert into public.player_updates(id,category,title,body,starts_at,ends_at,published)values(v,k,btrim(p_data->>'title'),btrim(p_data->>'body'),coalesce(st,now()),en,coalesce((p_data->>'enabled')::boolean,false))on conflict(id)do update set category=excluded.category,title=excluded.title,body=excluded.body,starts_at=excluded.starts_at,ends_at=excluded.ends_at,published=excluded.published,revision=public.player_updates.revision+1,updated_at=now();
 elsif k='shop'then update public.shop_catalog set available_from=st,available_until=en,active=(p_data->>'enabled')::boolean where item_id=p_data->>'id';
 elsif k='packs'then update public.basic_card_packs set available_from=st,available_until=en,enabled=(p_data->>'enabled')::boolean where id=p_data->>'id';
 elsif k='modes'then update public.game_mode_settings set available_from=st,available_until=en where mode_id=p_data->>'id';perform public.admin_set_game_mode(p_data->>'id',(p_data->>'enabled')::boolean);
 else raise exception 'Tipo inválido.';end if;
 perform public._security_event('content_schedule','info',null,jsonb_build_object('kind',k,'id',p_data->>'id'));return '{}';
 else raise exception 'Operação inválida.';end case;
end$$;
-- Keep complete public effect differences and enrich only events with an explicit source.
alter function public._audit_effect_diff(jsonb,jsonb) rename to _audit_effect_diff_before071;
create function public._audit_effect_diff(prior jsonb,next_state jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb:=public._audit_effect_diff_before071(prior,next_state);ev jsonb;t jsonb;f jsonb;src text;nm text;a jsonb:=public._audit_public_field(prior);z jsonb:=public._audit_public_field(next_state);target_id text;change_text text;
begin
 for ev in select value from jsonb_array_elements(coalesce(next_state->'visualEvents','[]')) where not coalesce(prior->'visualEvents','[]') @> jsonb_build_array(value) loop
 src:=ev->>'sourceCardId';if src is null then continue;end if;nm:=coalesce(public._r_card(src)->>'name',src);
 for t in select value from jsonb_array_elements(case when jsonb_typeof(ev->'targets')='array' then ev->'targets' else '[]'::jsonb end)loop
 target_id:=coalesce(t->>'uid',t#>>'{}');f:=coalesce(z->target_id,a->target_id);change_text:='';if a->target_id->>'power' is distinct from z->target_id->>'power' and a?target_id and z?target_id then change_text:=' Poder '||(a->target_id->>'power')||' → '||(z->target_id->>'power')||'.';end if;
 if f is not null then result:=result||jsonb_build_array(jsonb_build_object('round',coalesce((next_state->>'round')::int,1),'side',f->>'team','source_id',src,'card_id',f->>'card_id','kind',ev->>'kind','text',coalesce(f->>'name','Unidade')||': efeito '||(case ev->>'kind' when 'buff' then 'de aumento de poder' when 'reduce' then 'de redução' when 'destroy' then 'de destruição' when 'protect' then 'de proteção' when 'revive' then 'de recuperação' when 'enter' then 'de entrada em campo' else 'de habilidade' end)||' originado por '||nm||'.'||change_text));end if;end loop;end loop;return result;
end$$;
revoke all on function public._window071(timestamptz,timestamptz),public._assert_shop_window071(text,boolean),public.admin_player_tools(text,jsonb),public.reconcile_game_action(uuid,uuid),public.get_scheduled_shop(),public._audit_effect_diff_before071(jsonb,jsonb),public._audit_effect_diff(jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.admin_player_tools(text,jsonb),public.reconcile_game_action(uuid,uuid)to authenticated;
grant execute on function public.get_scheduled_shop()to anon,authenticated;
-- Add public provenance without serializing private effect queues or choices.
alter function public._r_resolve(jsonb,jsonb) rename to _r_resolve_before071;
create function public._r_resolve(x jsonb,e jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare source jsonb:=public._r_unit(x->'s',e->>'team',e->>'uid');previous jsonb:=x#>'{s,_publicEffectSource}';
begin
 if source is not null then x:=jsonb_set(x,'{s,_publicEffectSource}',to_jsonb(coalesce(source->>'copiedFrom',source->>'cardId')),true);else x:=jsonb_set(x,'{s,_publicEffectSource}','null',true);end if;
 x:=public._r_resolve_before071(x,e);
 if previous is null then x:=x#-'{s,_publicEffectSource}';else x:=jsonb_set(x,'{s,_publicEffectSource}',previous,true);end if;return x;
end$$;
create or replace function public._r_visual(x jsonb,kind text,t text,ids jsonb default '[]') returns jsonb language plpgsql volatile set search_path='' as $$
declare events jsonb:=coalesce(x#>'{s,visualEvents}','[]');ev jsonb;
begin
 ev:=jsonb_build_object('id',gen_random_uuid()::text,'kind',kind,'team',t,'targets',ids,'round',x#>'{s,round}');
 if x#>>'{s,_publicEffectSource}' is not null then ev:=ev||jsonb_build_object('sourceCardId',x#>>'{s,_publicEffectSource}');end if;
 events:=events||jsonb_build_array(ev);if jsonb_array_length(events)>80 then events:=events-0;end if;return jsonb_set(x,'{s,visualEvents}',events,true);
end$$;
revoke all on function public._r_resolve_before071(jsonb,jsonb),public._r_resolve(jsonb,jsonb),public._r_visual(jsonb,text,text,jsonb) from public,anon,authenticated;
-- Guild practice uses the standard custom-room reward rules, with a strict 1x1 cap.
do $$declare d text;begin
 select pg_get_functiondef('public.player_social_tools(text,jsonb)'::regprocedure)into d;
 d:=replace(d,'-- Existing lobby handles readiness, deck validation and the invitation inbox.','update public.sandbox_rooms set rules=rules||jsonb_build_object(''max_players'',2,''guild_training'',true) where id=(r->>''id'')::uuid; r:=public.custom_room_snapshot((r->>''id'')::uuid);');execute d;
 select pg_get_functiondef('public.custom_room_join(text,text,uuid)'::regprocedure)into d;
 d:=replace(d,'if chosen is null then raise exception ''A sala está cheia. Você pode tentar observar.'';end if;','if chosen is null or chosen>coalesce((r.rules->>''max_players'')::int,4) then raise exception ''A sala está cheia. Você pode tentar observar.'';end if;');execute d;
end$$;
create function public._wallet_match_label071()returns trigger language plpgsql security definer set search_path='' as $$begin
 update public.player_wallet_activity set operation='Recompensa de partida · '||new.mode,reference='match:'||new.match_id::text where id=(select id from public.player_wallet_activity where player_id=new.player_id and currency='mythic' and tx=txid_current() and delta=new.coins_earned and reference is null order by created_at desc limit 1);return new;
end$$;
create trigger wallet_match_label071 after insert on public.match_history for each row execute function public._wallet_match_label071();
revoke all on function public._wallet_match_label071()from public,anon,authenticated;
create function public.reconcile_atlas_action(p_run uuid,p_request uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare s jsonb;begin
 s:=public.get_guardian_campaign_run(p_run);
 return jsonb_build_object('accepted',exists(select 1 from public.guardian_campaign_requests where run_id=p_run and request_id=p_request),'snapshot',s);
end$$;
revoke all on function public.reconcile_atlas_action(uuid,uuid)from public,anon,authenticated;
grant execute on function public.reconcile_atlas_action(uuid,uuid)to authenticated;

notify pgrst,'reload schema';commit;
