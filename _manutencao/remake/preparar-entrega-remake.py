from pathlib import Path
import json,shutil,hashlib,re,ast
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo';work=root/'work/importacao-cartas';maintenance=site/'_manutencao/remake';maintenance.mkdir(exist_ok=True)
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'));data['version']=1;data['release']='20261020-remake';data['remakeRules']=json.loads((site/'remake-rules.json').read_text(encoding='utf-8'))
for c in data['cards']:
 if c['id']=='clone-macaco':c['tags']=['monstro','clone'];c['type']='Companheiro'
(site/'abilities-data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'abilities-data.js').write_text('window.MythicAbilitiesData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
avatars=json.loads((site/'avatars-chibi.json').read_text(encoding='utf-8'));avatars['version']=1;avatars['release']='20261020-remake'
(site/'avatars-chibi.json').write_text(json.dumps(avatars,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'avatars-chibi.js').write_text('window.MythicChibiAvatars='+json.dumps(avatars,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
for name in ['cards-remake.json','card-hologram-map.json']:
 p=site/name;obj=json.loads(p.read_text(encoding='utf-8'));obj['version']='20261020';p.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')
p=site/'card-expansion.js';s=p.read_text(encoding='utf-8');obj=json.loads(s[s.index('{'):s.rindex('}')+1]);obj['version']='20261020';p.write_text('window.MythicCardExpansion='+json.dumps(obj,ensure_ascii=False,indent=2)+';\n',encoding='utf-8')
cards=[c for c in data['cards'] if c.get('sourceEdition')=='remake-20261020']
received=json.loads((work/'manifest.json').read_text(encoding='utf-8'));by_id={c['id']:c for c in cards}
origin=[{'id':c['id'],'file':c['file'],'new':c['new'],'name':by_id[c['id']]['name'],'power':by_id[c['id']]['power'],'faction':by_id[c['id']]['faction'],'abilityTitle':by_id[c['id']]['abilityTitle'],'ability':by_id[c['id']]['ability']} for c in received]
(maintenance/'cartas-recebidas.json').write_text(json.dumps({'archive':'Cartas.zip','cards':origin},ensure_ascii=False,indent=2),encoding='utf-8')
templates=json.loads((work/'prompt-templates.json').read_text(encoding='utf-8'))
records=[];log_fragments=[]
for line in (work/'geracoes.jsonl').read_text(encoding='utf-8-sig').splitlines():
 if line.strip():
  try:records.append(json.loads(line.lstrip('\ufeff')))
  except json.JSONDecodeError:log_fragments.append(line)
(maintenance/'fragmentos-log-geracao.json').write_text(json.dumps(log_fragments,ensure_ascii=False,indent=2),encoding='utf-8')
custom={
 ('japonesa-amaterasu','chibi'):"Use case: stylized-concept. ONE square Mythic Clash profile avatar of Amaterasu based exactly on the character inside the reference card: long black hair, ornate golden sunburst crown, warm face, white red golden kimono collar. Premium polished chibi bust, oversized expressive eyes, large head, tiny shoulders, detailed sculpted soft 3D-painterly finish, appealing confident expression. Match game chibi avatar style, subtle purple edge lighting. Centered head and shoulders, all crown inside frame with margin. No card, text, circle frame or scenery. Genuine transparent background.",
 ('brasil-saci','hologram'):"Use case: background-extraction / identity-preserve. ONE full-body Mythic Clash hologram asset based on the illustrated Saci-Pererê inside the card. Preserve dark brown skin, curly black hair, long red cap, red shorts, mischievous smile, and exactly ONE leg. Same playful twisting pose balancing on his single foot. Character head to foot entirely visible, 8% margins, premium painterly realistic fantasy matching reference. A few leaves spiraling immediately near the foot. No scenery, floor, card, text, emblems, pedestal or background. Genuine transparent background.",
 ('brasil-saci','chibi'):"Use case: stylized-concept. ONE square Mythic Clash profile avatar, chibi head and tiny shoulders of Saci-Pererê from reference card. Preserve dark brown skin, short black curls, long red floppy cap, cheeky warm grin. Premium sculpted 3D-painterly chibi, big expressive brown eyes, detailed hair, subtle purple rim light, oversized head. Entire hat inside frame with comfortable margin. No body, text, card, badge, border or scenery. Genuine transparent background."
}
selected={}
for c in received:
 if c['new']:
  for kind in ['hologram','chibi']:selected[(c['id'],kind)]={'id':c['id'],'kind':kind,'file':c['file'],'prompt':custom.get((c['id'],kind),templates['templates'][kind].replace('${c.name}',c['name']))}
for rec in records:selected[(rec['id'],rec['kind'])]=rec
for key,rec in selected.items():rec['asset']=('assets/holograms/'+rec['id']+'-hologram.webp') if rec['kind']=='hologram' else ('assets/avatars-chibi/'+rec['id']+'.webp');rec.pop('path',None)
(maintenance/'prompts-selecionados.json').write_text(json.dumps({'mode':'built-in image_gen','assets':list(selected.values()),'iterations':records},ensure_ascii=False,indent=2),encoding='utf-8')
for path in (root/'work').glob('remake-*.sql'):shutil.copy2(path,maintenance/path.name)
for name in ['remake-engine-fragment.js','compilar-sql-remake.py','definir-regras-remake.py','integrar-motor-remake.py','finalizar-assets-remake.py','importar-cartas-site.py','preparar-importacao-cartas.py','produzir-clone-macaco.py','otimizar-cartas-remake.py','integrar-interface-remake.py','preparar-entrega-remake.py']:
 shutil.copy2(root/'work'/name,maintenance/name)
# The SQL compiler is usable from the delivered folder, with no original workspace.
p=maintenance/'compilar-sql-remake.py';s=p.read_text(encoding='utf-8');s=s.replace("root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'", "maintenance=Path(__file__).resolve().parent;site=maintenance.parents[1]")
s=s.replace("root/'work/", "maintenance/'")
ast.parse(s);p.write_text(s,encoding='utf-8')
guide='''# Cartas Remake — 20/10/2026

## Conteúdo desta entrega

- 108 cartas recebidas: 70 novas e 38 atualizadas, com os poderes e textos lidos das imagens.
- 71 hologramas novos e 71 ícones chibi novos. As outras 37 imagens de cada tipo foram aproveitadas da coleção existente.
- O Soldado de Esparta recebeu novo holograma. Rei de Todos recebeu ícone próprio.
- Galerias: `cartas-hologramas.html` e `icones-chibi.html`.
- Uma carta virtual de Clone Macaco, com poder 2 e sem habilidade, para a invocação de Sun Wukong.
- Cartas para o site com largura de 1100 pixels, seguindo o tamanho usado antes. As cópias em resolução recebida ficam em `_manutencao/remake/cartas-resolucao-recebida/`.
- Hologramas e chibis produzidos pela ferramenta integrada de criação de imagens. Prompts e iterações: `_manutencao/remake/prompts-selecionados.json`.

## Publicar no jogo online

Esta pasta está atualizada localmente. O domínio da Vercel e o banco Supabase não foram atualizados nesta execução.

1. No Supabase, aplicar `supabase/migrations/202610200040_remake_character_collection.sql`, após a migração 039.
2. Aplicar `supabase/migrations/202610200041_remake_chibi_icons.sql`.
3. Publicar esta pasta na Vercel, usando seu `vercel.json`. O build existente exclui `_manutencao` da pasta pública.

Os IDs antigos e as coleções já obtidas foram preservados. Cartas novas seguem o preço atual de 1000 MC e ícones, 500 MC. Preços e pausas personalizados de itens existentes são preservados pela migração.

## Interações adotadas

- Efeitos de entrada atingem os alvos presentes naquele momento; auras acompanham entradas, saídas e mudanças de fileira.
- Silêncio individual desativa a habilidade da unidade, mantendo equipamentos e efeitos externos. Dionísio conserva seu silêncio global.
- Apenas efeitos com “pode” ou “até” oferecem a opção de concluir sem escolher um alvo, quando houver alvos válidos.
- Proteções de Heimdall, Durga, Vishnu, Curupira, Chang'e e Boitatá são consideradas pelos efeitos correspondentes.
- Reduções diretas são bloqueadas por Vishnu. Remover um equipamento ou uma fonte de aura continua sendo uma ação distinta.
- Erlang Shen remove modificadores positivos armazenados e suspende o poder dos equipamentos já anexados. Auras contínuas continuam dependendo de sua fonte ativa.
- Efeitos limitados por Round mantêm sua memória na ressurreição; equipamentos não voltam anexados.
- Clones são unidades temporárias: não entram no baralho nem na mão e desaparecem ao sair do campo ou ao encerrar o Round.
- Escolhas atribuídas ao adversário, como um empate de alvos de Shiva, usam a fila de efeitos com tempo limitado e sem revelar cartas privadas.

## Manutenção

O catálogo final está em `abilities-data.json`; as 70 regras novas, em `remake-rules.json`. O motor de treino está em `abilities-engine.js`, e sua versão de servidor, na migração 040. O compilador da pasta `_manutencao/remake` recompõe o SQL a partir desses dados.

Foram realizadas conferência visual dos arquivos e checagens de sintaxe. Não foram executadas partidas de teste nem migrações no banco remoto.
'''
(site/'ATUALIZACAO-CARTAS-REMAKE.md').write_text(guide,encoding='utf-8')
(maintenance/'README.md').write_text('Catálogo e prompts da importação de Cartas.zip.\n\nO compilador `compilar-sql-remake.py` desta pasta pode ser executado com Python 3 para recompor a migração 040. Os demais scripts registram o processo de preparação e podem exigir os arquivos de origem e o runtime do TCG.\n',encoding='utf-8')
catalog=['# Cartas importadas de Cartas.zip','']
for faction in sorted({c['faction'] for c in cards}):
 catalog.extend(['## '+faction,''])
 for c in cards:
  if c['faction']==faction:catalog.extend(['### '+c['name'],'','**Poder:** '+str(c['power'])+' · **'+c['abilityTitle']+'**','',c['ability'],''])
(maintenance/'CATALOGO-REMAKE.md').write_text('\n'.join(catalog),encoding='utf-8')
# Keep current media caches; changed content gets a new revision key.
p=site/'sw.js';s=p.read_text(encoding='utf-8');stamp='// Remake 20261020: 108 cartas, hologramas e chibis; cache de mídia preservado.\n'
if not s.startswith(stamp):p.write_text(stamp+s,encoding='utf-8')
assets={p.relative_to(site).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()[:20] for p in sorted((site/'assets').rglob('*')) if p.is_file()}
(site/'asset-manifest.json').write_text(json.dumps({'version':1,'release':'20261020-remake','assets':assets},ensure_ascii=False,indent=2),encoding='utf-8')
for p in site.glob('*.html'):
 s=p.read_text(encoding='utf-8-sig')
 def revision(m):
  path=site/m.group(2)
  return m.group(1)+m.group(2)+'?v='+hashlib.sha256(path.read_bytes()).hexdigest()[:20]+m.group(3) if path.is_file() else m.group(0)
 s=re.sub(r'((?:src|href)=\")([^\"?#]+\.(?:js|css))(?:\?v=[^\"]*)?(\")',revision,s)
 p.write_text(s,encoding='utf-8')
print('Entrega preparada:',len(cards),'cartas,',len(avatars['avatars']),'avatares,',len(selected),'artes novas selecionadas.',flush=True)
