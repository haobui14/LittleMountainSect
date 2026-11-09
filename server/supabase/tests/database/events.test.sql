-- Surprise events (Milestone 5): the words of each player's event are stored
-- once per game day, readable only by that player, written only by the server.
-- Run with: supabase test db   (from the server/ directory)

begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test');

-- Storing event words (as the server) ------------------------------------------

select is(
  public.store_event_story('00000000-0000-0000-0000-00000000000a', 3, '{"title": "Goose"}'),
  '{"title": "Goose"}'::jsonb,
  'storing an event returns it'
);

select is(
  public.store_event_story('00000000-0000-0000-0000-00000000000a', 3, '{"title": "Cat"}'),
  '{"title": "Goose"}'::jsonb,
  'the first event for a day wins; a repeat returns the stored one'
);

select is(
  public.get_event_story('00000000-0000-0000-0000-00000000000a', 4),
  null,
  'a day without an event reads as null'
);

select public.store_event_story('00000000-0000-0000-0000-00000000000b', d, '{"title": "b"}')
from generate_series(1, 33) as d;

select results_eq(
  $$ select count(*)::int, min(game_day) from public.event_stories
     where player_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values (30, 4) $$,
  'only the newest 30 events per player are kept'
);

-- As player A ------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select results_eq(
  'select game_day from public.event_stories',
  $$ values (3) $$,
  'a player sees only their own events'
);

select throws_ok(
  $$ insert into public.event_stories (player_id, game_day, reply)
     values ('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot write events themselves'
);

select throws_ok(
  $$ select public.store_event_story('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot call the server''s store function'
);

select throws_ok(
  $$ select public.get_event_story('00000000-0000-0000-0000-00000000000b', 5) $$,
  '42501',
  null,
  'players cannot read events through the server''s function'
);

select * from finish();
rollback;
