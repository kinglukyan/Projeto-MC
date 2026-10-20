from pathlib import Path
import json,math,collections,html
here=Path(__file__).resolve();site=here.parents[2] if here.parent.name=='guardian-campaign' else here.parents[1]/'outputs/Mythic-Clash-Completo'
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'));C={c['id']:c for c in data['cards']};rules=data['remakeRules']
avatars={a['characterId']:a for a in json.loads((site/'avatars-chibi.json').read_text(encoding='utf-8'))['avatars']}
regions=[
 ('greece','Grécia','Grécia',23.7,38,520,190,'gregos-v3','aquiles hercules hermes minotauro athena afrodite dionisio artemis ares apolo medusa hefesto hades poseidon athena artemis ares poseidon hades zeus'.split(),['grecia','esparta','labirinto-dedalos','campo-troia']),
 ('egypt','Egito','Egípcios',31,26,585,242,'egipcios-v3','sobek horus isis seth anubis osiris horus ra seth osiris anubis isis sobek horus ra seth osiris anubis horus ra'.split(),['egito','alto-egito','baixo-egito','egito']),
 ('norse','Nove Reinos','Nórdicos',10,63,480,45,'nordicos-v3','beowulf ragnar thor loki heimdall odin beowulf ragnar thor heimdall loki odin ragnar thor heimdall loki beowulf heimdall thor odin'.split(),['asgard','bifrost','yggdrasil','nilfheim']),
 ('celtic','Terras Celtas','Celtas',-6,53,410,112,'celtas-v3',['celtas-'+s for s in ['brigid','lancelot','dama-do-lago','lugh','cu-chulainn','dagda','merlin','morgana','morrigan','lancelot','brigid','lugh','dagda','merlin','morgana','cu-chulainn','morrigan','dama-do-lago','merlin']]+['rei-arthur'],['Camelot','Floresta dos Druidas','Avalon','A Távola Redonda']),
 ('mesopotamian','Mesopotâmia','Mesopotâmica',44,33,657,188,'remake-mesopotamian',['mesopotamica-'+s for s in ['enki','enlil','utu-shamash','nanna-sin','ishtar','ninurta','nergal','ereshkigal','tiamat','marduk','enki','enlil','utu-shamash','nanna-sin','ishtar','nergal','ninurta','ereshkigal','tiamat','marduk']],['Canais de Eridu','Zigurates de Ur','Portões do Submundo','Babilônia']),
 ('hindu','Caminhos Hindus','Hindu',78,23,744,235,'remake-hindu',['hindu-'+s for s in ['ganesha','lakshmi','saraswati','hanuman','krishna','durga','indra','vishnu','kali','shiva']]*2,['Jardins de Lótus','Vale Sagrado','Palácio Celestial','Picos do Himalaia']),
 ('chinese','Reino Celestial','Chinesa',105,35,785,125,'remake-chinese',['chinesa-'+s for s in ['fuxi','hou-yi','nezha','guanyin','change','ao-guang','erlang-shen','sun-wukong','nuwa','imperador-jade']]*2,['Montanha das Flores','Jardim da Lua','Palácio do Mar','Corte de Jade']),
 ('japanese','Ilhas do Sol','Japonesa',138,36,902,160,'remake-japanese',['japonesa-'+s for s in ['inari','fujin','hachiman','raijin','tsukuyomi','izanagi','izanami','susanoo','ryujin','amaterasu']]*2,['Caminho dos Torii','Costa das Tempestades','Portões de Yomi','Santuário do Sol']),
 ('aztec','Terras Astecas','Asteca',-99,19,210,215,'remake-aztec',['asteca-'+s for s in ['xochiquetzal','chalchiuhtlicue','mictecacihuatl','tlaloc','xipe-totec','coatlicue','tezcatlipoca','huitzilopochtli','mictlantecuhtli','quetzalcoatl']]*2,['Jardins Sagrados','Escadarias de Pedra','Caminho de Mictlan','Templo da Serpente']),
 ('brasil','Lendas do Brasil','Brasil',-55,-10,365,320,'remake-brasil',['brasil-'+s for s in ['saci','boto','caipora','iara','curupira','cuca','mula-sem-cabeca','boitata','mapinguari','lampiao']]*2,['Veredas da Mata','Margens do Rio','Noite das Lendas','Caminhos do Sertão']),
 ('monster','Lendas Europeias','Monstros',24,47,592,88,'monstros-v3',['homem','mulher','lobo-beta','lobo-omega','lobo-alfa']*4,['Aldeia ao Crepúsculo','Floresta da Matilha','Trilha da Lua','Covil do Alfa']),
]
entries={'regions':[],'nodes':{},'rewardIcons':[a['id'] for cid,a in avatars.items() if C.get(cid,{}).get('badgeKey')!='alyans' and C.get(cid,{}).get('faction') not in ('Alyns','Alyn','Alyans')],'version':1}
impact={'zeus':10,'medusa':7,'hades':7,'apolo':8,'poseidon':5,'athena':4,'ares':3,'lobo-alfa':3,'homem':1,'mulher':1,'guardiao-nordico':2,'soldado-esparta':2}
for k,r in rules.items():impact[k]={'destroy':6,'steal':6,'shiva':7,'aura':4,'clones':4,'draft':3,'reviveQuiet':4,'waveBoth':1,'wave':4,'silence':3,'protectDestroy':3,'protectReduction':3,'protectMove':2,'occupiedAura':4,'saveOnce':3,'rebirth':4}.get(r['op'],1)
entries['impact']=impact
entries['cards']=list(C.values())

