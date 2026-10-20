from pathlib import Path
import json,re,shutil,hashlib
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'))
for c in data['cards']:
 if c.get('sourceEdition')=='remake-20261020':c['abilityTitle']=c['abilityTitle'].upper().replace('MJÕLNIR','MJÖLNIR').replace('BIFRÕST','BIFRÖST')
data['remakeRules']=json.loads((site/'remake-rules.json').read_text(encoding='utf-8'))
(site/'abilities-data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'abilities-data.js').write_text('window.MythicAbilitiesData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
cards=[c for c in data['cards'] if c.get('sourceEdition')=='remake-20261020']
(site/'cards-remake.json').write_text(json.dumps({'version':'20261020-remake','cards':cards},ensure_ascii=False,indent=2),encoding='utf-8')
(site/'card-hologram-map.json').write_text(json.dumps({'version':'20261020-remake','cards':cards},ensure_ascii=False,indent=2),encoding='utf-8')
source=root/'outputs/TCG-Card-Studio-0.4-Manutencao/assets/prepared/symbols'
new_factions={}
for c in cards:
 key=c.get('badgeKey','');p=source/(key+'.png')
 if p.exists():
  dest=site/'assets/card-badges'/('remake-'+key+'.png');shutil.copy2(p,dest)
  new_factions[c['faction']]={'key':key,'color':c.get('glow','#865bb2'),'asset':'assets/card-badges/'+dest.name}
p=site/'online.js';s=p.read_text(encoding='utf-8')
marker='  function cardEditorValue'
# Register the new faction appearances next to the existing built-in registry.
start=s.index('const cardBadgeStyles=');end=s.index(';',start)+1
statement=s[start:end]
if 'Object.assign(cardBadgeStyles,' not in s:s=s[:end]+'\n  Object.assign(cardBadgeStyles,'+json.dumps(new_factions,ensure_ascii=False,separators=(',',':'))+');'+s[end:]
p.write_text(s,encoding='utf-8')
p=site/'index.html';s=p.read_text(encoding='utf-8')
if 'src="remake-rules.js' not in s:s=s.replace('  <script src="abilities-engine.js','  <script src="remake-rules.js" defer></script>\n  <script src="abilities-engine.js')
match=re.search(r'(<select[^>]+id="admin-card-faction"[^>]*>)(.*?)(</select>)',s,re.S)
if match:
 inner=match.group(2)
 for faction in new_factions:
  if '>'+faction+'<' not in inner:inner+='<option>'+faction+'</option>'
 s=s[:match.start()]+match.group(1)+inner+match.group(3)+s[match.end():]
p.write_text(s,encoding='utf-8')
# Keep the maintenance scripts with the one complete delivery folder.
maintenance=site/'_manutencao/remake';maintenance.mkdir(exist_ok=True)
for file in ['definir-regras-remake.py','remake-engine-fragment.js','integrar-motor-remake.py','remake-server.sql','remake-server-hooks.sql','remake-foreign-choices.sql','remake-legacy-protections.sql','compilar-sql-remake.py','ajustar-regras-remake.py','completar-hooks-remake.py','integrar-interface-remake.py']:
 shutil.copy2(root/'work'/file,maintenance/file)
print('Interface e catálogo sincronizados:',len(cards),'cartas.',flush=True)
