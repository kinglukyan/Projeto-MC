"""Gera WebP sem alterar os originais. Requer Python + Pillow; resultado já acompanha a entrega."""
from pathlib import Path
from PIL import Image,ImageOps
import json,hashlib
root=Path(__file__).resolve().parents[1]
media=root/'entry-media.js';text=media.read_text(encoding='utf-8-sig');data=json.loads(text[text.index('=')+1:].strip().rstrip(';'))
destination=root/'assets/optimized';destination.mkdir(exist_ok=True)
records=[];mapping=data.setdefault('optimized',{})
for p in sorted((root/'assets').rglob('*')):
 if not p.is_file() or p.suffix.lower() not in('.png','.jpg','.jpeg') or p.stat().st_size<120000:continue
 rel=p.relative_to(root).as_posix()
 if rel in mapping and not mapping[rel].startswith('assets/optimized/'):continue
 digest=hashlib.sha256(p.read_bytes()).hexdigest()[:16];target=destination/(p.stem[:45]+'-'+digest+'.webp')
 try:
  with Image.open(p) as image:
   if getattr(image,'is_animated',False):continue
   img=ImageOps.exif_transpose(image).convert('RGBA' if 'A' in image.getbands() else 'RGB')
   limit=(1600,2300) if img.height>img.width*1.2 else (1920,1440)
   img.thumbnail(limit,Image.Resampling.LANCZOS)
   if not target.exists():img.save(target,'WEBP',quality=91,method=5)
   if target.stat().st_size>=p.stat().st_size*.9:continue
   mapping[rel]=target.relative_to(root).as_posix();records.append({'original':rel,'optimized':mapping[rel],'before':p.stat().st_size,'after':target.stat().st_size,'width':img.width,'height':img.height})
 except (OSError,ValueError):continue
media.write_text('window.MythicEntryMedia='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
report={'images':len(records),'original_bytes':sum(r['before'] for r in records),'optimized_bytes':sum(r['after'] for r in records),'files':records}
(root/'_manutencao/RELATORIO-IMAGENS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='files'}),flush=True)
