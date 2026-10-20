from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if '$revival_audit$' not in s:s=s.replace('do $acl$',(root/'work/ability-revival-audit.sql').read_text(encoding='utf-8')+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
if '**Anúbis e salvamento:**' not in s:s=s.replace('- **Cartas pausadas:**','- **Anúbis e salvamento:** no servidor, a recuperação só é oferecida se a vítima realmente foi destruída; Boitatá pode impedir a destruição. O ajuste de poder e a memória do Round só são aplicados à unidade realmente ressuscitada, nunca à última unidade pré-existente na fileira.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades';out.mkdir(exist_ok=True)
for n in ['ajustar-poder-exato.py','ability-exact-power.sql','ability-revival-audit.sql','fechar-auditoria-v44.py']:shutil.copy2(root/'work'/n,out/n)
print('Final incremental audit covers choices, durations, zones, cleansing, copies, and revivals.')
