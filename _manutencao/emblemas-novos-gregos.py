from pathlib import Path
root=Path(__file__).resolve().parents[1]
folder=root/'assets/character-emblems';folder.mkdir(exist_ok=True)
art={
 'hera':('Hera','<path d="M22 68 15 34l22 12 11-26 11 26 22-12-7 34Z"/><path d="M26 74h44v8H26Z"/><g fill="#28706e"><ellipse cx="20" cy="28" rx="8" ry="12"/><ellipse cx="76" cy="28" rx="8" ry="12"/><ellipse cx="48" cy="15" rx="8" ry="12"/></g><g fill="#b8a2ec"><circle cx="20" cy="27" r="4"/><circle cx="76" cy="27" r="4"/><circle cx="48" cy="14" r="4"/><path d="m48 48 7 10-7 10-7-10Z"/></g>'),
 'demeter':('Deméter','<g fill="none" stroke-width="3"><path d="M48 85V14M48 77 24 32m24 45 24-45"/></g><path d="m48 13-9 12 9 6 9-6Zm-7 19-12-4 4 14 10 2Zm14 0 12-4-4 14-10 2Zm-14 16-12-4 4 14 10 2Zm14 0 12-4-4 14-10 2ZM23 30l-9 2 3 12 11 1Zm51 0 9 2-3 12-11 1Z"/><path d="M33 86h30v-8H33Z"/>'),
 'hestia':('Héstia','<path d="M48 8c17 17 4 22 15 29 6 4 12-1 12-10 15 26 5 48-27 48S10 53 24 32c-1 13 11 13 12 5C37 27 43 23 48 8Z"/><path d="M49 35c8 10 0 16 10 20 6 8-1 16-11 16s-16-8-10-17c5-6 9-10 11-19Z" fill="#b85632"/><path d="M15 76h66l-9 11H24Z"/><path d="M29 90h38" fill="none" stroke-width="3"/>'),
 'perseu':('Perseu','<path d="M48 22 72 31v27L48 83 24 58V31Z"/><path d="m48 31 16 6v17L48 71 32 54V37Z" fill="#294f76"/><path d="M25 37C8 32 7 19 8 11c9 13 20 9 24 20ZM71 37c17-5 18-18 17-26-9 13-20 9-24 20Z"/><path d="m64 11 5 4-28 46-6-4ZM31 58l15 9-3 5-15-9Zm2 10 7 4-8 14-7-4Z"/><path d="m48 40 5 8-5 8-5-8Z" fill="#bad4e8"/>'),
}
for key,(name,body) in art.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><title>Emblema de {name}</title><defs><linearGradient id="gold" x1="10" y1="9" x2="80" y2="88" gradientUnits="userSpaceOnUse"><stop stop-color="#fff1b9"/><stop offset=".45" stop-color="#d5a447"/><stop offset="1" stop-color="#ffe3a1"/></linearGradient></defs><g fill="url(#gold)" stroke="#e2bd73" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>'
 (folder/(key+'.svg')).write_text(svg,encoding='utf-8')
print('Quatro emblemas de personagem preparados.')
