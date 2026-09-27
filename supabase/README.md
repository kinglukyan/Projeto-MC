# Conexão online do Mythic Clash

O projeto continua sendo uma página estática e usa Supabase para contas e recursos sociais. A migração `migrations/202609270001_online_game.sql` cria:

- Perfil público com código único para amigos, classificação e preferências.
- Solicitações/amizades e chat privado em tempo real.
- Convites por código e fila de partidas normal/ranqueada.
- Partidas visíveis somente aos participantes. O navegador não recebe permissão para alterar diretamente o estado de uma partida.

## Preparar o projeto

1. No painel Supabase, abra **SQL Editor** e execute, em ordem, `migrations/202609270001_online_game.sql`, `migrations/202609270002_progression_store.sql`, `migrations/202609270003_admin_console.sql`, `migrations/202609270004_profile_icons_and_intro.sql` e `migrations/202609270005_card_customizer.sql`. A última cria o armazenamento protegido das imagens e os campos usados pelo editor de cartas.
2. Em **Project Settings → API**, copie o Project URL e a chave **publishable** (ou a antiga `anon`). São valores próprios para uso no cliente web; nunca coloque a `service_role` no site ou no GitHub.
3. Coloque esses dois valores em `supabase-config.js` e publique os arquivos estáticos pelo GitHub.
4. Em **Authentication → URL Configuration**, inclua o endereço publicado do site em Site URL e Redirect URLs.
5. Ative **Realtime** para as tabelas `friend_messages`, `game_invites`, `game_matches` e `matchmaking_queue` (a migração tenta adicioná-las à publicação automaticamente).

As políticas RLS protegem as tabelas. As funções de perfil, amizade, convite, fila e ações da partida exigem uma sessão autenticada. O navegador não altera diretamente o estado do tabuleiro ou a classificação; as jogadas e a atualização de resultados passam pelas funções do banco.
