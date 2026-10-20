from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]/'outputs/Mythic-Clash-Completo'
D=json.loads((root/'abilities-data.json').read_text(encoding='utf-8'))['cards'];output=root/'assets/entry';output.mkdir(exist_ok=True)
optimized={};cards={};by_art={};before=after=0
for c in D:
 art=c.get('art');p=root/art if art else None
 if not p or not p.is_file():continue
 with Image.open(p) as im:
  im=im.convert('RGBA' if im.mode=='RGBA' else 'RGB');im.thumbnail((480,720),Image.Resampling.LANCZOS);dest=output/(c['id']+'-preview.webp');im.save(dest,'WEBP',quality=88,method=6)
 cards[c['id']]=dest.relative_to(root).as_posix();by_art[art]=cards[c['id']]
 # Legacy special cards still used multi-megabyte PNG files.
 if c['kind']!='unit' and p.suffix.lower() in ['.png','.jpg','.jpeg']:
  dest=output/(c['id']+'-full.webp')
  with Image.open(p) as im:
   im=im.convert('RGBA' if im.mode=='RGBA' else 'RGB');im.thumbnail((1100,1600),Image.Resampling.LANCZOS);im.save(dest,'WEBP',quality=94,method=6)
  optimized[art]=dest.relative_to(root).as_posix();by_art[optimized[art]]=cards[c['id']];before+=p.stat().st_size;after+=dest.stat().st_size
sources=['assets/onboarding/starter-pack.png','assets/concept-ui/citadela-luminosa.png','assets/backgrounds/citadela-paisagem.png','assets/sidebar-arcane/crystal-texture.png']+[p.relative_to(root).as_posix() for p in (root/'assets/universe').glob('banner-*.png')]
for art in sources:
 p=root/art
 if not p.is_file():continue
 dest=output/(p.stem+'.webp')
 with Image.open(p) as im:
  im=im.convert('RGBA' if im.mode=='RGBA' else 'RGB');limit=(640,960) if 'starter-pack' in art else ((960,960) if 'crystal' in art else (1920,1920));im.thumbnail(limit,Image.Resampling.LANCZOS);im.save(dest,'WEBP',quality=88,method=6)
 optimized[art]=dest.relative_to(root).as_posix();before+=p.stat().st_size;after+=dest.stat().st_size
media={'version':1,'cards':cards,'byArt':by_art,'optimized':optimized}
(root/'entry-media.js').write_text('window.MythicEntryMedia='+json.dumps(media,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
(root/'_manutencao/otimizacao-entrada.json').write_text(json.dumps({'originalBytes':before,'optimizedBytes':after,'assets':optimized,'previews':len(cards),'previewBytes':sum((root/v).stat().st_size for v in cards.values())},ensure_ascii=False,indent=2),encoding='utf-8')
# CSS backgrounds cannot pass through the URL helper; replace these explicit references.
for p in list(root.glob('*.css'))+[root/'universe-banners.js']:
 if p.name=='game-interface.css':continue
 s=p.read_text(encoding='utf-8-sig')
 for old,new in optimized.items():s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
print(f'Assets usados na entrada: {before/1024/1024:.1f} MB -> {after/1024/1024:.1f} MB. {len(cards)} previews.')
