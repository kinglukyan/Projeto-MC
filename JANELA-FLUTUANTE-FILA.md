# Janela flutuante da fila

- Aparece ao entrar na fila de partida normal ou ranqueada, solo ou em dupla.
- Acompanha a navegação pelas telas do site sem cancelar ou reiniciar a busca.
- Pode ser arrastada pelo cabeçalho com mouse ou toque. Pelo teclado, focar o cabeçalho e usar as setas; Shift faz ajustes menores.
- Mostra formato, modalidade e tempo de espera. O tempo usa o relógio, evitando atrasos quando a aba fica em segundo plano.
- Na dupla, mostra “Aguardando parceiro” até ele aceitar; a contagem começa quando a dupla entra na busca.
- “Voltar à sala” abre a tela de escolha de 1×1/2×2 correspondente, mantendo a fila.
- “Sair da fila” aguarda confirmação do servidor. Em caso de erro, mantém a janela e informa a falha. Se a partida já tiver sido encontrada, abre o combate.
- Some quando uma partida é encontrada, a busca é cancelada ou a conta é encerrada.
- A posição fica salva por conta neste navegador e é ajustada ao redimensionar ou girar a tela.

## Arquivos

`floating-queue.js` e `floating-queue.css`: componente independente das telas. `online.js`: estado compartilhado da busca, notificações e cancelamento. Incluído em `index.html` e `mobile.html`.

## Entrega

Publicar o ZIP atualizado. Não exige novo SQL. A persistência da janela cobre a navegação interna do site; não adiciona retomada da fila solo após recarregar a página. A dupla conserva a recuperação de estado que já existia.

Conferida a sintaxe JavaScript e produzidas prévias visuais. Não foram executados testes automatizados nem partidas reais. Não foi publicado automaticamente.
