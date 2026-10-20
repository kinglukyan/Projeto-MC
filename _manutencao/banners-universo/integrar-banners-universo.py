from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json,re,html,shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo';work=root/'work/banners-universo'
spec=json.loads((work/'prompts.json').read_text(encoding='utf-8'))
out=site/'assets/universe/characters';out.mkdir(exist_ok=True)
done=[]
for r in spec['records']:
 src=work/'geradas'/f"{r['id']}.png"
 if not src.exists():continue
 target=out/f"{r['id']}.webp"
 if not target.exists() or target.stat().st_mtime<src.stat().st_mtime:
  im=Image.open(src).convert('RGB');im.thumbnail((1920,1920),Image.Resampling.LANCZOS);im.save(target,'WEBP',quality=88,method=6)
 r['status']='completed';r['asset']=target.relative_to(site).as_posix();r['dimensions']=list(Image.open(target).size);r['bytes']=target.stat().st_size
 r['references']=[f"assets/holograms/{r['id']}-hologram.webp",'assets/universe/banner-02.png']
 done.append(r)
p=site/'universe-banners.js';s=p.read_text(encoding='utf-8')
first=s.splitlines()[0];data=json.loads(first[first.index('{'):first.rindex('}')+1])
for r in done:data[r['id']]={'atlas':r['asset'],'format':'wide','x':0,'y':0}
rest='\n'.join(s.splitlines()[1:])
rest=rest.replace("banner.dataset.customBanner=id;", "banner.dataset.customBanner=id;banner.dataset.bannerFormat=asset.format||'atlas';")
rest=rest.replace("node.style.backgroundSize='200% 200%';node.style.backgroundPosition=`${asset.x*100}% ${asset.y*100}%`;", "node.style.backgroundSize=asset.format==='wide'?'cover':'200% 200%';node.style.backgroundPosition=asset.format==='wide'?'center':`${asset.x*100}% ${asset.y*100}%`;")
p.write_text('window.MythicUniverseBanners='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n'+rest+'\n',encoding='utf-8')
p=site/'public-hall.js';s=p.read_text(encoding='utf-8').replace("node.style.backgroundSize='200% 200%';node.style.backgroundPosition=(b.x*100)+'% '+(b.y*100)+'%';", "node.style.backgroundSize=b.format==='wide'?'cover':'200% 200%';node.style.backgroundPosition=b.format==='wide'?'center':(b.x*100)+'% '+(b.y*100)+'%';");p.write_text(s,encoding='utf-8')
p=site/'universe-upgrade.css';s=p.read_text(encoding='utf-8');marker='/* Individual panoramic banners: preserve the original character proportions. */'
css='''
/* Individual panoramic banners: preserve the original character proportions. */
.concept-story-banner[data-banner-format="wide"] .universe-banner-art{inset:0;width:100%;height:100%;aspect-ratio:auto;background-size:cover;background-position:center}
body.concept-ui #view-lore .concept-lore-reader[data-mode="preview"] .concept-story-banner[data-banner-format="wide"] .universe-banner-art{inset:auto 0 auto auto;top:50%;width:max(100%,calc(var(--universe-preview-height) * 3));height:auto;aspect-ratio:3/1;transform:translateY(-50%)}
'''
if marker not in s:s+=css
p.write_text(s,encoding='utf-8')

# Standalone contact gallery uses lazy loading and only optimized final assets.
gallery='''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Banners do Universo — Mythic Clash</title><link rel="stylesheet" href="banners-universo.css"></head><body><header><a href="index.html">← Mythic Clash</a><h1>Novos banners do Universo</h1><p>70 personagens · 7 facções · cenários individuais</p></header><main>'''
for faction in dict.fromkeys(r['faction'] for r in done):
 gallery+='<section><h2>'+html.escape(faction)+'</h2><div class="gallery">'
 for r in done:
  if r['faction']!=faction:continue
  gallery+='<figure><a href="'+r['asset']+'"><img loading="lazy" decoding="async" src="'+r['asset']+'" alt="Banner de '+html.escape(r['name'],quote=True)+'" width="'+str(r['dimensions'][0])+'" height="'+str(r['dimensions'][1])+'"></a><figcaption>'+html.escape(r['name'])+'</figcaption></figure>'
 gallery+='</div></section>'
gallery+='</main></body></html>'
(site/'banners-universo.html').write_text(gallery,encoding='utf-8')
(site/'banners-universo.css').write_text('body{margin:0;background:#120e1d;color:#eee4d1;font:16px/1.6 system-ui;padding:clamp(16px,4vw,60px)}a{color:#d0b0fc}h1,h2{font-family:Georgia,serif;color:#edd18e}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,560px),1fr));gap:24px}figure{margin:0;border:1px solid #75598f;border-radius:12px;overflow:hidden;background:#20162e}img{display:block;width:100%;height:auto}figcaption{padding:10px 18px;font-weight:700}header{margin-bottom:40px}section{margin-bottom:50px}',encoding='utf-8')
maintenance=site/'_manutencao/banners-universo';maintenance.mkdir(exist_ok=True)
(maintenance/'prompts.json').write_text(json.dumps({'mode':'built-in-imagegen','records':done},ensure_ascii=False,indent=2),encoding='utf-8')
shutil.copy2(Path(__file__),maintenance/Path(__file__).name)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
for start in range(0,len(done),10):
 rows=done[start:start+10];board=Image.new('RGB',(1440,240*((len(rows)+1)//2)),(27,22,37));draw=ImageDraw.Draw(board)
 for j,r in enumerate(rows):
  x=(j%2)*720;y=(j//2)*240
  ref=Image.open(work/'geradas'/f"{r['id']}.png").convert('RGB');ref=ImageOps.fit(ref,(600,200),Image.Resampling.LANCZOS)
  board.paste(ref,(x+110,y+28))
  identity=Image.open(root/'work/importacao-cartas/holograms-novas'/f"{r['id']}.png").convert('RGBA');identity.thumbnail((100,200),Image.Resampling.LANCZOS)
  board.paste(identity,(x+(100-identity.width)//2,y+28+(200-identity.height)//2),identity)
  draw.text((x+10,y+4),r['name'],font=font,fill=(242,219,164))
 board.save(work/f'revisao-{start//10+1:02d}.jpg',quality=88)
print(len(done),'banners integrated;',sum(r['bytes'] for r in done),'bytes.')
