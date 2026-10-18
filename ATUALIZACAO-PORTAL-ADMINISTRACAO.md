# Portal, Alyn e administração — 18/10/2026

## Instalar

1. O banco deve estar atualizado até o SQL 026.
2. Executar `supabase/migrations/202610180027_alyn_starter_pack.sql`.
3. Executar `supabase/migrations/202610180028_admin_portal_controls.sql`.
4. Publicar o conteúdo do ZIP completo atualizado. Não publicar apenas a interface antes dos dois SQLs.

As migrações são transacionais. Nenhuma publicação nem alteração no Supabase remoto foi realizada nesta entrega.

## Boas-vindas

- Símbolos oficiais das facções substituem os personagens na escolha: Grécia, Nórdicos, Egípcios e Reino de Alyn.
- O ícone inicial continua sorteado na facção escolhida; o outro vem de outra das quatro facções disponíveis.
- Grécia, Nórdicos e Egípcios mantêm a preferência por seis unidades, um Local e um Terreno próprios quando disponíveis.
- Alyn possui hoje apenas Lukyan e Butter como unidades iniciais. O pacote inclui ambos e completa dez unidades e quatro cartas não-unidade com o catálogo disponível. Não cria personagens, Locais ou Terrenos que ainda não existem. As 14 cartas são distintas.
- Pacotes já entregues não mudam, não são repetidos e não recebem um novo sorteio.
- A ampliação agora é um segundo leque. Clique nos vizinhos, arraste para os lados, use as setas do teclado ou os botões Anterior/Próxima. Os limites respeitam a primeira e a última carta.

## Entrada e modos

- A página pública apresenta o jogo antes do login. Visitantes têm Login e Criar conta; quem está conectado vê JOGAR. Sair da conta retorna a essa página.
- Dois cliques em um modo abrem sua página. A configuração de filas e a exigência de liberar o PvP continuam ativas.
- Guardião possui uma página própria de treinamento e missões. As missões exibidas vêm do banco e usam progresso/recompensas reais; novas missões podem ser incluídas na tabela `missions`, com `mode='guardian'`.
- O cabeçalho passa a ter pelo menos 84 px de altura, com respiro vertical para os textos e controles.
- As três cartas decorativas da página pública usam prévias WebP leves; as artes originais continuam disponíveis na coleção e ampliação. Nenhum cache global de imagens é apagado.

## Administração

### Usuários

Busca por apelido, e-mail ou UUID e paginação de 50 resultados, cobrindo todas as contas. Suspensão por duração, remoção da suspensão e exclusão com confirmação do apelido exato. Contas administrativas e a própria conta administrativa não podem ser removidas ou suspensas por esses controles.

A suspensão é verificada no servidor, incluindo RPCs e políticas restritivas de acesso aos dados, além de bloquear novos logins e revogar sessões. Tokens previamente emitidos não liberam ações de jogo de uma conta suspensa. A interface consulta o acesso a cada minuto enquanto está visível.

Excluir uma conta remove seu usuário de autenticação, perfil, inventário e dados dependentes. Partidas em que participou e seus replays/timelines dependentes são removidos; referências opcionais antigas são limpas. Os registros financeiros legados que exigem a referência ao perfil também são removidos. A operação é uma transação: uma falha desfaz a exclusão inteira. O registro administrativo mantém UUID e apelido da conta excluída para auditoria.

As operações ficam registradas na tabela privada `admin_operation_log`. Chaves privilegiadas não são enviadas ao navegador.

### Telemetria

- Contas e cadastros nos últimos 7/30 dias.
- Tutorial concluído, contas suspensas e jogadores com partidas registradas nos últimos 30 dias.
- Idades por faixa, usando a idade declarada no perfil. Dados ausentes aparecem como Não informado.
- Mitologia preferida e uso efetivo de facções, a partir de cartas jogadas online.
- Modos de partidas, cartas mais usadas e etapas das boas-vindas.

As partidas online são contadas na tabela de partidas, evitando contar uma vez por participante. Partidas do Guardião são as registradas pelo servidor. A telemetria não preenche números ausentes com estimativas. A nota de cadastro informa o uso agregado da idade.

### Pausar cartas

A pausa é independente da propriedade: não apaga cartas, compras ou cópias. Impede novas jogadas, novas invocações, uso em novos baralhos, compra e sorteio do pacote inicial. A coleção informa a pausa e o construtor permite retirar a carta dos baralhos existentes. Reativar restaura seu uso.

Cartas já em campo continuam seus efeitos até saírem normalmente. Uma habilidade não invoca uma carta pausada. A validação online é imediata no servidor; a lista da interface e do treino local é atualizada ao entrar, ao retornar à janela e a cada minuto de uso visível.

## Universo

O desenho atual, banners e organização foram preservados. Passar o mouse, focar pelo teclado ou tocar um personagem apresenta seu banner com facção, nome e habilidade. Clicar abre a história. A trilha configurada para o personagem começa ao abrir, respeitando o volume e a opção de música, e pausa a música do menu. Quando não houver trilha cadastrada, nenhuma trilha é inventada.

A área História em quadrinhos sempre aparece ao abrir a história. Uma HQ cadastrada pode ser aberta; sem arquivo, o espaço informa que o conteúdo chegará em breve. Trilhas e HQs continuam sendo cadastradas na administração existente.

## Revisão desta entrega

- Sintaxe dos JavaScripts revisada.
- DDL e corpos das funções compilados em PostgreSQL temporário (PGlite), com esquema auxiliar; isso não substitui homologação no Supabase do projeto.
- Prévia visual local com respostas de autenticação e dados administrativos fictícios em 1366 × 900 e 390 × 844. As capturas ficam em `outputs/portal-update`, fora do pacote do jogo.
- Nenhuma conta real foi excluída ou suspensa. Nenhum teste automatizado de operações administrativas foi executado.
- Migrações futuras que criarem novas RPCs privilegiadas devem chamar `_assert_account_active()` para manter a restrição de contas.
