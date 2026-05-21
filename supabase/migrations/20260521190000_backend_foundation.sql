-- Perch Supabase backend foundation.
-- Applies the v1 schema, indexes, triggers, and row-level security policies
-- for auth-backed profile, spot, review, favorite, and preference sync.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null default 'Perch Keeper',
  username text not null,
  bio text,
  home_neighborhood text,
  avatar_url text,
  avatar_symbol text,
  perch_style text,
  favorite_moment text,
  default_review_name text,
  maps_app_preference text not null default 'appleMaps',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_min_length check (char_length(btrim(username)) >= 3),
  constraint profiles_default_review_name_check check (
    default_review_name is null
    or default_review_name in ('firstNameOnly', 'username', 'fullName')
  ),
  constraint profiles_maps_app_preference_check check (
    maps_app_preference in ('appleMaps', 'googleMaps')
  )
);

create unique index if not exists profiles_username_unique_lower_idx
  on public.profiles (lower(username));

create table if not exists public.spots (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  subtitle text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  spot_type text not null,
  seating_type text not null,
  has_seating boolean not null default true,
  shade_level text not null,
  noise_level text not null,
  crowd_level text not null,
  view_type text not null,
  best_time text not null,
  accessibility text not null,
  access_effort text not null,
  comfort_rating integer not null,
  scenic_rating integer not null,
  public_access_confirmed boolean not null default false,
  is_private boolean not null default false,
  photo_url text,
  notes text not null default '',
  last_confirmed timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint spots_latitude_range check (latitude between -90 and 90),
  constraint spots_longitude_range check (longitude between -180 and 180),
  constraint spots_comfort_rating_range check (comfort_rating between 1 and 5),
  constraint spots_scenic_rating_range check (scenic_rating between 1 and 5),
  constraint spots_spot_type_check check (
    spot_type in ('bench', 'overlook', 'picnicSeat', 'plazaSeat', 'parkEdge', 'waterfront', 'courtyard')
  ),
  constraint spots_seating_type_check check (
    seating_type in ('bench', 'chair', 'picnicTable', 'ledge', 'mixed')
  ),
  constraint spots_shade_level_check check (
    shade_level in ('sunny', 'partial', 'shaded')
  ),
  constraint spots_noise_level_check check (
    noise_level in ('quiet', 'moderate', 'lively')
  ),
  constraint spots_crowd_level_check check (
    crowd_level in ('low', 'medium', 'high')
  ),
  constraint spots_view_type_check check (
    view_type in ('water', 'skyline', 'park', 'hill', 'street', 'mixed')
  ),
  constraint spots_best_time_check check (
    best_time in ('sunrise', 'morning', 'midday', 'afternoon', 'sunset', 'evening')
  ),
  constraint spots_accessibility_check check (
    accessibility in ('wheelchairFriendly', 'stepFree', 'limited', 'unknown')
  ),
  constraint spots_access_effort_check check (
    access_effort in ('easy', 'shortWalk', 'moderate')
  )
);

create index if not exists spots_owner_user_id_idx
  on public.spots (owner_user_id);

create index if not exists spots_latitude_longitude_idx
  on public.spots (latitude, longitude);

create index if not exists spots_public_explore_idx
  on public.spots (is_private, latitude, longitude, updated_at);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null,
  title text not null,
  note text not null default '',
  settle_in_ease integer not null,
  stay_comfort integer not null,
  view_payoff integer not null,
  calm_factor integer not null,
  would_return boolean not null default true,
  best_for text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_settle_in_ease_range check (settle_in_ease between 1 and 5),
  constraint reviews_stay_comfort_range check (stay_comfort between 1 and 5),
  constraint reviews_view_payoff_range check (view_payoff between 1 and 5),
  constraint reviews_calm_factor_range check (calm_factor between 1 and 5),
  constraint reviews_best_for_values_check check (
    best_for <@ array[
      'soloReset',
      'reading',
      'coffeeBreak',
      'sunsetPause',
      'peopleWatching',
      'quickBreather'
    ]::text[]
  )
);

create index if not exists reviews_spot_id_idx
  on public.reviews (spot_id);

create index if not exists reviews_author_user_id_idx
  on public.reviews (author_user_id);

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

create index if not exists favorites_user_id_idx
  on public.favorites (user_id);

create index if not exists favorites_spot_id_idx
  on public.favorites (spot_id);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  quiet_only boolean not null default false,
  shaded_only boolean not null default false,
  sunset_only boolean not null default false,
  accessible_only boolean not null default false,
  easy_access_only boolean not null default false,
  favorites_only boolean not null default false,
  nearby_only boolean not null default true,
  updated_at timestamptz not null default now()
);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists spots_set_updated_at on public.spots;
create trigger spots_set_updated_at
  before update on public.spots
  for each row execute function public.set_updated_at();

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();

