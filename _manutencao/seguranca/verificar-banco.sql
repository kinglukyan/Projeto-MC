-- Executar no SQL Editor de homologação após a 037. Apenas leitura.
begin read only;
select 'acoes_anon_bloqueadas' check_name,not has_function_privilege('anon','public.submit_game_action(uuid,jsonb)','EXECUTE') ok
union all select 'acoes_autenticadas_permitidas',has_function_privilege('authenticated','public.submit_game_action(uuid,jsonb)','EXECUTE')
union all select 'motor_interno_privado',not has_function_privilege('authenticated','public._security_submit_game_action_v37(uuid,jsonb)','EXECUTE')
union all select 'auditoria_anon_bloqueada',not has_function_privilege('anon','public.admin_security_events(bigint,text,uuid)','EXECUTE');
select c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in('security_events','security_rate_windows','security_action_requests','security_match_leases');
select table_name,grantee,privilege_type from information_schema.role_table_grants where table_schema='public'
and table_name in('security_events','security_rate_windows','security_action_requests','security_match_leases') and grantee in('PUBLIC','anon','authenticated');
-- Esperado: nenhuma escrita/consulta direta dessas tabelas por cliente; leitura via RPC admin.
select p.oid::regprocedure signature,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (p.proname like '\_security\_%' escape '\' or p.proname in('submit_game_action','admin_security_events','admin_security_health'));
-- Diagnóstico de partidas históricas paralelas (não altera nem encerra partidas).
select u.player_id,count(*) active_matches from public.game_matches g
cross join lateral unnest(array[g.player_one,g.player_two,g.player_three,g.player_four]) u(player_id)
where g.status='active' and u.player_id is not null group by u.player_id having count(*)>1;
rollback;
