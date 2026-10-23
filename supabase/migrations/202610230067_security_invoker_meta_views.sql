-- 067: corrigir as duas views apontadas pelo Security Advisor.
-- Correção independente das funcionalidades dos SQLs 065/066.
-- Requer as views existentes das migrações 202610130001 e 202610160001.
-- Não concede acesso às tabelas de partidas, históricos ou eventos.
begin;

alter view public.public_match_meta set (security_invoker = true);
alter view public.public_card_meta set (security_invoker = true);

-- Estas views legadas não são consumidas pela interface atual.
-- Mantê-las disponíveis somente para operações internas autorizadas.
revoke all privileges on table public.public_match_meta from public, anon, authenticated;
revoke all privileges on table public.public_card_meta from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
