# Atualizar a página sem exibir o hall

A abertura agora consulta, antes da primeira exibição, se a conta tinha uma tela interna salva. Nesse caso, mantém uma tela neutra “Retomando sua jornada…” até a recuperação da sessão, do perfil e da tela de destino terminar. O hall continua disponível imediatamente para visitantes e para quem saiu do jogo pelo botão Início.

O registro local serve somente para escolher a apresentação de carregamento. A autenticação, as permissões e a consulta de partidas ativas continuam no fluxo existente. Partidas encerradas não são reabertas.

A tela interna e seus estilos são preparados antes de retirar a cobertura. O registro da última tela não é sobrescrito pela tela provisória durante essa recuperação. Em uma conexão lenta, aparecem as opções Tentar novamente e Ir para o início.

## Publicação

Atualize o repositório conectado à Vercel com os arquivos da pasta completa, incluindo `session-startup.js`, `session-resume.js`, `entry-critical.css` e `index.html`. Não é necessário SQL novo.

O mesmo ZIP foi atualizado. Alterações locais com revisão de código e checagens de sintaxe; sem testes de navegador ou publicação remota nesta sessão.
