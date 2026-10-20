from pathlib import Path
import json
root=Path('outputs/Mythic-Clash-Completo'); dest=root/'assets/deck-icons';dest.mkdir(exist_ok=True)
shapes={
'eclipse':('<circle cx="48" cy="48" r="24"/><path d="M55 25a24 24 0 0 0 0 46 25 25 0 0 1 0-46Z" fill="#bea1ef"/>','Eclipse'),
'matilha':('<path d="m25 25 12 49M44 21l9 52M64 25l5 43" stroke-width="7"/>','Matilha'),
'pelotao':('<path d="M25 70V25l-5 9m5-9 5 9M48 70V20l-5 9m5-9 5 9M71 70V25l-5 9m5-9 5 9"/><path d="M33 48h30v15L48 78 33 63Z" fill="#39234e"/>','Pelotão'),
'submundo':('<path d="M25 75V44a23 23 0 0 1 46 0v31M33 75V44a15 15 0 0 1 30 0v31"/><path d="M48 75c-18-8-5-18-1-28 0 12 17 20 1 28Z" fill="#bea1ef"/>','Submundo'),
'convergencia':('<path d="m30 21 6 18 18 6-18 6-6 18-6-18-18-6 18-6Zm38 13 5 16 17 6-17 5-5 17-6-17-17-5 17-6Z" fill="#f6d889"/>','Convergência'),
'realeza':('<path d="m23 35 10 29h30l10-29-16 11-9-20-9 20Z"/><path d="M32 72h32M48 64v18"/>','Realeza'),
'caos':('<path d="M24 27q24-12 48 0v25q-5 20-24 27-19-7-24-27Z"/><path d="m51 24-9 17 12 10-13 15 5 11M32 45l8 4m16 0 8-4M37 62h22"/>','Caos'),
'arsenal':('<path d="m27 71 40-44m-7-9 16 15M23 66l11 10M29 23l44 48m-9-1 9-8M21 24l11-7 9 10-11 9Z" stroke-width="5"/>','Arsenal'),
'lunar':('<path d="M61 23a27 27 0 1 0 13 39 26 26 0 0 1-13-39Z" fill="#bea1ef"/><path d="m70 20 2 6 7 2-7 2-2 7-2-7-6-2 6-2Z"/>','Lunar'),
'protecao':('<path d="m48 20 26 10v20q-2 18-26 29-24-11-26-29V30Z"/><path d="m35 48 9 9 18-19" stroke-width="5"/>','Proteção'),
'ofensiva':('<path d="m23 73 44-49 9-3-2 10-45 48ZM24 61l15 15M55 28l15 14"/>','Ofensiva'),
'combos':('<rect x="20" y="38" width="35" height="20" rx="10" transform="rotate(-35 38 48)"/><rect x="42" y="38" width="35" height="20" rx="10" transform="rotate(-35 60 48)"/><path d="m38 54 19-12"/>','Combos')}
for key,(shape,name) in shapes.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><title>{name}</title><g fill="none" stroke="#f0d48b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>'
 (dest/(key+'.svg')).write_text(svg,encoding='utf-8')
# Styles are independent of deck composition, so renaming a draft never changes its cards.
keys=['faction-'+k for k in ['greece','norse','egypt','celtic','monster','alyans','japanese','hindu','chinese','aztec','mesopotamian','brasil']]+list(shapes)
key_sql=','.join("'"+k+"'" for k in keys)
sql=f'''-- 042: Deck identity and the direct X1 room. Apply after 041.
begin;
alter table public.player_saved_decks add column if not exists icon_key text not null default 'convergencia', add column if not exists icon_color text not null default '#44305E';
alter table public.player_saved_decks drop constraint if exists deck_icon_key_allowed;
alter table public.player_saved_decks add constraint deck_icon_key_allowed check(icon_key in ({key_sql}));
alter table public.player_saved_decks drop constraint if exists deck_icon_color_allowed;
alter table public.player_saved_decks add constraint deck_icon_color_allowed check(icon_color ~ '^#[0-9A-Fa-f]{{6}}$');
create or replace function public.personalize_deck(p_slot integer,p_name text,p_icon text,p_color text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();deck public.player_saved_decks;
begin
 perform public._security_rpc_gate('personalize_deck',30);
 if uid is null then raise exception 'Entre na conta para personalizar seu baralho.';end if;
 if p_slot is null or p_slot not between 1 and 7 or length(btrim(coalesce(p_name,''))) not between 1 and 24 then raise exception 'Nome ou baralho inválido.';end if;
 if p_icon is null or p_icon not in ({key_sql}) or p_color is null or p_color !~ '^#[0-9A-Fa-f]{{6}}$' then raise exception 'Escolha um ícone e uma cor válidos.';end if;
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
__DYNAMIC__
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
'''
replacements=[("jsonb_build_object('name',title,'cards',normalized)","jsonb_build_object('name',title,'cards',normalized,'iconKey',coalesce((select icon_key from public.player_saved_decks where player_id=uid and slot=slot_index),'convergencia'),'iconColor',coalesce((select icon_color from public.player_saved_decks where player_id=uid and slot=slot_index),'#44305E'))"),("player_saved_decks(player_id,slot,name,card_counts,updated_at)","player_saved_decks(player_id,slot,name,card_counts,updated_at,icon_key,icon_color)"),("value->'cards',now()","value->'cards',now(),coalesce(value->>'iconKey','convergencia'),coalesce(value->>'iconColor','#44305E')")]
quote=lambda s:"'"+s.replace("'","''")+"'"
sql=sql.replace('__DYNAMIC__',''.join(' d:=replace(d,'+quote(a)+','+quote(b)+');\n' for a,b in replacements))
(root/'supabase/migrations/202610200042_deck_identity_direct_room.sql').write_text(sql,encoding='utf-8')
print('12 brasões e migração 042 preparados')
