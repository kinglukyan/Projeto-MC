from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=root/'work/ability-power-ledger.sql';s=p.read_text(encoding='utf-8')
a='end $ledger_hooks$;'
b=""" d:=pg_get_functiondef('public._r_reconcile_before_remake(jsonb)'::regprocedure);
 d:=replace(d,$a$u:=u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)+3);$a$,$b$u:=public._x_adjust(u,'bonus',3);$b$);execute d;
end $ledger_hooks$;"""
if "_r_reconcile_before_remake" not in s:s=s.replace(a,b);p.write_text(s,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
if 'function public._x_part' not in s:s=s.replace('do $acl$',(root/'work/ability-power-ledger.sql').read_text(encoding='utf-8')+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8').replace('const ability=u=>u.copiedAbilityId||u.cardId,','const ability=u=>u?.copiedAbilityId||u?.cardId,');p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8')
if '**Limpeza de poder:**' not in s:s=s.replace('- **Cartas pausadas:**','- **Limpeza de poder:** bônus e penalidades passam a ser registrados separadamente. Exemplo: +4 e -2 resultam em +2; limpar a redução deixa +4, enquanto remover o bônus deixa -2. Vale também para ajustes por troca de poder e cópias; Aquiles não perde seu bônus duas vezes se Erlang o remover antes de ele mudar de fileira. O saldo anterior de partidas já iniciadas não permite reconstruir as parcelas que se anularam; a separação vale para novos ajustes.\n- **Cartas pausadas:**')
p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades';out.mkdir(exist_ok=True)
for n in ['ability-power-ledger.sql','concluir-registros-poder.py','ajustar-registros-poder.py','ajustar-efeitos-silenciosos.py']:shutil.copy2(root/'work'/n,out/n)
print('Power history integrated into migration 044 and review notes.')
