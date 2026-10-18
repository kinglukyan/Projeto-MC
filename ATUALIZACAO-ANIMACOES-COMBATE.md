# Animações e navegação do combate

## Ajustes

- Eclipse: compatibilidade com partidas que só registram o clima, sem `eclipseReveal`; resultado visual usa o sorteio já realizado. Efeitos sonoros desativados não desligam a animação. A preferência de movimento reduzido continua respeitada.
- Galeria do duelo: cartas vizinhas clicáveis, gesto horizontal com captura do ponteiro durante o movimento, cancelamento de gesto tratado e navegação por setas do teclado. Cliques gerados depois de deslizar não fecham a ampliação.
- Hologramas: largura e altura aumentadas em 25% no desktop e mobile. Espaçamento dos companheiros e área livre acima das cartas acompanham o aumento.
- Habilidades: apresentação com o PNG do holograma e o nome da habilidade. Temas de raios, pedra, corações, água, lua, Submundo, vida, ilusão, runas e sol conforme o personagem. Cartas sem holograma usam a própria arte.
- Apresentação acontece antes dos impactos. Cartas removidas são mantidas visualmente no local até a explosão; depois as partículas seguem para o Submundo do dono.
- Posições dos alvos são guardadas por animação, para atualizações do campo não apagarem os alvos antes do efeito. Temporizadores são cancelados ao sair do combate/trocar conta.
- Janelas de escolha e de cartas reveladas aguardam a apresentação terminar. Animações não alteram o resultado ou os sorteios no servidor.

## Publicação

Esta alteração de interface não exige um SQL adicional. O pacote completo continua incluindo o SQL 018 da auditoria anterior, que é uma atualização separada do banco.

Publicar os arquivos de interface em conjunto: `index.html`, `app.js`, `abilities-ui.js`, `eclipse.js`, `combat-fx.js` e o novo `combat-cinematics.css`. Os scripts foram versionados para atualização dos caches por F5.

Conferência realizada: sintaxe JavaScript e referências locais dos arquivos. Não foram executados testes funcionais em navegador ou partidas no Supabase.
