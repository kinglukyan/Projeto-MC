from pathlib import Path
import os,sys,json
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
internal=root/'outputs/TCG-Card-Studio-Windows-v0.5-Catalogo-e-Cores/TCG-Card-Studio-0.4/_internal'
sys.path.insert(0,str(internal));handles=[os.add_dll_directory(str(p)) for p in [internal,internal/'PySide6'] if p.exists()]
os.environ['QT_PLUGIN_PATH']=str(internal/'PySide6/plugins')
from PySide6.QtGui import QImage
from PySide6.QtCore import Qt,QCoreApplication
app=QCoreApplication([])
folder=site/'assets/cards-remake';archive=site/'_manutencao/remake/cartas-resolucao-recebida';archive.mkdir(parents=True,exist_ok=True)
if not folder.resolve().is_relative_to(site.resolve()) or not archive.resolve().is_relative_to(site.resolve()):raise ValueError('Destino fora da pasta do jogo.')
before=after=0
for target in sorted(folder.glob('*.webp')):
 original=archive/target.name
 if not original.exists():target.replace(original)
 image=QImage(str(original));before+=original.stat().st_size
 if image.width()>1100:image=image.scaledToWidth(1100,Qt.TransformationMode.SmoothTransformation)
 if not image.save(str(target),'WEBP',96):raise RuntimeError(target)
 after+=target.stat().st_size
print('Cartas para o site:',round(after/1024/1024,1),'MB. Cópias na resolução recebida:',round(before/1024/1024,1),'MB.',flush=True)
