-- Após 050. Os detalhes ficam acessíveis somente pelo relatório encerrado.
begin;
create table if not exists public.match_effect_details(
 id bigint generated always as identity primary key,
 match_id uuid references public.game_matches(id) on delete cascade,
 run_id uuid references public.guardian_campaign_runs(id) on delete cascade,
 happened_at timestamptz not null default clock_timestamp(),
 effects jsonb not null,
 check((match_id is not null)<>(run_id is not null))
);
create index if not exists match_effect_details_match on public.match_effect_details(match_id,id) where match_id is not null;
create index if not exists match_effect_details_run on public.match_effect_details(run_id,id) where run_id is not null;
alter table public.match_effect_details enable row level security;
revoke all on public.match_effect_details from public,anon,authenticated;

-- Somente informações públicas do campo, nunca mãos, decks ou escolhas privadas.
create or replace function public._audit_public_field(s jsonb) returns jsonb
language plpgsql stable set search_path='' as $$
declare result jsonb:='{}';t text;u jsonb;cid text;k text;
begin
 foreach t in array array['player_one','player_two'] loop
  for u in select value from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]')) loop
   k:=u->>'uid';if k is null then continue;end if;
   cid:=coalesce(u->>'copiedFrom',u->>'cardId');
   result:=jsonb_set(result,array[k],jsonb_build_object('card_id',cid,'name',coalesce(public._r_card(cid)->>'name',cid),
    'team',t,'lane',coalesce((u->>'lane')::integer,0),'power',public._r_power(s,t,u),
    'equipment',coalesce(u->'equipment','[]'),'silenced',coalesce((u->>'silencedJogadas')::integer,0)>0 or coalesce((u->>'silencedOwnerEnd')::boolean,false),
    'saved',coalesce((u->>'savedOnce')::boolean,false),'guard',u->>'guardOwner'));
  end loop;
 end loop;
 return result;
end $$;
create or replace function public._audit_effect_diff(prior jsonb,next_state jsonb) returns jsonb
language plpgsql stable set search_path='' as $$
declare a jsonb:=public._audit_public_field(prior);b jsonb:=public._audit_public_field(next_state);
 k text;u jsonb;v jsonb;g jsonb;team text;message text;equip_before text;equip_after text;details jsonb:='[]';r integer:=coalesce((next_state->>'round')::integer,1);
