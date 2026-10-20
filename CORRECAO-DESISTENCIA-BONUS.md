# Correção do erro ao desistir

Mensagem exibida: `column reference "v" is ambiguous`.

A função `_x_bonus`, usada no cálculo de poder, declarava uma variável chamada `v` e também usava `v` como identificador de uma consulta. Ao calcular a pontuação antes de finalizar a desistência, o PostgreSQL encontrava as duas referências e rejeitava a operação.

A migração **047** separa os nomes da variável e das consultas, com referências explícitas às colunas. As condições de companheiros, crescimento pelo Submundo, auras, equipamentos e fileiras ocupadas permanecem iguais. A função corrigida também foi incluída nas fontes da migração 040 para novas instalações.

## Aplicar na instalação existente

Execute no editor SQL do Supabase o arquivo completo:

`supabase/migrations/202610200047_card_bonus_alias_fix.sql`

Como a confirmação de desistência já está publicada, esta correção no banco não exige outra publicação da interface. Depois de aplicar, tente confirmar a desistência novamente.

A operação que falhou é transacional: esse erro não deve ter confirmado a desistência nem suas recompensas. Enquanto isso, a partida pode ter continuado ou terminado por outro motivo. Se já estiver concluída, a solicitação de desistência preserva o resultado existente.

Não é necessário reinstalar o jogo nem executar novamente todas as migrações. Esta entrega não foi aplicada no banco remoto, e não foram executados testes de partida nesta sessão.
