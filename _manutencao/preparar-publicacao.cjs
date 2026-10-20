const fs=require('fs'),path=require('path');
require('./gerar-interface.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'site-publico');
const rootExtensions=new Set(['.html','.js','.css','.json','.webmanifest']);
const excluded=new Set(['vercel.json','package.json','package-lock.json']);
let files=[];
for(const name of fs.readdirSync(root)){const p=path.join(root,name);if(fs.statSync(p).isFile()&&((rootExtensions.has(path.extname(name))&&!excluded.has(name))||name==='_headers'))files.push([p,name]);}
function collect(folder){for(const name of fs.readdirSync(folder)){const p=path.join(folder,name);if(fs.lstatSync(p).isSymbolicLink())throw Error('Atalho não permitido: '+p);if(fs.statSync(p).isDirectory())collect(p);else files.push([p,path.relative(root,p)]);}}
collect(path.join(root,'assets'));
if(process.argv.includes('--listar')){console.log(JSON.stringify({total:files.length,bytes:files.reduce((n,[p])=>n+fs.statSync(p).size,0),excluded:['supabase','_manutencao','*.md','*.sql','*.zip']}));process.exit(0);}
// No servidor de build, o destino é sempre este diretório fixo dentro do projeto.
if(path.dirname(out)!==root||path.basename(out)!=='site-publico')throw Error('Destino de publicação inválido.');
if(fs.existsSync(out))fs.rmSync(out,{recursive:true,force:true});
fs.mkdirSync(out,{recursive:true});
for(const [p,relative] of files){const dest=path.join(out,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(p,dest);}
console.log('Publicação preparada: '+files.length+' arquivos do jogo.');
