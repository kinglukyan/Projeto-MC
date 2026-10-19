# Desempate e barra superior mobile

## Desempate

O erro `column u.wins does not exist` vinha de `_tb_award`: o histórico de baralhos usa `victories` e `defeats`, enquanto a função tentava atualizar `wins` e `losses`.

A migração 033 usa os nomes corretos, retira o empate anterior da estatística do baralho e mantém o número de partidas. Só converte registros ainda empatados: repetir a solicitação não concede a recompensa duas vezes. O erro anterior abortava a transação; a partida empatada pode ser tentada novamente após aplicar a correção.

Aplicar `supabase/migrations/202610180033_tiebreak_deck_counters.sql` após a 032. Não cria colunas extras e não altera as chances do sorteio.

## Barra superior

Em celulares e tablets de até 960px, a barra agora ocupa uma linha de cerca de 60px, com controles de 44px para toque. Menu e Início usam ícones; conexão usa um ponto de status. O título tem espaço flexível, e os botões ficam sem as grandes caixas individuais. Em telas de até 360px, o título é preservado para leitores de tela e permanece visível no cabeçalho da própria página.

Publicar os arquivos do ZIP atualizado para receber o ajuste visual. O SQL deve ser aplicado separadamente no banco. Não foi publicado nem aplicado ao banco online nesta conversa.
