# Publicar esta revisão

## 1. Banco Supabase

Com as migrações anteriores até a **056** já aplicadas, executar nesta ordem:

1. `supabase/migrations/202610220057_social_guilds_community.sql`
2. `supabase/migrations/202610220058_device_login_private.sql`
3. `supabase/migrations/202610220059_solo_tiebreak.sql`

057 cria convites/candidaturas e favoritos e adiciona os novos serviços. 058 cria o armazenamento privado do QR. 059 cria a disponibilidade do Desempate solo, inicialmente desligada. Os dados de guildas e decks já publicados são preservados.

## 2. Configurar o QR na Vercel

Em Settings → Environment Variables, adicionar apenas no servidor:

- `SUPABASE_URL`: URL do mesmo projeto Supabase usado pelo jogo.
- `SUPABASE_SERVICE_ROLE_KEY`: chave service_role do projeto, mantida privada.

Não colocar essa chave em `supabase-config.js`, no GitHub, em nomes `PUBLIC_` ou `VITE_`, nem em arquivo de frontend. O endpoint `api/device-login.js` usa essas variáveis no servidor; o build público não copia a pasta `api` para a pasta de arquivos estáticos.

## 3. Enviar ao GitHub

Substituir/adicionar os arquivos do pacote de atualização na raiz do repositório existente. O ZIP completo revisado inclui todos os arquivos atuais do projeto, exceto o histórico `.git`. Não substituir a pasta `.git` do seu checkout.

Manter `vercel.json`, incluindo o comando `node _manutencao/preparar-publicacao.cjs` e saída `site-publico`. A pasta `api` precisa ficar na raiz do repositório, no mesmo nível de `vercel.json`. Fazer novo deploy depois de definir as variáveis.

## 4. Ativação do Desempate

Depois de publicar e aplicar o SQL 059, uma conta já autorizada encontra o controle “Liberar o modo Desempate solo” no painel administrativo. Ao desligar, o cartão some da Arena; novas puxadas também são recusadas no servidor.

## Conferência após publicar

O proprietário pode conferir o cabeçalho em Safari/PWA no iPhone, o gesto do menu, entrada PC/celular em ambos os sentidos, convites/candidaturas com duas contas, votos/favoritos após atualizar a página e ativação/desativação do modo solo. Sem as migrações e variáveis, os serviços novos apresentam indisponibilidade em vez de simular salvamento.