def build(faction,hero,stage,region_index):
 pool=[c for c in C.values() if c.get('faction')==faction and not c.get('specialOnly') and not c.get('previewOnly')]
 if faction=='Monstros':pool.append(C['eclipse'])
 units=[c for c in pool if c['kind']=='unit'];n=14+min(21,(region_index*20+stage-1)//3);counts=collections.Counter({hero:1})
 intensity=min(1,.2+(region_index*20+stage-1)/80*.8)
 cap=2 if region_index*20+stage<12 else 3 if region_index*20+stage<35 else 4
 def desirability(c):
  cid=c['id'];r=rules.get(cid,{});op=r.get('op');p=c.get('power',0);already=counts[cid]
  # Gradually trade broad beginner lists for coherent cores and stronger answers.
  score=(p*.3+impact.get(cid,1)*(.2+intensity))*(.55+intensity*.8)
  if cid==hero:score+=2+intensity*2
  if c['kind']!='unit':
   if c['kind']=='equipment':
    gear=data['equipment'].get(cid,{});wearers=[u for u in units if counts[u['id']] and (u['id'] in gear.get('ids',[]) or u['faction']==gear.get('faction'))]
    if not wearers:return -1000
    score=2+intensity*3+sum(counts[u['id']] for u in wearers)*.25
   else:score=1+intensity*2
   if already:return -1000
   if sum(v for key,v in counts.items() if C[key]['kind']!='unit')>=max(2,n//6):return -1000
  else:
   if already>=cap:return -1000
   if region_index==0 and stage<5 and cid in ('zeus','hades','medusa','apolo','poseidon'):return -1000
   if cid in ('soldado-esparta','guardiao-nordico','homem'):score+=already*(.5+intensity*2)
   if faction=='Monstros':
    score+=3 if cid=='lobo-beta' and (counts['lobo-alfa'] or hero=='lobo-alfa') else 0
    score+=2 if cid=='mulher' and counts['homem'] else 0
   if op in ('aura','company','occupiedAura'):score+=min(6,sum(counts.values()))*.35*intensity
   if op in ('recover','reviveQuiet'):
    candidates=[u for u in pool if u['id']!=cid and (not r.get('kind') or u['kind']==r['kind']) and (not r.get('kinds') or u['kind'] in r['kinds']) and (not r.get('max') or u.get('power',0)<=r['max'])]
    if not candidates:score-=5
   if op=='equipmentAura' and not any(u['kind']=='equipment' for u in pool):score-=4
   # More unique tools early; more repeated complementary tools later.
   score-=already*(2.8-intensity*2)
  if hero in ('athena','ares','aquiles','apolo') and cid=='soldado-esparta':score+=1+intensity
  if hero=='odin' and cid in ('yggdrasil','heimdall','runas-nordicas'):score+=2
  if hero=='thor' and cid=='mjolnir':score+=3
  if hero=='zeus' and cid=='raio-de-zeus':score+=3
  if hero in ('rei-arthur','celtas-dama-do-lago') and cid in ('rei-arthur','excalibur'):score+=3
  # Stable variation across encounters rather than pure highest-power stacking.
  score+=((sum(map(ord,cid))+stage*17)%13)/35
  return score
 while sum(counts.values())<n:
  eligible=sorted(pool,key=lambda c:(desirability(c),c['id']),reverse=True)
  if not eligible or desirability(eligible[0])<=-999:break
  counts[eligible[0]['id']]+=1
 if sum(counts.values())<14:raise ValueError((faction,hero,stage,counts))
 return dict(counts)
for idx,(key,name,faction,lon,lat,lx,ly,badge,opponents,chapters) in enumerate(regions):
 region={'id':key,'name':name,'faction':faction,'order':idx+1,'longitude':lon,'latitude':lat,'labelX':lx/10,'labelY':ly/5,'badge':f'assets/card-badges/{badge}.png','chapters':[],'nodeIds':[]}
 for j,place in enumerate(chapters):
  original=C.get(place);hero=opponents[min(j*5+4,19)];art=(original.get('art') if original else f'assets/universe/characters/{hero}.webp')
  if original and place in ('grecia','egito','asgard'):art={'grecia':'assets/onboarding/greek-realm.webp','egito':'assets/onboarding/egyptian-realm.webp','asgard':'assets/onboarding/norse-realm.webp'}[place]
  region['chapters'].append({'name':original['name'] if original else place,'sourceCard':place if original else None,'art':art})
 for stage,hero in enumerate(opponents,1):
  cid=f'{key}-{stage:02d}';deck=build(faction,hero,stage,idx)
  node={'id':cid,'region':key,'stage':stage,'opponent':hero,'name':C[hero]['name'],'icon':avatars[hero]['id'],'difficulty':min(5,1+(idx*20+stage-1)//12),'chapter':(stage-1)//5,'boss':stage%5==0,'deck':deck,'deckSize':sum(deck.values()),'style':('Primeiros combos' if stage<=5 else 'Sinergias da facção' if stage<=10 else 'Controle e proteção' if stage<=15 else 'Convergência de poderes')}
  entries['nodes'][cid]=node;region['nodeIds'].append(cid)
 entries['regions'].append(region)
(site/'_manutencao/guardian-campaign/catalogo-servidor.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
public={**{k:v for k,v in entries.items() if k not in ('impact','cards')},'nodes':{k:{a:b for a,b in n.items() if a!='deck'} for k,n in entries['nodes'].items()}}
(site/'guardian-campaign-data.js').write_text('window.MythicGuardianCampaignData='+json.dumps(public,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
# Simplified geographic outlines, equirectangular projection; markers use real-world coordinates.
continents=[[-168,72,-140,70,-128,55,-123,49,-124,40,-117,32,-108,25,-100,18,-90,18,-85,10,-78,8,-81,22,-76,35,-64,45,-54,51,-60,61,-82,65,-92,75,-112,79,-140,72],[-81,12,-72,12,-60,5,-50,1,-35,-6,-35,-19,-48,-29,-54,-39,-66,-55,-73,-51,-75,-30,-81,-5],[-52,83,-23,77,-20,66,-42,59,-55,65,-65,76],[-17,36,-5,36,10,37,30,31,35,22,43,12,51,11,43,-2,41,-15,33,-28,20,-35,12,-25,8,-5,-2,5,-16,14],[-10,36,-9,43,-1,50,-6,58,6,58,8,71,29,71,38,64,60,69,90,75,120,73,160,65,180,65,177,52,160,58,145,49,140,40,130,32,122,23,114,21,109,10,106,1,100,7,96,19,88,22,80,9,73,8,67,24,57,25,49,14,44,12,35,30,29,41,21,38,14,42,6,44,0,43], [112,-11,131,-12,139,-17,146,-18,153,-27,149,-38,135,-35,129,-32,115,-35,112,-22], [47,-13,50,-16,49,-25,44,-25], [130,32,135,35,138,40,142,44,145,43,141,35], [-10,51,-6,50,-1,54,-4,59,-7,58], [95,5,105,-6,116,-9,127,-8,134,-5,128,2,118,5,109,1,103,4], [172,-35,178,-38,173,-43,167,-47,166,-45,170,-39]]
paths=[]
for pts in continents:
 coords=[((pts[i]+180)/360*1000,(90-pts[i+1])/180*500) for i in range(0,len(pts),2)]
 paths.append('<path d="M'+' L'.join(f'{x:.1f},{y:.1f}' for x,y in coords)+' Z"/>')
grid=''.join(f'<path d="M{x} 0V500"/>' for x in range(0,1001,100))+''.join(f'<path d="M0 {y}H1000"/>' for y in range(0,501,50))
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 500"><defs><radialGradient id="o"><stop stop-color="#29314b"/><stop offset="1" stop-color="#111323"/></radialGradient><linearGradient id="l" x2=".3" y2="1"><stop stop-color="#83745e"/><stop offset="1" stop-color="#39384b"/></linearGradient></defs><rect width="1000" height="500" rx="16" fill="url(#o)"/><g fill="none" stroke="#cbb68c" opacity=".09" stroke-width=".5">{grid}</g><g fill="url(#l)" stroke="#b9a477" stroke-width="1.1" stroke-linejoin="round">{''.join(paths)}</g></svg>'''
assets=site/'assets/guardian-campaign';assets.mkdir(exist_ok=True)
(assets/'world.svg').write_text(svg,encoding='utf-8')
print(len(regions),'regions;',len(entries['nodes']),'sequential encounters; initial region: Greece.')
