# Entrada e retomada de partidas

## Boas-vindas aparecendo em contas antigas

A janela das boas-vindas era aberta com “Consultando sua jornada…” antes de o servidor informar se a conta já tinha terminado essa etapa. Agora a consulta ocorre sem abrir a janela. A apresentação aparece apenas quando o servidor confirma que falta escolher a mitologia ou abrir/concluir o pacote inicial.

As chamadas simultâneas usam a mesma consulta pendente. Uma falha nessa consulta exibe uma mensagem para tentar entrar novamente, sem tratar a conta como recém-criada. A entrega do pacote e o registro de conclusão continuam sendo controlados pelo servidor.

## Derrota ou resumo reaparecendo

Foram ajustados os caminhos que podiam reabrir uma partida concluída:

- A retomada no servidor retorna apenas partidas em andamento.
- A consulta inicial do navegador envia uma indicação nula para não buscar uma partida concluída nem em instalações que ainda usam a versão anterior dessa consulta.
- O carregador de partidas verifica o estado recebido antes de abrir a mesa. Referências antigas vindas da fila ou do lobby não reabrem uma batalha encerrada.
- Atualizações de uma partida já aberta continuam podendo mostrar seu resultado ao terminar. Uma notificação tardia não cria outra mesa para uma partida encerrada.
- Desafios concluídos da campanha não são retomados como partidas atuais.
- O snapshot temporário de um treinamento local é descartado quando ele termina. Snapshots antigos marcados como encerrados são removidos ao serem consultados.
- A retomada de um treinamento local acontece depois da busca por uma partida online/campanha, para evitar duas restaurações disputando a tela.
- O navegador deixa de salvar o pós-partida como tela de retorno. Ao recarregar depois de uma partida encerrada, a entrada segue para uma tela normal.
- A navegação automática do resultado para o resumo verifica se o jogador ainda está na mesa. Voltar ao hall ou sair da tela de uma partida concluída cancela esse retorno tardio.
- Ao clicar em Jogar, uma partida ainda em andamento pode ser retomada; um resultado concluído é descartado como estado atual.

O relatório continua aparecendo depois de uma partida que acaba enquanto o jogador está na mesa. O histórico, placares, vitórias, derrotas e recompensas já gravados permanecem no servidor.

## Publicar

1. Execute `supabase/migrations/202610210048_resume_active_matches_only.sql` no Supabase, após a 047.
2. Atualize no GitHub conectado à Vercel os arquivos desta entrega, incluindo os scripts e o HTML com suas versões de cache atualizadas.

Não é necessário remover manualmente dados do navegador. A limpeza dos snapshots encerrados é feita na leitura, dentro da conta correspondente.

## Conferência desta entrega

Os arquivos foram preparados localmente e a sintaxe dos scripts alterados foi conferida. Não foram executados testes de navegador ou partidas nesta sessão. A migração não foi aplicada no Supabase remoto e não houve publicação na Vercel.
