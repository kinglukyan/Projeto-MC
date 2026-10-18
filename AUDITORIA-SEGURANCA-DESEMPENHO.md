# Auditoria do Mythic Clash — 17/10/2026

## Entrega e alcance

Revisão dos arquivos locais do projeto: interface, scripts, cache, imagens, configurações, documentação e histórico SQL. O inventário detalhado, com um registro por arquivo, acompanha a entrega em `revisao-arquivo-a-arquivo.csv` e JSON na pasta externa de auditoria.

As correções estão nos arquivos locais e na nova migração `supabase/migrations/202610170018_audit_hardening.sql`. Não foram publicadas nem executadas no banco remoto. A revisão estática não comprova ausência de vulnerabilidades nem substitui validação funcional e de permissões em um banco de homologação.

Não foram executados testes de navegador, partidas reais, pagamentos, testes de carga ou SQL no PostgreSQL. A configuração real da hospedagem, do projeto Supabase, de backups e da autenticação não foi inspecionada remotamente.

## Correções realizadas

| Prioridade | Problema identificado no código | Correção preparada | Limite / atenção |
| --- | --- | --- | --- |
| Crítica | O estado completo da partida podia revelar mãos e ordem dos baralhos pela API, respostas de ações e Realtime. Ocultar na interface não protege esses dados. | Respostas filtradas por participante; baralhos mascarados; somente a consulta autorizada de Odin revela a primeira carta. Revogação da leitura direta das colunas privadas e dos auxiliares internos. Realtime passa a publicar um sinal sem cartas. | Requer SQL 018 e atualização dos clientes; validar 1v1, 2v2 e Odin em homologação. |
| Alta | Replays recebiam eventos enviados pelo cliente e snapshots podiam carregar informações privadas. | Replay passa a usar o histórico do servidor; mãos e baralhos são mascarados para espectadores e replays. Versões antigas dos eventos são arquivadas em tabela privada antes da limpeza. | A retenção do histórico e dos arquivos privados precisa de política operacional. |
| Alta | Rotinas internas com `security definer` e permissões padrão ampliavam a superfície da API. | Lista explícita de funções públicas do aplicativo; revogação dos auxiliares e das escritas diretas desnecessárias. As funções de serviço continuam separadas. | Novas migrações futuras também precisam declarar permissões. |
| Alta | Campos editáveis de preferências podiam influenciar o desbloqueio do PvP; cosméticos equipados tinham caminhos de escrita sem a mesma verificação da loja. | Desbloqueio usa campos confiáveis; equipamento é feito pela função que verifica propriedade. Removida a simulação de conclusão do tutorial após erro da API. | O cliente precisa receber o sucesso real do servidor. |
| Alta | Reconhecimento administrativo dependia do e-mail sem exigir confirmação. | Verificação da identidade no servidor e de e-mail confirmado; aplicação do mesmo critério à entrega automática de itens. | Antes de aplicar, confirmar que o e-mail da conta administrativa está verificado. Recomenda-se migrar depois para cargos associados a UUID. |
| Alta | Presentes de cartas e expedições operavam no deck, podendo produzir inconsistências com a quantidade realmente possuída. | Operações transacionais na coleção; bloqueio de perfil/cópias; não enviar ou reservar cópias comprometidas nos decks; resgate concede/restaura a cópia corretamente. | Exige uma cópia excedente e mantém uma na coleção. Expedições antigas são tratadas sem criar cópias novas indevidas. |
| Alta | Recompensas do Guardião podiam disputar a verificação do limite diário em chamadas paralelas. | Bloqueio por jogador antes da contagem; validação de valores nulos e idempotência. | O resultado do combate local ainda é informado pelo cliente. Isso não resolve integralmente trapaças; veja sugestões. |
| Média | Respostas assíncronas e dados locais de uma conta podiam aparecer após troca de usuário. | Guardas por usuário em perfil, inventário, amigos, chat, presentes, histórico e administração; limpeza de canais, temporizadores e telas privadas; partida/histórico local separados por usuário. | Registros locais antigos sem identificação de proprietário não são restaurados automaticamente. Histórico remoto e inventário não são apagados. |
| Média | Falhas ao enviar ações podiam deixar controles bloqueados; respostas repetidas provocavam trabalho desnecessário. | Liberação em `finally`, proteção contra resposta de partida anterior, consulta simultânea consolidada e comparação do snapshot antes de redesenhar. | Validação de interação em partidas continua necessária. |
| Média | Chat carregava as primeiras 100 mensagens em vez das últimas e podia duplicar mensagens. | Busca recente, ordenação para leitura, deduplicação e limite de 200 elementos na tela. | Sugere-se sincronização após reconexão para fechar a pequena janela entre busca e assinatura. |
| Média | Entradas remotas usadas em HTML e endereços de imagens tinham tratamento inconsistente. | Utilitário de escape/URLs, protocolos restritos, credenciais em URLs rejeitadas e conteúdo escapado nos pontos revisados. Limites de tamanho/formato no perfil no servidor. | Não foi implantada uma CSP completa de scripts nesta entrega. |
| Média | Função de expiração de turnos percorria partidas além das do solicitante. | Usuário só solicita processamento das próprias partidas; serviço continua podendo processar globalmente; lote limitado e bloqueios de concorrência. | O processo de serviço precisa continuar usando suas credenciais privadas. |
| Média | Desempate tinha lista e poderes antigos, excluindo personagens adicionados posteriormente. | Usa o catálogo de unidades atual e seus poderes base; cartas especiais não entram. | Mantido o critério histórico de vitória do desempate. |
| Média | Lista de partidas de amigos não abrangia corretamente os participantes; perfis da comunidade dependiam de leitura bloqueada por RLS. | Consulta de participantes corrigida e função limitada aos dados cosméticos públicos necessários. | Não expõe telefone, idade, preferências ou dados de autenticação. |
| Desempenho | PNGs de cartas e outros recursos tinham compressão muito baixa. | Recompressão sem perdas do fluxo IDAT, sem mudar dimensões, transparência ou pixels. | Não reduz o tamanho da imagem decodificada na memória; miniaturas ainda podem melhorar o mobile. |
| Desempenho | Votos geravam várias consultas por página; algumas consultas eram sequenciais ou sem limite. | Contagem agrupada de votos, consultas independentes em paralelo, limite de linhas de torneios e índices direcionados. | Não foi medido tempo real de rede ou plano de execução do banco. |
| Desempenho | Observação de mudanças reaplicava o mesmo tratamento dos ícones; cache podia acumular revisões antigas. | Ícones já tratados são ignorados; novas revisões de uma imagem removem somente versões antigas daquela imagem; manifestos inválidos são rejeitados. | Mantidos os caches e o fluxo de atualização existente. |
| Proteção HTTP | Faltavam restrições básicas de enquadramento, MIME e capacidades do navegador. | Cabeçalhos de segurança em `_headers`, preservando as regras de cache. | O provedor precisa interpretar `_headers`; em outros hosts, configurar os mesmos cabeçalhos. |

