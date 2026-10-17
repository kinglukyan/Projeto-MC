# Atualização das habilidades — 17/10/2026

O motor de habilidades está integrado ao Guardião local e às ações online de 1 × 1 e 2 × 2. Os diálogos de escolha se adaptam ao celular.

## Regras confirmadas

- Hades: o invocador escolhe uma carta do próprio Submundo para retornar ao campo, na fileira de Hades. A habilidade de entrada da carta retornada também é processada.
- Ísis: escolhe uma carta do próprio Submundo com poder base de até 2. O critério é poder, não custo.
- Afrodite: escolhe entre os inimigos elegíveis com menos de 5 de poder.
- Loki: escolhe um inimigo em campo e copia seu poder e sua habilidade até o fim da rodada.
- Odin: consulta o topo antes da compra normal, no início do próximo turno do dono. O jogador escolhe manter ou descartar; depois continua seu turno. A consulta ocorre uma vez por entrada de Odin no campo.
- Hércules: ganha +1 ao final da rodada. O progresso é zerado na troca de rodada, conforme a regra atualizada.
- Metades de poder são arredondadas para baixo.

Também foram implementados os efeitos de Anúbis, Apolo, Ares, Ártemis, Aquiles, Beowulf, Butter, Dionísio, Hefestos, Heimdall, Hermes, Hórus, Minotauro, Osíris, Rá, Ragnar, Seth, Sobek, Thor e os lobisomens, além das interações com equipamentos, terrenos, locais e Eclipse.

O catálogo tem 54 cartas disponíveis para baralhos e 3 formas especiais. Lukyan — Rei de Todos e os resultados Lunar/Solar continuam fora do baralho e da compra direta. Rei Arthur permanece aguardando a carta que será enviada posteriormente.

## Aplicação no Supabase

Após as migrações anteriores até `202610170009_loki_card.sql`, execute:

`supabase/migrations/202610170010_all_character_abilities.sql`

A migração atualiza o catálogo e os dois formatos online dentro de uma transação. Ela mantém as validações de jogador e turno e valida as escolhas no servidor. Inicie partidas novas após atualizar o site e aplicar a migração; partidas antigas de duplas podem ter cartas no Submundo sem o registro de seu dono.

## Estado da entrega

Arquivos e migração preparados localmente. A migração não foi aplicada ao banco remoto. Não foram executados testes de jogo, navegador ou banco nesta atualização.

## Regra de limpeza atualizada

A migração 012 zera todos os efeitos ao trocar a rodada, incluindo o silêncio de Dionísio e o progresso de Hércules.
