# Ranqueada: estrelas Strix e pontos

## Regra aprovada

- Aprendiz de Herói, Escudeiro, Herói e Lenda usam cinco estrelas Strix por rank.
- Vitória ranqueada concede uma estrela; derrota retira uma estrela.
- Ao conquistar a quinta estrela, sobe para o próximo rank, começando com zero estrelas.
- Se perder com zero estrelas, cai para o rank anterior com quatro estrelas.
- Exceção: Aprendiz de Herói fica no mesmo rank com zero estrelas.
- Ao completar Lenda, entra em Semideus com 1.700 pontos. A partir daí permanecem +25 pontos por vitória e −25 por derrota.
- Deus começa em 2.000 pontos e Convergente em 2.400. Se Semideus cair abaixo de 1.700 pontos, volta para Lenda com quatro estrelas.
- Normal, personalizada e Guardião não dão nem retiram estrelas ou pontos de rank. No 2×2 e no desempate, cada participante recebe a alteração correspondente ao resultado final, como já acontecia com os pontos.

As estrelas de progressão Strix são independentes das duas estrelas de Round de cada equipe durante uma partida.

## Tela ranqueada

Rank atual, emblema, cinco estrelas preenchidas/vazias, regra de ganho/perda, progresso até o próximo rank e trilha dos sete ranks. Em Semideus ou superior, o indicador passa a mostrar pontos. A trilha pode ser deslizada no celular. O quadro não aparece na fila normal.

Perfil e perfil de amigos exibem estrelas nos ranks iniciais e pontos nos ranks superiores.

## Migração e proteção

O SQL 034 preserva o rank existente e converte proporcionalmente o progresso dentro dele para estrelas. Contas novas começam em Aprendiz com zero estrelas. XP, moedas, vitórias, derrotas e recompensas antigas não são reprocessados.

Para manter compatibilidade com os emblemas, consultas e matchmaking já existentes, `rating_points` continua como coordenada interna: abaixo de Semideus, suas cinco posições por faixa representam 0 a 4 estrelas, e não pontos exibidos ao jogador. Um gatilho do servidor converte as recompensas ranqueadas existentes de +25/−25 para uma estrela, cobrindo as mesmas rotas de resolução 1×1, 2×2, desistência e desempate. A interface não calcula nem grava recompensas. Acima de Lenda, o campo volta a representar pontos.

Os limites internos existentes foram mantidos; a busca de adversários não foi redesenhada nesta atualização. Os clientes continuam sem permissão para editar a pontuação diretamente.

## Aplicação

1. Aplicar `supabase/migrations/202610190034_rank_strix_stars.sql` depois da migração 033.
2. Publicar os arquivos do ZIP atualizado do site. Os SQLs não são executados automaticamente pela publicação.

Foi feita revisão do código e conferência de sintaxe JavaScript. A prévia visual não pôde ser aberta neste ambiente. Não foram executados testes de partidas nem aplicado o SQL ao banco online nesta conversa.
