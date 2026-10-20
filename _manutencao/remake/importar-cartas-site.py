exec(open('work/preparar-importacao-cartas.py',encoding='utf-8').read().split('designs=json.loads')[0])
import hashlib,re,shutil
site=root/'outputs/Mythic-Clash-Completo'
manifest=json.loads((root/'work/importacao-cartas/manifest.json').read_text(encoding='utf-8'))
# Values read directly from the 108 supplied card exports, in manifest order.
powers=[5,5,5,4,6,3,5,4,3,6, 5,4,4,4,4,4,5,4,5,7, 4,4,4,7,4,6,7,6,4,4,
4,4,2,6,7,6,4,3,3,1, 6,5,4,4,5,8,3,5,5,5, 6,7,5,3,6,4,4,2,1,3,
6,3,6,4,7,4,3,4,5,3, 5,5,7,2,5,6,6,7,5,8, 6,7,5,3,6,5,8,8,3,4,
4,8,2,3,7,5,6,6,9,6, 3,6,6,5,4,8,5,4]
assert len(powers)==len(manifest)
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8-sig'))
existing={c['id']:c for c in data['cards']}
assets=site/'assets/cards-remake';assets.mkdir(exist_ok=True)
cards=[]
for row,power in zip(manifest,powers):
 src=row['original'];cid=row['id'];old=existing.get(cid,{})
 image=QImage(str(root/'work/cartas-recebidas'/row['file']))
 target=assets/(cid+'.webp')
 if not image.save(str(target),'WEBP',100):raise RuntimeError(cid)
 ability=row['ability'].replace('em 2 0 poder','em 2 o poder').replace('fileira de ísis','fileira de Ísis')
 cls=row['characterClass'];cls={'Espirito':'Espírito','Heroi':'Herói','Deus':'Deus'}.get(cls,cls)
 badge=src.get('badge',old.get('badgeKey',''));color=src.get('color','#865bb2')
 card={**old,'id':cid,'name':row['name'],'kind':'unit','type':old.get('type','Personagem'),'subtype':cls,'characterClass':cls,'faction':row['faction'],'power':power,'abilityTitle':row['abilityTitle'],'ability':ability,'badgeKey':badge,'art':'assets/cards-remake/'+cid+'.webp','previewOnly':False,'abilityPending':False,'tags':old.get('tags',[]),'specialOnly':old.get('specialOnly',False),'sourceEdition':'remake-20261020'}
 if row['new']:
  card['hologram']='assets/holograms/'+cid+'-hologram.webp'
  card['glow']=color
  card['story']=[card['name']+' · '+cls+' · '+row['faction']+'.','Habilidade — '+card['abilityTitle']+': '+ability]
  card['cost']=None
 if cls=='Monstro' and 'monstro' not in card['tags']:card['tags'].append('monstro')
 existing[cid]=card;cards.append(card)
 row['power']=power;row['ability']=ability;row['characterClass']=cls
data['cards']=list(existing.values());data['version']='20261020-remake'
(site/'abilities-data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'abilities-data.js').write_text('window.MythicAbilitiesData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
expansion={'version':'20261020-remake','cards':cards}
(site/'cards-remake.json').write_text(json.dumps(expansion,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'work/importacao-cartas/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
appfile=site/'app.js';code=appfile.read_text(encoding='utf-8-sig')
start=code.index('const presentationV3=');end=code.index('const cardById',start)
code=code[:start]+"// Imported card exports are authoritative for the default art and printed values.\n  "+code[end:]
appfile.write_text(code,encoding='utf-8')
print('Importadas:',len(cards),'cartas;',sum(c['new'] for c in manifest),'novas',flush=True)
print('Artes WebP:',sum(p.stat().st_size for p in assets.glob('*.webp')),flush=True)
