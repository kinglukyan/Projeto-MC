from pathlib import Path
import re,shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql'
s=p.read_text(encoding='utf-8')
s,n=re.subn(r'-- Re-check the current legal choices before applying a previously issued selection\.\s*do \$choice_guard\$.*?end \$choice_guard\$;',lambda m:(root/'work/choice-guard-compatible.sql').read_text(encoding='utf-8').strip(),s,flags=re.S)
assert n==1,'Original choice block not found'
# Install an explicit current dispatcher for revival, instead of modifying legacy function bodies by text.
dispatcher=(root/'work/remake-legacy-protections.sql').read_text(encoding='utf-8')
dispatcher=dispatcher.replace("if op='remake' then x:=public._x_resolve(x,e);", "if op='remake' then x:=public._x_resolve(x,e);\n elsif op in ('revive','revive_cost','anubis_revive') then x:=public._x_legacy_revive(x,e);")
dispatcher=dispatcher.replace("v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+delta);", "v:=public._x_adjust(v,'powerShift',(vals->>i)::numeric-public._x_raw_power(x->'s',team,v,0));")
dispatcher=dispatcher.replace("elsif op='anubis' and public._x_block(x->'s',enemy,public._r_unit(x->'s',enemy,selected),t,'destroy') then null;", """elsif op='anubis' then
  v:=public._r_unit(x->'s',enemy,selected);
  if v is not null and not public._x_block(x->'s',enemy,v,t,'destroy') then
   delta:=public._r_power(x->'s',enemy,v);x:=public._r_destroy(x,enemy,jsonb_build_array(selected));
   if public._r_unit(x->'s',enemy,selected) is null then x:=public._r_evt(x,e-'selection'||jsonb_build_object('op','anubis_revive','wantedPower',delta));end if;
  end if;""")
replacement=(root/'work/revival-compatible.sql').read_text(encoding='utf-8')+'\n'+dispatcher
s,n=re.subn(r'-- Complete the exact assignments against the current approved legacy dispatcher\.\s*do \$revival_audit\$.*?end \$revival_audit\$;',lambda m:replacement.strip(),s,flags=re.S)
assert n==1,'Original revival block not found'
s=s.replace('-- 044: Reviewed choices, guard duration, movement, and shared-zone ownership.', '-- 044: Reviewed choices, guard duration, movement, and shared-zone ownership.\n-- Compatibility revision: stable action wrapper and explicit revival dispatcher.\n-- Run this complete file after migrations 040–043; do not run only a selected block.')
p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades'
for name in ['choice-guard-compatible.sql','revival-compatible.sql','corrigir-compatibilidade-sql044.py']:shutil.copy2(root/'work'/name,out/name)
note='''
## Correção de compatibilidade da migração 044

O erro “Validação de escolhas incompatível; nenhuma alteração aplicada” vinha de uma busca por um trecho literal do código antigo do banco. A 044 corrigida usa a interface da função e conserva a implementação anterior, incluindo suas validações, sem exigir o mesmo texto interno. O tratamento de ressurreições também passou a usar um manipulador explícito, evitando outra dependência de texto antigo.

Se a 044 anterior falhou, execute novamente **o arquivo completo da 044 corrigida**. O arquivo usa uma transação; a execução que falhou não confirmou as alterações. Se o editor informar que a transação está abortada, execute `ROLLBACK;` antes de rodar o arquivo completo. Não é necessário reaplicar 040–043 para corrigir este erro.

O arquivo foi revisado localmente; não foi executado no seu banco nesta sessão.
'''
p=site/'ATUALIZACAO-HABILIDADES-E-UNIVERSO.md';p.write_text(p.read_text(encoding='utf-8')+note,encoding='utf-8')
print('Migration 044 compatibility corrected; canonical filename preserved.')
