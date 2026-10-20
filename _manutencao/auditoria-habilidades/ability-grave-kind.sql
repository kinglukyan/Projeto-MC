-- Ereshkigal forbids unit resurrection, not recovering/equipping non-unit cards.
create or replace function public._x_grave_ok(x jsonb,e jsonb,g jsonb,revive boolean default true) returns boolean language sql stable set search_path='' as $$
 select coalesce((g->>'lockedRound')::integer,0)<>coalesce((x#>>'{s,round}')::integer,1)
 and (not revive or public._r_card(g->>'cardId')->>'kind'<>'unit' or not exists(
  select 1 from jsonb_array_elements(x#>array['s',public._r_other(e->>'team'),'field']) v
  where v->>'lane'=e->>'lane' and public._x_rule(v)->>'op'='blockRevive' and public._r_active(x->'s',public._r_other(e->>'team'),v))) $$;