drop trigger if exists user_preferences_set_updated_at on public.user_preferences;
create trigger user_preferences_set_updated_at
  before update on public.user_preferences
  for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
begin
  base_username := lower(regexp_replace(split_part(new.email, '@', 1), '[^a-zA-Z0-9_-]', '', 'g'));

  insert into public.profiles (
    user_id,
    display_name,
    username,
    avatar_symbol,
    default_review_name
  )
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), 'Perch Keeper'),
    coalesce(nullif(base_username, ''), 'perch') || '-' || left(replace(new.id::text, '-', ''), 8),
    'leaf.circle.fill',
    'firstNameOnly'
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_perch_profile on auth.users;
create trigger on_auth_user_created_create_perch_profile
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.spots enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.user_preferences enable row level security;

drop policy if exists profiles_public_read on public.profiles;
create policy profiles_public_read
  on public.profiles
  for select
  using (true);

drop policy if exists profiles_owner_insert on public.profiles;
create policy profiles_owner_insert
  on public.profiles
  for insert
  with check (user_id = auth.uid());

drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update
  on public.profiles
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists profiles_owner_delete on public.profiles;
create policy profiles_owner_delete
  on public.profiles
  for delete
  using (user_id = auth.uid());

drop policy if exists spots_public_or_owner_read on public.spots;
create policy spots_public_or_owner_read
  on public.spots
  for select
  using (is_private = false or owner_user_id = auth.uid());

drop policy if exists spots_owner_insert on public.spots;
create policy spots_owner_insert
  on public.spots
  for insert
  with check (owner_user_id = auth.uid());

drop policy if exists spots_owner_update on public.spots;
create policy spots_owner_update
  on public.spots
  for update
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists spots_owner_delete on public.spots;
create policy spots_owner_delete
  on public.spots
  for delete
  using (owner_user_id = auth.uid());

drop policy if exists reviews_visible_spot_or_author_read on public.reviews;
create policy reviews_visible_spot_or_author_read
  on public.reviews
  for select
  using (
    author_user_id = auth.uid()
    or exists (
      select 1
      from public.spots
      where spots.id = reviews.spot_id
        and (spots.is_private = false or spots.owner_user_id = auth.uid())
    )
  );

drop policy if exists reviews_author_insert on public.reviews;
create policy reviews_author_insert
  on public.reviews
  for insert
  with check (
    author_user_id = auth.uid()
    and exists (
      select 1
      from public.spots
      where spots.id = reviews.spot_id
        and (spots.is_private = false or spots.owner_user_id = auth.uid())
    )
  );

drop policy if exists reviews_author_update on public.reviews;
create policy reviews_author_update
  on public.reviews
  for update
  using (author_user_id = auth.uid())
  with check (author_user_id = auth.uid());

drop policy if exists reviews_author_delete on public.reviews;
create policy reviews_author_delete
  on public.reviews
  for delete
  using (author_user_id = auth.uid());

drop policy if exists favorites_owner_read on public.favorites;
create policy favorites_owner_read
  on public.favorites
  for select
  using (user_id = auth.uid());

drop policy if exists favorites_owner_insert on public.favorites;
create policy favorites_owner_insert
  on public.favorites
  for insert
  with check (user_id = auth.uid());

drop policy if exists favorites_owner_delete on public.favorites;
create policy favorites_owner_delete
  on public.favorites
  for delete
  using (user_id = auth.uid());

drop policy if exists user_preferences_owner_read on public.user_preferences;
create policy user_preferences_owner_read
  on public.user_preferences
  for select
  using (user_id = auth.uid());

drop policy if exists user_preferences_owner_insert on public.user_preferences;
create policy user_preferences_owner_insert
  on public.user_preferences
  for insert
  with check (user_id = auth.uid());

drop policy if exists user_preferences_owner_update on public.user_preferences;
create policy user_preferences_owner_update
  on public.user_preferences
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists user_preferences_owner_delete on public.user_preferences;
create policy user_preferences_owner_delete
  on public.user_preferences
  for delete
  using (user_id = auth.uid());

grant usage on schema public to anon, authenticated;
grant select on public.profiles, public.spots, public.reviews to anon, authenticated;
grant insert, update, delete on public.profiles, public.spots, public.reviews to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert, update, delete on public.user_preferences to authenticated;
