from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
s=s.replace('function power(x,t,u,depth=0){','function power(x,t,u,depth=0,raw=false){')
s=s.replace('if(enemy>p)p+=8;','if(enemy>power(x,t,u,1))p+=8;')
a='p=Math.max(0,Math.floor(p+(Number(u.powerShift)||0)));\n p=Math.max(0,Math.floor(p+(Number(u.copyOffset)||0)+(Number(u.reviveOffset)||0)));\n return p;'
b='p=p+(Number(u.powerShift)||0)+(Number(u.copyOffset)||0)+(Number(u.reviveOffset)||0);\n return raw?p:Math.max(0,Math.floor(p));'
assert a in s;s=s.replace(a,b)
s=s.replace("adjustPower(u,'powerShift',power(x,team,v)-power(x,t,u));", "adjustPower(u,'powerShift',power(x,team,v)-power(x,t,u,0,true));")
s=s.replace("adjustPower(u,'powerShift',b-a);adjustPower(ally,'powerShift',a-b);", "adjustPower(u,'powerShift',b-power(x,t,u,0,true));adjustPower(ally,'powerShift',a-power(x,t,ally,0,true));")
s=s.replace("adjustPower(v,'powerShift',values[i]-p);", "adjustPower(v,'powerShift',values[i]-power(x,team,v,0,true));")
s=s.replace('u.copyOffset=snapshot-power(x,t,u);', 'u.copyOffset=snapshot-power(x,t,u,0,true);')
s=s.replace('raised.reviveOffset=e.wantedPower-power(x,t,raised);', 'raised.reviveOffset=e.wantedPower-power(x,t,raised,0,true);')
s=s.replace('fresh.powerShift=Number(ruleFor(u).power||3)-power(x,t,fresh);', 'fresh.powerShift=Number(ruleFor(u).power||3)-power(x,t,fresh,0,true);')
s=s.replace("if(u.guardOwner&&['destroy','steal'].includes(kind))", "if(u.guardOwner&&globalActive(x,t,u)&&['destroy','steal'].includes(kind))")
p.write_text(s,encoding='utf-8')

sql="""
-- Keep the un-clamped total available for exact copy/swap/rebirth assignments.
do $exact_power$
declare d text;raw_d text;
begin
 d:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 d:=replace(d,$a$if enemy>p then p:=p+8;end if;$a$,$b$if enemy>public._r_power(s,t,u,1) then p:=p+8;end if;$b$);
 d:=replace(d,$a$p:=greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'powerShift')::numeric,0);$b$);
 execute d;
 raw_d:=replace(d,'FUNCTION public._r_power(','FUNCTION public._x_raw_power(');
 raw_d:=replace(raw_d,$a$p:=greatest(0,floor(p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0);$b$);
 execute raw_d;
 d:=pg_get_functiondef('public._x_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u))$a$,$b$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._x_raw_power(x->'s',t,u,0))$b$);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',wanted-p);v:=public._x_adjust(v,'powerShift',p-wanted)$a$,$b$public._x_adjust(u,'powerShift',wanted-public._x_raw_power(x->'s',t,u,0));v:=public._x_adjust(v,'powerShift',p-public._x_raw_power(x->'s',t,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(v,'powerShift',delta)$a$,$b$public._x_adjust(v,'powerShift',(vals->>i)::numeric-public._x_raw_power(x->'s',team,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,v)$a$,$b$wanted-public._x_raw_power(x->'s',t,v,0)$b$);
 d:=replace(d,$a$snapshot-public._r_power(x->'s',t,u)$a$,$b$snapshot-public._x_raw_power(x->'s',t,u,0)$b$);execute d;
 d:=pg_get_functiondef('public._r_destroy(jsonb,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$a$3-public._r_power(x->'s',t,v)$a$,$b$3-public._x_raw_power(x->'s',t,v,0)$b$);execute d;
 d:=pg_get_functiondef('public._x_block(jsonb,text,jsonb,text,text)'::regprocedure);
 d:=replace(d,$a$if u ? 'guardOwner' and k in$a$,$b$if u ? 'guardOwner' and public._x_global(s,t,u) and k in$b$);execute d;
end $exact_power$;
"""
(root/'work/ability-exact-power.sql').write_text(sql,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if '$exact_power$' not in s:s=s.replace('do $acl$',sql+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
s=s.replace('- **Cartas pausadas:**','- **Poder exato:** cópias, trocas, Anúbis e renascimento calculam a diferença antes do limite mínimo de zero. Isso evita que uma penalidade oculta abaixo de zero faça uma cópia de poder 5 terminar com 4, por exemplo.\n- **Ômega:** compara a força inimiga com seu poder completo sem o próprio bônus condicional, incluindo clima, terreno e auras.\n- **Proteção e Dionísio:** a proteção temporária de Chang’e também fica suspensa quando os efeitos da unidade estão globalmente silenciados.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
print('Exact power assignments and full Omega comparison updated.')
