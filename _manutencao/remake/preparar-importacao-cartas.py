from pathlib import Path
import json,unicodedata,os,sys
root=Path(__file__).resolve().parents[1]
internal=root/'outputs/TCG-Card-Studio-Windows-v0.5-Catalogo-e-Cores/TCG-Card-Studio-0.4/_internal'
sys.path.insert(0,str(internal))
handles=[os.add_dll_directory(str(p)) for p in [internal,internal/'PySide6'] if p.exists()]
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_PLUGIN_PATH']=str(internal/'PySide6/plugins')
from PySide6.QtGui import QImage,QPainter,QColor,QFont,QGuiApplication
app=QGuiApplication([])
from PySide6.QtCore import Qt
def norm(s):return ''.join(c for c in unicodedata.normalize('NFKD',s).lower() if not unicodedata.combining(c)).replace('—','-').strip()
maintenance=root/'outputs/TCG-Card-Studio-0.4-Manutencao/assets'
designs=json.loads((maintenance/'prepared/designs.json').read_text(encoding='utf-8-sig'))
game=json.loads((maintenance/'in-game/catalog.json').read_text(encoding='utf-8-sig'))
print(type(game),flush=True)
if isinstance(game,dict):game=game.get('cards',game.get('entries',[]))
aliases={'rei arthur':'arthur','utu - shamash':'utu / shamash','nanna - sin':'nanna / sin'}
sources={norm(c['name']):c for c in designs}
for c in game:sources[norm(c.get('name',c.get('card_name','')))]=c
ocr=json.loads((root/'work/cartas-ocr.json').read_text(encoding='utf-8-sig'))
manifest=[]
for row in ocr:
 name=Path(row['file']).stem;key=aliases.get(norm(name),norm(name));src=sources.get(key)
 if src is None:raise ValueError(name)
 sid=src.get('id',src.get('card_id'))
 cid=sid.removeprefix('prepared-v1-') if sid.startswith('prepared-') else sid
 if key=='arthur':cid='rei-arthur'
 def yy(l):return min(l['y']) if isinstance(l['y'],list) else l['y']
 def lines(lo,hi):return ' '.join(l['text'] for l in row['lines'] if lo<=yy(l)<hi)
 item={'id':cid,'sourceId':sid,'name':name,'file':row['file'],'new':sid.startswith('prepared-'),'power':src.get('power'),'faction':src.get('faction'),'abilityTitle':lines(1300,1480),'ability':lines(1490,1670),'characterClass':lines(310,328).split(' ')[0].capitalize(),'original':src}
 manifest.append(item)
out=root/'work/importacao-cartas';out.mkdir(exist_ok=True)
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Mapped',len(manifest),flush=True)
# Read-only visual analysis sheets: all source card content remains untouched.
for batch in range((len(manifest)+9)//10):
 items=manifest[batch*10:(batch+1)*10]
 sheet=QImage(1500,900,QImage.Format.Format_RGB32);sheet.fill(QColor('#23202a'));p=QPainter(sheet)
 for i,c in enumerate(items):
  image=QImage(str(root/'work/cartas-recebidas'/c['file']))
  # Show artwork only for character identity review, with separate power crop.
  x=(i%5)*300;y=(i//5)*450
  p.drawImage(x,y,image.copy(160,400,1180,910).scaled(295,280,Qt.AspectRatioMode.KeepAspectRatio,Qt.TransformationMode.SmoothTransformation))
  p.drawImage(x+75,y+290,image.copy(1090,190,210,200).scaled(105,100))
  p.setPen(QColor('white'));p.setFont(QFont('Arial',11));p.drawText(x+5,y+420,c['name'])
 p.end();sheet.save(str(out/f'analise-{batch+1:02}.png'))
