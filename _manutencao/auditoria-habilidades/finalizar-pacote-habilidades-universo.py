from pathlib import Path
import shutil,re,json
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8').replace("if(revive&&x.s[other(e.team)].field.some", "if(revive&&C[g.cardId]?.kind==='unit'&&x.s[other(e.team)].field.some");p.write_text(s,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if '-- Ereshkigal forbids unit resurrection' not in s:s=s.replace('do $acl$',(root/'work/ability-grave-kind.sql').read_text(encoding='utf-8')+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
if '**Ereshkigal e não unidades:**' not in s:s=s.replace('- **Cartas pausadas:**','- **Ereshkigal e não unidades:** o bloqueio atinge ressurreição de unidades; não impede Ísis de recuperar um equipamento compatível nem a recuperação de Locais/Terrenos.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
p=site/'universe-banners.js';s=p.read_text(encoding='utf-8');s=re.sub(r"(?:banner\.dataset\.bannerFormat=asset\.format\|\|'atlas';)+","banner.dataset.bannerFormat=asset.format||'atlas';",s);s=s.replace('delete banner.dataset.customBanner;if(node)', 'delete banner.dataset.customBanner;delete banner.dataset.bannerFormat;if(node)');p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades'
for n in ['ability-grave-kind.sql','finalizar-pacote-habilidades-universo.py']:shutil.copy2(root/'work'/n,out/n)
print('Final rule notes and banner mapping normalized.')
