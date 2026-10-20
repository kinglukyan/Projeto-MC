from pathlib import Path
import os,sys,json,html,shutil,hashlib,re
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo';work=root/'work/importacao-cartas'
internal=root/'outputs/TCG-Card-Studio-Windows-v0.5-Catalogo-e-Cores/TCG-Card-Studio-0.4/_internal'
sys.path.insert(0,str(internal));handles=[os.add_dll_directory(str(p)) for p in [internal,internal/'PySide6'] if p.exists()]
os.environ['QT_PLUGIN_PATH']=str(internal/'PySide6/plugins')
from PySide6.QtGui import QImage
from PySide6.QtCore import Qt,QCoreApplication
app=QCoreApplication([])
manifest=json.loads((work/'manifest.json').read_text(encoding='utf-8'))
new=[c for c in manifest if c['new']]
missing=[str(work/folder/(c['id']+'.png')) for c in new for folder in ['holograms-novas','chibis-novos'] if not (work/folder/(c['id']+'.png')).exists()]
if missing:raise RuntimeError('Gerações pendentes: '+', '.join(missing))
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'));cards=[c for c in data['cards'] if c.get('sourceEdition')=='remake-20261020']
legacy_text=(site/'card-expansion.js').read_text(encoding='utf-8-sig');legacy=json.loads(legacy_text[legacy_text.index('{'):legacy_text.rindex('}')+1])
badges={'Grécia':'greece','Nórdicos':'norse','Egípcios':'egypt','Celtas':'celtic','Monstros':'monster','Alyns':'alyans'}
for c in cards:
 if not c.get('badgeKey'):c['badgeKey']=badges.get(c['faction'],'')
 if c['id'] in ('soldado-esparta','guardiao-nordico'):c['type']='Companheiro'
 if not c.get('hologram'):
  old=legacy.get('legacyHolograms',{}).get(c['id'])
  if isinstance(old,dict):old=old.get('hologram')
  standard='assets/holograms/'+c['id']+'-hologram.png'
  c['hologram']=old or (standard if (site/standard).exists() else None)
avatars=json.loads((site/'avatars-chibi.json').read_text(encoding='utf-8-sig'))
for c in new:
 for folder,target,quality in [('holograms-novas',site/'assets/holograms'/(c['id']+'-hologram.webp'),94),('chibis-novos',site/'assets/avatars-chibi'/(c['id']+'.webp'),95)]:
  source=work/folder/(c['id']+'.png')
  if target.exists() and target.stat().st_mtime>=source.stat().st_mtime:continue
  image=QImage(str(source))
  if image.isNull():raise ValueError(source)
  if folder=='chibis-novos':image=image.scaled(512,512,Qt.AspectRatioMode.KeepAspectRatio,Qt.TransformationMode.SmoothTransformation)
  if not image.save(str(target),'WEBP',quality):raise RuntimeError(target)
 entry={'id':'chibi-'+c['id'],'characterId':c['id'],'name':c['name'],'asset':'assets/avatars-chibi/'+c['id']+'.webp','single':True}
 avatars['avatars']=[a for a in avatars['avatars'] if a['characterId']!=c['id']]+[entry]
soldier=work/'holograms-novas/soldado-esparta.png'
if soldier.exists():
 target=site/'assets/holograms/soldado-esparta-hologram.webp'
 if not QImage(str(soldier)).save(str(target),'WEBP',94):raise RuntimeError(target)
 for c in cards:
  if c['id']=='soldado-esparta':c['hologram']='assets/holograms/soldado-esparta-hologram.webp'
special=work/'chibis-novos/lukyan-rei-de-todos.png'
if special.exists():
 target=site/'assets/avatars-chibi/lukyan-rei-de-todos.webp'
 image=QImage(str(special)).scaled(512,512,Qt.AspectRatioMode.KeepAspectRatio,Qt.TransformationMode.SmoothTransformation)
 if not image.save(str(target),'WEBP',95):raise RuntimeError(target)
 entry={'id':'chibi-lukyan-rei-de-todos','characterId':'lukyan-rei-de-todos','name':'Lukyan — Rei de Todos','asset':'assets/avatars-chibi/lukyan-rei-de-todos.webp','single':True}
 avatars['avatars']=[a for a in avatars['avatars'] if a['characterId']!='lukyan-rei-de-todos']+[entry]
