-- 042: Deck identity and the direct X1 room. Apply after 041.
begin;
alter table public.player_saved_decks add column if not exists icon_key text not null default 'convergencia', add column if not exists icon_color text not null default '#44305E';
alter table public.player_saved_decks drop constraint if exists deck_icon_key_allowed;
alter table public.player_saved_decks add constraint deck_icon_key_allowed check(icon_key in ('faction-greece','faction-norse','faction-egypt','faction-celtic','faction-monster','faction-alyans','faction-japanese','faction-hindu','faction-chinese','faction-aztec','faction-mesopotamian','faction-brasil','eclipse','matilha','pelotao','submundo','convergencia','realeza','caos','arsenal','lunar','protecao','ofensiva','combos'));
alter table public.player_saved_decks drop constraint if exists deck_icon_color_allowed;
alter table public.player_saved_decks add constraint deck_icon_color_allowed check(icon_color ~ '^#[0-9A-Fa-f]{6}$');
create or replace function public.personalize_deck(p_slot integer,p_name text,p_icon text,p_color text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();deck public.player_saved_decks;
begin
 perform public._security_rpc_gate('personalize_deck',30);
 if uid is null then raise exception 'Entre na conta para personalizar seu baralho.';end if;
 if p_slot is null or p_slot not between 1 and 7 or length(btrim(coalesce(p_name,''))) not between 1 and 24 then raise exception 'Nome ou baralho inválido.';end if;
 if p_icon is null or p_icon not in ('faction-greece','faction-norse','faction-egypt','faction-celtic','faction-monster','faction-alyans','faction-japanese','faction-hindu','faction-chinese','faction-aztec','faction-mesopotamian','faction-brasil','eclipse','matilha','pelotao','submundo','convergencia','realeza','caos','arsenal','lunar','protecao','ofensiva','combos') or p_color is null or p_color !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Escolha um ícone e uma cor válidos.';end if;
 perform 1 from public.profiles where id=uid for update;
 update public.player_saved_decks set name=btrim(p_name),icon_key=p_icon,icon_color=upper(p_color),updated_at=now() where player_id=uid and slot=p_slot returning * into deck;
 if not found then raise exception 'Salve o baralho no construtor antes de personalizá-lo.';end if;
 return jsonb_build_object('slot',deck.slot,'name',deck.name,'iconKey',deck.icon_key,'iconColor',deck.icon_color);
end $$;
revoke all on function public.personalize_deck(integer,text,text,text) from public,anon;
grant execute on function public.personalize_deck(integer,text,text,text) to authenticated;
-- Preserve identity when deletion compacts the seven deck slots. Read cosmetics
-- from the server rather than accepting unvalidated client properties.
do $identity_delete$
declare d text;
begin
 d:=pg_get_functiondef('public.delete_builder_deck(integer,integer,jsonb)'::regprocedure);
 if position('iconKey' in d)=0 then
 d:=replace(d,'jsonb_build_object(''name'',title,''cards'',normalized)','jsonb_build_object(''name'',title,''cards'',normalized,''iconKey'',coalesce((select icon_key from public.player_saved_decks where player_id=uid and slot=slot_index),''convergencia''),''iconColor'',coalesce((select icon_color from public.player_saved_decks where player_id=uid and slot=slot_index),''#44305E''))');
 d:=replace(d,'player_saved_decks(player_id,slot,name,card_counts,updated_at)','player_saved_decks(player_id,slot,name,card_counts,updated_at,icon_key,icon_color)');
 d:=replace(d,'value->''cards'',now()','value->''cards'',now(),coalesce(value->>''iconKey'',''convergencia''),coalesce(value->>''iconColor'',''#44305E'')');

 end if;
 execute d;
end $identity_delete$;
create or replace function public.my_direct_invite()
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public._security_rpc_gate('my_direct_invite',30);
 select jsonb_build_object('code',i.code,'expiresAt',i.expires_at,'name',coalesce(nullif(p.nickname,''),p.display_name),'icon',p.equipped_avatar,'rating',p.rating_points)
 into result from public.game_invites i left join public.profiles p on p.id=i.invited_user_id
 where i.host_id=auth.uid() and i.mode='friend' and i.status='waiting' and i.expires_at>now() order by i.created_at desc limit 1;
 return result;
end $$;
create or replace function public.cancel_direct_invite(p_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public._security_rpc_gate('cancel_direct_invite',15);
 update public.game_invites set status='declined' where code=upper(btrim(p_code)) and host_id=auth.uid() and status='waiting';
 if not found then raise exception 'O convite já foi aceito ou encerrado. Atualize a sala.';end if;
end $$;
revoke all on function public.my_direct_invite() from public,anon;
revoke all on function public.cancel_direct_invite(text) from public,anon;
grant execute on function public.my_direct_invite() to authenticated;
grant execute on function public.cancel_direct_invite(text) to authenticated;
notify pgrst,'reload schema';
commit;
