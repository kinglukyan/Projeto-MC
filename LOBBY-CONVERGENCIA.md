# Sala de convergência e convites

## Fluxo

- A sala abre com o jogador e uma vaga quadrada com **+**. A escolha manual de 1×1/2×2, os campos de código, o adversário e o VS foram retirados desta sala.
- O **+** abre a lista de amigos com nick, ícone e elo. Online vem primeiro, depois ausente e offline; a busca filtra pelo nick.
- O convite abre uma janela flutuante para o destinatário, sem trocar sua tela. Ela pode ser arrastada ou movida pelas setas ao focar o cabeçalho.
- **Entrar na sala** aceita o convite e forma a dupla. Não inicia a fila. Convites sem resposta expiram após cinco minutos.
- Sem parceiro, **Convergir** inicia 1×1. Com a dupla formada, somente o anfitrião inicia 2×2. O modo Normal/Ranqueada é o da sala do anfitrião.
- O tempo aparece no lugar do botão. No computador, passar o mouse ou focar revela **Cancelar busca**. Em aparelhos de toque, esse botão permanece visível abaixo do contador.
- Cancelar uma busca em dupla mantém os dois na sala. **Desfazer dupla/Sair da sala** encerra a sala; **Cancelar convite** retira um convite ainda não aceito.
- A janela flutuante do tempo em fila continua acompanhando o jogador pelo site.

## Atualizar o servidor e publicar

1. No Supabase SQL Editor, aplicar `supabase/migrations/202610190035_convergence_lobby.sql` após a 034. Esta migração adiciona o estado `ready` e separa aceitar convite de procurar partida. Preserva as partidas e os dados existentes.
2. Publicar o conteúdo atualizado desta pasta como raiz do site.

A migração mantém a autorização no servidor: apenas os participantes veem a sala, apenas o convidado aceita e apenas o anfitrião inicia a busca. Novos convites exigem amizade aceita. O modo solo é bloqueado enquanto a conta pertence a uma sala em dupla. A presença e a lista usam as APIs de amigos existentes.

O pacote foi atualizado localmente; a migração não foi aplicada ao Supabase e o site não foi publicado nesta entrega. A sintaxe dos JavaScripts alterados foi conferida. Não foram executadas partidas reais nem conferência em celulares físicos.
