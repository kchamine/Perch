-- Perch Storage buckets for portable spot photos and profile avatars.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  ('spot-photos', 'spot-photos', true, 5242880, array['image/jpeg']),
  ('user-avatars', 'user-avatars', true, 5242880, array['image/jpeg'])
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types,
  updated_at = now();

drop policy if exists perch_storage_public_read on storage.objects;
create policy perch_storage_public_read
  on storage.objects
  for select
  using (bucket_id in ('spot-photos', 'user-avatars'));

drop policy if exists perch_storage_authenticated_insert on storage.objects;
create policy perch_storage_authenticated_insert
  on storage.objects
  for insert
  with check (
    bucket_id in ('spot-photos', 'user-avatars')
    and auth.role() = 'authenticated'
  );

drop policy if exists perch_storage_owner_update on storage.objects;
create policy perch_storage_owner_update
  on storage.objects
  for update
  using (
    bucket_id in ('spot-photos', 'user-avatars')
    and owner_id = auth.uid()::text
  )
  with check (
    bucket_id in ('spot-photos', 'user-avatars')
    and owner_id = auth.uid()::text
  );

drop policy if exists perch_storage_owner_delete on storage.objects;
create policy perch_storage_owner_delete
  on storage.objects
  for delete
  using (
    bucket_id in ('spot-photos', 'user-avatars')
    and owner_id = auth.uid()::text
  );