avatars['version']='20261020-remake'
(site/'avatars-chibi.json').write_text(json.dumps(avatars,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'avatars-chibi.js').write_text('window.MythicChibiAvatars='+json.dumps(avatars,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
byid={c['id']:c for c in cards}
# Update legacy public consumers, preserving their supporting hologram mappings.
p=site/'card-expansion.js';s=p.read_text(encoding='utf-8-sig');start=s.index('{');end=s.rindex('}')+1;expansion=json.loads(s[start:end])
expansion['cards']=[byid.get(c['id'],c) for c in expansion['cards'] if c['id'] not in byid]+cards;expansion['version']='20261020-remake'
p.write_text('window.MythicCardExpansion='+json.dumps(expansion,ensure_ascii=False,indent=2)+';\n',encoding='utf-8')
for c in cards:
 if c.get('story'):c['story']=[('Habilidade — '+c['abilityTitle']+': '+c['ability']) if str(line).startswith('Habilidade —') else line for line in c['story']]
data['cards']=[byid.get(c['id'],c) for c in data['cards']]
(site/'abilities-data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'abilities-data.js').write_text('window.MythicAbilitiesData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
for filename in ['cards-remake.json','card-hologram-map.json']:(site/filename).write_text(json.dumps({'version':'20261020-remake','cards':cards},ensure_ascii=False,indent=2),encoding='utf-8')

esc=html.escape
avatar_byid={a['characterId']:a for a in avatars['avatars']}
def avatar_markup(a):
 if not a:return ''
 if a.get('single'):return '<img class="avatar" loading="lazy" src="'+esc(a['asset'],quote=True)+'" alt="Ícone chibi">'
 url=a['asset'].split('#')[0];return '<span class="avatar sheet" role="img" aria-label="Ícone chibi" style="background-image:url('+esc(url,quote=True)+');background-position:'+str(a['col']*50)+'% '+str(a['row']*100)+'%"></span>'
styles='''*{box-sizing:border-box}body{margin:0;background:#100c1c;color:#f3dfaa;font:16px system-ui,sans-serif}header{padding:28px;position:sticky;top:0;background:#160f26ee;z-index:2;border-bottom:1px solid #886d36}h1{margin:0 0 8px;font-size:26px}header p{color:#bdb4ce;margin:6px 0 16px}input,select{padding:12px;border:1px solid #79658d;background:#21172e;color:white;border-radius:8px;max-width:100%;margin:4px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px;padding:24px}article{border:1px solid #6e582d;border-radius:12px;background:#1b1329;padding:16px}h2{font-size:19px;margin:0 0 12px}.pair{display:grid;grid-template-columns:1fr 1fr;align-items:center;gap:10px}.card{width:100%;border-radius:8px}.holo{display:grid;place-items:center;aspect-ratio:2/3;background:radial-gradient(ellipse,#57415b55,transparent 65%)}.holo img{width:100%;height:100%;object-fit:contain}.avatar{width:80px;height:80px;object-fit:contain;border-radius:50%;background-color:#2b1b40;display:inline-block;vertical-align:middle}.sheet{background-size:300% 200%;background-repeat:no-repeat}article p{font-size:14px;line-height:1.55;color:#d0c6df}.meta{display:flex;align-items:center;gap:12px;margin-top:12px}small{color:#e3bd66}[hidden]{display:none!important}.icons{grid-template-columns:repeat(auto-fit,minmax(190px,1fr))}.icons article{text-align:center}.icons .avatar{width:136px;height:136px}a{color:#dcbdff}'''
styles+='@media(max-width:700px){main{grid-template-columns:1fr;padding:12px}header{padding:16px}}'
(site/'remake-gallery.css').write_text(styles,encoding='utf-8')
heading='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cartas, hologramas e chibis · Mythic Clash</title><link rel="stylesheet" href="remake-gallery.css"><header><h1>Cartas, hologramas e chibis</h1><p>108 cartas importadas · 70 personagens novos · artes anteriores atualizadas</p><input id="search" placeholder="Buscar personagem" aria-label="Buscar personagem"><select id="faction" aria-label="Filtrar facção"><option value="">Todas as facções</option>'''+''.join('<option>'+esc(f)+'</option>' for f in sorted({c['faction'] for c in cards}))+'''</select></header><main>'''
items=[]
for c in cards:
 holo=c.get('hologram')
 if not holo or not (site/holo).exists():raise RuntimeError('Holograma ausente: '+c['id'])
 items.append('<article data-name="'+esc(c['name'].lower(),quote=True)+'" data-faction="'+esc(c['faction'],quote=True)+'"><h2>'+esc(c['name'])+'</h2><div class="pair"><a href="'+c['art']+'" target="_blank"><img loading="lazy" class="card" src="'+c['art']+'" alt="Carta '+esc(c['name'],quote=True)+'"></a><div class="holo"><img loading="lazy" src="'+holo+'" alt="Holograma '+esc(c['name'],quote=True)+'"></div></div><div class="meta">'+avatar_markup(avatar_byid.get(c['id']))+'<small>'+esc(c['faction'])+' · '+str(c['power'])+' de poder</small></div><h3>'+esc(c['abilityTitle'])+'</h3><p>'+esc(c['ability'])+'</p></article>')
filter_script=r'''</main><script>const s=document.querySelector('#search'),f=document.querySelector('#faction'),norm=v=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR');function update(){for(const a of document.querySelectorAll('main article'))a.hidden=!(norm(a.dataset.name).includes(norm(s.value))&&(!f.value||a.dataset.faction===f.value));}s.oninput=update;f.onchange=update;</script></html>'''
(site/'remake-gallery.js').write_text(filter_script.split('<script>',1)[1].split('</script>',1)[0],encoding='utf-8')
(site/'cartas-hologramas.html').write_text(heading+''.join(items)+'</main><script src="remake-gallery.js" defer></script></html>',encoding='utf-8')
(site/'icones-chibi.html').write_text('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ícones chibi · Mythic Clash</title><link rel="stylesheet" href="remake-gallery.css"><header><h1>Ícones chibi</h1><p>Personagens da Convergência</p></header><main class="icons">'+''.join('<article>'+avatar_markup(a)+'<h2>'+esc(a['name'])+'</h2></article>' for a in avatars['avatars'])+'</main></html>',encoding='utf-8')

def sql(s):return "'"+str(s).replace("'","''")+"'"
newids={c['id'] for c in new}|({'lukyan-rei-de-todos'} if special.exists() else set())
iconrows=[a for a in avatars['avatars'] if a['characterId'] in newids]
sqltext='-- 041: ícones chibi das novas cartas. Aplicar depois de 040.\nbegin;\ninsert into public.shop_catalog(item_id,title,description,kind,price,asset_path,active) values\n'+',\n'.join('('+','.join([sql(a['id']),sql(a['name']),sql('Ícone chibi de '+a['name']+'.'),sql('avatar'),'500',sql(a['asset']),'true'])+')' for a in iconrows)+'\non conflict(item_id) do update set title=excluded.title,description=excluded.description,asset_path=excluded.asset_path;\nnotify pgrst,\'reload schema\';\ncommit;\n'
(site/'supabase/migrations/202610200041_remake_chibi_icons.sql').write_text(sqltext,encoding='utf-8')
maintenance=site/'_manutencao/remake';maintenance.mkdir(exist_ok=True)
for filename in ['geracoes.jsonl']:
 if (work/filename).exists():shutil.copy2(work/filename,maintenance/filename)
shutil.copy2(Path(__file__),maintenance/Path(__file__).name)
print('Assets finalizados:',len(cards),'cartas,',len(new)+int(soldier.exists()),'hologramas novos,',len(iconrows),'chibis novos.',flush=True)
