from pathlib import Path
import json
maintenance=Path(__file__).resolve().parent;site=maintenance.parents[1]
data=json.loads((site/'abilities-data.json').read_text(encoding='utf-8'))
data['remakeRules']=json.loads((site/'remake-rules.json').read_text(encoding='utf-8'))
cards={c['id']:c for c in data['cards']}
rows=json.loads((site/'cards-remake.json').read_text(encoding='utf-8'))['cards']
def sql(s):return "'"+str(s).replace("'","''")+"'"
catalog='alter table public.card_lore drop constraint if exists card_lore_card_id_check;\n'
catalog+='alter table public.card_lore add constraint card_lore_card_id_check check(card_id in ('+','.join(sql(cid) for cid in cards)+'));\n'
badge_keys=sorted({'greece','norse','egypt','celtic','monster','alyans'}|{c['badgeKey'] for c in cards.values() if c.get('badgeKey')})
catalog+='alter table public.card_lore drop constraint if exists card_lore_badge_key_allowed;\n'
catalog+='alter table public.card_lore add constraint card_lore_badge_key_allowed check(badge_key is null or badge_key in ('+','.join(sql(key) for key in badge_keys)+'));\n'
catalog+='create or replace function public._r_card(cid text) returns jsonb language sql immutable set search_path=\'\' as $$ select coalesce($remake$'+json.dumps(cards,ensure_ascii=False,separators=(',',':'))+"$remake$::jsonb->cid,'{}'::jsonb) $$;\n"
catalog+="create or replace function public._r_data() returns jsonb language sql immutable set search_path='' as $$ select $remake$"+json.dumps(data,ensure_ascii=False,separators=(',',':'))+"$remake$::jsonb $$;\n"
catalog+='insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values\n'
catalog+=',\n'.join('('+','.join([sql(c['id']),sql(c['name']),sql(c['abilityTitle']),sql(c['ability']),sql(c['art']),sql(c['faction']),str(c['power']),sql(c.get('badgeKey',''))])+')' for c in rows)
catalog+='\non conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key;\n'
# Follow the existing price of 1000 MC; preserve per-item prices and pauses.
catalog+='insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active) values\n'
catalog+=',\n'.join('('+','.join([sql('card-'+c['id']),sql(c['name']),sql(c['ability']),'\'card\'','1000',sql(c['art']),sql(c['id']),'true'])+')' for c in rows if not c.get('specialOnly'))
catalog+='\non conflict(item_id) do update set title=excluded.title,description=excluded.description,asset_path=excluded.asset_path,card_id=excluded.card_id;\n'
hooks=(maintenance/'remake-server-hooks.sql').read_text(encoding='utf-8')+'\n'+(maintenance/'remake-foreign-choices.sql').read_text(encoding='utf-8')+'\n'+(maintenance/'remake-legacy-protections.sql').read_text(encoding='utf-8')+'\n'+(maintenance/'remake-choice-timeout.sql').read_text(encoding='utf-8')+'\n'+(maintenance/'remake-local-silence.sql').read_text(encoding='utf-8')+'\n'+(maintenance/'remake-round-memory.sql').read_text(encoding='utf-8')
sql_text=(maintenance/'remake-server.sql').read_text(encoding='utf-8').replace('__CATALOG__',catalog).replace('__HOOKS__',hooks)
(site/'supabase/migrations/202610200040_remake_character_collection.sql').write_text(sql_text,encoding='utf-8')
print('Migração 040 preparada:',len(rows),'cartas e',len(data['remakeRules']),'regras.',flush=True)
