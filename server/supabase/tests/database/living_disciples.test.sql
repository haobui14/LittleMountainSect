-- Evening stories and the Spirit Energy display (Milestone 4).
-- Run with: supabase test db   (from the server/ directory)

begin;
create extension if not exists pgtap with schema extensions;

select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test');

-- Storing stories (as the server) --------------------------------------------

select is(
  public.store_evening_story('00000000-0000-0000-0000-00000000000a', 1, '{"story": "first"}'),
  '{"story": "first"}'::jsonb,
  'storing a story returns it'
);

select is(
  public.store_evening_story('00000000-0000-0000-0000-00000000000a', 1, '{"story": "second"}'),
  '{"story": "first"}'::jsonb,
  'the first story for a day wins; a repeat returns the stored one'
);

select is(
  public.get_evening_story('00000000-0000-0000-0000-00000000000a', 1),
  '{"story": "first"}'::jsonb,
  'the server can read a stored story'
);

select is(
  public.get_evening_story('00000000-0000-0000-0000-00000000000a', 2),
  null,
  'a day without a story reads as null'
);

select public.store_evening_story('00000000-0000-0000-0000-00000000000b', d, '{"story": "b"}')
from generate_series(1, 35) as d;

select results_eq(
  $$ select count(*)::int, min(game_day) from public.evening_stories
     where player_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values (30, 6) $$,
  'only the newest 30 stories per player are kept'
);

-- Spirit Energy status, before switching roles: an old day shows a refill. --

update public.players set spirit_energy = 3, spirit_energy_day = current_date - 1
where id = '00000000-0000-0000-0000-00000000000b';

-- As player A ------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select results_eq(
  'select game_day from public.evening_stories',
  $$ values (1) $$,
  'a player sees only their own stories'
);

select throws_ok(
  $$ insert into public.evening_stories (player_id, game_day, reply)
     values ('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot write stories themselves'
);

select throws_ok(
  $$ select public.store_evening_story('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot call the server''s store function'
);

select is(
  public.spirit_energy_status(),
  '{"left": 50, "per_day": 50, "enabled": true,
    "costs": {"chat": 1, "elder": 1, "event": 2, "evening": 3}}'::jsonb,
  'a player can see their Spirit Energy and the costs'
);

-- As player B, whose Spirit Energy is from yesterday ----------------------------

set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  public.spirit_energy_status() ->> 'left',
  '50',
  'on a new day the status shows the full amount'
);

reset role;

select results_eq(
  $$ select spirit_energy, spirit_energy_day from public.players
     where id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values (3, current_date - 1) $$,
  'reading the status changes nothing'
);

-- Signed-out visitors -------------------------------------------------------------

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select throws_ok(
  'select public.spirit_energy_status()',
  '42501',
  null,
  'signed-out visitors cannot read Spirit Energy'
);

select throws_ok(
  'select * from public.evening_stories',
  '42501',
  null,
  'signed-out visitors cannot read stories'
);

select * from finish();
rollback;
