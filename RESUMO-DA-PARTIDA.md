# Resumo depois da partida

## Experiência

Após a animação de vitória ou derrota, o jogo abre uma tela de relatório. O jogador permanece nela até pressionar **Voltar à sala**. O desempate mostra seu resultado e oferece **Ver resumo da partida**, seguindo para a mesma tela.

O relatório inclui:

- Modo, formato, participantes e resultado final.
- Duração, início, fim e identificador da partida.
- Vitórias em Rounds e pontos de cada Round, apresentados separadamente.
- Quantidade e relação das cartas jogadas por cada participante, inclusive em 2 × 2.
- Ações registradas e recompensas de XP/moedas quando confirmadas pelo servidor.
- Informação de desempate quando houve puxadas ou Eclipse.

Cartas geradas por habilidades não contam como novas jogadas da mão. O relatório não mostra mãos, compras ou baralhos ocultos. A quantidade de ações inclui jogadas, passes e decisões; não equivale à quantidade de turnos.

## Modos e retorno

- Normal/ranqueada: sala do mesmo modo. As duplas podem voltar juntas; a próxima fila aguarda ambos saírem do relatório.
- Personalizada: volta à sala original com suas vagas. O servidor impede outra partida enquanto alguém ainda lê o relatório.
- Desafio direto: sala de desafios.
- Guardião/tutorial: tela do Guardião.
- Teste de baralho: ao encerrar o teste, mostra o relatório da sessão sem vitória, derrota ou recompensas; retorna aos baralhos.

O relatório está ligado ao fluxo compartilhado dos duelos online, incluindo partidas iniciadas por competições. Ele não altera critérios de vitória nem soma pontos entre Rounds.

## Registro online

Aplicar **202610190039_match_report.sql**, depois da **038**, seguindo `_manutencao/ORDEM-DAS-MIGRACOES.txt`, e publicar o cliente atualizado.

O servidor registra ações aceitas dentro da transação de `submit_game_action`, preservando limites de solicitações, validação, auditoria e idempotência da 037. Reenvios de uma mesma solicitação não duplicam cartas no relatório. Ações rejeitadas não entram no registro. A tabela é privada; somente participantes autenticados e com conta ativa podem solicitar o relatório final pela operação própria.

Partidas iniciadas antes da migração têm cobertura parcial e são identificadas na tela. Não há reconstrução fictícia de cartas já jogadas. Guardião/teste acompanham estatísticas localmente; sessões antigas sem início registrado mostram duração indisponível.

## Entrega

Código, SQL e pacote locais atualizados. A migração não foi executada no Supabase e não houve publicação no site online. A apresentação foi renderizada com dados ilustrativos no desktop e no celular; partidas reais e operações do banco não foram executadas nesta entrega.
