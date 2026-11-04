-- Spirit Energy, the daily budget and memories.
-- Run with: supabase test db   (from the server/ directory)

begin;
create extension if not exists pgtap with schema extensions;

select plan(19);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test');

-- Spending ---------------------------------------------------------------

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat'),
  '{"ok": true, "reason": "ok", "spirit_energy_left": 49}'::jsonb,
  'a chat costs 1 Spirit Energy'
);

select is(
  (select spirit_energy from public.players where id = '00000000-0000-0000-0000-00000000000a'),
  49,
  'the spend is saved on the player'
);

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'evening')
    ->> 'spirit_energy_left',
  '46',
  'an evening story costs 3'
);

update public.players set spirit_energy = 0
where id = '00000000-0000-0000-0000-00000000000a';

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat') ->> 'reason',
  'no_energy',
  'with no Spirit Energy left, the request is refused'
);

update public.players
set spirit_energy = 0, spirit_energy_day = (now() at time zone 'utc')::date - 1
where id = '00000000-0000-0000-0000-00000000000a';

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat')
    ->> 'spirit_energy_left',
  '49',
  'a new UTC day refills to 50 before spending'
);

select throws_ok(
  $$ select public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'poem') $$,
  '22023',
  null,
  'an unknown request kind is an error'
);

-- Refunds ----------------------------------------------------------------

select is(
  public.refund_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat'),
  50,
  'a refund gives the Spirit Energy back'
);

select is(
  public.refund_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat'),
  50,
  'a refund never goes over the daily amount'
);

-- The budget -------------------------------------------------------------

select lives_ok(
  $$ select public.record_ai_usage(
       '00000000-0000-0000-0000-00000000000b', 'chat', 'claude-haiku-5-5',
       800, 1500, 0, 250, 0.60, 1200, 'ok') $$,
  'usage can be recorded'
);

select is(
  (select count(*)::int from public.ai_usage),
  1,
  'recording usage adds an ai_usage row'
);

select is(
  (select spent_usd from public.daily_budget where day = (now() at time zone 'utc')::date),
  0.600000::numeric,
  'recording usage adds its cost to today''s budget'
);

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000b', 'chat') ->> 'reason',
  'budget_cap',
  'once today''s spending reaches the cap, AI requests stop for everyone'
);

update public.ai_settings set enabled = false, daily_cap_usd = 100;

select is(
  public.spend_spirit_energy('00000000-0000-0000-0000-00000000000b', 'chat') ->> 'reason',
  'disabled',
  'the kill switch stops AI requests'
);

update public.ai_settings set enabled = true;

-- Memories ---------------------------------------------------------------

do $$
begin
  for n in 1..12 loop
    perform public.add_memory(
      '00000000-0000-0000-0000-00000000000a', 'lin', 'memory ' || n, n);
  end loop;
end
$$;

select is(
  (select array_agg(game_day order by game_day) from public.memories
   where player_id = '00000000-0000-0000-0000-00000000000a' and subject = 'lin'),
  array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  'only the newest 10 memories per disciple are kept'
);

-- Who may call these functions ---------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select throws_ok(
  $$ select public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat') $$,
  '42501',
  null,
  'players cannot spend Spirit Energy directly'
);

select throws_ok(
  $$ select public.refund_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat') $$,
  '42501',
  null,
  'players cannot refund themselves'
);

select throws_ok(
  $$ select public.record_ai_usage(
       '00000000-0000-0000-0000-00000000000a', 'chat', 'x', 0, 0, 0, 0, 0, 0, 'ok') $$,
  '42501',
  null,
  'players cannot record usage'
);

select throws_ok(
  'select * from public.ai_settings',
  '42501',
  null,
  'players cannot read the AI settings'
);

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select throws_ok(
  $$ select public.spend_spirit_energy('00000000-0000-0000-0000-00000000000a', 'chat') $$,
  '42501',
  null,
  'signed-out visitors cannot spend Spirit Energy'
);

select * from finish();
rollback;
