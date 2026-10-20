from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
s=s.replace("const c=C[v.cardId];if((c.tags||[]).includes('espartano')||v.cardId==='leonidas')", "const c=C[identity(v)];if((c.tags||[]).includes('espartano')||identity(v)==='leonidas')")
s=s.replace("C[v.cardId]?.faction==='Monstros'", "C[identity(v)]?.faction==='Monstros'")
p.write_text(s,encoding='utf-8')
sql="""
-- Faction/tag checks must use copied identities, just like Locations and auras do.
do $allied_identity$
declare d text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._r_card(a->>'cardId')$a$,$b$public._r_card(public._r_identity(a))$b$);
 d:=replace(d,$a$a->>'cardId'='leonidas'$a$,$b$public._r_identity(a)='leonidas'$b$);execute d;
end $allied_identity$;
"""
(root/'work/ability-allied-identity.sql').write_text(sql,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if '$allied_identity$' not in s:s=s.replace('do $acl$',sql+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
if '**Identidade copiada:**' not in s:s=s.replace('- **Cartas pausadas:**','- **Identidade copiada:** Ares e Beowulf passam a reconhecer a facção e as características copiadas por Loki, em vez de consultar apenas a carta física Loki.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
print('Ares and Beowulf recognize copied faction identities.')
