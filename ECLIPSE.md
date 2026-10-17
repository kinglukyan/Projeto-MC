# Eclipse: sorteio, regras e apresentação

## Cartas

Eclipse (arte cósmica com Sol e Lua) continua usando o identificador eclipse, disponível no deck. Eclipse Lunar (Lua vermelha) e Eclipse Solar (Sol encoberto) são resultados especiais, sem cópias no deck nem compras para a mão. O resultado ocupa o espaço compartilhado de Clima/Evento até o fim da rodada.

Sorteio único com 50% para cada resultado. No Guardião, usa crypto.getRandomValues; online, random() no servidor, dentro da transação já protegida por turno e bloqueio da partida. O cliente não escolhe o resultado. Reabrir a partida conserva o resultado salvo e não sorteia novamente.

## Efeitos nos dois lados

- Lunar: lobisomens, vampiros e Ártemis têm o poder dobrado; Apolo e Rá ficam com metade.
- Solar: Apolo e Rá têm o poder dobrado; Ártemis fica com metade; vampiros vão ao Submundo; Beta/Omega viram Homem e Alfa vira Mulher.
- Metades arredondam para baixo, conforme escolha do usuário. Os multiplicadores são calculados depois dos demais bônus, sem modificar permanentemente os pontos.
- O clima afeta cartas presentes e novas entradas. Local e Terreno continuam ativos.
- Transformações preservam fileira, posição, bônus e equipamentos. Ao sair do campo, o lobisomem retorna à carta original no Submundo. A transformação não dispara novamente uma habilidade de entrada.
- Humanos usam as regras de suas cartas: cada Homem dobra o poder da Mulher; os Homens dobram por cada outro Homem aliado. Esses efeitos são calculados pela identidade atual em campo.
- Vampiros são identificados por IDs começando com vampir e pelo ID dracula. Não foram inventadas cartas de vampiros; novas identidades devem ser registradas com essa classificação.

## Apresentação

Animação de 3,2 segundos alterna as duas cartas antes da revelação, com órbitas e iluminação. Inclui pular animação, Escape, disposição para celular em pé/deitado e opção de movimento reduzido. O mapa Lunar usa Lua vermelha, névoa violeta e partículas; o Solar usa coroa dourada e brasas. A atualização do mapa lê o resultado já salvo, inclusive após reconexão.

## Disponibilidade e instalação

Os personagens que já estavam em prévia continuam em prévia: esta atualização não libera suas habilidades incompletas. As transformações solares podem usar as artes de Homem/Mulher no campo mesmo enquanto suas cartas independentes estão em prévia.

Aplicar supabase/migrations/202610170008_eclipse_event.sql após o 007. SQL não aplicado remotamente. Não foram executados testes de navegador ou banco nesta alteração. Partidas já iniciadas antes da atualização com o Eclipse antigo conservam seu estado legado até terminar a rodada; iniciar nova partida usa as regras novas.
