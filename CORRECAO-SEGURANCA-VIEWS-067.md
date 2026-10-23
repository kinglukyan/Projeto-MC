# Correção dos alertas de views — SQL 067

## O que foi encontrado
As views `public.public_match_meta` e `public.public_card_meta` foram definidas nos arquivos antigos com `security_invoker=false`. Assim, as permissões das tabelas de origem são verificadas com o papel do proprietário da view. O Security Advisor sinaliza esse comportamento porque pode contornar as políticas de acesso por linha (RLS).

As definições locais retornam apenas estatísticas agregadas por modo e por carta. O alerta, sozinho, não comprova vazamento. A inspeção foi feita nos arquivos locais; não houve conexão com o banco publicado para confirmar a definição ou as permissões em produção.

## Correção
- Define `security_invoker=true` nas duas views.
- Revoga o acesso direto de `PUBLIC`, `anon` e `authenticated` às duas views legadas.
- Não concede permissões novas nas tabelas privadas de partidas, histórico ou eventos.
- Mantém as views e seus dados de origem; não apaga partidas nem altera saldos, recompensas ou perfis.

A busca nos arquivos atuais não encontrou chamadas a essas views na interface. As estatísticas de perfil usam outras consultas. Integrações externas que consultem diretamente essas duas views perderão o acesso com as credenciais de jogador.

## Como aplicar
1. Abra o SQL Editor do projeto no Supabase.
2. Cole e execute `202610230067_security_invoker_meta_views.sql`.
3. Atualize o Security Advisor para conferir os dois alertas novamente.

Este SQL corrige as views já presentes e pode ser aplicado mesmo se as atualizações de criação de personagem e modos de jogo (065/066) ainda não tiverem sido instaladas. Não exige publicação dos arquivos do site. Em uma instalação nova, siga a ordem normal das migrações.

## Estado
Correção preparada localmente. Não executada no Supabase; resultado dos alertas ainda não confirmado. Nenhum teste de banco foi executado.

Referências oficiais:
- https://supabase.com/docs/guides/database/views
- https://supabase.github.io/splinter/0010_security_definer_view/
