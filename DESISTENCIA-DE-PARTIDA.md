# Desistir da partida

O botão “Sair do duelo” foi substituído por **Desistir** nas partidas normal, ranqueada, personalizada e contra o Guardião, incluindo a campanha. Ele abre uma confirmação com “Continuar jogando” e “Sim, desistir”. Durante uma escolha de habilidade, há também acesso à confirmação pelo próprio diálogo de escolha.

Confirmar encerra a partida: derrota para quem desistiu e vitória para o adversário. No 2×2, a derrota vale para a dupla de quem confirmou. A confirmação informa isso antes de enviar a solicitação.

Depois aparecem o resultado e o relatório, com a indicação de encerramento por desistência. Os pontos e Rounds realmente registrados são preservados; não são inventadas vitórias em Rounds para justificar o resultado. O relatório de uma partida online registra também os pontos do Round interrompido, identificando-o como “Em campo”.

No laboratório de baralhos, o botão continua sendo “Encerrar teste”, com confirmação e resumo do teste, pois não é uma partida competitiva. Quando a partida já acabou, o botão passa a ser “Ver resumo”.

## Ativação

1. Aplique a migração `supabase/migrations/202610200046_match_surrender.sql` após a 045.
2. Publique os arquivos atualizados no repositório conectado à Vercel.

O servidor verifica se a conta participa da partida. A desistência funciona mesmo fora do turno do jogador e é serializada com as jogadas: uma partida já concluída não tem seu vencedor alterado. O encerramento usa os mecanismos existentes de histórico, recompensas e rank. Solicitações repetidas não repetem essas premiações.

Uma falha de comunicação não simula uma derrota local em uma partida online: a interface permite tentar confirmar novamente. Cancelar a confirmação não envia uma solicitação de desistência.

Os arquivos foram preparados localmente e a sintaxe dos scripts alterados foi conferida. Não foram executadas partidas de teste, aplicada a migração no Supabase ou feita publicação na Vercel nesta sessão.
