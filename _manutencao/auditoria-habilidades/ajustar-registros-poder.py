from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
helpers="""function powerPart(u,key){const n=Number(u[key])||0;u.powerLedger=u.powerLedger||{};let v=u.powerLedger[key];if(!v||v.positive+v.negative!==n)v=u.powerLedger[key]={positive:Math.max(0,n),negative:Math.min(0,n)};return v;}
function adjustPower(u,key,delta){const v=powerPart(u,key);if(delta>=0)v.positive+=delta;else v.negative+=delta;u[key]=v.positive+v.negative;}
function removePowerBuff(u,key,amount){const v=powerPart(u,key);v.positive=Math.max(0,v.positive-amount);u[key]=v.positive+v.negative;}
function cleanPower(u,positive=false){for(const key of ['bonus','powerShift','copyOffset','reviveOffset']){const v=powerPart(u,key);if(positive)v.positive=0;else v.negative=0;u[key]=v.positive+v.negative;}}
"""
if 'function powerPart(' not in s:s=s.replace('function remakeCleanse(u){',helpers+'function remakeCleanse(u){')
a="function remakeCleanse(u){if(u.bonus<0)u.bonus=0;if(u.powerShift<0)u.powerShift=0;if(u.multiplier<1)u.multiplier=1;if(u.copyOffset<0)u.copyOffset=0;if(u.reviveOffset<0)u.reviveOffset=0;}"
b="function remakeCleanse(u){cleanPower(u);if(u.multiplier<1)u.multiplier=1;}"
assert a in s;s=s.replace(a,b)
s=s.replace('u.bonus+=amount;u.multiplier*=mult;',"adjustPower(u,'bonus',amount);u.multiplier*=mult;")
s=s.replace('u.bonus-=u.greekBonusAmount||0;',"removePowerBuff(u,'bonus',u.greekBonusAmount||0);")
s=s.replace('u.bonus+=3;u.sourceCardId',"adjustPower(u,'bonus',3);u.sourceCardId")
s=s.replace('u.powerShift=(u.powerShift||0)+power(x,team,v)-power(x,t,u);',"adjustPower(u,'powerShift',power(x,team,v)-power(x,t,u));")
s=s.replace('u.powerShift=(u.powerShift||0)+b-a;ally.powerShift=(ally.powerShift||0)+a-b;',"adjustPower(u,'powerShift',b-a);adjustPower(ally,'powerShift',a-b);")
s=s.replace('v.powerShift=(v.powerShift||0)+values[i]-p;',"adjustPower(v,'powerShift',values[i]-p);")
a='enemy.bonus=Math.min(0,enemy.bonus||0);enemy.multiplier=Math.min(1,enemy.multiplier||1);enemy.powerShift=Math.min(0,enemy.powerShift||0);enemy.copyOffset=Math.min(0,enemy.copyOffset||0);enemy.reviveOffset=Math.min(0,enemy.reviveOffset||0);enemy.progress=0;'
b='cleanPower(enemy,true);enemy.multiplier=Math.min(1,enemy.multiplier||1);enemy.progress=0;if(enemy.greekBonusAmount)enemy.greekBonusAmount=0;'
assert a in s;s=s.replace(a,b)
s=s.replace('u.copiedEquipment=[...(target.equipment||[]),',"u.powerLedger=copy(target.powerLedger||{});delete u.powerLedger.copyOffset;delete u.powerLedger.reviveOffset;u.copiedEquipment=[...(target.equipment||[]),")
p.write_text(s,encoding='utf-8')
print('Positive and negative power adjustments now tracked separately.')
