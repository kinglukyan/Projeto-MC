# Hall de entrada

## Conteúdo

- Logo com o emblema existente e a frase “Mitologias se encontram. Lendas entram em combate.” sobre o cenário com movimento suave.
- Login e Criar conta para visitantes; JOGAR para uma conta conectada. O fluxo anterior de autenticação/boas-vindas é mantido.
- Vídeo ilustrativo de 12 segundos, com mesa, hologramas, raios de Zeus, tsunami de Poseidon e corações de Afrodite. Composto com as artes existentes; não é gravação de uma partida real. Carrega somente ao apertar play e começa mudo.
- Exploração de Grécia, Nórdicos, Egípcios, Reino de Alyn e Monstros. Símbolos sobre cenários, descrição de estilo e personagens que abrem suas histórias.
- Como jogar em três passos, ilustrados com cartas e símbolos existentes.
- Destaque para o pacote inicial: 14 cartas e dois ícones aleatórios, com a influência da preferência escolhida no cadastro. As cartas expostas são ilustrativas, não garantias de conteúdo.
- Personagem em destaque, banner, resumo e história completa pública. A alternância é feita a cada nove segundos quando a seção está visível e sem interação; pode ser pausada ou controlada manualmente.
- Duas chamadas locais de funcionalidades e o comunicado ativo real da administração. Sem comunicado, não são inventados eventos; uma falha de conexão é identificada como indisponibilidade.

## Celular, movimento e áudio

Layouts para telas estreitas, campos e ações por toque, vídeo com controls/playsinline, imagens secundárias com carregamento tardio. O áudio ambiente só começa após clicar em Ativar áudio, com botão Silenciar. Pausa ao sair do hall, abrir a autenticação ou ocultar a aba.

O movimento respeita prefers-reduced-motion e o modo de economia de dados. Há botão para pausar/ativar movimentos. O vídeo não toca automaticamente e é interrompido quando sai da área visível.

## Arquivos

`public-hall.js` e `public-hall.css` ampliam o portal existente. `portal-upgrade.js` mantém autenticação e entrada no jogo. `online.js` emite o comunicado público usando a consulta já existente de game_announcements. Os vídeos e o pôster estão em `assets/portal/`.

O hall não exige nova migração SQL. Publicar os arquivos atualizados; as migrações de lobby 035/036 do pacote continuam necessárias para os respectivos recursos.

Foram renderizadas apresentações locais em 1440×1000 e 390×844 e revisados os espaçamentos visuais. A captura foi feita sem acesso ao servidor online. Não foram executados testes de login, recompensas, áudio em aparelhos físicos ou partidas nesta entrega.
