# Mythic Clash — melhorias de experiência (2026.10.23.7 / SQL 068)

## Instalação
1. Faça uma cópia do projeto que está publicado.
2. Se ainda faltam, aplique os SQLs 065 revisado, 066 e 067, nessa ordem. O 067 corrige as views apontadas pelo Security Advisor.
3. Aplique `supabase/migrations/202610230068_experience_improvements.sql` no SQL Editor do Supabase.
4. Substitua os arquivos do projeto pelos arquivos desta atualização e publique pelo fluxo habitual.

O SQL 068 deve entrar antes da publicação: a versão nova usa as funções de ação/snapshot, detalhes dos modos e abertura completa de pacotes. O ZIP inclui também os arquivos das atualizações anteriores do criador e da administração.

## Atlas
- Categorias de cabelo, roupa, calça e botas adaptadas para celular.
- Alternância corpo inteiro/retrato, botões maiores e rodapé de salvamento com margem da área segura do aparelho.
- A prévia continua na própria coluna, sem acompanhar a rolagem.
- Aviso de alterações não salvas e diálogo de salvar/descartar/continuar ao sair.
- Rascunho local por conta, recuperável por até 30 dias. Se a aparência salva mudou, o usuário recebe um aviso antes de recuperar o rascunho; a revisão do banco continua impedindo sobrescrita concorrente.
- Desfazer/refazer, restauração da aparência salva e sorteio de combinação existente.
- Filtro para mostrar somente combinações imediatamente compatíveis.
- Opções que exigem outra peça mostram uma proposta com prévia e lista de alterações; só são aplicadas após a escolha do jogador.
- A ficha só é considerada salva após a confirmação do serviço da conta. Falhas preservam o rascunho.

## Partidas
- Ação e snapshot filtrado na mesma chamada ao servidor, usando a validação e a proteção contra repetição já existentes. A nova função nunca retorna o estado bruto com cartas privadas.
- Feedback imediato de confirmação da jogada e bloqueio de cliques duplicados.
- Pré-carregamento e cache de imagens de cartas/hologramas.
- Preservação do HTML de campos, mãos, zonas, estrelas e pilhas quando não mudou, reduzindo reconstruções da mesa.
- Sequência visual: voo da carta, apresentação, entrada do holograma, transformação quando houver e efeito no alvo. A próxima etapa espera a anterior terminar.
- Recursos que falham têm apresentação simplificada; uma falha visual libera a sequência e não mantém as cartas ocultas.
- Posições dos alvos são atualizadas antes do impacto; alvos destruídos usam a posição capturada antes de sair da mesa.
- Escolha de habilidade com origem, localização do alvo, seleção para conferir e botão de confirmação. Não inclui desistência.
- Mantidos os intervalos do bot: 2 segundos para a jogada e 1 segundo para uma escolha. O agendamento respeita a sequência visual.
- Configuração de apresentação completa ou reduzida, respeitando também a preferência de movimento reduzido do aparelho.
- Aba administrativa Desempenho com medições locais separadas de servidor/sincronização, renderização e sequência visual. Não armazena mãos privadas e limpa os registros ao sair da conta.

Os ganhos de tempo ainda não foram medidos em partidas reais nesta tarefa. As medições foram implementadas para observar o comportamento depois da publicação.

## Administração
- Modos com estados Ativo/Desativado, motivo público, confirmação do alcance da alteração e histórico por administrador/data.
- Cancelamento de filas conforme o comportamento do SQL 066; partidas iniciadas e resultados permanecem preservados.
- Estado visual só muda após confirmação do banco. Em caso de falha, a disponibilidade anterior permanece.
- Motivos de manutenção aparecem na Arena e no aviso de tentativa de acesso.
- Contabilidade permanece em aba própria, separada da loja e dos demais recursos.

## Criador de cartas
- Cinco etapas: Modelo, Ilustração, Textos, Cores e Exportação.
- Personagens têm poder; modelos especiais, campos e equipamentos não recebem esse atributo no desenho.
- Arraste direto da ilustração, zoom, posição horizontal/vertical e centralização.
- Avisos de resolução útil baixa e textos extensos, mantendo a prévia como origem do PNG de 1500 × 2100.
- Histórico de até 25 estados, desfazer/refazer e duplicação de projeto.
- Rascunhos nomeados, recuperação automática por conta neste navegador e importação/exportação do projeto com a imagem incorporada.
- Referência de habilidade existente no projeto visual. Isso copia os textos e registra a referência; não publica regras novas no motor de partidas.

## Pacotes
- Clique/toque direto para romper o selo; o botão de abrir também continua disponível.
- Abertura sem painel cinza, mantendo o desfoque da loja.
- Preparação das imagens com progresso antes da abertura e opção de apresentação reduzida.
- Cartas reveladas uma a uma, contador de posição e botão Revelar todas.
- Resumo final com todas as cartas e uma cópia de cada.
- Compras novas registram no servidor quais cartas já existiam antes da entrega. Compras anteriores não recebem classificação inventada de nova/repetida; simulações são identificadas como tal.
- A compra entrega as cartas uma vez na mesma transação do débito. As funções de revelação só alteram o progresso visual, inclusive Revelar todas; não entregam nem cobram novamente.
- Fechar ou perder a conexão preserva o pacote para continuar na loja. Uma resposta perdida pode ser repetida sem entrega duplicada.

## Estado e pendências
- Arquivos preparados e arquivos agrupados de publicação gerados localmente.
- SQL não executado no banco publicado; site não publicado nesta tarefa.
- Testes automatizados, testes de navegador e partidas não foram executados.
- Remoção do fundo das artes de corpo inteiro e novas aparências continuam pendentes, conforme a escolha de aguardar a ferramenta de imagens.
- Rascunhos são locais. Para levar projetos de carta a outro aparelho, exporte o JSON.