begin
 for k,u in select key,value from jsonb_each(b) loop
  v:=a->k;message:='';
  if v is null then message:='entrou em campo';
  else
   if v->>'team'<>u->>'team' then message:=message||'mudou de lado por roubo; ';end if;
   if v->>'card_id'<>u->>'card_id' then message:=message||'identidade copiada ou transformada; ';end if;
   if v->>'lane'<>u->>'lane' then message:=message||format('movida da fileira %s para %s; ',(v->>'lane')::integer+1,(u->>'lane')::integer+1);end if;
   if v->>'power'<>u->>'power' then message:=message||format('poder %s → %s; ',v->>'power',u->>'power');end if;
   if v->'equipment' is distinct from u->'equipment' then
    select string_agg(coalesce(public._r_card(e.value)->>'name',e.value),', ') into equip_before from jsonb_array_elements_text(v->'equipment') e(value);
    select string_agg(coalesce(public._r_card(e.value)->>'name',e.value),', ') into equip_after from jsonb_array_elements_text(u->'equipment') e(value);
    message:=message||format('equipamentos: %s → %s; ',coalesce(equip_before,'nenhum'),coalesce(equip_after,'nenhum'));
   end if;
   if v->>'silenced'<>u->>'silenced' then message:=message||case when (u->>'silenced')::boolean then 'habilidade silenciada; ' else 'habilidade restaurada; ' end;end if;
   if not (v->>'saved')::boolean and (u->>'saved')::boolean then message:=message||'proteção contra destruição consumida; ';end if;
   if v->'guard' is distinct from u->'guard' then message:=message||case when u->>'guard' is null then 'proteção temporária encerrada; ' else 'proteção temporária recebida; ' end;end if;
  end if;
  if message<>'' then details:=details||jsonb_build_array(jsonb_build_object('round',r,'side',u->>'team','text',(u->>'name')||': '||rtrim(message,'; ')||'.'));end if;
 end loop;
 for k,u in select key,value from jsonb_each(a) loop
  if not (b?k) then
   message:=case when exists(select 1 from jsonb_array_elements(coalesce(next_state#>array[u->>'team','grave'],'[]')) as grave_rows(grave_entry) where grave_entry->>'uid'=k) then 'enviada ao Submundo' else 'saiu do campo' end;
   details:=details||jsonb_build_array(jsonb_build_object('round',r,'side',u->>'team','text',(u->>'name')||': '||message||'.'));
  end if;
 end loop;
 foreach team in array array['player_one','player_two'] loop
  for g in select value from jsonb_array_elements(coalesce(prior#>array[team,'grave'],'[]')) loop
   if not exists(select 1 from jsonb_array_elements(coalesce(next_state#>array[team,'grave'],'[]')) item where item->>'uid'=g->>'uid') then
    details:=details||jsonb_build_array(jsonb_build_object('round',r,'side',team,'text',coalesce(public._r_card(g->>'cardId')->>'name',g->>'cardId')||': recuperada ou retirada do Submundo.'));
   end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(next_state#>array[team,'grave'],'[]')) loop
   if g->>'lockedRound'=r::text and not exists(select 1 from jsonb_array_elements(coalesce(prior#>array[team,'grave'],'[]')) item where item->>'uid'=g->>'uid' and item->>'lockedRound'=r::text) then
    details:=details||jsonb_build_array(jsonb_build_object('round',r,'side',team,'text',coalesce(public._r_card(g->>'cardId')->>'name',g->>'cardId')||': bloqueada no Submundo até o fim do Round.'));
   end if;
  end loop;
 end loop;
 return details;
end $$;
create or replace function public._capture_post_match_effects() returns trigger
language plpgsql security definer set search_path='' as $$
declare effects jsonb;a jsonb;b jsonb;
begin
 if tg_table_name='guardian_campaign_runs' then a:=old.context->'s';b:=new.context->'s';else a:=old.state;b:=new.state;end if;
 if a is not distinct from b then return new;end if;
 effects:=public._audit_effect_diff(a,b);
 if jsonb_array_length(effects)>0 then
  if tg_table_name='guardian_campaign_runs' then insert into public.match_effect_details(run_id,effects) values(new.id,effects);
  else insert into public.match_effect_details(match_id,effects) values(new.id,effects);end if;
 end if;
 return new;
end $$;
drop trigger if exists capture_post_match_effects on public.game_matches;
create trigger capture_post_match_effects after update of state on public.game_matches for each row execute function public._capture_post_match_effects();
drop trigger if exists capture_post_match_effects on public.guardian_campaign_runs;
create trigger capture_post_match_effects after update of context on public.guardian_campaign_runs for each row execute function public._capture_post_match_effects();

do $$ begin
 if to_regprocedure('public._get_match_report_v51(uuid)') is null then alter function public.get_match_report(uuid) rename to _get_match_report_v51;end if;
 if to_regprocedure('public._get_guardian_campaign_report_v51(uuid)') is null then alter function public.get_guardian_campaign_report(uuid) rename to _get_guardian_campaign_report_v51;end if;
end $$;
create or replace function public.get_match_report(p_match_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare report jsonb;entries jsonb;
begin
 report:=public._get_match_report_v51(p_match_id); -- valida participante e partida encerrada
 select coalesce(jsonb_agg(e.value order by d.id,e.ordinality),'[]') into entries
 from public.match_effect_details d cross join lateral jsonb_array_elements(d.effects) with ordinality e(value,ordinality) where d.match_id=p_match_id;
 return report||jsonb_build_object('effects',entries);
end $$;
create or replace function public.get_guardian_campaign_report(p_run_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare report jsonb;entries jsonb;
begin
 report:=public._get_guardian_campaign_report_v51(p_run_id); -- valida proprietário e término
 select coalesce(jsonb_agg(e.value order by d.id,e.ordinality),'[]') into entries
 from public.match_effect_details d cross join lateral jsonb_array_elements(d.effects) with ordinality e(value,ordinality) where d.run_id=p_run_id;
 return report||jsonb_build_object('effects',entries);
end $$;
revoke all on function public._audit_public_field(jsonb),public._audit_effect_diff(jsonb,jsonb),public._capture_post_match_effects(),public._get_match_report_v51(uuid),public._get_guardian_campaign_report_v51(uuid) from public,anon,authenticated;
revoke all on function public.get_match_report(uuid),public.get_guardian_campaign_report(uuid) from public,anon;
grant execute on function public.get_match_report(uuid),public.get_guardian_campaign_report(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
