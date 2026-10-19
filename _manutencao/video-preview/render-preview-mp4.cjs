const fs=require('fs'),path=require('path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
const paths={bg:'assets/onboarding/public-citadel.webp',zeus:'assets/holograms/zeus-hologram.png',poseidon:'assets/holograms/poseidon-hologram.png',afrodite:'assets/holograms/afrodite-hologram.png',athena:'assets/holograms/athena-hologram.png',beta:'assets/holograms/lobo-beta-hologram.png',lightning:'assets/vfx/lightning.png',tsunami:'assets/vfx/tsunami.png',hearts:'assets/vfx/hearts.png',card:'assets/cards-20261017/athena.png',enemy:'assets/cards-20261017/lobo-beta.png'};
const assets=Object.fromEntries(Object.entries(paths).map(([k,v])=>[k,'data:image/'+(v.endsWith('webp')?'webp':'png')+';base64,'+fs.readFileSync(path.join(root,v)).toString('base64')]));
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.MYTHIC_BROWSER_EXE||'C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe',headless:true,args:['--disable-gpu']});
 try{
 const page=await browser.newPage({viewport:{width:960,height:540}});
 await page.setContent('<html><body style="margin:0;background:#110e1b"><canvas width="960" height="540"></canvas></body></html>');
 const result=await page.evaluate(async assets=>{
  const imgs={};await Promise.all(Object.entries(assets).map(([k,src])=>new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>{imgs[k]=i;resolve();};i.onerror=reject;i.src=src;})));
  const c=document.querySelector('canvas'),x=c.getContext('2d'),W=960,H=540;
  function fit(i,cx,cy,w,h){const scale=Math.min(w/i.width,h/i.height),iw=i.width*scale,ih=i.height*scale;x.drawImage(i,cx-iw/2,cy-ih/2,iw,ih);}
  function text(s,px,py,size=15,color='#f2d99a'){x.font='bold '+size+'px Georgia';x.fillStyle=color;x.fillText(s,px,py);}
  function draw(t){
   x.globalAlpha=1;x.drawImage(imgs.bg,0,0,W,H);x.fillStyle='#0c0919c9';x.fillRect(0,0,W,H);
   text('MYTHIC CLASH',26,29,19);x.textAlign='right';text('PRÉVIA ILUSTRATIVA',935,28,10,'#bfa4d5');x.textAlign='left';
   const ys=[53,111,169,319,377,435];
   for(let row=0;row<6;row++){const y=ys[row];x.fillStyle=row<3?'#452c495c':'#382c655c';x.fillRect(27,y,906,54);x.strokeStyle='#a887c766';x.strokeRect(27,y,906,54);for(let j=1;j<10;j++){x.beginPath();x.moveTo(27+j*90.6,y);x.lineTo(27+j*90.6,y+54);x.stroke();}}
   x.fillStyle='#21152a';x.fillRect(27,235,906,62);x.strokeStyle='#c4a16366';x.strokeRect(27,235,906,62);
   text('ADVERSÁRIO',44,257,10,'#e6a5a5');text('SUA EQUIPE',805,257,10,'#c9b1f1');
   for(let j=0;j<3;j++){x.strokeStyle='#ba965b';x.strokeRect(323+j*108,247,99,36);text(['LOCAL','TERRENO','CLIMA'][j],338+j*108,270,10);}
   const phase=Math.floor(t/4)%3,local=t%4,progress=Math.min(1,Math.max(0,(local-.5)/.65));
   for(let j=0;j<3;j++){
    let fade=phase===0&&j<2?1-Math.min(1,Math.max(0,(local-2.1)/.8)):1;
    let shift=phase===2&&j===0?Math.min(1,Math.max(0,(local-2)/1))*210:0;
    x.globalAlpha=fade;fit(imgs.enemy,239+j*180,194+shift,31,44);fit(imgs.beta,239+j*180,153+shift,68,95);
   }
   x.globalAlpha=1;fit(imgs.card,239,461,32,44);fit(imgs.athena,239,414,78,120);
   const who=['zeus','poseidon','afrodite'][phase];
   x.globalAlpha=progress;fit(imgs[who],420,407-(1-progress)*25,90+progress*16,140);x.globalAlpha=1;
   if(local>.8&&local<3.3){const a=Math.min(1,(local-.8)*3,(3.3-local)*2);x.globalAlpha=a*.86;
    x.fillStyle='#110b20b0';x.fillRect(0,0,W,H);fit(imgs[who],675,265,230,355);
    const g=x.createLinearGradient(0,0,600,0);g.addColorStop(0,'#4d2a7455');g.addColorStop(1,'#4d2a7400');x.fillStyle=g;x.fillRect(0,198,710,130);
    text(['ZEUS','POSEIDON','AFRODITE'][phase],55,250,40);text(['Senhor dos Céus','Deus do Mar','Laço de Amor'][phase],57,288,23,'#d5b4f4');x.globalAlpha=1;
   }
   if(local>1.6&&local<3.5){const a=Math.min(1,(local-1.6)*3,(3.5-local)*2);x.globalAlpha=a*.9;
    fit(imgs[['lightning','tsunami','hearts'][phase]],480,phase===1?150:132,phase===1?870:650,phase===1?200:225);x.globalAlpha=1;
    for(let j=0;j<30;j++){const v=(local-1.6),xx=190+(j%10)*60+Math.sin(j*13+v*3)*15,yy=145-v*(15+j%7*8);x.fillStyle=phase===0?'#d6c6ff':phase===1?'#7be2f8':'#ffadcf';x.globalAlpha=a*.7;x.fillRect(xx,yy,2+j%3,2+j%3);}x.globalAlpha=1;
   }
   for(let j=0;j<8;j++)fit(j%2?imgs.card:imgs.enemy,330+j*41,526-Math.abs(3.5-j)*3,40,55);
   x.fillStyle='#0c091dc9';x.fillRect(25,492,200,34);text('Hologramas • Habilidades • Combos',35,514,10,'#d8c3eb');
  }
  draw(2.2);const poster=c.toDataURL('image/jpeg',.86).split(',')[1];
  const mime=['video/mp4;codecs=avc1.42001E','video/mp4'].find(t=>MediaRecorder.isTypeSupported(t));
  if(!mime)throw Error('Codificador MP4 indisponível.');
  const chunks=[],stream=c.captureStream(24),recorder=new MediaRecorder(stream,{mimeType:mime,videoBitsPerSecond:1400000});
  const done=new Promise(resolve=>{recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data);};recorder.onstop=resolve;});recorder.start();
  const start=performance.now();await new Promise(resolve=>{function frame(){const t=(performance.now()-start)/1000;draw(Math.min(t,11.99));if(t<12)requestAnimationFrame(frame);else resolve();}frame();});recorder.stop();await done;stream.getTracks().forEach(t=>t.stop());
  const bytes=new Uint8Array(await new Blob(chunks,{type:mime}).arrayBuffer());let binary='';for(let i=0;i<bytes.length;i+=32768)binary+=String.fromCharCode(...bytes.subarray(i,i+32768));return{video:btoa(binary),poster,mime};
 },assets);
 fs.writeFileSync(path.join(root,'assets/portal/duel-preview.mp4'),Buffer.from(result.video,'base64'));fs.writeFileSync(path.join(root,'assets/portal/duel-preview-poster.jpg'),Buffer.from(result.poster,'base64'));console.log(JSON.stringify({mime:result.mime,bytes:fs.statSync(path.join(root,'assets/portal/duel-preview.mp4')).size}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1)});
