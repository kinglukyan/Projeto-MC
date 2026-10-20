exec(open('work/produzir-cartas-v3.py',encoding='utf-8').read().split("data=base/")[0])
import copy
from footer_cleanup import is_footer_background
store=CatalogStore(base/'work/tcg-producao-v3')
row=store.connection.execute("SELECT body FROM projects WHERE json_extract(body,'$.attributes.name')='Sun Wukong' LIMIT 1").fetchone()
if row is None:raise ValueError('Arte de Sun Wukong não encontrada na biblioteca de produção.')
doc=json.loads(row[0]);doc['uuid']='virtual-clone-macaco';doc['game_id']='clone-macaco'
doc['attributes'].update(name='Clone Macaco',power=2,abilityTitle='Clone',ability='Sem habilidade. Desaparece ao fim do Round.',characterClass='Monstro',type='Personagem',kind='unit',faction='Chinesa')
doc['sides']['front']=[layer for layer in doc['sides']['front'] if not is_footer_background(layer)]
install_rendering();renderer=Renderer(store)
image=renderer.render(doc,'front',width=1500)
target=base/'outputs/Mythic-Clash-Completo/assets/cards-remake/clone-macaco.webp'
if not image.save(str(target),'WEBP',100):raise ValueError('Não foi possível salvar a carta de Clone Macaco.')
site=target.parents[2];p=site/'abilities-data.json';data=json.loads(p.read_text(encoding='utf-8'))
for c in data['cards']:
 if c['id']=='clone-macaco':c['art']='assets/cards-remake/clone-macaco.webp'
p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(site/'abilities-data.js').write_text('window.MythicAbilitiesData='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
store.close();print('Carta virtual Clone Macaco criada com poder 2.',flush=True)
