"""Novos gregos e trilhas com oponentes únicos. Execute uma vez antes de publicar."""
from pathlib import Path
import json,re,copy,math
root=Path(__file__).resolve().parents[2]
migration=root/'supabase/migrations/202610220055_unique_atlas_and_greek_characters.sql'
if migration.exists():raise SystemExit('055 já preparada; edite as fontes atuais sem regenerar a migração histórica.')
def read(name):return json.loads((root/name).read_text(encoding='utf-8-sig'))
def dump(name,data): (root/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def js(name,prefix,data): (root/name).write_text(prefix+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
def quote(s):return "'"+str(s).replace("'","''")+"'"
definitions=[
 ('hera','Hera',6,'Deusa','SOBERANIA DO OLIMPO','Enquanto Hera estiver em campo, as outras unidades gregas aliadas na sua fileira recebem +1 de poder. Esta aura não se acumula com outra Hera.',{'op':'aura','faction':'Grécia','amount':1,'unique':True},'Rainha do Olimpo, Hera sustenta sua autoridade entre juramentos, coroas e alianças. Na Convergência, sua presença reúne os gregos em uma única frente.'),
 ('demeter','Deméter',4,'Deusa','COLHEITA ABUNDANTE','Ao entrar, compre 1 carta. Depois, escolha outra unidade grega aliada na mesma fileira para receber +2 de poder.',{'op':'drawBuff','faction':'Grécia','amount':2},'Deméter guarda os ciclos da terra. Quando a Convergência alcança seus campos, a deusa transforma a abundância das colheitas em força para seus aliados.'),
 ('hestia','Héstia',4,'Deusa','CHAMA DO LAR','Enquanto Héstia estiver em campo, as outras unidades gregas aliadas na sua fileira ficam protegidas contra reduções de poder causadas por habilidades.',{'op':'protectReduction','faction':'Grécia'},'No centro de cada lar, Héstia preserva uma chama. Mesmo diante da Convergência, oferece abrigo e firmeza àqueles que lutam ao seu lado.'),
 ('perseu','Perseu',5,'Herói','GOLPE DO ESPELHO','Ao entrar, escolha e destrua uma unidade inimiga de até 4 de poder atual na fileira oposta.',{'op':'destroy','opposite':True,'max':4},'Com a espada curva e o escudo espelhado, Perseu enfrenta o desconhecido. Na Convergência, o herói confia na observação e na precisão antes do golpe decisivo.'),
]
new=[];rules=read('remake-rules.json')
for cid,name,power,cls,title,ability,rule,story in definitions:
 new.append({'id':cid,'name':name,'kind':'unit','type':'Personagem','subtype':cls,'characterClass':cls,'faction':'Grécia','badgeKey':'greece','power':power,'cost':4 if power>=5 else 3,'abilityTitle':title,'ability':ability,'art':f'assets/cards-remake/{cid}.webp','hologram':f'assets/holograms/{cid}-hologram.webp','tags':['grego','heroi' if cls=='Herói' else 'deus'],'glow':'rgba(83,53,128,.42)','previewOnly':False,'specialOnly':False,'abilityPending':False,'sourceEdition':'greeks-20261022','story':[story]})
 rules[cid]=rule
dump('remake-rules.json',rules);js('remake-rules.js','window.MythicRemakeRules=',rules)
abilities=read('abilities-data.json');abilities['cards']=[c for c in abilities['cards'] if c['id'] not in rules or c['id'] not in {c['id'] for c in new}]+new;abilities['remakeRules']=rules
dump('abilities-data.json',abilities);js('abilities-data.js','window.MythicAbilitiesData=',abilities)
expansion_text=(root/'card-expansion.js').read_text(encoding='utf-8-sig');expansion=json.loads(expansion_text.split('=',1)[1].strip().removesuffix(';'));expansion['cards']+=new;js('card-expansion.js','window.MythicCardExpansion=',expansion)
for filename in ['cards-remake.json','card-hologram-map.json']:
 data=read(filename);data['cards']+=new;dump(filename,data)
chibi_text=(root/'avatars-chibi.js').read_text(encoding='utf-8-sig');chibi=json.loads(chibi_text.split('=',1)[1].strip().removesuffix(';'))
for c in new:chibi['avatars'].append({'id':'chibi-'+c['id'],'characterId':c['id'],'name':c['name'],'asset':f"assets/avatars-chibi/{c['id']}.webp",'single':True})
js('avatars-chibi.js','window.MythicChibiAvatars=',chibi)
p=root/'universe-banners.js';s=p.read_text(encoding='utf-8-sig');offset=s.index(';')
banners=json.loads(s[:offset].split('=',1)[1]);banners.update({c['id']:{'atlas':f"assets/universe/characters/{c['id']}.webp",'format':'wide','x':0,'y':0} for c in new});p.write_text('window.MythicUniverseBanners='+json.dumps(banners,ensure_ascii=False,separators=(',',':'))+s[offset:],encoding='utf-8')
p=root/'world-lore.js';s=p.read_text(encoding='utf-8-sig');lore=json.loads(s.split('=',1)[1].strip().removesuffix(';'));lore.update({c['id']:{'origin':'MITOLOGIA GREGA · RECONTO','story':c['story']} for c in new});js('world-lore.js','window.MythicWorldLore=',lore)
catalog=read('_manutencao/guardian-campaign/catalogo-servidor.json');old=copy.deepcopy(catalog)
for stage,cid in [(8,'perseu'),(9,'hestia'),(13,'demeter'),(14,'hera')]:
 n=catalog['nodes'][f'greece-{stage:02}'];c=next(c for c in new if c['id']==cid);n.update(opponent=cid,name=c['name'],icon='chibi-'+cid);n.pop('placeholder',None);n['deck'][cid]=1
 # Keep the previous deck size, replacing one generic card.
 for key in list(n['deck']):
  if key!=cid and n['deck'][key]>0:
   n['deck'][key]-=1
   if n['deck'][key]==0:del n['deck'][key]
   break
catalog['cards']+=new
catalog['version']=4
legacy={};mapping={};progress_map={};new_nodes={}
for region in catalog['regions']:
 seen={};kept=[];stages=[0]
 for old_id in region['nodeIds']:
  node=catalog['nodes'][old_id];key=node.get('opponent') or old_id
  if key not in seen:
   seen[key]=old_id;kept.append(old_id);node['stage']=len(kept);node['chapter']=(len(kept)-1)//5;new_nodes[old_id]=node
  else:legacy[old_id]=old['nodes'][old_id]
  mapping[old_id]=seen[key];stages.append(len(kept))
 region['nodeIds']=kept;region['chapters']=region['chapters'][:math.ceil(len(kept)/5)];progress_map[region['id']]=stages
 for i,nid in enumerate(kept):new_nodes[nid]['boss']=(i+1)%5==0 or i==len(kept)-1
catalog['nodes']=new_nodes;catalog['legacyNodes']=legacy
dump('_manutencao/guardian-campaign/catalogo-servidor.json',catalog)
public={k:v for k,v in catalog.items() if k not in ('cards','impact','legacyNodes')};public['nodes']={k:{a:b for a,b in n.items() if a!='deck'} for k,n in new_nodes.items()};js('guardian-campaign-data.js','window.MythicGuardianCampaignData=',public)

sql='''-- 055: Apply after 054. Unique opponents, variable trail sizes, four new Greek cards.
begin;
do $pre$ begin
 if to_regprocedure('public._gc_drive(jsonb,text,integer)') is null then raise exception 'Aplique primeiro as migrações anteriores até a 054.';end if;
end $pre$;
'''
sql+="create or replace function public._gc_data() returns jsonb language sql immutable set search_path='' as $$ select $atlas055$"+json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+"$atlas055$::jsonb $$;\n"
sql+="create or replace function public._gc_node(nid text) returns jsonb language sql immutable set search_path='' as $$ select coalesce(public._gc_data()#>array['nodes',nid],public._gc_data()#>array['legacyNodes',nid]) $$;\n"
sql+='''do $progress$ declare p record;mapping jsonb:=$map$'''+json.dumps(progress_map,separators=(',',':'))+'''$map$::jsonb;begin
 if not exists(select 1 from public.game_schema_versions where version='atlas-unique-055') then
  for p in select player_id,region_id,cleared from public.guardian_campaign_progress for update loop
   update public.guardian_campaign_progress set cleared=coalesce((mapping#>>array[p.region_id,least(20,greatest(0,p.cleared))::text])::integer,p.cleared),updated_at=clock_timestamp() where player_id=p.player_id and region_id=p.region_id;
  end loop;
  insert into public.game_schema_versions(version) values('atlas-unique-055');
 end if;
end $progress$;
'''
# Use a private, narrowly scoped migration marker instead of relying on application tables.
sql=sql.replace("public.game_schema_versions", "public.mythic_migration_markers")
marker="create table if not exists public.mythic_migration_markers(version text primary key,applied_at timestamptz not null default now());\nalter table public.mythic_migration_markers enable row level security;\nrevoke all on public.mythic_migration_markers from public,anon,authenticated;\n"
sql=sql.replace('do $progress$',marker+'do $progress$',1)
sql+='''update public.guardian_campaign_runs run set node_id=map.value,version=run.version+1 from jsonb_each_text($active$'''+json.dumps(mapping,separators=(',',':'))+'''$active$::jsonb) map where run.status='active' and run.node_id=map.key and run.node_id<>map.value;
'''
api=(root/'_manutencao/guardian-campaign/guardian-campaign-api.sql').read_text(encoding='utf-8-sig');oldcheck="if previous_cleared<20 then";newcheck="if previous_cleared<jsonb_array_length(previous_region->'nodeIds') then";api=api.replace(oldcheck,newcheck)
(root/'_manutencao/guardian-campaign/guardian-campaign-api.sql').write_text(api,encoding='utf-8')
sql+=re.search(r'create or replace function public\.start_guardian_campaign\(.*?end \$\$;',api,re.S).group()+'\n'
schema=root/'_manutencao/guardian-campaign/guardian-campaign-schema.sql';s=schema.read_text(encoding='utf-8-sig');s=s.replace("select public._gc_data()#>array['nodes',nid]", "select coalesce(public._gc_data()#>array['nodes',nid],public._gc_data()#>array['legacyNodes',nid])");schema.write_text(s,encoding='utf-8')
sql+='''do $rename$ begin
 if to_regprocedure('public._r_card_before055(text)') is null then alter function public._r_card(text) rename to _r_card_before055;end if;
 if to_regprocedure('public._r_data_before055()') is null then alter function public._r_data() rename to _r_data_before055;end if;
end $rename$;
'''
cards_json=json.dumps({c['id']:c for c in new},ensure_ascii=False,separators=(',',':'));rules_json=json.dumps({c['id']:rules[c['id']] for c in new},ensure_ascii=False,separators=(',',':'));array_json=json.dumps(new,ensure_ascii=False,separators=(',',':'))
sql+="create or replace function public._r_card(cid text) returns jsonb language sql immutable set search_path='' as $$ select coalesce($cards055$"+cards_json+"$cards055$::jsonb->cid,public._r_card_before055(cid)) $$;\n"
sql+="create or replace function public._r_data() returns jsonb language sql immutable set search_path='' as $$ select public._r_data_before055()||jsonb_build_object('remakeRules',coalesce(public._r_data_before055()->'remakeRules','{}')||$rules055$"+rules_json+"$rules055$::jsonb,'cards',coalesce(public._r_data_before055()->'cards','[]')||$list055$"+array_json+"$list055$::jsonb) $$;\n"
sql+='''do $constraint$ declare expression text;begin
 select pg_get_expr(conbin,conrelid) into expression from pg_constraint where conrelid='public.card_lore'::regclass and conname='card_lore_card_id_check';
 if expression is not null then
  alter table public.card_lore drop constraint card_lore_card_id_check;
  execute 'alter table public.card_lore add constraint card_lore_card_id_check check (('||expression||') or card_id in (''hera'',''demeter'',''hestia'',''perseu''))';
 end if;
end $constraint$;
'''
sql+='insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values\n'+',\n'.join('('+','.join([quote(c['id']),quote(c['name']),quote(c['abilityTitle']),quote(c['ability']),quote(c['art']),quote(c['faction']),str(c['power']),"'greece'"])+')' for c in new)+''' on conflict(card_id) do nothing;
'''
products=[]
for c in new:
 products.append('('+','.join([quote('card-'+c['id']),quote(c['name']),quote(c['ability']),"'card'",'1000',quote(c['art']),quote(c['id']),'true'])+')')
 products.append('('+','.join([quote('chibi-'+c['id']),quote(c['name']+' · Chibi'),quote('Ícone de perfil de '+c['name']),"'avatar'",'1200',quote(f"assets/avatars-chibi/{c['id']}.webp"),'null','true'])+')')
sql+='insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active) values\n'+',\n'.join(products)+' on conflict(item_id) do nothing;\n'
sql+='''revoke all on function public._gc_data(),public._gc_node(text),public._r_card_before055(text),public._r_data_before055(),public._r_card(text),public._r_data() from public,anon,authenticated;
revoke all on function public.start_guardian_campaign(text,jsonb) from public,anon;
grant execute on function public.start_guardian_campaign(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
'''
migration.write_text(sql,encoding='utf-8')
dump('_manutencao/novos-gregos.json',{'cards':new,'rules':{c['id']:rules[c['id']] for c in new}})
(root/'ATLAS-SEM-REPETICOES.md').write_text('# Ordem atual do Atlas\n\n'+ '\n\n'.join(f"## {r['order']}. {r['name']} · {len(r['nodeIds'])} desafios\n\n"+'\n'.join(f"{i}. {catalog['nodes'][nid]['name']}" for i,nid in enumerate(r['nodeIds'],1)) for r in catalog['regions'])+'\n\nO progresso foi convertido contando adversários distintos já vencidos. Tesouros e históricos existentes foram preservados.\n',encoding='utf-8')
print('055 preparada:',len(new_nodes),'desafios únicos e',len(new),'novos gregos.')
