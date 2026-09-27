-- Editor visual de cartas: arte pública, edição restrita ao administrador.
begin;

alter table public.card_lore
  add column if not exists card_name text,
  add column if not exists ability_title text,
  add column if not exists ability_text text,
  add column if not exists art_url text,
  add column if not exists source_art_url text,
  add column if not exists faction text,
  add column if not exists power integer,
  add column if not exists badge_key text;

alter table public.card_lore drop constraint if exists card_lore_power_range;
alter table public.card_lore add constraint card_lore_power_range check (power is null or power between 0 and 99);
alter table public.card_lore drop constraint if exists card_lore_badge_key_allowed;
alter table public.card_lore add constraint card_lore_badge_key_allowed
  check (badge_key is null or badge_key in ('greece','norse','egypt','celtic','monster','alyans'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mythic-card-art','mythic-card-art',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/png','image/jpeg','image/webp'];

drop policy if exists "Public reads Mythic card art" on storage.objects;
create policy "Public reads Mythic card art" on storage.objects for select to anon,authenticated
  using (bucket_id='mythic-card-art');
drop policy if exists "Admins upload Mythic card art" on storage.objects;
create policy "Admins upload Mythic card art" on storage.objects for insert to authenticated
  with check (bucket_id='mythic-card-art' and public.is_site_admin());
drop policy if exists "Admins update Mythic card art" on storage.objects;
create policy "Admins update Mythic card art" on storage.objects for update to authenticated
  using (bucket_id='mythic-card-art' and public.is_site_admin())
  with check (bucket_id='mythic-card-art' and public.is_site_admin());
drop policy if exists "Admins delete Mythic card art" on storage.objects;
create policy "Admins delete Mythic card art" on storage.objects for delete to authenticated
  using (bucket_id='mythic-card-art' and public.is_site_admin());

commit;
