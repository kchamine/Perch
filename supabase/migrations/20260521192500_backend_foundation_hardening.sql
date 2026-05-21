-- Hardening pass after first live Supabase advisor run.
-- Keeps trigger helpers private and optimizes auth.uid() calls in RLS policies.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.create_profile_for_new_user() from public;
revoke execute on function public.create_profile_for_new_user() from anon;
revoke execute on function public.create_profile_for_new_user() from authenticated;

drop policy if exists profiles_owner_insert on public.profiles;
create policy profiles_owner_insert
  on public.profiles
  for insert
  with check (user_id = (select auth.uid()));

drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update
  on public.profiles
  for update
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists profiles_owner_delete on public.profiles;
create policy profiles_owner_delete
  on public.profiles
  for delete
  using (user_id = (select auth.uid()));

drop policy if exists spots_public_or_owner_read on public.spots;
create policy spots_public_or_owner_read
  on public.spots
  for select
  using (is_private = false or owner_user_id = (select auth.uid()));

drop policy if exists spots_owner_insert on public.spots;
create policy spots_owner_insert
  on public.spots
  for insert
  with check (owner_user_id = (select auth.uid()));

drop policy if exists spots_owner_update on public.spots;
create policy spots_owner_update
  on public.spots
  for update
  using (owner_user_id = (select auth.uid()))
  with check (owner_user_id = (select auth.uid()));

drop policy if exists spots_owner_delete on public.spots;
create policy spots_owner_delete
  on public.spots
  for delete
  using (owner_user_id = (select auth.uid()));

drop policy if exists reviews_visible_spot_or_author_read on public.reviews;
create policy reviews_visible_spot_or_author_read
  on public.reviews
  for select
  using (
    author_user_id = (select auth.uid())
    or exists (
      select 1
      from public.spots
      where spots.id = reviews.spot_id
        and (spots.is_private = false or spots.owner_user_id = (select auth.uid()))
    )
  );

drop policy if exists reviews_author_insert on public.reviews;
create policy reviews_author_insert
  on public.reviews
  for insert
  with check (
    author_user_id = (select auth.uid())
    and exists (
      select 1
      from public.spots
      where spots.id = reviews.spot_id
        and (spots.is_private = false or spots.owner_user_id = (select auth.uid()))
    )
  );

drop policy if exists reviews_author_update on public.reviews;
create policy reviews_author_update
  on public.reviews
  for update
  using (author_user_id = (select auth.uid()))
  with check (author_user_id = (select auth.uid()));

drop policy if exists reviews_author_delete on public.reviews;
create policy reviews_author_delete
  on public.reviews
  for delete
  using (author_user_id = (select auth.uid()));

drop policy if exists favorites_owner_read on public.favorites;
create policy favorites_owner_read
  on public.favorites
  for select
  using (user_id = (select auth.uid()));

drop policy if exists favorites_owner_insert on public.favorites;
create policy favorites_owner_insert
  on public.favorites
  for insert
  with check (user_id = (select auth.uid()));

drop policy if exists favorites_owner_delete on public.favorites;
create policy favorites_owner_delete
  on public.favorites
  for delete
  using (user_id = (select auth.uid()));

drop policy if exists user_preferences_owner_read on public.user_preferences;
create policy user_preferences_owner_read
  on public.user_preferences
  for select
  using (user_id = (select auth.uid()));

drop policy if exists user_preferences_owner_insert on public.user_preferences;
create policy user_preferences_owner_insert
  on public.user_preferences
  for insert
  with check (user_id = (select auth.uid()));

drop policy if exists user_preferences_owner_update on public.user_preferences;
create policy user_preferences_owner_update
  on public.user_preferences
  for update
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists user_preferences_owner_delete on public.user_preferences;
create policy user_preferences_owner_delete
  on public.user_preferences
  for delete
  using (user_id = (select auth.uid()));
