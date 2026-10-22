/* Build the CSS bundle and public HTML without downloading dependencies. */
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex').slice(0,20);
const config=JSON.parse(fs.readFileSync(path.join(__dirname,'interface-fontes.json'),'utf8').replace(/^\uFEFF/,''));
for(const name of config.styles)if(path.basename(name)!==name||!name.endsWith('.css'))throw Error('Nome de estilo inválido: '+name);
let fonts=[];
const css=config.styles.map(name=>{let text=fs.readFileSync(path.join(root,name),'utf8').replace(/^\uFEFF/,'');text=text.replace(/@font-face\s*\{[^}]*\}/g,face=>{fonts.push(face);return '';});return '/* '+name+' */\n'+text;}).join('\n');
fs.writeFileSync(path.join(root,'game-fonts.css'),fonts.join('\n'));

fs.writeFileSync(path.join(root,'game-interface.css'),css);
const portal=fs.readFileSync(path.join(root,'portal-upgrade.js'),'utf8'),match=portal.match(/home\.innerHTML=`([\s\S]*?)`;/);
if(!match||match[1].includes('${'))throw Error('Não foi possível preparar o hall estático.');
const actions='<a href="#login" class="button button-secondary" data-entry-auth="signin">Login</a><a href="#criar-conta" class="button button-primary" data-entry-auth="signup">Criar conta</a>';
const mediaSource=fs.readFileSync(path.join(root,'entry-media.js'),'utf8').replace(/^\uFEFF/,'');const media=JSON.parse(mediaSource.slice(mediaSource.indexOf('=')+1).trim().replace(/;$/,''));
let hall=match[1].replace(/<div class="(public-account-actions|public-hero-actions|public-final-actions)"><\/div>/g,(_,name)=>`<div class="${name}">${actions}</div>`).replace(/<img (?=[^>]*src="assets\/portal\/)/g,'<img loading="lazy" fetchpriority="low" ');
hall=hall.replace(/assets\/portal\/(zeus|poseidon|lukyan)\.webp/g,(src,id)=>media.cards[id]||src);
hall+='<footer class="hall-version">Mythic Clash · Versão '+JSON.parse(fs.readFileSync(path.join(root,'version.json'),'utf8')).version+'</footer>';
hall='<section class="mythic-public-home" id="mythic-public-home" aria-label="Conheça Mythic Clash">'+hall+'</section>\n<noscript><p class="startup-status">Ative o JavaScript do navegador para entrar ou criar sua conta.</p></noscript>';
const fontVersion=hash(fs.readFileSync(path.join(root,'game-fonts.css')));
const index=path.join(root,'index.html');let html=fs.readFileSync(index,'utf8');
html=html.replace(/id="mythic-game-styles"(?: data-fonts="[^"]*")?/, 'id="mythic-game-styles" data-fonts="game-fonts.css?v='+fontVersion+'"');
html=html.replace(/<!-- MYTHIC_PUBLIC_SHELL_START -->[\s\S]*?<!-- MYTHIC_PUBLIC_SHELL_END -->/,'<!-- MYTHIC_PUBLIC_SHELL_START -->\n'+hall+'\n<!-- MYTHIC_PUBLIC_SHELL_END -->');
for(const name of ['game-interface.css','entry-critical.css','entry-startup.js','entry-media.js']){const version=hash(fs.readFileSync(path.join(root,name)));const escaped=name.replace(/\./g,'\\.');html=html.replace(new RegExp('((?:src|href)=")'+escaped+'(?:\\?[^" ]*)?("|$)','g'),'$1'+name+'?v='+version+'$2');}
fs.writeFileSync(index,html);console.log('Hall estático e CSS agrupado preparados: '+config.styles.length+' folhas.');

require("./gerar-runtime.cjs");
