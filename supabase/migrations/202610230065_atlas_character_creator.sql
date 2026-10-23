-- SQL 065 revisado: Kael com artes completas. Aplicar após 064.
-- Substitui o 065 rejeitado; pode também ser reaplicado se o anterior foi executado.
begin;
create table if not exists public.atlas_player_characters(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 config jsonb not null check(jsonb_typeof(config)='object'),portraits jsonb not null,
 revision uuid not null,updated_at timestamptz not null default now());
alter table public.atlas_player_characters enable row level security;
revoke all on public.atlas_player_characters from public,anon,authenticated;
grant all on public.atlas_player_characters to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('atlas-portraits','atlas-portraits',true,1048576,array['image/webp'])
on conflict(id) do update set public=true,file_size_limit=1048576,allowed_mime_types=array['image/webp'];
drop policy if exists atlas_portrait_insert on storage.objects;
create policy atlas_portrait_insert on storage.objects for insert to authenticated
with check(bucket_id='atlas-portraits' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists atlas_portrait_select on storage.objects;
create policy atlas_portrait_select on storage.objects for select to authenticated
using(bucket_id='atlas-portraits' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists atlas_portrait_delete on storage.objects;
create policy atlas_portrait_delete on storage.objects for delete to authenticated
using(bucket_id='atlas-portraits' and (storage.foldername(name))[1]=auth.uid()::text);

create or replace function public.get_atlas_character() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 select jsonb_build_object('config',config,'portraits',portraits,'revision',revision,'updated_at',updated_at) into result
 from public.atlas_player_characters where player_id=auth.uid();return result;
end $$;

create table if not exists public.atlas_character_catalog(
 asset_id text primary key, top integer not null, bottom integer not null, shoe integer not null, hair integer not null,
 enabled boolean not null default true, unique(top,bottom,shoe,hair));
alter table public.atlas_character_catalog enable row level security;
revoke all on public.atlas_character_catalog from public,anon,authenticated;
grant all on public.atlas_character_catalog to service_role;
insert into public.atlas_character_catalog(asset_id,top,bottom,shoe,hair) values
('01-couro-preto--01-preta--01-tunica-clara--curto',0,0,0,0),
('01-couro-preto--01-preta--01-tunica-clara--longo',0,0,0,2),
('01-couro-preto--01-preta--01-tunica-clara--medio',0,0,0,1),
('01-couro-preto--01-preta--02-camisa-vermelha--curto',1,0,0,0),
('01-couro-preto--01-preta--02-camisa-vermelha--longo',1,0,0,2),
('01-couro-preto--01-preta--02-camisa-vermelha--medio',1,0,0,1),
('01-couro-preto--01-preta--03-armadura-couro--curto',2,0,0,0),
('01-couro-preto--01-preta--03-armadura-couro--longo',2,0,0,2),
('01-couro-preto--01-preta--03-armadura-couro--medio',2,0,0,1),
('01-couro-preto--01-preta--04-traje-nordico--curto',3,0,0,0),
('01-couro-preto--01-preta--04-traje-nordico--longo',3,0,0,2),
('01-couro-preto--01-preta--04-traje-nordico--medio',3,0,0,1),
('01-couro-preto--01-preta--05-veste-egipcia--curto',4,0,0,0),
('01-couro-preto--01-preta--05-veste-egipcia--longo',4,0,0,2),
('01-couro-preto--01-preta--05-veste-egipcia--medio',4,0,0,1),
('01-couro-preto--01-preta--06-camisa-casual--curto',5,0,0,0),
('01-couro-preto--01-preta--06-camisa-casual--longo',5,0,0,2),
('01-couro-preto--01-preta--06-camisa-casual--medio',5,0,0,1),
('01-couro-preto--02-bege--01-tunica-clara--curto',0,1,0,0),
('01-couro-preto--02-bege--01-tunica-clara--longo',0,1,0,2),
('01-couro-preto--02-bege--01-tunica-clara--medio',0,1,0,1),
('01-couro-preto--02-bege--02-camisa-vermelha--curto',1,1,0,0),
('01-couro-preto--02-bege--02-camisa-vermelha--longo',1,1,0,2),
('01-couro-preto--02-bege--02-camisa-vermelha--medio',1,1,0,1),
('01-couro-preto--02-bege--03-armadura-couro--curto',2,1,0,0),
('01-couro-preto--02-bege--03-armadura-couro--longo',2,1,0,2),
('01-couro-preto--02-bege--03-armadura-couro--medio',2,1,0,1),
('01-couro-preto--02-bege--04-traje-nordico--curto',3,1,0,0),
('01-couro-preto--02-bege--04-traje-nordico--longo',3,1,0,2),
('01-couro-preto--02-bege--04-traje-nordico--medio',3,1,0,1),
('01-couro-preto--02-bege--05-veste-egipcia--curto',4,1,0,0),
('01-couro-preto--02-bege--05-veste-egipcia--longo',4,1,0,2),
('01-couro-preto--02-bege--05-veste-egipcia--medio',4,1,0,1),
('01-couro-preto--02-bege--06-camisa-casual--curto',5,1,0,0),
('01-couro-preto--02-bege--06-camisa-casual--longo',5,1,0,2),
('01-couro-preto--02-bege--06-camisa-casual--medio',5,1,0,1),
('01-couro-preto--03-azul--01-tunica-clara--curto',0,2,0,0),
('01-couro-preto--03-azul--01-tunica-clara--longo',0,2,0,2),
('01-couro-preto--03-azul--01-tunica-clara--medio',0,2,0,1),
('01-couro-preto--03-azul--02-camisa-vermelha--medio',1,2,0,1),
('01-couro-preto--03-azul--03-armadura-couro--medio',2,2,0,1),
('01-couro-preto--03-azul--04-traje-nordico--medio',3,2,0,1),
('01-couro-preto--03-azul--05-veste-egipcia--medio',4,2,0,1),
('01-couro-preto--03-azul--06-camisa-casual--medio',5,2,0,1),
('02-viajante-clara--01-preta--01-tunica-clara--medio',0,0,1,1),
('02-viajante-clara--01-preta--02-camisa-vermelha--medio',1,0,1,1),
('02-viajante-clara--01-preta--03-armadura-couro--medio',2,0,1,1),
('02-viajante-clara--01-preta--04-traje-nordico--medio',3,0,1,1),
('02-viajante-clara--01-preta--05-veste-egipcia--medio',4,0,1,1),
('02-viajante-clara--01-preta--06-camisa-casual--medio',5,0,1,1),
('02-viajante-clara--02-bege--01-tunica-clara--medio',0,1,1,1),
('02-viajante-clara--02-bege--02-camisa-vermelha--medio',1,1,1,1),
('02-viajante-clara--02-bege--03-armadura-couro--medio',2,1,1,1),
('02-viajante-clara--02-bege--04-traje-nordico--medio',3,1,1,1),
('02-viajante-clara--02-bege--05-veste-egipcia--medio',4,1,1,1),
('02-viajante-clara--02-bege--06-camisa-casual--medio',5,1,1,1),
('02-viajante-clara--03-azul--01-tunica-clara--medio',0,2,1,1),
('02-viajante-clara--03-azul--02-camisa-vermelha--medio',1,2,1,1),
('02-viajante-clara--03-azul--03-armadura-couro--medio',2,2,1,1),
('02-viajante-clara--03-azul--04-traje-nordico--medio',3,2,1,1),
('02-viajante-clara--03-azul--05-veste-egipcia--medio',4,2,1,1),
('02-viajante-clara--03-azul--06-camisa-casual--medio',5,2,1,1),
('03-combate-metal--01-preta--01-tunica-clara--medio',0,0,2,1),
('03-combate-metal--01-preta--02-camisa-vermelha--medio',1,0,2,1),
('03-combate-metal--01-preta--03-armadura-couro--medio',2,0,2,1),
('03-combate-metal--01-preta--04-traje-nordico--medio',3,0,2,1),
('03-combate-metal--01-preta--05-veste-egipcia--medio',4,0,2,1),
('03-combate-metal--01-preta--06-camisa-casual--medio',5,0,2,1),
('03-combate-metal--02-bege--01-tunica-clara--medio',0,1,2,1),
('03-combate-metal--02-bege--02-camisa-vermelha--medio',1,1,2,1),
('03-combate-metal--02-bege--03-armadura-couro--medio',2,1,2,1),
('03-combate-metal--02-bege--04-traje-nordico--medio',3,1,2,1),
('03-combate-metal--02-bege--05-veste-egipcia--medio',4,1,2,1),
('03-combate-metal--02-bege--06-camisa-casual--medio',5,1,2,1),
('03-combate-metal--03-azul--01-tunica-clara--medio',0,2,2,1),
('03-combate-metal--03-azul--02-camisa-vermelha--medio',1,2,2,1),
('03-combate-metal--03-azul--03-armadura-couro--medio',2,2,2,1),
('03-combate-metal--03-azul--04-traje-nordico--medio',3,2,2,1),
('03-combate-metal--03-azul--05-veste-egipcia--medio',4,2,2,1),
('03-combate-metal--03-azul--06-camisa-casual--medio',5,2,2,1)
on conflict(asset_id) do update set top=excluded.top,bottom=excluded.bottom,shoe=excluded.shoe,hair=excluded.hair,enabled=true;

create or replace function public.save_atlas_character(p_config jsonb,p_revision uuid,p_expected_revision uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); old public.atlas_player_characters%rowtype; config jsonb; paths jsonb:='{}';
 key text; upper_limit integer; pose text; file text; character_name text; art public.atlas_character_catalog%rowtype;
begin
 perform public._assert_account_active();perform public._security_rpc_gate('save_atlas_character',12);
 if who is null then raise exception 'Entre na conta.';end if;
 if p_config is null or jsonb_typeof(p_config)<>'object' or octet_length(p_config::text)>8192 or p_revision is null then raise exception 'Ficha inválida.';end if;
 perform pg_advisory_xact_lock(hashtextextended('atlas-character:'||who::text,65));
 select * into old from public.atlas_player_characters where player_id=who for update;
 if found and old.revision=p_revision then return public.get_atlas_character();end if;
 if old.revision is distinct from p_expected_revision then raise exception 'A aparência foi alterada em outro dispositivo. Reabra o criador para continuar.';end if;
 if p_config->>'version' is distinct from '2' then raise exception 'Atualize o criador de personagens.';end if;
 character_name:=btrim(regexp_replace(coalesce(p_config->>'name',''),'\s+',' ','g'));
 if char_length(character_name) not between 1 and 24 or character_name ~ '[[:cntrl:]<>]' then raise exception 'Use um nome de personagem com até 24 caracteres.';end if;
 config:=jsonb_build_object('version',2,'name',character_name,'skin','bronzeada','hairColor','castanho-original');
 foreach key in array array['top','bottom','shoe','hair','age','height'] loop
  if coalesce(p_config->>key,'') !~ '^[0-9]{1,3}$' then raise exception 'Valor inválido: %',key;end if;
  upper_limit:=case key when 'top' then 5 when 'bottom' then 2 when 'shoe' then 2 when 'hair' then 2 when 'age' then 100 else 220 end;
  if (p_config->>key)::integer>upper_limit or key='age' and (p_config->>key)::integer<18 or key='height' and (p_config->>key)::integer<140 then raise exception 'Opção fora do catálogo: %',key;end if;
  config:=config||jsonb_build_object(key,(p_config->>key)::integer);
 end loop;
 if p_config->>'skin' is distinct from 'bronzeada' or p_config->>'hairColor' is distinct from 'castanho-original' then raise exception 'Esta cor ainda não está disponível.';end if;
 select * into art from public.atlas_character_catalog where asset_id=p_config->>'assetId' and enabled
 and top=(config->>'top')::integer and bottom=(config->>'bottom')::integer and shoe=(config->>'shoe')::integer and hair=(config->>'hair')::integer;
 if not found then raise exception 'Esta combinação ainda não está disponível. Atualize o catálogo.';end if;
 config:=config||jsonb_build_object('assetId',art.asset_id);
 foreach pose in array array['normal','falando','rindo'] loop
  file:=who::text||'/'||p_revision::text||'/'||pose||'.webp';
  if not exists(select 1 from storage.objects where bucket_id='atlas-portraits' and name=file) then raise exception 'Falta salvar o retrato: %',pose;end if;
  paths:=paths||jsonb_build_object(pose,file);
 end loop;
 insert into public.atlas_player_characters(player_id,config,portraits,revision) values(who,config,paths,p_revision)
 on conflict(player_id) do update set config=excluded.config,portraits=excluded.portraits,revision=excluded.revision,updated_at=now();
 return public.get_atlas_character()||jsonb_build_object('previous_portraits',coalesce(old.portraits,'{}'));
end $$;

do $$ begin
 if to_regprocedure('public._start_guardian_before065(text,jsonb)') is null then alter function public.start_guardian_campaign(text,jsonb) rename to _start_guardian_before065;end if;
end $$;
revoke all on function public._start_guardian_before065(text,jsonb) from public,anon,authenticated;
create or replace function public.start_guardian_campaign(p_node_id text,p_cards jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public._assert_account_active();
 if auth.uid() is null or not exists(select 1 from public.atlas_player_characters where player_id=auth.uid() and config->>'version'='2') then raise exception 'Crie e salve seu personagem antes de começar a jornada.';end if;
 return public._start_guardian_before065(p_node_id,p_cards);
end $$;
revoke all on function public.get_atlas_character(),public.save_atlas_character(jsonb,uuid,uuid),public.start_guardian_campaign(text,jsonb) from public,anon;
grant execute on function public.get_atlas_character(),public.save_atlas_character(jsonb,uuid,uuid),public.start_guardian_campaign(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
