# Guardião — Jornada das Mitologias

## O que foi preparado

- Atlas do mundo real com símbolos das facções e posições aproximadas. Há zoom, arraste e foco no próximo destino.
- 11 destinos, com 20 desafios cada: **220 batalhas**. A Grécia começa aberta; concluir seus 20 desafios libera o Egito, e assim sucessivamente.
- Ordem: Grécia, Egito, Nove Reinos, Terras Celtas, Mesopotâmia, Caminhos Hindus, Reino Celestial, Ilhas do Sol, Terras Astecas, Lendas do Brasil e Lendas Europeias (Monstros).
- Os Alyns não têm destino, adversários ou recompensas nesta campanha inicial. O jogador pode usar seu baralho normal.
- Cada adversário usa seu ícone chibi e um deck montado com cartas de sua facção. Os Monstros também podem usar o Eclipse, que é um evento universal.
- Quatro áreas por destino, com cinco desafios por cenário e navegação lateral. O novo Atlas tem cenários próprios em `assets/guardian-campaign/atlas/`, inspirados nos Locais e Terrenos quando disponíveis. Nas facções sem essas cartas, os nomes das áreas são cenográficos; não foram inventadas cartas de Local jogáveis. Consulte `NOVO-ATLAS-DAS-LENDAS.md`.
- Seleção de baralho antes de entrar no desafio, repetição de fases concluídas, retomada de uma batalha e relatório com retorno ao mapa.

## Progressão e recompensas

A fase seguinte exige a vitória na anterior. Perder ou encerrar uma batalha não apaga as fases concluídas. Os Rounds têm pontuações independentes; vence quem alcançar duas vitórias, ou quem liderar após o terceiro Round. Empate em vitórias usa as puxadas de unidades e o Eclipse já existentes, com a mesma animação.

A cada **cinco desafios diferentes vencidos pela primeira vez**, o servidor entrega um item aleatório: carta ou ícone. Não é uma sequência obrigatória de vitórias; derrotas entre as fases não reiniciam a contagem. Repetições não duplicam os prêmios.

O sorteio começa com 50% de chance de cada categoria. Ícones já possuídos são evitados enquanto houver opções; esgotados os ícones, o sorteio pode entregar uma carta. Cartas pausadas e formas especiais não são sorteadas. Se todos os itens elegíveis estiverem em manutenção, o prêmio fica reservado para resgate posterior em “Tesouros da jornada”. Há até 44 marcos na campanha.

Não foram criadas recompensas extras de moedas ou XP por fase. A primeira vitória da Grécia conclui o treinamento inicial e garante o mínimo de 100 XP apenas para quem ainda não o concluiu, preservando o acesso aos outros modos.

## Como os adversários evoluem

Os decks começam menores e com menos repetições. O gerador aumenta gradualmente o tamanho pretendido, as repetições permitidas e a prioridade de combinações que funcionam juntas. O limite é 35 cartas; facções com poucas cartas podem usar decks menores.

Entre os critérios estão companheiros juntos, auras na mesma fileira, proteção, alvos de recuperação disponíveis, equipamentos com portadores compatíveis e cartas de controle. A dificuldade global não reinicia ao trocar de destino. A indicação vai de 1 a 5; os decks continuam variando dentro desse intervalo.

Na batalha, o adversário escolhe cartas e fileiras a partir de sua mão e do campo visível. Resolve escolhas de habilidade, avalia alvos protegidos, busca unidades valiosas para destruição/recuperação e pode preservar cartas passando quando já tem vantagem. Ele não escolhe resultados aleatórios nem altera o poder impresso das cartas. Esse sistema é heurístico e ainda precisa de balanceamento com partidas reais.

## Para colocar no site

1. O banco precisa estar atualizado até a **044 corrigida**, incluindo a correção da mensagem “Validação de escolhas incompatível”.
2. Execute no Supabase o arquivo `supabase/migrations/202610200045_guardian_world_campaign.sql` completo. Ele cria a campanha e seus registros, sem apagar partidas ou coleções anteriores.
3. Atualize o repositório conectado à Vercel com os arquivos desta pasta. O processo de publicação já inclui os novos scripts, estilos e mapa.

Até a migração estar aplicada, o Guardião informa que a jornada aguarda a atualização 045. Não usa progresso fictício como substituição.

O progresso, as jogadas do bot, a propriedade do baralho e os prêmios são calculados no servidor. As tabelas da campanha não aceitam acesso direto dos jogadores. As ações têm autenticação, verificação de versão e identificador para evitar confirmação duplicada.

## Arquivos para futuras alterações

- `guardian-campaign.js` / `.css`: mapa, trilhas, baralhos, conexão com a batalha e recompensas.
- `guardian-campaign-data.js`: catálogo público dos destinos e adversários.
- `_manutencao/guardian-campaign/catalogo-servidor.json`: catálogo completo com os decks.
- `_manutencao/guardian-campaign/preparar-campanha.py`: regenera os catálogos a partir das cartas atuais.
- `_manutencao/guardian-campaign/compilar-campanha.py`: recompila a migração 045 a partir dos três fragmentos SQL.

O catálogo completo permanece fora da pasta publicada. Alterar os decks no servidor exige atualizar a migração correspondente; editar somente o catálogo visual não altera as partidas.

## Limites desta entrega

Os arquivos foram preparados localmente. Não houve aplicação no Supabase nem publicação na Vercel nesta sessão. Não foram executados testes de partidas. A checagem local se limitou à sintaxe dos scripts e à revisão do código; as interações de combate e o equilíbrio dos 220 desafios precisam ser avaliados no ambiente do jogo.
