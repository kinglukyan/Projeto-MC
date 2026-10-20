from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]/'outputs/Mythic-Clash-Completo';module=root/'entry-media.js';s=module.read_text(encoding='utf-8');media=json.loads(s.split('=',1)[1].strip().rstrip(';'));meta_path=root/'_manutencao/otimizacao-entrada.json';meta=json.loads(meta_path.read_text(encoding='utf-8'))
paths=list((root/'assets/avatars-chibi').glob('portraits-*.png'))+list((root/'assets/card-badges').glob('*.png'))
for p in paths:
 relative=p.relative_to(root).as_posix()
 if relative in media['optimized']:continue
 dest=root/'assets/entry'/(p.parent.name+'-'+p.stem+'.webp')
 with Image.open(p) as im:
  im=im.convert('RGBA');im.thumbnail((256,256) if 'card-badges' in relative else (1600,1600),Image.Resampling.LANCZOS);im.save(dest,'WEBP',quality=90,method=6)
 media['optimized'][relative]=dest.relative_to(root).as_posix();meta['originalBytes']+=p.stat().st_size;meta['optimizedBytes']+=dest.stat().st_size
meta['assets']=media['optimized'];meta_path.write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8');module.write_text('window.MythicEntryMedia='+json.dumps(media,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8');print('Símbolos e atlas de chibis preparados.')
