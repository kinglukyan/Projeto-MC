# Vitória por Rounds e correção das estrelas

## Problemas encontrados

1. No online 1×1 e 2×2, a finalização do Round descontava uma estrela da equipe vencedora. O correto é descontar da perdedora; empate não retira estrelas.
2. No 2×2, os objetos alterados das equipes não eram gravados no estado antes de serem relidos pela limpeza do Round, perdendo alterações nas estrelas.
3. A tela de resultado do online 1×1 recalculava vitória pela soma de pontos e podia contrariar um resultado por desistência confirmado pelo servidor.
4. O jogo somava pontos entre Rounds para decidir a partida. Essa regra estava errada: cada Round deve ser independente.

## Correções

- SQL 032 corrige o desconto das estrelas e a gravação no 2×2. As estrelas passam a corresponder a duas menos as vitórias em Rounds do adversário. Partidas em andamento são normalizadas na próxima atualização do estado.
- O site usa o vencedor confirmado pelo servidor para exibir o resultado online, inclusive em desistências e desempates.
- O combate local e o servidor decidem a partida pelas vitórias em Rounds, sem acumular pontos.
- Durante o combate, o placar principal mostra os pontos do Round atual. A legenda informa os Rounds vencidos. Ao terminar, o placar principal exibe o resultado em Rounds.
- O histórico e o registro do resultado do Guardião recebem as vitórias em Rounds como placar da série. As recompensas continuam dependendo do vencedor.

## Regra aprovada pelo usuário

- Mais pontos no campo ao encerrar o Round: vence esse Round; o adversário perde uma estrela.
- Pontos iguais no Round: empate; ambos mantêm as estrelas.
- Os pontos valem somente para o Round em que foram obtidos. Não há soma entre Rounds.
- A partida termina antecipadamente quando alguém vencer dois Rounds.
- Após três Rounds, vence quem tiver mais vitórias. Se as vitórias empatarem, entra o desempate de cartas e Eclipse já implementado, mesmo se os pontos dos Rounds tiverem sido diferentes.
- Exemplo: A ganha 100 × 5 no primeiro Round e perde 0 × 10 nos dois seguintes. B vence a partida por 2 × 1 em Rounds.
- Desistência pode encerrar a partida independentemente do placar; a interface respeita o resultado do servidor.

## Aplicação

Executar `supabase/migrations/202610180031_match_deck_catalog_fix.sql`, se ainda não tiver sido aplicado. Em seguida executar `supabase/migrations/202610180032_round_stars_and_result.sql` e publicar os arquivos do pacote atualizado do site. Os SQLs não são executados automaticamente ao publicar o ZIP.

O campo legado `totalPoints` continua existindo para compatibilidade, mas recebe somente os pontos do Round encerrado, sem acumular. Cada placar individual é preservado em `roundScores` e `lastRoundPoints`. O vencedor é calculado por `roundWins`. As animações de transição usam o placar individual salvo. Não há reprocessamento das recompensas de partidas antigas.

Revisão realizada por leitura do fluxo de combate e das migrações, com conferência de sintaxe JavaScript. Não foram executados testes automatizados de partidas nem partidas reais. Não foi aplicado ao banco online nem publicado nesta conversa.