## Resultado mensurável nas imagens

- 127 PNGs analisados; 85 foram recomprimidos.
- Antes: **803.870.283 bytes** de PNGs.
- Depois: **312.065.451 bytes**.
- Economia: **491.804.832 bytes**, aproximadamente **61,18%** do volume dos PNGs.
- CRCs e fluxos descomprimidos foram conferidos; os dados de pixels antes/depois são iguais.
- Não houve redimensionamento, recorte, troca de arte ou conversão com perdas.

Esse resultado mede bytes dos arquivos de imagem, não uma promessa de redução de 61% no tempo total de carregamento ou no ZIP final. Imagens que já estavam em cache dependem da atualização do manifesto para receber a versão otimizada.

## Conferências realizadas

- Inventário de todos os arquivos e comparação de hashes antes/depois.
- Análise de sintaxe de todos os JavaScripts com Node, sem executar o aplicativo.
- Leitura dos JSONs e manifesto web; referências locais e IDs dos HTMLs; estrutura XML dos SVGs e blocos CSS.
- Verificação das imagens PNG e preservação do fluxo descomprimido.
- Revisão do caminho das chamadas RPC, concessões de acesso, RLS, dados privados, escrita direta, estado de sessão, concorrência e cache.
- Conferência lexical do SQL: strings, comentários e blocos delimitados. Isso **não compila nem executa** funções PL/pgSQL.
- Conferência de preservação das seções de barra lateral e combate e dos arquivos de apresentação protegidos pelo empacotador existente.
- Chave configurada no navegador identificada como `anon`; não foi encontrada chave `service_role` nesse arquivo. A chave pública não substitui RLS e permissões corretas.

As migrações históricas foram preservadas. Correções cumulativas estão no SQL 018, evitando alterar silenciosamente o histórico já aplicado.

## Aplicação da atualização

