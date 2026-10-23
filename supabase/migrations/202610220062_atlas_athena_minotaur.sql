-- Apply after 061. Preserve cleared stages, run IDs and claimed treasures.
begin;
-- Do not change the identity of an opponent in a battle that is still running.
lock table public.guardian_campaign_runs in share row exclusive mode;
do $prerequisites$
begin
 if to_regprocedure('public.guild_level(bigint)') is null then raise exception 'Aplique primeiro o SQL 061.';end if;
 if exists(select 1 from public.guardian_campaign_runs r where r.status='active' and r.node_id in ('greece-04','greece-15')) then
  raise exception 'Conclua ou desista dos desafios 4 e 15 da Grécia que estão em andamento. Depois execute novamente o SQL 062 completo.';
 end if;
 if to_regprocedure('public._gc_data_before062()') is null then
  alter function public._gc_data() rename to _gc_data_before062;
 end if;
end $prerequisites$;
create or replace function public._gc_data() returns jsonb
language plpgsql immutable set search_path='' as $$
declare d jsonb:=public._gc_data_before062();
begin
 d:=jsonb_set(d,'{nodes,greece-04}',(d#>'{nodes,greece-04}')||jsonb_build_object('opponent','athena','name','Athena','icon','chibi-athena'));
 d:=jsonb_set(d,'{nodes,greece-15}',(d#>'{nodes,greece-15}')||jsonb_build_object('opponent','minotauro','name','Minotauro','icon','chibi-minotauro'));
 return jsonb_set(d,'{version}','5'::jsonb);
end $$;
revoke all on function public._gc_data_before062(),public._gc_data() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
