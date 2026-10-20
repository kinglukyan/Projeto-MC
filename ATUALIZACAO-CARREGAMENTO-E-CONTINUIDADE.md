# Carregamento e continuidade — 20/10/2026

## Publicar

1. Aplicar `supabase/migrations/202610200043_resume_my_game.sql`, após o SQL 042. Se ainda não aplicou o 042 dos ícones de deck, aplique-o primeiro.
2. Atualizar o conteúdo desta pasta no GitHub conectado à Vercel. Incluir `_manutencao`, `vercel.json`, `assets` e todos os arquivos da raiz.
3. Aguardar a publicação de produção finalizar.

As melhorias de carregamento, a classificação da loja, a sugestão de decks e a unificação do X1 são do site. O SQL 043 permite localizar com segurança a partida do próprio jogador. Não altera vitórias, pontos, relógios ou recompensas.

Esta entrega é local. Não houve publicação na Vercel nem aplicação de SQL no banco remoto. Foram realizadas checagens de sintaxe e conferência dos arquivos; não foram executadas partidas de teste nem medições de tempo de carregamento em celulares ou na produção.

## Primeiro acesso mais leve

- O hall já está no HTML: não precisa aguardar a montagem da interface inteira para aparecer.
- Uma folha crítica pequena apresenta o hall; 33 folhas de interface foram agrupadas em um arquivo carregado sem bloquear essa apresentação inicial.
- As fontes decorativas ficam para depois das boas-vindas. A entrada usa fontes do aparelho e mantém a hierarquia visual.
- Miniaturas de 128 cartas para o hall e o leque inicial; ao ampliar uma carta selecionada, a versão maior continua disponível.
- Pacotinho convertido de 2.517.668 bytes para 165,646 bytes.
- Cartas especiais antigas, cenários, banners, símbolos e atlas de chibis receberam versões WebP leves. No conjunto convertido, 161,125,651 bytes de origem correspondem a 15,636,470 bytes nas versões leves. Esse é o conjunto de arquivos preparados, não uma medição do download de uma visita.
- Originais preservados no pacote. O jogo direciona a exibição para as versões otimizadas.
- Banners abaixo da dobra são solicitados ao se aproximarem da área visível; o vídeo continua dependendo da interação do visitante.
- Abertura do pacotinho sem esperar o download simultâneo das 14 cartas grandes.
- Coleção e propriedade de itens continuam sendo confirmadas no servidor. Loja completa, guildas, amigos e estatísticas deixam de bloquear as boas-vindas.
- Cache e sessão de autenticação preservados; não é necessário limpar todo o navegador.

## Classificação na loja

Para **Cartas** e **Ícones**:

- Busca por nome, personagem e habilidade.
- Facção e tipo/classe correspondente.
- Todos, já possui ou ainda não possui.
- Menor preço, maior preço e ordem alfabética; cartas também por poder base.
- Quantidade de resultados e categoria identificada em cada item.
- Filtros lembrados por conta neste navegador.

A classificação usa os dados reais do catálogo. Não foi criada uma raridade artificial para as cartas.

## X1 na Personalizada

A Arena apresenta Guardião, Normal, Ranqueada e Personalizada. Para X1, crie uma sala personalizada e convide um adversário para o outro lado. Um jogador de cada lado forma 1 × 1; dois de cada lado formam 2 × 2.

O desafio enviado pela lista de amigos cria ou usa uma sala personalizada. Códigos antigos de X1 continuam disponíveis em **Recebi um código X1 da versão anterior**, para aceitar convites pendentes. O modo histórico `friend` foi preservado no banco para manter partidas e relatórios existentes.

## Deck automático / sugerido

Clique em **Sugerir deck** nos Baralhos ou no construtor. Escolha tamanho, preferência de facção e estilo: equilibrado, sinergias ou controle.

O algoritmo usa somente cartas possuídas e disponíveis; considera poder base, proporção de unidades, efeitos de resposta/compra, sinergias reconhecidas e portadores dos equipamentos. A facção é uma preferência e permite complementos de outras facções. Se houver menos cópias que o tamanho solicitado, usa a quantidade disponível, mantendo o mínimo de 14.

A sugestão aparece para avaliação. **Usar no construtor** substitui a montagem em edição e permite desfazer. Não salva automaticamente nem compra cartas. Salve após revisar. O algoritmo é uma heurística de montagem; não prevê uma taxa de vitória.

## Recarregar e reabrir o navegador

- A sessão autenticada do Supabase continua sendo necessária. Se for preciso fazer login novamente, a retomada acontece após o acesso à mesma conta.
- O servidor localiza somente partidas em que o jogador é participante. A mesa, mão privada, efeitos pendentes, Round e pontuação vêm da leitura oficial já usada pelo jogo.
- A partida ativa tem prioridade. Um resultado já concluído pode voltar ao relatório, quando essa era a tela anterior.
- A sala personalizada é reassociada à partida para o botão de retorno do relatório.
- O Guardião mantém sua recuperação local por conta; os dados ficam neste navegador. O laboratório de testes livre não é tratado como partida competitiva persistente.
- A última tela, posição de rolagem, baralho selecionado e filtros da loja são lembrados por conta. Modais de senha e dados privados não são gravados para restauração.
- A fila solo ainda válida é reassociada à assinatura de atualizações e conserva o horário de entrada. Filas expiradas não são recriadas silenciosamente.
- Nenhum relógio é pausado ou reiniciado ao sair: a partida pode terminar durante a ausência. Sessões abandonadas continuam sujeitas às regras existentes do servidor.
- O histórico local de navegação expira após 30 dias; não substitui a autorização do servidor.

## Manutenção

`_manutencao/gerar-interface.cjs` agrupa as folhas listadas em `interface-fontes.json`, separa as fontes e prepara o hall no HTML. O comando de publicação da Vercel já o executa antes de montar a pasta pública. Os CSS originais continuam separados para edição. Ao adicionar uma folha, inclua-a na lista. Edite o conteúdo base do hall em `portal-upgrade.js`; o HTML inicial é recomposto a partir dele.

`entry-media.js` contém os caminhos das versões leves. `security.js` mantém a validação das URLs e só aplica as substituições a arquivos conhecidos do próprio site. `session-resume.js` guarda identificadores e navegação; não salva nem reenvia o estado de uma partida online.
