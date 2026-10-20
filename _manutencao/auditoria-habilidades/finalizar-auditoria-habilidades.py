from pathlib import Path
import json,re,shutil
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'app.js';s=p.read_text(encoding='utf-8').replace('zoneOwners:duel.zoneOwners||{},','zoneOwners:duel.zoneOwners||{},zoneCards:duel.zoneCards||duel.rulesState?.zoneCards||{},').replace('["sharedZones","zoneOwners",','["sharedZones","zoneOwners","zoneCards",');p.write_text(s,encoding='utf-8')
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
s=s.replace("title:titles[e.op]||'Escolha o alvo'", "title:e.op==='remake'?(C[identity(x.s[e.team].field.find(v=>v.uid===e.uid)||{})]?.name||'Habilidade')+' — '+({lane:'Escolha a fileira',order:'Escolha a próxima carta',draft:'Escolha uma carta',shiva:'Escolha entre as unidades empatadas',finish:'Habilidade resolvida'}[e.phase]||'Escolha o alvo'):titles[e.op]||'Escolha o alvo'")
p.write_text(s,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8').replace("('location','terrain','climate','event')", "('location','terrain','climate','event','weather')")
patch="""
-- Re-check the current legal choices before applying a previously issued selection.
do $choice_guard$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);
 a:=$old$if not exists(select 1 from jsonb_array_elements(pending->'options') v where v->>'value'=a->>'choice_value') then raise exception 'Escolha inválida.';end if;$old$;
 b:=a||$new$ /* choice_guard_v44 */ if not exists(select 1 from jsonb_array_elements(public._r_options(x,pending->'event')) v where v->>'value'=a->>'choice_value') then raise exception 'Essa escolha não está mais disponível.';end if;$new$;
 if position('choice_guard_v44' in d)=0 then
  if position(a in d)=0 then raise exception 'Validação de escolhas incompatível; nenhuma alteração aplicada.';end if;
  execute replace(d,a,b);
 end if;
end $choice_guard$;
"""
if 'choice_guard_v44' not in s:s=s.replace('do $acl$',patch+'\ndo $acl$')
p.write_text(s,encoding='utf-8')

data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'));rules=json.loads((site/'remake-rules.json').read_text(encoding='utf-8'))
intro='''# Revisão das habilidades — 20/10/2026

## Alcance e limites

Revisão do código e do catálogo completo, incluindo unidades, equipamentos, Locais, Terrenos, Clima, formas especiais e clones. Os motores local e online foram comparados. A revisão não equivale a uma sessão de partidas reais: esta entrega não foi executada no banco de produção nem submetida a testes de partidas.

## Correções desta entrega

- **Chang’e:** a proteção permanece durante as jogadas intermediárias e termina no início do próximo turno do invocador. A repetição da fase inicial no mesmo turno não a remove.
- **Enlil:** pode escolher qualquer outro aliado; apenas o bônus de +2 depende de ele ser Mesopotâmico.
- **Shiva:** não pede escolha quando existe apenas um menor alvo elegível. Em empate, o invocador decide o lado aliado e um dono das unidades empatadas decide o lado inimigo. Em duplas, a escolha representa o campo da equipe.
- **Locais, Terrenos e Climas:** registram o jogador de origem e vão ao Submundo ao serem substituídos ou ao fechar o Round. Isso torna recuperações como Enki possíveis. Eclipse guarda a carta original, não entrega uma forma especial para a mão. Partidas iniciadas antes desta atualização não permitem reconstruir com segurança o dono de zonas antigas.
- **Escolhas:** a seleção é conferida novamente contra as opções legais; a interface impede envios duplicados durante a requisição e permite tentar novamente em caso de falha.
- **Retorno de tokens:** um clone devolvido à mão desaparece, sem se tornar uma carta permanente.
- **Cartas pausadas:** uma invocação bloqueada não devolve o objeto de estado como se fosse uma unidade.

## Critérios usados

- **Entrada:** acontece uma vez ao entrar, salvo quando a ressurreição declara ativar a entrada. Roubo e movimento não repetem entradas.
- **Aura:** recalculada com a fileira, identidade e habilidade ativas. Entradas futuras recebem o efeito; saída, silêncio ou mudança de fileira remove a parcela contínua.
- **Bônus recebido:** permanece até o fim do Round, salvo regra expressa. Aquiles perde definitivamente seu bônus de entrada ao sair da fileira em que o recebeu.
- **Poder:** limites de alvos usam poder atual; recuperações que dizem poder base usam o valor impresso. Anúbis considera o poder atual da vítima e o poder registrado no Submundo.
- **Proteções:** Heimdall bloqueia efeitos inimigos sobre a fileira; Medusa age contra o jogador. Durga, Vishnu, Curupira, Chang’e e Boitatá respeitam seus tipos de proteção e não bloqueiam sacrifícios aliados.
- **Silêncio:** Morgana/Cuca desligam a habilidade própria. Equipamentos, bônus recebidos e auras externas permanecem. Dionísio suspende efeitos por 3 jogadas subsequentes, exceto resistências previstas por Heimdall. Utu e Ganesha removem o silêncio dos alvos indicados.
- **Duplas:** mão, deck, compras e Submundo pessoal respeitam o jogador; a fileira é da equipe. Hórus revela informação somente ao invocador. Medusa passa o próximo turno dos dois inimigos.
- **Uma vez por Round:** ressurreição conserva os marcadores já gastos de renascimento, salvamento e luto. A troca de Round limpa esses marcadores.
- **Sem alvo:** encerra apenas o efeito sem alvo; não inventa um alvo inválido. Efeitos independentes, como comprar antes de mover, continuam acontecendo.
- **Escolhas opcionais:** podem concluir sem alvo quando a carta diz “pode” ou “até”. Reordenações mantêm as cartas não compradas na ordem escolhida.
- **Equipamentos:** uma cópia por portador; destruir ou devolver equipamento respeita a origem em duplas. Ressuscitar a unidade não devolve seus equipamentos.
- **Rounds:** poder e soma são independentes por Round. Limpeza de campo ao encerrá-lo não conta como destruição para Osíris/Cú Chulainn/Xipe.

## Instalação

Com as migrações anteriores até 043 aplicadas, executar `supabase/migrations/202610200044_ability_interaction_audit.sql`. Para instalação nova, seguir toda a sequência até 044. Publicar também os arquivos atualizados do site. Não reaplicar somente a 040 sobre um banco já atualizado até 044.

## Catálogo revisado

Texto vigente e mecanismo de cada carta. “Entrada” significa seleção/execução pela fila de habilidades; “contínuo” significa recalcular enquanto a fonte estiver ativa. A ficha impressa prevalece sobre inferências pelo nome.

'''
parts=[intro]
for faction in dict.fromkeys(c.get('faction','Outras') for c in data['cards']):
 parts.append('### '+faction+'\n\n')
 for c in data['cards']:
  if c.get('faction','Outras')!=faction:continue
  r=rules.get(c['id']);ops=data['entries'].get(c['id'],[])
  mechanism=('Entrada: '+r['op'] if 'remake' in ops else 'Contínuo/gatilho: '+r['op']) if r else ('Entrada: '+', '.join(ops) if ops else 'Contínuo, equipamento, zona ou regra própria')
  parts.append('#### '+c['name']+'\n\n**'+c.get('abilityTitle','Habilidade')+'** · Poder '+str(c.get('power',0))+' · '+mechanism+'.\n\n'+c.get('ability','Sem habilidade.')+'\n\n')
(site/'REVISAO-HABILIDADES.md').write_text(''.join(parts),encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades';out.mkdir(exist_ok=True)
for f in ['auditar-habilidades-v44.py','ability-audit-zones.sql','finalizar-auditoria-habilidades.py']:shutil.copy2(root/'work'/f,out/f)
print('Review document:',len(data['cards']),'cards. Incremental SQL 044 prepared.')
