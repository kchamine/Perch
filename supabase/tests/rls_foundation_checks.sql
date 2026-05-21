-- Manual RLS verification for the Perch backend foundation.
-- Run this only in a disposable Supabase project or local test database.

begin;

do $$
declare
  user_a uuid := '00000000-0000-0000-0000-0000000000a1';
  user_b uuid := '00000000-0000-0000-0000-0000000000b2';
  public_spot uuid := '10000000-0000-0000-0000-000000000001';
  private_spot uuid := '10000000-0000-0000-0000-000000000002';
  visible_count integer;
begin
  insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values
    (user_a, 'perch-a@example.test', crypt('password', gen_salt('bf')), now(), now(), now()),
    (user_b, 'perch-b@example.test', crypt('password', gen_salt('bf')), now(), now(), now())
  on conflict (id) do nothing;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  insert into public.spots (
    id,
    owner_user_id,
    name,
    subtitle,
    latitude,
    longitude,
    spot_type,
    seating_type,
    has_seating,
    shade_level,
    noise_level,
    crowd_level,
    view_type,
    best_time,
    accessibility,
    access_effort,
    comfort_rating,
    scenic_rating,
    public_access_confirmed,
    is_private,
    notes
  )
  values
    (
      public_spot,
      user_a,
      'Public Perch',
      'Visible to everyone',
      37.779,
      -122.419,
      'bench',
      'bench',
      true,
      'partial',
      'quiet',
      'low',
      'park',
      'afternoon',
      'stepFree',
      'easy',
      4,
      4,
      true,
      false,
      'public'
    ),
    (
      private_spot,
      user_a,
      'Private Perch',
      'Owner only',
      37.780,
      -122.420,
      'bench',
      'bench',
      true,
      'shaded',
      'quiet',
      'low',
      'park',
      'morning',
      'stepFree',
      'easy',
      5,
      5,
      true,
      true,
      'private'
    );

  insert into public.reviews (
    spot_id,
    author_user_id,
    author_name,
    title,
    note,
    settle_in_ease,
    stay_comfort,
    view_payoff,
    calm_factor,
    would_return,
    best_for
  )
  values (
    public_spot,
    user_a,
    'A',
    'Quiet stop',
    'Good public test review',
    4,
    4,
    4,
    5,
    true,
    array['soloReset']
  );

  insert into public.favorites (user_id, spot_id)
  values (user_a, public_spot);

  insert into public.user_preferences (user_id, quiet_only, nearby_only)
  values (user_a, true, true);

  select count(*) into visible_count from public.spots;
  if visible_count <> 2 then
    raise exception 'user_a should see both own public and private spots, saw %', visible_count;
  end if;

  perform set_config('request.jwt.claim.sub', user_b::text, true);

  select count(*) into visible_count from public.spots;
  if visible_count <> 1 then
    raise exception 'user_b should see only user_a public spot, saw %', visible_count;
  end if;

  update public.spots
  set name = 'Bad edit'
  where id = public_spot;

  get diagnostics visible_count = row_count;
  if visible_count <> 0 then
    raise exception 'user_b should not update user_a spot';
  end if;

  select count(*) into visible_count from public.favorites;
  if visible_count <> 0 then
    raise exception 'user_b should not read user_a favorites, saw %', visible_count;
  end if;

  select count(*) into visible_count from public.user_preferences;
  if visible_count <> 0 then
    raise exception 'user_b should not read user_a preferences, saw %', visible_count;
  end if;

  perform set_config('request.jwt.claim.sub', user_a::text, true);

  execute 'reset role';

  delete from auth.users where id = user_a;

  select count(*) into visible_count from public.spots where owner_user_id = user_a;
  if visible_count <> 0 then
    raise exception 'deleting auth user should cascade owned spots, saw %', visible_count;
  end if;
end $$;

rollback;
