from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
for p in [root/'work/remake-engine-fragment.js',site/'abilities-engine.js']:
 s=p.read_text(encoding='utf-8').replace("some(v=>v!==u&&active(x,t,v)&&(\n  kind==='move'", "some(v=>(v!==u||ruleFor(v).op==='protectMove')&&active(x,t,v)&&(\n  kind==='move'")
 p.write_text(s,encoding='utf-8')
p=root/'work/remake-server.sql';s=p.read_text(encoding='utf-8')
s=s.replace("where value->>'uid'<>u->>'uid' and value->>'lane'=u->>'lane' loop\n  if not public._r_active(s,t,v) then continue;end if;r:=public._x_rule(v);", "where value->>'lane'=u->>'lane' loop\n  if not public._r_active(s,t,v) then continue;end if;r:=public._x_rule(v);if v->>'uid'=u->>'uid' and r->>'op'<>'protectMove' then continue;end if;")
p.write_text(s,encoding='utf-8')
p=root/'work/remake-server-hooks.sql';s=p.read_text(encoding='utf-8')
s=s.replace("'_r_turn_end(jsonb,text,text,integer)'", "'_r_turn_end(jsonb,text,text,integer)','_r_clear_round(jsonb)'")
start=s.index('do $round_locks$')
s=s[:start]+'''create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text;
begin s:=public._r_clear_round_before_remake(s);foreach t in array array['player_one','player_two'] loop s:=jsonb_set(s,array[t,'grave'],coalesce((select jsonb_agg(value-'lockedRound'-'rebornOnce'-'rebornRound' order by ordinality) from jsonb_array_elements(coalesce(s#>array[t,'grave'],'[]')) with ordinality a(value,ordinality)),'[]'),true);end loop;return s;end $$;
'''
s=s.replace("'deathPower',death);", "'deathPower',death,'rebornOnce',coalesce((u->>'rebornOnce')::boolean,false),'rebornRound',x#>'{s,round}');")
# Preserve a physical unit's rebirth status through an ordinary resurrection.
s+='''
do $revive_state$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 a:='x:=public._r_spawn(x,cid,t,owner_id,lane,coalesce((g->>''progress'')::integer,0));';
 b:=a||'if coalesce((g->>''rebornOnce'')::boolean,false) and g->>''rebornRound''=x#>>''{s,round}'' then select value into v from jsonb_array_elements(x#>array[''s'',t,''field'']) with ordinality a(value,ordinality) where value->>''cardId''=cid and value->>''playedBy''=owner_id order by ordinality desc limit 1;if v is not null then x:=public._r_set_unit(x,t,v->>''uid'',v||jsonb_build_object(''rebornOnce'',true));end if;end if;';
 if position(b in d)=0 then d:=replace(d,a,b);end if;
 d:=replace(d,'(public._r_card(a->>''cardId'')->''tags'') ?| array[''heroi'',''soldado'',''espartano'']','((public._r_card(a->>''cardId'')->''tags'') ?| array[''heroi'',''soldado'',''espartano''] or public._r_card(a->>''cardId'')->>''characterClass''=''Herói'')');
 execute d;
end $revive_state$;
'''
p.write_text(s,encoding='utf-8')
p=root/'work/remake-foreign-choices.sql';s=p.read_text(encoding='utf-8')
s=s.replace("for row_item in select player_id,private_state from public.duo_player_states where match_id=g.id for update loop\n+", "") if False else s
s=s.replace("for row_item in select player_id,private_state from public.duo_player_states where match_id=g.id for update loop\n    t:=case when row_item.player_id in(g.player_one,g.player_three) then 'player_one' else 'player_two' end;", "for row_item in select ps.player_id,ps.private_state,mp.team from public.duo_player_states ps join public.duo_match_players mp on mp.match_id=ps.match_id and mp.player_id=ps.player_id where ps.match_id=g.id for update of ps loop\n    t:=case when row_item.team=1 then 'player_one' else 'player_two' end;")
p.write_text(s,encoding='utf-8')
print('Hooks concluídos',flush=True)
