# Atlas — interações do primeiro mapa — 2026.10.22.6

## Instalar

1. Esta atualização parte da versão 2026.10.22.5, com o SQL 061 já aplicado.
2. Aplicar `supabase/migrations/202610220062_atlas_athena_minotaur.sql` inteiro. Se houver partidas ativas nos desafios 4 ou 15 da Grécia, o SQL pedirá que sejam concluídas ou encerradas antes de repetir a migração. Isso impede mudar o oponente de uma batalha em andamento.
3. Extrair o pacote na raiz do projeto e publicar pelo GitHub conectado à Vercel. Não é necessário importar novamente imagens pelo painel.

## Ordem dos desafios

1. Aquiles
2. Hércules
3. Hermes
4. Athena
5. Soldado de Esparta

O Minotauro passa para o desafio 15, encerrando o Labirinto de Dédalos. Somente identidade, nome e ícone dos oponentes 4 e 15 mudam. Os identificadores das fases, progresso vencido, recompensas resgatadas, dificuldade, ensinamentos e baralhos gregos dessas posições são preservados. Quem já venceu uma fase continua com ela vencida. O roteiro guardado do Minotauro ainda não recebe uma cena no Labirinto nesta entrega; suas artes de diálogo serão preparadas para aquela área.

## Interações

Os cinco personagens do primeiro mapa recebem os diálogos e escolhas aprovados. Aquiles mantém suas quatro artes originais. Hércules, Hermes, Athena e o soldado usam as novas pranchas PNG transparentes, com recortes por posição no próprio navegador, sem reduzir ou recomprimir as fontes.

As falas alternam boca fechada e aberta a cada sete quadros em 30 fps, aproximadamente 233 ms. As outras expressões entram ao terminar a fala. Há botão para completar o texto e opções de teclado 1–9. A preferência de redução de movimento desativa a animação. O duelo só é criado no servidor depois da última resposta e da reação do personagem; fechar o diálogo antes disso não cria partida.

Depois da apresentação de vitória ou derrota, o personagem fala antes do resumo da partida. O botão “Ver resumo da partida” continua o fluxo existente. As falas não geram outra recompensa e não são acionadas ao apenas abrir histórico ou atualizar uma partida já concluída. Fechar a fala final segue para o resumo; ao sair da conta ou mudar de tela, a cena é encerrada.

A vitória contra o soldado inclui o aviso “E cuidado em Esparta...” combinado para a passagem de página. Sua resposta sobre adversários anteriores foi ajustada para mencionar dois heróis, um mensageiro e uma deusa, pois o Minotauro agora está no Labirinto.

## Entrega

Build local preparado. O SQL não foi executado no banco online e esta entrega não publicou o site. Não foram executados testes automatizados ou partidas reais, conforme a orientação de você testar depois. Após publicar, conferir as duas ramificações de cada encontro, vitória/derrota, fechamento antes do duelo, mobile e retorno ao resumo.
