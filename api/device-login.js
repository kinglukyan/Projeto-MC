'use strict';
// Vercel server only. Never bundle this file or expose the service key to the browser.
const {randomBytes,randomUUID,randomInt,createHash,timingSafeEqual}=require('node:crypto');
const hash=v=>createHash('sha256').update(v).digest('hex');
const secret=()=>randomBytes(32).toString('base64url');
const equal=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
module.exports=async function handler(req,res){
 res.setHeader('Cache-Control','no-store, max-age=0');res.setHeader('Pragma','no-cache');
 res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST')return res.status(405).json({error:'Método indisponível.'});
 const origin=req.headers.origin,host=req.headers.host;
 try{if(!origin||new URL(origin).host!==host)return res.status(403).json({error:'Origem inválida.'});}catch{return res.status(403).json({error:'Origem inválida.'});}
 const base=process.env.SUPABASE_URL,service=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!base||!service)return res.status(503).json({error:'A entrada por QR Code ainda não foi configurada no servidor.'});
 let body;try{body=typeof req.body==='string'?JSON.parse(req.body):req.body||{};}catch{return res.status(400).json({error:'Solicitação inválida.'});}
 if(!body||Array.isArray(body)||typeof body!=='object')return res.status(400).json({error:'Solicitação inválida.'});
 if(JSON.stringify(body).length>2048)return res.status(413).json({error:'Solicitação inválida.'});
 const headers={apikey:service,Authorization:'Bearer '+service,'Content-Type':'application/json'};
 async function db(path,method='GET',payload){const response=await fetch(base+'/rest/v1/'+path,{method,headers:{...headers,Prefer:'return=representation'},...(payload!==undefined?{body:JSON.stringify(payload)}:{}),signal:AbortSignal.timeout(8000)});const data=await response.json().catch(()=>null);if(!response.ok)throw Error(data?.message||'Não foi possível confirmar esta solicitação.');return data;}
 async function auth(path,method='GET',payload,authorization=service){const response=await fetch(base+'/auth/v1/'+path,{method,headers:{apikey:service,Authorization:'Bearer '+authorization,'Content-Type':'application/json'},...(payload?{body:JSON.stringify(payload)}:{}),signal:AbortSignal.timeout(8000)});const data=await response.json().catch(()=>null);if(!response.ok)throw Error('Não foi possível autorizar a entrada. Entre novamente na conta e gere outro código.');return data;}
 try{
  if(body.action==='create'){
   const ip=String(req.headers['x-forwarded-for']||'unknown').split(',')[0].trim();
   await db('rpc/device_login_rate_limit','POST',{p_bucket:hash(service+ip)+':'+Math.floor(Date.now()/300000)});
   const id=randomUUID(),requestSecret=secret(),approvalSecret=secret(),pairingCode=String(randomInt(1000,10000)),expires=new Date(Date.now()+180000).toISOString();
   const label=String(body.device||'Novo aparelho').replace(/[<>\r\n]/g,'').slice(0,100);
   await db('device_login_requests','POST',{id,request_hash:hash(requestSecret),approval_hash:hash(approvalSecret),pairing_code:pairingCode,device_label:label,expires_at:expires});
   return res.status(200).json({id,requestSecret,approvalSecret,pairingCode,expiresAt:expires});
  }
  if(!/^[\da-f-]{36}$/i.test(body.id||''))return res.status(400).json({error:'QR Code inválido.'});
  const rows=await db('device_login_requests?id=eq.'+encodeURIComponent(body.id)+'&limit=1'),row=rows?.[0];
  if(!row||Date.parse(row.expires_at)<=Date.now()||['consumed','cancelled'].includes(row.status))return res.status(410).json({error:'Este QR Code expirou ou já foi encerrado. Gere outro.'});
  const approval=['preview','approve','reject'].includes(body.action),provided=String(approval?body.approvalSecret||'':body.requestSecret||'');
  if(!provided||!equal(hash(provided),approval?row.approval_hash:row.request_hash))return res.status(403).json({error:'QR Code inválido.'});
  if(body.action==='preview')return res.status(200).json({pairingCode:row.pairing_code,device:row.device_label,expiresAt:row.expires_at,status:row.status});
  if(body.action==='reject'){await db('device_login_requests?id=eq.'+row.id,'PATCH',{status:'cancelled',token_hash:null});return res.status(200).json({status:'closed'});}
  if(body.action==='approve'){
   const bearer=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');if(!bearer)return res.status(401).json({error:'Entre na sua conta neste aparelho para confirmar.'});
   const account=await auth('user','GET',null,bearer);if(!account?.id||!account.email)return res.status(401).json({error:'Entre novamente na sua conta.'});
   if(row.status!=='pending')return res.status(409).json({error:'Esta solicitação já foi confirmada.'});
   const updated=await db('device_login_requests?id=eq.'+row.id+'&status=eq.pending','PATCH',{approved_by:account.id,status:'approved'});
   if(!updated?.length)return res.status(409).json({error:'Solicitação já confirmada.'});
   return res.status(200).json({status:'approved'});
  }
  if(body.action==='cancel'||body.action==='complete'){
   await db('device_login_requests?id=eq.'+row.id,'PATCH',{status:body.action==='cancel'?'cancelled':'consumed',token_hash:null});return res.status(200).json({status:'closed'});
  }
  if(body.action!=='poll')return res.status(400).json({error:'Solicitação inválida.'});
  if(row.status==='pending'||row.status==='issuing')return res.status(200).json({status:row.status});
  if(row.status==='ready')return res.status(200).json({status:'ready',tokenHash:row.token_hash});
  if(row.status==='approved'){
   const claimed=await db('device_login_requests?id=eq.'+row.id+'&status=eq.approved','PATCH',{status:'issuing'});
   if(!claimed?.length)return res.status(200).json({status:'issuing'});
   try{
    const response=await auth('admin/users/'+row.approved_by),account=response.user||response;
    const link=await auth('admin/generate_link','POST',{type:'magiclink',email:account.email});
    const token=link.properties?.hashed_token||link.hashed_token;
    if(!token)throw Error('Não foi possível preparar a entrada. Gere outro QR Code.');
    const ready=await db('device_login_requests?id=eq.'+row.id+'&status=eq.issuing','PATCH',{status:'ready',token_hash:token});
    if(!ready?.length)throw Error('Solicitação encerrada. Gere outro QR Code.');
    return res.status(200).json({status:'ready',tokenHash:token});
   }catch(error){await db('device_login_requests?id=eq.'+row.id+'&status=eq.issuing','PATCH',{status:'approved'}).catch(()=>{});throw error;}
  }
  return res.status(400).json({error:'Solicitação indisponível.'});
 }catch(error){return res.status(400).json({error:error.message||'Não foi possível conectar os aparelhos. Tente novamente.'});}
};
