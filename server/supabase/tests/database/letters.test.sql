-- Letters home (Milestone 6): each player's letters are stored
-- once per game day, readable only by that player, written only by the server.
-- Run with: supabase test db   (from the server/ directory)

begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test');

-- Storing letters (as the server) ------------------------------------------

select is(
  public.store_letter_story('00000000-0000-0000-0000-00000000000a', 3, '{"letter": "Goose"}'),
  '{"letter": "Goose"}'::jsonb,
  'storing a letter returns it'
);

select is(
  public.store_letter_story('00000000-0000-0000-0000-00000000000a', 3, '{"letter": "Cat"}'),
  '{"letter": "Goose"}'::jsonb,
  'the first letter for a day wins; a repeat returns the stored one'
);

select is(
  public.get_letter_story('00000000-0000-0000-0000-00000000000a', 4),
  null,
  'a day without a letter reads as null'
);

select public.store_letter_story('00000000-0000-0000-0000-00000000000b', d, '{"letter": "b"}')
from generate_series(1, 33) as d;

select results_eq(
  $$ select count(*)::int, min(game_day) from public.letter_stories
     where player_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values (30, 4) $$,
  'only the newest 30 letters per player are kept'
);

-- Costs -------------------------------------------------------------------------

select is(
  (public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'letter'))->>'spirit_energy_left',
  '49',
  'a letter costs 1 Spirit Energy'
);

select is(
  public.refund_spirit_energy('00000000-0000-0000-0000-00000000000a', 'letter'),
  50,
  'a failed letter gives its Spirit Energy back'
);

select lives_ok(
  $$ insert into public.ai_usage (player_id, kind, model, outcome)
     values ('00000000-0000-0000-0000-00000000000a', 'letter', 'test', 'ok') $$,
  'letters can be logged in ai_usage'
);

-- As player A ------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select results_eq(
  'select game_day from public.letter_stories',
  $$ values (3) $$,
  'a player sees only their own letters'
);

select throws_ok(
  $$ insert into public.letter_stories (player_id, game_day, reply)
     values ('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot write letters themselves'
);

select throws_ok(
  $$ select public.store_letter_story('00000000-0000-0000-0000-00000000000a', 9, '{}') $$,
  '42501',
  null,
  'players cannot call the server''s store function'
);

select throws_ok(
  $$ select public.get_letter_story('00000000-0000-0000-0000-00000000000b', 5) $$,
  '42501',
  null,
  'players cannot read letters through the server''s function'
);

select * from finish();
rollback;
