# Correção da entrada do segundo jogador na fila

## Causa

A entrada do segundo jogador é o momento em que o servidor cria a partida e distribui os dois baralhos. Os construtores de partidas ainda continham listas próprias de cartas permitidas, herdadas das primeiras versões. Essa validação duplicada podia rejeitar um baralho aceito pelo construtor e exibir “O baralho contém quantidade ou carta inválida”.

## Correção

- A criação de partidas 1×1 e 2×2 usa a validação atual da coleção, sem outra lista fixa de cartas.
- Permanecem as verificações de propriedade das cópias, cartas especiais proibidas no baralho, cartas pausadas, suspensão de participantes e tamanho de 14 a 35 cartas.
- O jogador tem seu baralho validado antes de entrar na fila solo, mesmo quando ainda não há adversário.
- Mantidas a distribuição inicial de cinco cartas para quem começa e quatro para os demais, mãos privadas nas duplas e a estrutura dos estados de combate.
- Nenhum baralho salvo, saldo ou partida em andamento é alterado.

## Aplicação

No projeto Supabase do jogo, executar `supabase/migrations/202610180031_match_deck_catalog_fix.sql` no SQL Editor, depois das migrações até a 030. Não é necessário republicar o site para esta correção.

O arquivo foi preparado localmente; não foi aplicado ao banco de produção nesta conversa. Não foram executados testes automatizados ou partidas reais.