1. Fazer backup do banco e guardar o pacote anterior. A cópia local completa anterior à auditoria está em `outputs/auditoria-projeto/site-antes.zip`; ela não é backup do banco.
2. Usar uma cópia de homologação com as migrações anteriores aplicadas, incluindo **017**. Confirmar o e-mail do administrador.
3. Validar nessa cópia a atualização do site e o **SQL 018** em conjunto. O SQL é transacional e interrompe a aplicação se faltar o 017 ou se a publicação Realtime estiver em `FOR ALL TABLES`.
4. Na publicação definitiva, usar uma janela sem partidas ativas. Publicar todos os arquivos do pacote, incluindo `security.js`, manifesto, service worker, scripts versionados e PNGs otimizados; em seguida aplicar o SQL 018.
5. Atualizar as abas abertas. Clientes antigos deixam de receber o estado completo pelo canal antigo; o cliente novo usa sinais e possui consulta periódica como recuperação.
6. Verificar cabeçalhos na hospedagem. Não enviar credenciais privadas para o navegador.

Não reaplicar migrações antigas por cima do SQL 018. Restaurar apenas o site antigo depois da mudança de permissões pode ser incompatível; um retorno deve incluir planejamento da versão do banco. O arquivo de eventos antigos guardado em `audit_replay_backup` não é acessível aos jogadores.

### Validações recomendadas antes de produção — não executadas

- Conta comum, administrador, troca de conta e saída/entrada em duas abas.
- Inventário inicial, compra, resgate de código, equipamento, presente e expedição concorrentes.
- Criar, editar, excluir e selecionar os sete decks; arrastar cartas; fechar e salvar o construtor.
- Partida 1v1 e 2v2, reconexão, fim de turno, desempate, Odin, Loki, Hades, Afrodite e Eclipse.
- Confirmar pela API que um participante não recebe a mão adversária nem a ordem do próprio baralho; espectador/replay não recebem mãos privadas.
- Confirmar que usuário comum não executa auxiliares internos, não escreve saldo/cópias e não equipa itens sem propriedade.
- Imagens e atualização por F5 em desktop/mobile, com cache novo e cache já existente.

## Sugestões priorizadas

1. **Tornar o Guardião autoritativo no servidor.** Hoje a simulação local informa o resultado. O limite diário foi protegido contra concorrência, mas um cliente alterado ainda pode informar resultados falsos dentro do limite. Resolver isso exige mover a simulação ou validar uma sequência verificável de ações no servidor.
2. **Criar homologação e uma matriz automatizada de regressão e RLS.** Cobrir as interações listadas acima antes de cada publicação, incluindo duas contas concorrentes. A migração desta auditoria precisa dessa validação antes de produção.
3. **Unificar o catálogo e as regras entre cliente e servidor.** Evitar listas e poderes duplicados; uma edição administrativa de texto/arte não deve produzir divergências com a regra real de combate.
4. **Gerar miniaturas próprias para loja, coleção e construtor.** Manter arte completa só na ampliação; avaliar WebP/AVIF e tamanhos responsivos. A compressão sem perdas desta entrega já reduz transferência, mas não a memória ocupada ao decodificar imagens grandes.
5. **Fixar a versão do SDK do Supabase e adotar integridade de dependências.** O CDN atual usa a versão principal `@2`, que pode mudar sem publicação do site. Fixar após validar a versão escolhida; preferir dependências empacotadas localmente.
6. **Ampliar CSP e proteções de autenticação.** Remover dependência de scripts inline antes de restringir `script-src`; configurar limites, proteção contra abuso e CAPTCHA no Supabase conforme o uso real. Adotar cargos administrativos por UUID com trilha de auditoria.
7. **Instrumentar erros e desempenho.** Registrar falhas de RPC, latências de carregamento, desconexões e consultas lentas sem salvar tokens ou mãos privadas. Definir retenção para timelines, replays e backups privados.
8. **Concluir sincronização de chat e paginação.** Recuperar mensagens após reconexão e paginar listas que crescerão com o número de jogadores, em vez de aumentar limites indefinidamente.
9. **Manter compra de slots e Clash Bit sob autoridade do servidor.** Quando essas funções forem ativadas, concessão de saldo/slots deve depender de eventos verificados e idempotentes do provedor. Os fluxos de recarga continuam ocultos nesta entrega.

## Referências técnicas

As mudanças de permissão seguem a documentação oficial: [funções e segurança](https://supabase.com/docs/guides/database/functions), [permissões por coluna](https://supabase.com/docs/guides/database/postgres/column-level-security), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) e [Realtime Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes).
