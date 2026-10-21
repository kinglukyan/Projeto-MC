# Recompensas, torneios e entrada na Arena

## Publicar esta atualização

1. Após as migrações anteriores, execute no editor SQL do Supabase o arquivo completo `supabase/migrations/202610210049_rewards_and_tournament_hub.sql`.
2. Envie os arquivos atualizados desta pasta ao repositório GitHub conectado à Vercel.

As operações novas dependem da migração 049. O ZIP contém o código-fonte, o SQL e a arte do emblema. A pasta e o mesmo `Mythic-Clash-Completo.zip` foram atualizados.

## Entrada na conta

- Fazer login novamente abre sempre a Arena, conforme a orientação final.
- Atualizar a página com a sessão ainda conectada continua recuperando a tela anterior, com a proteção contra o flash do hall.
- Uma partida encerrada não é transformada em uma partida ativa durante a retomada.

## Criar e resgatar recompensas

Em Administração → Recompensas, escolha um produto ou um pacote. Pesquise por nome e selecione as imagens de cartas, ícones ou aparências; também é possível incluir Mythic Coins. Não é necessário digitar IDs de produtos.

Escolha a quantidade, use **Adicionar ao presente** e confira a lista visual. No modo pacote, até 30 produtos diferentes podem compartilhar um único código. Ícones e aparências têm quantidade 1; cartas podem ter até 100 cópias e moedas, até 100.000 por produto. Defina o código de compartilhamento, o limite total de resgates e a validade opcional. Cada conta pode recebê-lo uma única vez.

Na loja, o resgate abre uma janela com os produtos que o servidor confirmou. As cartas recebem cópias utilizáveis, os ícones e aparências são registrados no inventário e as moedas entram no saldo. O perfil e a coleção são recarregados após a entrega. Se o mesmo pedido for repetido, o servidor devolve o comprovante sem conceder os itens novamente. Ícones já possuídos são identificados na janela e não geram compensação extra.

Os códigos anteriores continuam sendo interpretados. Configurações antigas com produtos inexistentes são identificadas no painel para que o administrador as desative e recrie. Os códigos novos são criados por uma função administrativa no servidor, respeitando as permissões que bloqueiam a escrita direta nas tabelas.

O código e seus itens são entregues em uma única transação: uma falha não deve consumir o código deixando um pacote incompleto. Os registros de auditoria usam uma identificação derivada do código, sem expor seu texto nos eventos.

## Torneios

O cartão **Torneio** fica entre Jogo normal e Ranqueada, com um emblema próprio e aura. Ele aparece somente quando existe competição publicada, em inscrição ou em andamento, dentro do período de disponibilidade. Quando não há competição disponível, o cartão some e os quatro modos restantes dividem o espaço igualmente. No celular, a grade usa duas colunas e acomoda o quinto modo quando necessário.

Em Administração → Torneios, a criação inclui nome, apresentação, formato, limite de 2 a 128 jogadores, início, fim opcional e opção de publicar ou guardar como rascunho. A prévia mostra como o evento será apresentado. Torneios em inscrição podem ser editados. Há controles para publicar, ocultar e cancelar; o cancelamento exige que as partidas em andamento terminem primeiro.

As inscrições encerram no horário de início e respeitam o limite de vagas. O organizador pode iniciar a chave após esse horário, com pelo menos dois inscritos. A tela da competição apresenta nomes dos jogadores, rodadas, inscrição e botões para iniciar ou retomar os próprios duelos. O funcionamento existente dos formatos mata-mata e suíço foi mantido. Gerar e avançar a chave continua sendo ação do organizador.

A consulta é atualizada ao entrar na Arena, no painel de torneios e periodicamente enquanto essas telas estão visíveis. Os controles administrativos também atualizam a disponibilidade após salvar. Ocultar ou encerrar um evento impede a abertura de novos duelos desse evento no servidor.

## Arquivos de manutenção

- `rewards-tournaments.js` e `.css`: seleção de produtos, comprovante, torneios e administração.
- `assets/mode-tournament.webp`: emblema com fundo transparente, criado com o gerador integrado de imagens.
- `_manutencao/rewards-tournaments/prompt-icone.json`: prompt e identificação da arte.
- `session-resume.js`, `portal-upgrade.js` e `online.js`: separação entre novo login e atualização da página.

Foi feita revisão do código e checagem de sintaxe JavaScript. Não foram executados testes de navegador, resgates ou torneios, nem aplicada a migração no banco remoto ou publicada a atualização nesta sessão.
