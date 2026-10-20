from pathlib import Path
import json,shutil
source_folder=Path(__file__).resolve().parent;site=source_folder.parents[1] if source_folder.name=='guardian-campaign' else source_folder.parent/'outputs/Mythic-Clash-Completo';folder=site/'_manutencao/guardian-campaign'
catalog=json.loads((folder/'catalogo-servidor.json').read_text(encoding='utf-8'))
data="create or replace function public._gc_data() returns jsonb language sql immutable set search_path='' as $$ select $guardian_catalog$"+json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+"$guardian_catalog$::jsonb $$;"
parts=[]
for name in ['schema','engine','api']:
 source=source_folder/f'guardian-campaign-{name}.sql'
 if source.resolve()!=(folder/source.name).resolve():shutil.copy2(source,folder/source.name)
 parts.append(source.read_text(encoding='utf-8').replace('__CATALOG__',data))
(site/'supabase/migrations/202610200045_guardian_world_campaign.sql').write_text('\n\n'.join(parts),encoding='utf-8')
prepare=source_folder/('preparar-campanha.py' if source_folder.name=='guardian-campaign' else 'preparar-campanha-guardiao.py')
if prepare.resolve()!=(folder/'preparar-campanha.py').resolve():shutil.copy2(prepare,folder/'preparar-campanha.py')
if Path(__file__).resolve()!=(folder/'compilar-campanha.py').resolve():shutil.copy2(Path(__file__),folder/'compilar-campanha.py')
print('Migração 045 compilada:',len(catalog['nodes']),'desafios.')
