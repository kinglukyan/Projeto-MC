# Modo teste em Meu Baralho

Selecione um baralho e clique em **Testar baralho**. As cartas desse baralho começam na mão para facilitar a montagem de combos. A simulação usa as mesmas regras de habilidades, hologramas e efeitos visuais do combate.

Em **Configurar teste** é possível:

- Buscar e invocar personagens inimigos, escolhendo uma das três fileiras.
- Resolver manualmente os alvos das habilidades dos dois lados.
- Enviar um inimigo ao Submundo, ativando também os efeitos de destruição previstos nas regras.
- Preparar cartas na mão inimiga para testar habilidades que revelam ou dependem dessa mão.
- Repor as cartas do próprio baralho na mão. Essa ação cria cópias apenas na simulação.
- Manter quatro cartas na mão e reservar as demais no baralho, para testar compras e habilidades de topo, como Odin.
- Comprar uma carta, avançar turnos, encerrar rodadas ou reiniciar o cenário.

O teste não tem adversário automático, cronômetro, classificação, XP, moedas ou registro de resultado. Não altera o baralho salvo nem o inventário. Ao sair, o cenário é descartado. Uma partida em andamento precisa ser encerrada ou abandonada antes de abrir o teste.

## Eclipse ao encerrar a rodada

Verificação executada no motor local com Eclipse Solar e Lunar:

- A pontuação da rodada considera os efeitos ativos até o encerramento.
- O campo é esvaziado e os personagens vão para o Submundo.
- Lobisomens transformados em Homem/Mulher são registrados no Submundo como o lobisomem original.
- Vampiros destruídos pelo Solar permanecem no Submundo; o fim do clima não os ressuscita.
- O Eclipse é removido da área de clima, assim como Local e Terreno. A carta de zona não é acrescentada ao Submundo nem devolvida à mão pelo comportamento atual.
- A revelação e os bônus do Eclipse são apagados. A próxima rodada começa sem o clima, e novas cartas entram com seus poderes normais até que outro clima seja jogado.

Foi corrigido o intervalo em que a limpeza retirava a revelação e os personagens, mas deixava o clima no estado até a preparação da próxima rodada. Agora as zonas são limpas pela mesma operação que encerra os efeitos, inclusive na rodada final.

## Supabase

O modo teste funciona localmente e não precisa de novas tabelas. Para aplicar a limpeza de zonas também às partidas online, execute **supabase/migrations/202610180022_round_zone_cleanup.sql**, depois das migrações anteriores até 021.

O SQL 022 foi revisado estaticamente, mas não foi executado no banco remoto. A verificação funcional descrita acima foi feita no motor local, sem alterar contas ou partidas reais.
