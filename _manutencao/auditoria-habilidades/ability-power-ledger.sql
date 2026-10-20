-- Preserve buffs and reductions separately even when their numeric sum cancels out.
create or replace function public._x_part(u jsonb,k text) returns jsonb language plpgsql immutable set search_path='' as $$
declare n numeric:=coalesce((u->>k)::numeric,0);p jsonb:=u#>array['powerLedger',k];
begin
 if p is null or coalesce((p->>'positive')::numeric,0)+coalesce((p->>'negative')::numeric,0)<>n then return jsonb_build_object('positive',greatest(0,n),'negative',least(0,n));end if;
 return p;
end $$;
create or replace function public._x_adjust(u jsonb,k text,delta numeric) returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public._x_part(u,k);pos numeric:=(p->>'positive')::numeric;neg numeric:=(p->>'negative')::numeric;
begin
 if delta>=0 then pos:=pos+delta;else neg:=neg+delta;end if;
 u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
 return jsonb_set(u,array[k],to_jsonb(pos+neg),true);
end $$;
create or replace function public._x_remove_buff(u jsonb,k text,amount numeric) returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public._x_part(u,k);pos numeric:=greatest(0,(p->>'positive')::numeric-amount);neg numeric:=(p->>'negative')::numeric;
begin
 u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
 return jsonb_set(u,array[k],to_jsonb(pos+neg),true);
end $$;
create or replace function public._x_clean_parts(u jsonb,remove_positive boolean default false) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;p jsonb;pos numeric;neg numeric;
begin
 foreach k in array array['bonus','powerShift','copyOffset','reviveOffset'] loop
  p:=public._x_part(u,k);pos:=case when remove_positive then 0 else (p->>'positive')::numeric end;neg:=case when remove_positive then (p->>'negative')::numeric else 0 end;
  u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
  u:=jsonb_set(u,array[k],to_jsonb(pos+neg),true);
 end loop;
 return u;
end $$;
create or replace function public._x_clean(u jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
begin u:=public._x_clean_parts(u);if coalesce((u->>'multiplier')::numeric,1)<1 then u:=jsonb_set(u,'{multiplier}','1'::jsonb);end if;return u;end $$;
create or replace function public._x_purge(u jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
begin
 u:=public._x_clean_parts(u,true)||jsonb_build_object('mutedEquipment',coalesce(u->'equipment','[]')||coalesce(u->'copiedEquipment','[]'),'equipmentMuted',false,'multiplier',least(1,coalesce((u->>'multiplier')::numeric,1)),'progress',0);
 if u ? 'greekBonusAmount' then u:=jsonb_set(u,'{greekBonusAmount}','0'::jsonb);end if;return u;
end $$;
create or replace function public._r_change(x jsonb,t text,id text,src text,amount numeric default 0,mult numeric default 1) returns jsonb language plpgsql immutable set search_path='' as $$
declare old_u jsonb:=public._r_unit(x->'s',t,id);new_u jsonb;recorded jsonb;
begin
 if old_u is null or amount<0 and public._x_block(x->'s',t,old_u,src,'reduce') then return x;end if;
 x:=public._r_change_before_remake(x,t,id,src,amount,mult);new_u:=public._r_unit(x->'s',t,id);
 if new_u is not null then
  recorded:=public._x_adjust(old_u,'bonus',coalesce((new_u->>'bonus')::numeric,0)-coalesce((old_u->>'bonus')::numeric,0));
  x:=public._r_set_unit(x,t,id,new_u||jsonb_build_object('powerLedger',recorded->'powerLedger'));
 end if;return x;
end $$;
do $ledger_hooks$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._x_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u));$a$,$b$u:=public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u));$b$);
 d:=replace(d,$a$u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+wanted-p);v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+p-wanted);$a$,$b$u:=public._x_adjust(u,'powerShift',wanted-p);v:=public._x_adjust(v,'powerShift',p-wanted);$b$);
 a:=$a$v:=v||jsonb_build_object('mutedEquipment',coalesce(v->'equipment','[]')||coalesce(v->'copiedEquipment','[]'),'equipmentMuted',false,'bonus',least(0,coalesce((v->>'bonus')::numeric,0)),'multiplier',least(1,coalesce((v->>'multiplier')::numeric,1)),'powerShift',least(0,coalesce((v->>'powerShift')::numeric,0)),'copyOffset',least(0,coalesce((v->>'copyOffset')::numeric,0)),'reviveOffset',least(0,coalesce((v->>'reviveOffset')::numeric,0)),'progress',0);$a$;
 d:=replace(d,a,'v:=public._x_purge(v);');execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+delta);$a$,$b$v:=public._x_adjust(v,'powerShift',delta);$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 if position('''powerLedger'',coalesce(target' in d)=0 then
  d:=replace(d,$a$'copiedEquipment',coalesce(target->'equipment'$a$,$b$'powerLedger',coalesce(target->'powerLedger','{}')-'copyOffset'-'reviveOffset','mutedEquipment',coalesce(target->'mutedEquipment','[]'),'copiedEquipment',coalesce(target->'equipment'$b$);
 end if;execute d;
 d:=pg_get_functiondef('public._r_reconcile(jsonb)'::regprocedure);
 d:=replace(d,$a$(u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)-coalesce((u->>'greekBonusAmount')::numeric,0)))$a$,$b$public._x_remove_buff(u,'bonus',coalesce((u->>'greekBonusAmount')::numeric,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_reconcile_before_remake(jsonb)'::regprocedure);
 d:=replace(d,$a$u:=u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)+3);$a$,$b$u:=public._x_adjust(u,'bonus',3);$b$);execute d;
end $ledger_hooks$;
