"""Emblemas vetoriais próprios para baralhos e conquistas do perfil."""
from pathlib import Path
from html import escape

root = Path(__file__).resolve().parents[1]
deck = root / 'assets/deck-icons'
achievements = root / 'assets/profile-achievements'
achievements.mkdir(parents=True, exist_ok=True)

def svg(title, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" role="img"><title>{escape(title)}</title>
<defs><linearGradient id="gold" x1="15" y1="12" x2="72" y2="86" gradientUnits="userSpaceOnUse"><stop stop-color="#fff0b1"/><stop offset=".38" stop-color="#edc367"/><stop offset=".65" stop-color="#ad702a"/><stop offset="1" stop-color="#ffe5a0"/></linearGradient><linearGradient id="violet" x1="24" y1="18" x2="68" y2="80" gradientUnits="userSpaceOnUse"><stop stop-color="#9b71c7"/><stop offset="1" stop-color="#302047"/></linearGradient></defs>
<g stroke="#35203e" stroke-width="5" stroke-linejoin="round">{body}</g>
</svg>'''

def gold(d, extra=''):
    return f'<path d="{d}" fill="url(#gold)" stroke="#f6d58c" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" {extra}/>'

def line(d):
    return f'<path d="{d}" fill="none" stroke="#ffe6a4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'

def gem(x=48,y=48):
    return f'<path d="m{x} {y-7} 5 7-5 7-5-7Z" fill="#c6a2fa" stroke="#f7dd9c" stroke-width="1.5"/>'

icons = {
 'eclipse': ('Eclipse', '<circle cx="48" cy="48" r="26" fill="#22182f" stroke="url(#gold)" stroke-width="3"/>'+gold('M51 23a25 25 0 0 0 0 50 29 29 0 0 1 0-50Z')+line('M48 8v8m0 64v8M8 48h8m64 0h8M20 20l6 6m44 44 6 6M20 76l6-6m44-44 6-6')+gem(61,45)),
 'matilha': ('Matilha', gold('m19 15 21 12 8-5 8 5 21-12-5 36-9 23-15 12-15-12-9-23Z')+'<path d="m29 29 12 10 7-6 7 6 12-10-4 28-15 22-15-22Z" fill="url(#violet)" stroke="#7e4d29" stroke-width="2"/>'+line('m31 48 10 4m24-4-10 4m-14 9 7 5 7-5m-7 5v9')+'<path d="m34 47 7 3-7 2m28-5-7 3 7 2" fill="#f9dc88" stroke="none"/>'),
 'pelotao': ('Pelotão',gold('M12 26h24v25L24 63 12 51Zm48 0h24v25L72 63 60 51Z')+gold('M29 19h38v42L48 82 29 61Z')+'<path d="M36 27h24v31L48 72 36 58Z" fill="url(#violet)" stroke="#70462c" stroke-width="1.5"/>'+line('M48 33v28M39 45h18M24 32v18m48-18v18')+gem(48,19)),
 'submundo': ('Submundo',gold('M18 81V40a30 30 0 0 1 60 0v41H66V40a18 18 0 0 0-36 0v41Z')+'<path d="M35 50c0-18 26-18 26 0v13l-7 5v8H42v-8l-7-5Z" fill="url(#violet)" stroke="#f3cb76" stroke-width="2"/>'+line('m40 53 4 2m12-2-4 2m-4 7v7M13 81h70M48 9v9m-24 8 7 5m41-5-7 5')),
 'convergencia': ('Convergência', '<circle cx="48" cy="48" r="30" fill="none" stroke="url(#gold)" stroke-width="2"/>'+line('m26 26 44 44m-44 0 44-44')+gold('m48 8 9 31 31 9-31 9-9 31-9-31-31-9 31-9Z')+'<path d="m48 17 7 24 24 7-24 7-7 24-7-24-24-7 24-7Z" fill="url(#violet)" stroke="none"/>'+line('M48 22v52M22 48h52')+gem()),
 'realeza': ('Realeza', gold('m13 30 20 12 15-24 15 24 20-12-9 37H22Z')+'<path d="m24 44 11 8 13-19 13 19 11-8-5 16H29Z" fill="url(#violet)" stroke="none"/>'+gold('M23 71h50v9H23Z')+gem(48,57)+'<g fill="#fce3a0" stroke="none"><circle cx="13" cy="27" r="4"/><circle cx="48" cy="15" r="4"/><circle cx="83" cy="27" r="4"/></g>'),
 'caos': ('Caos',gold('m53 8-4 21 15-8-5 19 22-1-19 15 15 12-23 1-4 22-11-18-16 12 4-23-20-4 19-13-10-17 23 7Z')+'<path d="m50 28-18 24h14l-1 19 19-27H51Z" fill="url(#violet)" stroke="#fff0be" stroke-width="1.5"/>'),
 'arsenal': ('Arsenal',gold('m22 13 12 7 4 29-6 5-5-4Zm52 0-12 7-4 29 6 5 5-4ZM25 55l31 27 6-7-31-27Zm46 0L40 82l-6-7 31-27Z')+gold('M33 29h30v27L48 70 33 56Z')+'<path d="M39 35h18v18l-9 9-9-9Z" fill="url(#violet)" stroke="none"/>'+gem(48,48)),
 'lunar': ('Lunar',gold('M61 14a33 33 0 1 0 19 56A33 33 0 0 1 61 14Z')+line('M23 48a25 25 0 0 0 25 25')+gold('m65 28 3 10 11 3-11 3-3 11-3-11-11-3 11-3Z')+'<circle cx="79" cy="20" r="3" fill="#f5d895" stroke="none"/>'+gem(47,15)),
 'protecao': ('Proteção',gold('M48 10 77 22v28c0 19-29 36-29 36S19 69 19 50V22Z')+'<path d="m48 20 20 9v21c0 12-20 26-20 26S28 62 28 50V29Z" fill="url(#violet)" stroke="#69402d" stroke-width="1.5"/>'+line('m35 48 9 9 18-23')+gem(48,15)),
 'ofensiva': ('Ofensiva',gold('m68 10 16 3-3 16-39 39-14-14Z')+'<path d="m71 19-35 39 5 4 36-40Z" fill="url(#violet)" stroke="none"/>'+gold('m17 51 28 28 6-6-28-28ZM22 65l9 9-14 14-9-9Z')+line('M24 20v13m-6-7h12m42 35v15m-7-8h14')),
 'combos': ('Combos', '<g fill="none" stroke="url(#gold)" stroke-width="9"><rect x="13" y="29" width="43" height="29" rx="14" transform="rotate(-40 34 43)"/><rect x="40" y="39" width="43" height="29" rx="14" transform="rotate(-40 61 53)"/></g>'+line('m35 58 26-22M19 74l-6 7m65-66 6-7')+gem(48,48)),
}
for key,(title,body) in icons.items():
    (deck / (key+'.svg')).write_text(svg(title,body), encoding='utf-8')

laurel = line('M26 80C8 66 9 39 23 24m47 56c18-14 17-41 3-56')+gold('m18 60-9-4 7 15 6 3Zm-1-13-9-9 3 16 7 4Zm4-14-5-12-4 15 6 7Zm57 27 9-4-7 15-6 3Zm1-13 9-9-3 16-7 4Zm-4-14 5-12 4 15-6 7Z')
medals = {
 'first-victory':('Primeira vitória',laurel+gold('m29 13 7 3 28 45-9 5Zm38 0-7 3-28 45 9 5ZM22 61l18 11 4-6-18-11Zm52 0L56 72l-4-6 18-11ZM27 70l7 4-5 11-7-4Zm42 0-7 4 5 11 7-4Z')+gem(48,40)),
 'ten-victories':('Dez vitórias',laurel+gold('M31 15h34v25c0 14-17 22-17 22S31 54 31 40ZM43 62h10v12H43ZM31 78h34v7H31Z')+line('M30 23H20v10c0 11 8 16 16 16m30-26h10v10c0 11-8 16-16 16')+gem(48,35)),
 'twenty-five-duels':('Vinte e cinco duelos',gold('m11 27 25-7 16 58-25 7Zm49-7 25 7-16 58-25-7Z')+gold('M29 13h38v69H29Z')+'<path d="M35 20h26v54H35Z" fill="url(#violet)" stroke="#7d4c2b" stroke-width="1.5"/>'+gold('m48 26 5 16 15 5-15 5-5 16-5-16-15-5 15-5Z')+line('M48 30v34M32 47h32')+gem(48,47)),
 'five-streak':('Cinco vitórias seguidas',laurel+gold('M36 40c-10-14 6-19 8-30 18 11 7 21 16 23 4 1 7-3 8-9 13 24 8 35-5 41H34c-13-7-14-18-10-29 2 6 7 10 12 4Z')+'<path d="M43 43c-4-8 4-12 6-17 6 13 0 18 10 17 4 7 0 15-7 20H41c-6-7-7-15 2-20Z" fill="url(#violet)" stroke="none"/>'+gold('m25 57 12 7 11-14 11 14 12-7-5 20H30ZM31 81h34v6H31Z')+gem(48,70)),
}
for key,(title,body) in medals.items():
    (achievements / (key+'.svg')).write_text(svg(title,body), encoding='utf-8')

# Standalone visual catalog; all artwork is embedded, with no external dependencies.
rows = []
for i, (key,(title,body)) in enumerate(list(icons.items())+list(medals.items())):
    x,y = 26+(i%4)*210,86+(i//4)*160
    art=svg(title,body).replace('<svg ', f'<svg x="{x+49}" y="{y}" width="90" height="90" ')
    # Isolate paint servers so each embedded emblem owns its gradients.
    art=art.replace('id="gold"',f'id="gold-{i}"').replace('id="violet"',f'id="violet-{i}"').replace('url(#gold)',f'url(#gold-{i})').replace('url(#violet)',f'url(#violet-{i})')
    rows.append(f'<rect x="{x}" y="{y-8}" width="190" height="140" rx="14" fill="#281d3b" stroke="#a17c49"/>{art}<text x="{x+95}" y="{y+113}" text-anchor="middle" fill="#f8dfac" font-family="Georgia,serif" font-size="15">{escape(title)}</text>')
(root / 'EMBLEMAS-DECKS-E-CONQUISTAS.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="870" height="750" viewBox="0 0 870 750"><rect width="870" height="750" fill="#15101f"/><text x="40" y="43" fill="#f8dfac" font-family="Georgia,serif" font-size="25">Mythic Clash · Decks e conquistas</text>'+''.join(rows)+'</svg>',encoding='utf-8')
print('12 ícones de estratégia e 4 medalhas criados.')
