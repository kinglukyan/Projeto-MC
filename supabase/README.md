# Conexão online do Mythic Clash

O projeto continua sendo uma página estática e usa Supabase para contas e recursos sociais. A migração `migrations/202609270001_online_game.sql` cria:

- Perfil público com código único para amigos, classificação e preferências.
- Solicitações/amizades e chat privado em tempo real.
- Convites por código e fila de partidas normal/ranqueada.
- Partidas visíveis somente aos participantes. O navegador não recebe permissão para alterar diretamente o estado de uma partida.

## Preparar o projeto

1. No painel Supabase, abra **SQL Editor** e execute a migração em `migrations/202609270001_online_game.sql`.
2. Em **Project Settings → API**, copie o Project URL e a chave **publishable** (ou a antiga `anon`). São valores próprios para uso no cliente web; nunca coloque a `service_role` no site ou no GitHub.
3. Coloque esses dois valores em `supabase-config.js` e publique os arquivos estáticos pelo GitHub.
4. Em **Authentication → URL Configuration**, inclua o endereço publicado do site em Site URL e Redirect URLs.
5. Ative **Realtime** para as tabelas `friend_messages`, `game_invites`, `game_matches` e `matchmaking_queue` (a migração tenta adicioná-las à publicação automaticamente).

As políticas RLS protegem as tabelas. As funções de perfil, amizade, convite e fila são chamadas autenticadas. A classificação não deve ser atualizada pelo cliente: a conclusão de partidas ranqueadas precisa passar por lógica confiável no servidor (por exemplo, uma Edge Function), junto com as ações do jogo.
