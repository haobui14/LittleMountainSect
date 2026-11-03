-- Row-level security tests for the initial schema.
-- Run with: supabase test db   (from the server/ directory)

begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

-- Three players sign up. A and B have saves; C has none yet.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.test');

select is(
  (select count(*)::int from public.players),
  3,
  'signing up creates a players row'
);

select results_eq(
  'select spirit_energy from public.players order by id',
  array[50, 50, 50],
  'new players start with 50 Spirit Energy'
);

insert into public.saves (player_id, data) values
  ('00000000-0000-0000-0000-00000000000a', '{"day": 1}'),
  ('00000000-0000-0000-0000-00000000000b', '{"day": 7}');
insert into public.memories (player_id, subject, kind, content) values
  ('00000000-0000-0000-0000-00000000000b', 'disciple-1', 'key', 'Master praised my dumplings.');
insert into public.ai_usage (player_id, kind, model, outcome) values
  ('00000000-0000-0000-0000-00000000000b', 'chat', 'claude-haiku-5-5', 'ok');

-- From here on, act as player A.
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select results_eq(
  'select player_id from public.saves',
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'a player sees only their own save'
);

select results_eq(
  $$ with changed as (
       update public.saves set data = '{"hacked": true}'
       where player_id = '00000000-0000-0000-0000-00000000000b'
       returning 1
     )
     select count(*)::int from changed $$,
  array[0],
  'a player cannot overwrite another player''s save'
);

select throws_ok(
  $$ insert into public.saves (player_id, data)
     values ('00000000-0000-0000-0000-00000000000c', '{}') $$,
  '42501',
  null,
  'a player cannot create a save for someone else'
);

select lives_ok(
  $$ update public.players set language = 'vi', last_seen_at = now()
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'a player can change their own language'
);

select throws_ok(
  $$ update public.players set spirit_energy = 9999
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501',
  null,
  'a player cannot change their own Spirit Energy'
);

select results_eq(
  'select count(*)::int from public.players',
  array[1],
  'a player sees only their own players row'
);

select is_empty(
  'select 1 from public.memories',
  'a player cannot read another player''s memories'
);

select throws_ok(
  $$ insert into public.memories (player_id, subject, kind, content)
     values ('00000000-0000-0000-0000-00000000000a', 'disciple-1', 'key', 'I am the chosen one.') $$,
  '42501',
  null,
  'a player cannot write memories directly'
);

select throws_ok(
  'select * from public.ai_usage',
  '42501',
  null,
  'a player cannot read ai_usage'
);

select throws_ok(
  'select * from public.daily_budget',
  '42501',
  null,
  'a player cannot read daily_budget'
);

-- Signed-out visitors (the anon role) can read nothing.
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select throws_ok(
  'select * from public.saves',
  '42501',
  null,
  'signed-out visitors cannot read saves'
);

select throws_ok(
  'select * from public.players',
  '42501',
  null,
  'signed-out visitors cannot read players'
);

select * from finish();
rollback;
