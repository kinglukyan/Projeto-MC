# Segurança e jogo justo — auditoria de 19/10/2026

## Alcance real

Revisão do código local do site, da configuração de publicação e das migrações SQL. As correções desta entrega estão preparadas no pacote; **não foram aplicadas ao Supabase nem publicadas no site online**. Não houve acesso ao banco de produção, aos usuários, aos logs do provedor ou ao painel Vercel. Não foi realizado pentest no servidor remoto.

## Correções preparadas

| Área | Evidência encontrada | Proteção adicionada | Ativação |
|---|---|---|---|
| Publicação | Existia `_headers`, mas não configuração equivalente da Vercel. | `vercel.json` com CSP, bloqueio de enquadramento, MIME, HSTS e restrições de capacidades. O redirecionamento mobile saiu de script inline. | Publicar o pacote usando a configuração incluída. |
| Arquivos internos | A raiz incluía migrações, documentação e ferramentas de manutenção junto do site estático. | Build sem dependências copia somente arquivos do jogo e assets para `site-publico`. SQL e manutenção ficam fora do diretório publicado. | Build automático configurado na Vercel. |
| Contas suspensas | Funções do lobby recriadas em 035/036 não herdavam os guards inseridos pela 028. | Guard de conta ativa reaplicado aos RPCs PL/pgSQL autenticados expostos. | SQL 037. |
| Repetição de jogadas | O cliente não identificava unicamente cada comando enviado. | UUID por comando, vínculo conta/partida, hash canônico e processamento idempotente. Repetir o mesmo comando não repete a jogada; reutilizar o UUID com outro conteúdo é rejeitado. | SQL 037 + cliente atualizado. |
| Entrada adulterada | Havia validação de objeto e tamanho; faltava um contrato explícito dos campos na entrada pública. | Tipos permitidos, limite de 8 KB, validação de índices, limites de campos e rejeição de chaves desconhecidas. O motor existente continua verificando turno, mão, opções e regras. | SQL 037. |
| Flood de ações | Não havia limite específico persistente para jogadas rejeitadas. | 120 ações/minuto e 12/2 segundos por conta; rejeições retornam um envelope sem aplicar ação, mantendo quota e registro no banco. | SQL 037 + cliente que reconhece `_securityError`. |
| Abuso de operações | Operações de convite, presentes, compra e resgate não tinham quota própria uniforme. | Quotas por operação/conta para transações concluídas. Erros que fazem rollback são registrados com marcador no log PostgreSQL quando o limite já foi alcançado. | SQL 037. Não equivale a firewall ou limitação por IP. |
| Partidas simultâneas | Caminhos de fila/desafio podiam tentar criar duas partidas ativas para a mesma conta. | Reserva única por jogador, verificada transacionalmente ao inserir partida, inclusive 2×2. Partidas existentes não são apagadas ou reprocessadas. | SQL 037. |
| Auditoria | Logs administrativos existentes não reuniam rejeições do combate e alterações de progresso. | Registros privados de formatos inesperados, acesso indisponível, reuso de ID, limites, rejeições do motor, alterações econômicas e operações administrativas. | SQL 037 + Administração → Gestão do jogo → Segurança. |
| Força bruta de código administrativo | A 029 já limitava tentativas, mas não havia sinal no novo painel. | Evento a partir da terceira tentativa na janela existente. O código e seu hash não são copiados ao log. | SQL 037. |
| Upload | Limites precisavam continuar no servidor, além do formulário. | Tipos permitidos e tamanho dos buckets reafirmados: arte até 5 MB; HQ até 50 MB. Sem upload de HTML ou SVG nesses buckets. | SQL 037. Não é antivírus para PDF. |
| Permissões futuras | Grants padrão podem expor funções novas sem intenção. | EXECUTE padrão revogado de PUBLIC/anon/authenticated para novas funções do mesmo owner; funções públicas precisam de grant explícito. Auxiliares da proteção permanecem privados. | SQL 037. |

## Registros e revisão

O painel mostra conta, horário, categoria, partida autorizada e metadados mínimos. Não armazena senhas, JWTs, códigos administrativos, mãos, ordem de baralho ou payload bruto das jogadas. Registros têm limite de emissão por categoria/conta para reduzir spam. Eventos de alteração econômica são fatos, não acusações.

**Nenhum ban automático foi criado.** Versão antiga do cliente, clique fora de hora e conflitos de rede também geram rejeições. A administração pode revisar um registro e anotar uma conclusão; uma suspensão usa o fluxo administrativo existente.

