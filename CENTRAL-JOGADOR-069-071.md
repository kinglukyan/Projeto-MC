# Central do jogador e operações — atualização 069–071

Versão: 2026.10.23.8.

## Aplicação

Este pacote atualiza o projeto existente. Não é um projeto novo nem substitui o banco.

1. Com a atualização 068 já aplicada, executar no Supabase, nesta ordem:
   - `202610230069_player_services.sql`
   - `202610230070_social_tools.sql`
   - `202610230071_operations_and_recovery.sql`
2. Copiar os arquivos de `Projeto MC` sobre a mesma pasta do projeto.
3. Publicar a versão atualizada pelo processo habitual.

Se 065–068 ainda não foram aplicadas, seguir antes a ordem em `_manutencao/ORDEM-DAS-MIGRACOES.txt`. A 065 presente neste projeto é a versão revisada do criador do Atlas, não a atualização antiga rejeitada.

As migrações usam transação. Não reaplicar uma migração que já concluiu. Este trabalho não executou SQL no projeto online nem publicou o site.

## Onde encontrar

A Central do jogador está em Configurações e no Perfil. Coleção, Baralhos, Guilda, Comunidade, Loja e Relatório têm atalhos próprios.

### Conta, conexão e atendimento

- Aviso de perda de conexão; jogada pendente conservada na aba e vinculada à conta.
- Consulta da identificação da jogada antes de liberar nova tentativa. O servidor continua validando turno, alvo e regras. Nunca há reenvio automático após reconectar.
- Recuperação tanto em PvP quanto no Atlas. A restauração não substitui uma partida diferente que esteja aberta.
- Histórico paginado de Mythic Coins e Trixx Coins, com entradas, gastos, datas, identificação e saldo após a operação quando disponível.
- Central de novidades, balanceamento, problemas conhecidos e eventos. A visita registra as revisões vistas; mudanças posteriores voltam a aparecer como novas.
- Chamados com identificação da partida, mensagens, andamento e captura enviada pelo jogador. Capturas ficam em bucket privado e só o dono e administradores podem acessá-las.
- Acessibilidade: texto maior, contraste, símbolos e opção de desabilitar arraste. A carta ampliada permite escolher explicitamente uma das três fileiras por botão.
- Termos Fileira, Aura e Submundo tocáveis na descrição ampliada da carta; glossário com exemplos.

### Cartas e decks

- Comparação lado a lado: poder, habilidade, mitologia, tipo e função reconhecida.
- Assistente reutiliza o avaliador existente, explica requisitos inválidos, cópias faltantes, curva de poder e sugestões de combinação.
- Checklist de compra, proteção, recuperação, destruição e aumento de poder.
- Lista de desejos e indicação de ofertas ativas encontradas.
- Coleção por mitologia, progresso por cartas diferentes e fontes de aquisição conhecidas.
- Versões de baralho com comparação de composição e resultados da mesma composição. As partidas podem ser anteriores à data de salvamento da versão.
- Laboratório de candidatos separado do baralho utilizado nas partidas. Aplicar uma proposta continua passando pelas validações de propriedade e quantidade do editor normal.

### Comunidade e guildas

- Mural com estratégia, aviso e referência a deck da comunidade. Publicações próprias podem ser excluídas; líderes e oficiais também podem moderar e fixar.
- Calendário com início, término e confirmações Vou/Talvez/Não vou. Líderes e oficiais organizam os encontros.
- Convite de treino para outro membro: sala personalizada 1×1, sem classificação, usando as regras e recompensas normais da personalizada e seus bônus aplicáveis.
- Comentários em decks, exclusão do próprio comentário e denúncias com fila administrativa de moderação.
- Código de 20 caracteres para compartilhar partidas encerradas: resumo, cartas jogadas, sequência pública de ações e efeitos públicos. Não compartilha mãos, baralhos privados nem decisões ocultas.
- Relatório pesquisável de efeitos; eventos novos com fonte pública registrada indicam a origem da habilidade e a alteração de poder observada. Registros antigos não recebem uma origem inventada.

### Loja e aparências

- Pacote presente: consultar o código de amigo, conferir o nome e confirmar o preço antes de pagar. Débito do remetente e entrega ao destinatário ocorrem juntos no servidor.
- A mesma identificação de compra evita dupla cobrança em nova tentativa. O pacote para abrir fica na loja do destinatário.
- Teste administrativo de presente sem débito, entrega ou contabilização, respeitando a configuração já existente da loja.
- Distinção de item não possuído, já possuído, quantidade de cópias e equipado.
- Conjuntos salvos de ícone, título, medalhas, moldura, campo e mão; aplicação valida os itens e acontece em uma transação.
- Molduras simples dourada, prateada, violeta e sem moldura, usando o sistema visual existente. Nenhuma imagem nova foi gerada.

### Administração

Abas independentes:

- Visão do jogador: consulta por nickname/código, saldos, movimentações, compras/recompensas registradas, partidas e chamados. Cada consulta detalhada deixa registro de acesso.
- Atendimento: respostas e situações dos chamados.
- Moderação: denúncias de comentários, ocultar ou manter.
- Agendamento: comunicados, eventos, itens, pacotes e modos com início e término. A janela é verificada no servidor ao listar, comprar e iniciar modos, sem depender de um computador aberto ou de cron.
- Saúde do jogo: falhas de recursos, ações, desconexões, média e percentil 95 de tempo de resposta, em amostras das últimas 24 horas. Nenhuma carta privada é enviada na telemetria.

## Limites dos registros

- O histórico detalhado de saldo passa a existir ao aplicar 069. Movimentações anteriores são mostradas a partir da contabilidade que já existia; não há reconstrução de saldos antigos inexistentes.
- O relatório só atribui origem quando ela foi registrada publicamente pela resolução da habilidade. Dados antigos não permitem reconstruir toda a causalidade.
- Fontes de cartas consideram ofertas ativas e pacotes disponíveis. Prêmios aleatórios do Atlas não garantem uma carta específica.
- Treino de guilda utiliza a personalizada existente, incluindo suas recompensas; não é uma simulação sem recompensas.
- Agendar um evento publica seu comunicado no período escolhido. Regras especiais de torneio continuam no sistema de torneios existente.
- O motor de pagamento por dinheiro real continua pendente de escolha, conforme a decisão anterior.

## Compilação

A interface e o pacote JavaScript foram compilados. O agrupamento agora compila a sintaxe das fontes antes de produzir a versão. Não foram executados testes de navegação, partidas ou integração com o Supabase.
