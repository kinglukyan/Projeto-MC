from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
s=s.replace('const a=x.s[t],p=power(x,t,u),wasLive=active(x,t,u);', 'const a=x.s[t],p=!killed&&Number.isFinite(x.s.clearRoundPowers?.[u.uid])?x.s.clearRoundPowers[u.uid]:power(x,t,u),wasLive=active(x,t,u);')
s=s.replace('function clearRound(x){init(x);for(const t of teams)', 'function clearRound(x){init(x);x.s.clearRoundPowers=Object.fromEntries(teams.flatMap(t=>x.s[t].field.map(u=>[u.uid,power(x,t,u)])));for(const t of teams)')
s=s.replace('x.s.zoneCards={};x.s.sharedZones=', 'x.s.zoneCards={};delete x.s.clearRoundPowers;x.s.sharedZones=')
p.write_text(s,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if '$round_power_snapshot$' not in s:s=s.replace('do $acl$',(root/'work/ability-round-snapshot.sql').read_text(encoding='utf-8')+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
if '**Poder no fechamento do Round:**' not in s:s=s.replace('- **Cartas pausadas:**','- **Poder no fechamento do Round:** registra o poder de todas as unidades antes de retirar a primeira aura do campo. Assim, o Submundo mantém o valor correto para Anúbis, independentemente da ordem de limpeza das cartas.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades'
for n in ['ability-round-snapshot.sql','fechar-poderes-do-round.py']:shutil.copy2(root/'work'/n,out/n)
print('Round cleanup preserves the final power snapshot for the Underworld.')