A tela “Verificar permissões” consulta tabelas sem RLS, auxiliares acessíveis e grants de escrita em tabelas sensíveis. Ela aponta itens para análise, não certifica a segurança de todas as políticas. RLS não substitui a checagem de identidade de uma função SECURITY DEFINER.

A limpeza `security_prune_history()` é restrita a serviço/admin. Remove janelas antigas (2 dias), IDs de requisições de partidas não ativas (30 dias) e eventos **já revisados** (90 dias). Precisa ser agendada no provedor ou executada por responsável; este pacote não criou uma automação externa. Eventos não revisados exigem acompanhamento para não acumular indefinidamente.

## Limitações encontradas que continuam exigindo trabalho

1. **Alta — Guardião e tutorial:** parte do progresso/recompensa ainda depende de resultados locais enviados pelo navegador. O limite diário, a validação de formato e os logs não provam uma vitória. Para eliminar esse caminho de trapaça, o treino recompensado precisa ser simulado/validado no servidor, com os comandos registrados. Esta entrega não declara essa parte como antitrapaça completo.
2. **Infraestrutura:** não foi possível confirmar quais migrações estão efetivamente aplicadas, backups, políticas reais do Auth/Storage, logs ou firewall. Código preparado não significa proteção já ativa no site.
3. **Login, bots e DDoS:** ativar a proteção de senha vazada, verificação de e-mail, limites do Auth e CAPTCHA suportado pelo Supabase com chaves próprias. Configurar firewall/limites na Vercel e no caminho da API. Quotas por conta no banco não substituem proteção por IP nem protegem todo o tráfego anônimo.
4. **Administração:** ativar MFA nas contas responsáveis pelo Supabase/Vercel e planejar exigir AAL2 nas ações administrativas do próprio jogo, com fluxo de MFA no aplicativo. O MFA obrigatório dentro do jogo ainda não foi implementado aqui.
5. **Dependência externa:** o cliente Supabase ainda é carregado do CDN existente com a faixa `@2`. É necessário controlar atualização/revisão dessa dependência ou empacotar uma versão aprovada com integridade. Não foi escolhido arbitrariamente um pacote antigo como “seguro”.
6. **Banco:** a migração não foi executada num PostgreSQL de homologação; concorrência, recompensas, RLS e todos os poderes precisam de validação em ambiente separado antes de aplicar em produção. A confirmação estática não comprova execução correta do SQL.
7. **Contas comprometidas/conluio:** não há garantia de identificar alguém que roubou uma conta, combine resultados com outro jogador ou use múltiplas contas. Os registros ajudam a investigação e não revelam a identidade real da pessoa.

## Ativar esta entrega

1. Fazer backup do banco e do Storage e usar primeiro um projeto de homologação com as migrações até a 036.
2. Aplicar `supabase/migrations/202610190037_security_and_fair_play.sql` nesse ambiente e executar as verificações de `_manutencao/seguranca/verificar-banco.sql`.
3. Publicar o cliente junto com a 037: clientes antigos não enviam `request_id` e terão comandos rejeitados. Não reaplicar migrações anteriores que já estejam executadas.
4. Confirmar na hospedagem os cabeçalhos, o funcionamento de login, 1×1, 2×2, efeitos com escolha, recompensa única e as permissões entre duas contas distintas.
5. Após a validação, aplicar/publicar em produção. Abrir o painel Segurança com conta administrativa e organizar a revisão/retensão dos registros.

## Verificações locais desta entrega

As seis verificações estáticas passaram (incluindo sintaxe dos 38 scripts da raiz), e seu relatório fica em `_manutencao/seguranca/`. Também foi renderizado o hall localmente com os cabeçalhos CSP desta entrega: sem erro JavaScript e sem violações CSP nessa renderização. Recursos externos foram abortados; isso não validou login, CDN, Storage nem o servidor. Elas conferem a configuração HTTP, ausência de script inline nas páginas, sintaxe JavaScript e sinais de chaves privilegiadas. Não substituem o banco de homologação nem uma auditoria independente.

## Referências primárias

- Vercel — cabeçalhos: https://vercel.com/docs/cdn-security/security-headers
- Vercel — configuração do projeto: https://vercel.com/docs/project-configuration/vercel-json
- Supabase — funções e permissões: https://supabase.com/docs/guides/database/functions
- Supabase — RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase — segurança da API: https://supabase.com/docs/guides/api/securing-your-api
- Supabase — MFA: https://supabase.com/docs/guides/auth/auth-mfa
