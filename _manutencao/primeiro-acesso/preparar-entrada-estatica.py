from pathlib import Path
import re,json
r=Path('outputs/Mythic-Clash-Completo');p=r/'index.html';s=p.read_text(encoding='utf-8')
css=re.findall(r'<link rel="stylesheet" href="([^"?]+)(?:\?[^" ]*)?">',s)
(r/'_manutencao/interface-fontes.json').write_text(json.dumps({'styles':css},ensure_ascii=False,indent=2),encoding='utf-8')
s=re.sub(r'  <link rel="stylesheet" href="[^"\n]+">\n?', '',s)
csslinks='''  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="preconnect" href="https://ytiwezadkkhfseafnhtq.supabase.co" crossorigin>
  <link rel="stylesheet" href="entry-critical.css">
  <link rel="preload" href="game-interface.css" as="style">
  <link rel="stylesheet" href="game-interface.css" media="print" id="mythic-game-styles">
  <script src="entry-startup.js" async></script>
'''
s=s.replace('</head>',csslinks+'</head>')
s=s.replace('<div class="app-shell">','<!-- MYTHIC_PUBLIC_SHELL_START -->\n<!-- MYTHIC_PUBLIC_SHELL_END -->\n  <div class="app-shell">',1)
# Metadata is small and needed by the URL helper and onboarding.
s=s.replace('  <script src="security.js', '  <script src="entry-media.js" defer></script>\n  <script src="security.js',1)
# Duplicate listeners were being installed by a second copy of identity-art.js.
seen=False
s=re.sub(r'  <script src="identity-art.js[^\"]*" defer></script>\n?',lambda m: '' if globals().get('seen') else (globals().__setitem__('seen',True) or m.group(0)),s)
p.write_text(s,encoding='utf-8')
p=r/'portal-upgrade.js';s=p.read_text(encoding='utf-8');s=s.replace("const home=el('section','mythic-public-home');", "const existingHome=$('#mythic-public-home'),home=existingHome||el('section','mythic-public-home');")
s=s.replace(' home.innerHTML=`<header', ' if(!existingHome)home.innerHTML=`<header',1)
s=s.replace(' document.body.prepend(home);',' if(!existingHome)document.body.prepend(home);',1)
p.write_text(s,encoding='utf-8')
print('Hall independente preparado e 32 folhas de estilo agrupadas.')
