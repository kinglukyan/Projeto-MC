from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
root=Path(__file__).resolve().parents[1]
out=root/'novos-personagens';out.mkdir(exist_ok=True)
ids=['hera','demeter','hestia','perseu'];names=['Hera','Deméter','Héstia','Perseu']
f=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',27)
cards=Image.new('RGB',(1640,620),'#171020');draw=ImageDraw.Draw(cards)
for i,(cid,name) in enumerate(zip(ids,names)):
 im=Image.open(out/f'cartas/{cid}.png').convert('RGB');im.thumbnail((390,546),Image.Resampling.LANCZOS);cards.paste(im,(15+i*410,12));draw.text((210+i*410,585),name,font=f,fill='#f5d991',anchor='mm')
cards.save(out/'previa-cartas.jpg',quality=95)
sheet=Image.new('RGB',(1440,900),'#171020');draw=ImageDraw.Draw(sheet)
for i,(cid,name) in enumerate(zip(ids,names)):
 x=(i%2)*720;y=(i//2)*450
 im=ImageOps.fit(Image.open(root/f'assets/new-greeks/{cid}-banner.png').convert('RGB'),(700,394),Image.Resampling.LANCZOS)
 sheet.paste(im,(x+10,y+10));draw.text((x+360,y+426),name,font=f,fill='#f5d991',anchor='mm')
sheet.save(out/'previa-banners.jpg',quality=95)
print('Prévias de cartas e banners preparadas.')
