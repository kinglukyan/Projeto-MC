# Convite bloqueado por fila ou partida antiga

## Causa encontrada no código

A migração 035 recusava convites se qualquer participante tivesse qualquer registro de partida com `status=active`. Sair da tela somente limpava o estado local; não havia heartbeat de sessão de partida nem expiração de filas solo abandonadas. Assim, registros antigos podiam impedir convites. A captura de tela não permite determinar qual registro existe no banco real.

## Correção 036

- O cliente confirma sua sessão de partida/fila a cada 20 segundos enquanto ela está ativa.
- Antes de um convite, o servidor limpa filas solo sem confirmação há mais de 90 segundos. Filas recém-criadas e confirmadas são preservadas.
- Partidas sem ação **nem heartbeat de qualquer participante** há mais de 15 minutos são marcadas `abandoned`. O histórico não é apagado; não há concessão de vitória, derrota, estrelas ou moedas por essa limpeza. Partidas recebendo uma ação ou heartbeat não são encerradas pela rotina.
- A mensagem distingue se a própria conta ou o amigo está em fila ou partida.
- Se a própria conta estiver numa fila real, aparece **Sair da fila**. Se houver uma partida em andamento, aparece **Retomar partida**. O convite pode ser enviado novamente depois de resolver o bloqueio.
- A conta não pode cancelar uma fila real nem encerrar uma partida recente do amigo. A verificação permanece no servidor.

## Aplicar

Aplicar `supabase/migrations/202610190036_invite_session_recovery.sql` após a 035 e publicar os arquivos atualizados do site. O servidor e o cliente devem ser atualizados juntos, para habilitar o heartbeat e as novas mensagens.

A atualização foi preparada localmente. Não houve acesso à sessão das contas da captura, aplicação de SQL no Supabase ou publicação do site nesta entrega. A sintaxe dos scripts JavaScript alterados foi conferida; não foram executadas partidas reais.
