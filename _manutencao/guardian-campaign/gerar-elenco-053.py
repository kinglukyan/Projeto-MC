"""Atualiza o catálogo público e a migração 053 a partir do catálogo servidor atual."""
from pathlib import Path
import json,re
site=Path(__file__).resolve().parents[2]
catalog=json.loads((site/'_manutencao/guardian-campaign/catalogo-servidor.json').read_text(encoding='utf-8-sig'))
public={**{k:v for k,v in catalog.items() if k not in ('impact','cards')},'nodes':{k:{a:b for a,b in n.items() if a!='deck'} for k,n in catalog['nodes'].items()}}
(site/'guardian-campaign-data.js').write_text('window.MythicGuardianCampaignData='+json.dumps(public,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
schema=(site/'_manutencao/guardian-campaign/guardian-campaign-schema.sql').read_text(encoding='utf-8-sig')
deck=re.search(r'create or replace function public\._gc_deck\(.*?end \$\$;',schema,re.S).group()
sql='''-- 053: Greek roster. Apply after 052. No progress, histories or reward claims are reset.
begin;
do $prerequisite$
begin
 if to_regprocedure('public._match_reward(text,text)') is null then
  raise exception 'Aplique primeiro a migração 052, depois execute a 053 completa.';
 end if;
end $prerequisite$;
create or replace function public._gc_data() returns jsonb language sql immutable set search_path='' as $$ select $guardian_catalog$'''+json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'''$guardian_catalog$::jsonb $$;
'''+deck+'''
revoke all on function public._gc_data(),public._gc_deck(text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
'''
(site/'supabase/migrations/202610210053_greek_roster_placeholders.sql').write_text(sql,encoding='utf-8')
print('Catálogo público e migração 053 preparados.')
