/* Deterministic runtime, resource revisions and release marker, without npm. */
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8').replace(/^\uFEFF/,''),write=(n,s)=>fs.writeFileSync(path.join(root,n),s),hash=v=>crypto.createHash('sha256').update(v).digest('hex').slice(0,20);
const mediaText=read('entry-media.js'),media=JSON.parse(mediaText.slice(mediaText.indexOf('=')+1).trim().replace(/;$/,'')),optimized=media.optimized||{};
function css(text){text=text.replace(/url\((['"]?)(assets\/[^)'"?#]+)([?#][^)'" ]*)?\1\)/g,(m,q,p,suffix='')=>optimized[p]?`url(${q}${optimized[p]}${suffix}${q})`:m);text=text.replace(/((?:min-|max-)?height\s*:\s*)([^;{}]*\b[\d.]+(?:dvh|svh)[^;{}]*)([;}])/g,(m,k,v,end)=>k+v.replace(/([\d.]+)(?:dvh|svh)/g,'calc(var(--mythic-vh,1vh) * $1)')+';'+k+v+end);text=text.replace(/(^|[;{])\s*(backdrop-filter|mask-image)\s*:\s*([^;}]+)/g,(m,start,k,v)=>`${start}-webkit-${k}:${v};${k}:${v}`);return text;}
write('game-interface.css',css(read('game-interface.css')));write('entry-optimized.css',css(read('entry-critical.css')));write('game-fonts.css',read('game-fonts.css').replace(/font-display\s*:\s*\w+/g,'font-display:swap'));
const sources=JSON.parse(read('_manutencao/runtime-fontes.json'));if(!sources.includes('site-updates.js'))sources.push('site-updates.js');write('_manutencao/runtime-fontes.json',JSON.stringify(sources,null,2));
for(const s of sources){if(s.includes('..')||!s.endsWith('.js')||!fs.existsSync(path.join(root,s)))throw Error('Fonte inválida: '+s);}
// Compile sources while bundling, so invalid JavaScript cannot become a release.
for(const source of sources)new(require('vm').Script)(read(source),{filename:source});
write('game-runtime.js',sources.map(n=>`/* ${n} */\n`+read(n).replace(/^\/\/# sourceMappingURL=.*$/gm,'')+'\n;').join('\n'));
const assets={},sizes={};function walk(dir){if(path.basename(dir)==='new-greeks')return;for(const n of fs.readdirSync(dir)){const p=path.join(dir,n);if(fs.statSync(p).isDirectory())walk(p);else{const key=path.relative(root,p).split(path.sep).join('/');assets[key]=hash(fs.readFileSync(p));sizes[key]=fs.statSync(p).size;}}}walk(path.join(root,'assets'));
write('asset-manifest.json',JSON.stringify({version:3,assets,sizes,optimized}));
const skip=new Set(['release.json','release-stamp.js','entry-bootstrap.js','sw.js']);const inputs=fs.readdirSync(root).filter(n=>!skip.has(n)&&/\.(js|css|json)$/.test(n)&&fs.statSync(path.join(root,n)).isFile()).sort();
const htmlInputs=fs.readdirSync(root).filter(n=>n.endsWith('.html')).sort().map(n=>n+':'+hash(read(n).replace(/\?v=[a-f0-9]+/g,'?v=HASH').replace(/\s+/g,' ')));
const workerSource=read('sw.js').replace(/const BUILD_ID\s*=\s*['"][a-f0-9]+['"];?/,"const BUILD_ID='BUILD';");
const id=hash([...inputs.map(n=>n+':'+hash(fs.readFileSync(path.join(root,n)))),...htmlInputs,'sw.js:'+hash(workerSource)].join('\n'));
const version=JSON.parse(read('version.json')).version;write('release-stamp.js',`window.MythicRelease=Object.freeze({id:${JSON.stringify(id)},version:${JSON.stringify(version)}});\n`);
write('release.json',JSON.stringify({id,version}));
write('entry-bootstrap.js',['release-stamp.js','browser-compat.js','session-startup.js','entry-startup.js'].map(n=>`/* ${n} */\n`+read(n)+'\n;').join('\n'));
let worker=read('sw.js');worker=worker.replace(/const BUILD_ID\s*=\s*['"][a-f0-9]+['"];?/,`const BUILD_ID='${id}';`);write('sw.js',worker);
for(const filename of fs.readdirSync(root).filter(n=>n.endsWith('.html'))){let html=read(filename);if(filename==='index.html'){
 html=html.replace(/<link rel="preconnect" href="https:\/\/cdn\.jsdelivr\.net" crossorigin>\s*/g,'');
 html=html.replace(/<script src="(?:session-startup|entry-startup|entry-bootstrap)\.js[^\"]*"[^>]*><\/script>/g,'');
 html=html.replace(/(<link rel="stylesheet" href=")(?:entry-critical|entry-optimized)\.css[^\"]*(")/,'$1entry-optimized.css$2');
 html=html.replace(/(<link rel="stylesheet" href="entry-optimized\.css)/,'<script src="entry-bootstrap.js"></script>\n  $1');
 const deferred=/<script src="[^\"]+" defer><\/script>/g;let first=true;html=html.replace(deferred,()=>{if(!first)return '';first=false;return '<script src="game-runtime.js" defer></script>';});
 }
 html=html.replace(/<img\b([^>]*?)>/g,(m,attrs)=>{attrs=attrs.replace(/\bsrc="(assets\/[^"?#]+)([^\"]*)"/,(_,p,s)=>`src="${optimized[p]||p}${s}"`);if(!/\bloading=/.test(attrs))attrs+=' loading="lazy"';if(!/\bdecoding=/.test(attrs))attrs+=' decoding="async"';return '<img'+attrs+'>';});
 html=html.replace(/((?:src|href)=")([^"?#]+\.(?:js|css))(?:\?[^\"]*)?(")/g,(m,p,n,q)=>fs.existsSync(path.join(root,n))?p+n+'?v='+hash(fs.readFileSync(path.join(root,n)))+q:m);write(filename,html.replace(/\n[ \t]*\n(?:[ \t]*\n)+/g,'\n\n'));
}
console.log(`Versão ${id}: ${sources.length} scripts agrupados; ${Object.keys(optimized).length} imagens mapeadas.`);
