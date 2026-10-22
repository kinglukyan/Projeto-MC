"""Monta novas cartas com a moldura existente; preserva os arquivos originais gerados."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageColor
import json
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'_manutencao/novos-gregos.json').read_text(encoding='utf-8-sig'))
colors={'hera':'#69458b','demeter':'#356847','hestia':'#a04d32','perseu':'#2a5978'}
fonts=Path('C:/Windows/Fonts')
def font(size,bold=False,serif=False):return ImageFont.truetype(str(fonts/('georgiab.ttf' if serif and bold else 'georgia.ttf' if serif else 'arialbd.ttf' if bold else 'arial.ttf')),size)
def fitfont(draw,text,maxwidth,size=42,serif=False):
 while size>15:
  f=font(size,True,serif)
  if draw.textlength(text,font=f)<=maxwidth:return f
  size-=1
 return f
def lines(draw,text,f,width):
 result=[];line=''
 for word in text.split():
  test=(line+' '+word).strip()
  if draw.textlength(test,font=f)>width and line:result.append(line);line=word
  else:line=test
 if line:result.append(line)
 return result
for c in data['cards']:
 cid=c['id'];source=root/f'assets/new-greeks/{cid}-illustration.png'
 card=Image.open(root/'assets/cards-remake/athena.webp').convert('RGB').resize((1500,2100),Image.Resampling.LANCZOS)
 draw=ImageDraw.Draw(card);sx=1500/1100;sy=2100/1540
 def rect(box,fill,r=0,outline=None,width=1):
  box=tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate(box));draw.rounded_rectangle(box,radius=round(r*sx),fill=fill,outline=outline,width=width)
 def text(x,y,value,f,fill):draw.text((round(x*sx),round(y*sy)),value,font=f,fill=fill,anchor='mm')
 # Header clear area stays inside the original parchment and decorations.
 rect((306,149,792,262),'#f1ddba')
 text(550,199,c['name'].upper(),fitfont(draw,c['name'].upper(),610,55,True),'#332015')
 text(550,245,c['characterClass'].upper()+' · GRÉCIA',font(24,True),colors[cid])
 # Preserve the current, centered faction symbol and centered power.
 for x in (227,874):
  box=((x-70)*sx,141*sy,(x+70)*sx,281*sy)
  draw.ellipse(box,fill=colors[cid],outline='white',width=9)
 badge=Image.open(root/'assets/card-badges/gregos-v3.png').convert('RGBA');badge.thumbnail((150,150),Image.Resampling.LANCZOS);card.paste(badge,(round(227*sx-badge.width/2),round(211*sy-badge.height/2)),badge)
 powerfont=font(104,True,True);value=str(c['power']);ink=draw.textbbox((0,0),value,font=powerfont)
 draw.text((874*sx-(ink[2]-ink[0])/2-ink[0],201*sy-(ink[3]-ink[1])/2-ink[1]),value,font=powerfont,fill='white');text(874,248,'PODER',font(21,True),'white')
 # Same art window and gold border as the existing Greek cards.
 artbox=(round(117*sx),round(296*sy),round(983*sx),round(964*sy));art=ImageOps.fit(Image.open(source).convert('RGB'),(artbox[2]-artbox[0],artbox[3]-artbox[1]),Image.Resampling.LANCZOS,centering=(.5,0));mask=Image.new('L',art.size,0);ImageDraw.Draw(mask).rounded_rectangle((0,0,*art.size),radius=18,fill=255);card.paste(art,artbox[:2],mask)
 panel=tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate((94,987,1007,1294)))
 draw.rounded_rectangle(panel,radius=28,fill=tuple(round(v*.28) for v in ImageColor.getrgb(colors[cid])),outline='#d6ad59',width=8)
 text(550,1040,c['abilityTitle'],fitfont(draw,c['abilityTitle'],1150,52,True),'#f4d88c')
 draw.line((int(143*sx),int(1082*sy),int(958*sx),int(1082*sy)),fill='#d6ad59',width=2)
 f=font(31);wrapped=lines(draw,c['ability'],f,int(800*sx))
 while len(wrapped)>4:
  f=font(f.size-1);wrapped=lines(draw,c['ability'],f,int(800*sx))
 start=1146-(len(wrapped)-1)*14
 for i,line in enumerate(wrapped):text(550,start+i*29,line,f,'#fff3df')
 rect((327,1222,775,1273),colors[cid],r=25,outline='#d6ad59',width=4);text(551,1247,'HABILIDADE',font(26,True),'white')
 (root/'assets/cards-remake').mkdir(exist_ok=True)
 card.save(root/f'assets/cards-remake/{cid}.webp','WEBP',quality=98,method=6)
 export=root/'novos-personagens/cartas';export.mkdir(parents=True,exist_ok=True);card.save(export/f'{cid}.png')
 for kind,folder,target in [('hologram','holograms',f'{cid}-hologram.webp'),('chibi','avatars-chibi',f'{cid}.webp'),('banner','universe/characters',f'{cid}.webp')]:
  src=root/f'assets/new-greeks/{cid}-{kind}.png'
  if not src.exists():continue
  image=Image.open(src).convert('RGBA' if kind!='banner' else 'RGB')
  # Format conversion retains alpha and full composition; no background removal.
  if kind=='chibi':image.thumbnail((768,768),Image.Resampling.LANCZOS)
  dest=root/'assets'/folder/target;dest.parent.mkdir(parents=True,exist_ok=True);image.save(dest,'WEBP',quality=98,method=6)
print('Cartas 1500x2100 e versões WebP preparadas.')
