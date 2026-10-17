# Títulos, medalhas e sair da conta

## Ativação

1. No SQL Editor do seu projeto Supabase, execute **supabase/migrations/202610170001_titles_medals.sql**, depois das migrações anteriores.
2. Publique todo o conteúdo desta pasta, incluindo os novos arquivos honors.js e honors.css, index.html, online.js, app.js e sw.js.
3. Feche e reabra o webapp. Abra Perfil → Títulos e medalhas.

O código da migração foi incluído, mas **não foi executado no servidor nesta entrega**. Sem ele, o perfil informa que as conquistas aguardam a atualização do banco; os botões de sair funcionam independentemente da migração. Não foi executada uma bateria de testes nesta etapa.

## Regras

- O catálogo contém **8 títulos e 10 medalhas**.
- O banco calcula o progresso a partir do histórico completo de partidas e da conclusão do tutorial. Os filtros do perfil não alteram o progresso das conquistas.
- Os desbloqueios são registrados ao consultar as conquistas e permanecem salvos, mesmo se os registros do histórico mudarem posteriormente.
- Uma conta pode equipar um título e destacar até três medalhas distintas. Pode remover ou substituir as escolhas a qualquer momento.
- Amigos aceitos podem consultar o título e as medalhas em destaque pelo perfil do amigo. E-mail, telefone e idade não fazem parte dessa consulta.
- São recompensas cosméticas, sem alterar poder das cartas, XP ou MC.
- Não existe gravação direta das conquistas pelo navegador: as funções do servidor validam os requisitos e a seleção.

### Títulos

| Título | Requisito |
|---|---|
| Viajante da Convergência | Conta criada |
| Iniciado da Arena | Tutorial concluído |
| Portador da Vitória | 1 vitória |
| Veterano da Arena | 25 partidas |
| Campeão Ranqueado | 10 vitórias ranqueadas |
| Duelista Lendário | 10 vitórias X1 |
| Conquistador de Mundos | 50 vitórias |
| Lenda Imortal | 100 vitórias |

### Medalhas

Primeiros Passos (tutorial), Primeira Vitória (1 vitória), Glória de Bronze (10 vitórias), Glória de Prata (50), Glória de Ouro (100), Explorador da Arena (25 partidas), Cem Batalhas (100 partidas), Ascensão Competitiva (10 vitórias ranqueadas), Rival Respeitado (10 vitórias X1), Guardião Superado (10 vitórias contra o Guardião).

## Sair da conta

Há botões no menu lateral, nas ações do perfil e nas configurações. A saída encerra a sessão deste aparelho, retorna à entrada da conta, fecha janelas abertas e limpa a apresentação da partida e os hologramas. Não apaga cartas, decks, progresso ou conquistas do servidor. Não encerra sessões em outros aparelhos nem declara uma derrota automática; uma partida online continua seguindo suas regras de prazo e desconexão.
