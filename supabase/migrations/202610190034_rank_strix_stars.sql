-- 034: cinco estrelas Strix por rank até Lenda; pontos a partir de Semideus.
-- Aplicar depois da 033. Aprendiz é o único piso protegido nos ranks de estrelas.
begin;

create or replace function public._rank_strix_normalize(rating integer)
returns integer language plpgsql immutable set search_path='' as $$
declare value integer:=greatest(1000,coalesce(rating,1000));base integer;step integer;
begin
 if value>=1700 then return value;end if;
 if value<1100 then base:=1000;step:=20;
 elsif value<1250 then base:=1100;step:=30;
 elsif value<1450 then base:=1250;step:=40;
 else base:=1450;step:=50;end if;
 return base+least(4,greatest(0,(value-base)/step))*step;
end $$;

-- The existing rating column remains the matchmaking coordinate. Below 1700,
-- its five positions inside each rank encode 0..4 stars, not public points.
-- Completing star five moves directly to the next rank at zero stars.
create or replace function public._rank_strix_next(rating integer,change integer)
returns integer language plpgsql immutable set search_path='' as $$
declare value integer:=public._rank_strix_normalize(rating);base integer;step integer;stars integer;
begin
 if change=0 then return value;end if;
 if value>=1700 then
  if value+change<1700 then return 1650;end if; -- Lenda, quatro estrelas.
  return value+change;
 end if;
 if value<1100 then base:=1000;step:=20;
 elsif value<1250 then base:=1100;step:=30;
 elsif value<1450 then base:=1250;step:=40;
 else base:=1450;step:=50;end if;
 stars:=(value-base)/step;
 if change>0 then return base+(stars+1)*step;end if;
 if stars>0 then return base+(stars-1)*step;end if;
 return case base when 1000 then 1000 when 1100 then 1080 when 1250 then 1220 else 1410 end;
end $$;

create or replace function public._apply_rank_strix_progression()
returns trigger language plpgsql security definer set search_path='' as $$
declare difference integer;
begin
 if tg_op='INSERT' then
  new.rating_points:=public._rank_strix_normalize(new.rating_points);return new;
 end if;
 if new.rating_points is not distinct from old.rating_points then return new;end if;
 difference:=new.rating_points-old.rating_points;
 -- All ranked resolution paths already award +/-25 once: 1v1, 2v2,
 -- forfeits and the automatic tiebreak. Convert that award at the source.
 if difference in (-25,25) then
  new.rating_points:=public._rank_strix_next(old.rating_points,difference);
 else
  new.rating_points:=public._rank_strix_normalize(new.rating_points);
 end if;
 return new;
end $$;
revoke all on function public._rank_strix_normalize(integer),public._rank_strix_next(integer,integer),public._apply_rank_strix_progression() from public,anon,authenticated;

-- Retain every existing rank and its proportional progress. No historical
-- rewards, XP, coins, wins or losses are replayed or changed.
drop trigger if exists rank_strix_progression on public.profiles;
update public.profiles set rating_points=public._rank_strix_normalize(rating_points)
 where rating_points<>public._rank_strix_normalize(rating_points);
alter table public.profiles alter column rating_points set default 1000;
create trigger rank_strix_progression before insert or update of rating_points on public.profiles
for each row execute function public._apply_rank_strix_progression();

notify pgrst,'reload schema';
commit;
