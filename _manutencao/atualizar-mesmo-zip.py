"""Atualiza o mesmo ZIP ao lado desta pasta. Requer Python 3."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
archive=root.parent/'Mythic-Clash-Completo.zip'
files=sorted(p for p in root.rglob('*') if p.is_file() and not any(part in {'__pycache__','site-publico','node_modules','.git'} for part in p.relative_to(root).parts) and p.suffix!='.pyc' and p.name!='INVENTARIO-SHA256.json')
manifest={p.relative_to(root).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
index=root/'_manutencao/INVENTARIO-SHA256.json'
index.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in files+[index]:z.write(p,Path(root.name)/p.relative_to(root))
print(str(archive))
print(f'{len(files)+1} arquivos; {archive.stat().st_size} bytes')
