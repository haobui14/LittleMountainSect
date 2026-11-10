-- Little Mountain Sect: letters home (Milestone 6).
--
-- A disciple who is away travelling sends a letter every 6 to 9 days. Claude
-- writes it the night before, for 1 Spirit Energy (cost_letter). Like events,
-- letter_stories keeps the checked words once per player per game day, so
-- asking twice for the same day's letter returns the stored words instead of
-- paying again. The AI gateway writes it with the service role; players can
-- only read their own.

-- Costs and kinds --------------------------------------------------------------

alter table public.ai_settings
  add column cost_letter integer not null default 1 check (cost_letter >= 0);

alter table public.ai_usage drop constraint ai_usage_kind_check;
alter table public.ai_usage add constraint ai_usage_kind_check check (
  kind in ('chat', 'elder', 'event', 'evening', 'letter', 'batch')
);

-- The cost of one request of a kind, or null for an unknown kind.
create function public.request_cost(s public.ai_settings, p_kind text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'chat' then s.cost_chat
    when 'elder' then s.cost_elder
    when 'event' then s.cost_event
    when 'evening' then s.cost_evening
    when 'letter' then s.cost_letter
  end;
$$;

revoke execute on function public.request_cost(public.ai_settings, text)
  from public, anon, authenticated;

-- Same as before, with letters. The grants made in 20261104145751 stay.
create or replace function public.spend_spirit_energy(p_player uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.ai_settings;
  v_cost integer;
  v_energy integer;
  v_day date;
  v_spent numeric;
  v_today date := (now() at time zone 'utc')::date;
begin
  select * into s from public.ai_settings where id;
  v_cost := public.request_cost(s, p_kind);
  if v_cost is null then
    raise exception 'unknown request kind: %', p_kind using errcode = '22023';
  end if;

  select spirit_energy, spirit_energy_day into v_energy, v_day
  from public.players where id = p_player
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_player', 'spirit_energy_left', 0);
  end if;

  -- Unused Spirit Energy does not carry over: a new day starts from the full amount.
  if v_day < v_today then
    v_energy := s.spirit_energy_per_day;
    update public.players
    set spirit_energy = v_energy, spirit_energy_day = v_today
    where id = p_player;
  end if;

  if not s.enabled then
    return jsonb_build_object('ok', false, 'reason', 'disabled', 'spirit_energy_left', v_energy);
  end if;

  insert into public.daily_budget (day, cap_usd) values (v_today, s.daily_cap_usd)
  on conflict (day) do nothing;
  select spent_usd into v_spent from public.daily_budget where day = v_today;
  if v_spent >= s.daily_cap_usd then
    return jsonb_build_object('ok', false, 'reason', 'budget_cap', 'spirit_energy_left', v_energy);
  end if;

  if v_energy < v_cost then
    return jsonb_build_object('ok', false, 'reason', 'no_energy', 'spirit_energy_left', v_energy);
  end if;

  update public.players
  set spirit_energy = v_energy - v_cost, last_seen_at = now()
  where id = p_player;
  return jsonb_build_object('ok', true, 'reason', 'ok', 'spirit_energy_left', v_energy - v_cost);
end;
$$;

create or replace function public.refund_spirit_energy(p_player uuid, p_kind text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.ai_settings;
  v_cost integer;
  v_left integer;
begin
  select * into s from public.ai_settings where id;
  v_cost := public.request_cost(s, p_kind);
  if v_cost is null then
    raise exception 'unknown request kind: %', p_kind using errcode = '22023';
  end if;

  update public.players
  set spirit_energy = least(spirit_energy + v_cost, s.spirit_energy_per_day)
  where id = p_player and spirit_energy_day = (now() at time zone 'utc')::date
  returning spirit_energy into v_left;
  if not found then
    select spirit_energy into v_left from public.players where id = p_player;
  end if;
  return v_left;
end;
$$;

create or replace function public.spirit_energy_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.ai_settings;
  v_energy integer;
  v_day date;
  v_today date := (now() at time zone 'utc')::date;
begin
  select * into s from public.ai_settings where id;
  select spirit_energy, spirit_energy_day into v_energy, v_day
  from public.players where id = (select auth.uid());
  if not found then
    return null;
  end if;
  if v_day < v_today then
    v_energy := s.spirit_energy_per_day;
  end if;
  return jsonb_build_object(
    'left', v_energy,
    'per_day', s.spirit_energy_per_day,
    'enabled', s.enabled,
    'costs', jsonb_build_object(
      'chat', s.cost_chat,
      'elder', s.cost_elder,
      'event', s.cost_event,
      'evening', s.cost_evening,
      'letter', s.cost_letter
    )
  );
end;
$$;

-- Letters ------------------------------------------------------------------------

create table public.letter_stories (
  player_id uuid not null references public.players (id) on delete cascade,
  game_day integer not null check (game_day >= 1),
  reply jsonb not null,
  created_at timestamptz not null default now(),
  primary key (player_id, game_day),
  constraint letter_stories_reply_size check (pg_column_size(reply) <= 8 * 1024)
);

comment on table public.letter_stories is
  'The words of each letter home, one per player per game day, already checked by the AI '
  'gateway. Only the newest 30 per player are kept.';

alter table public.letter_stories enable row level security;
revoke all on public.letter_stories from anon, authenticated;
grant select on public.letter_stories to authenticated;

create policy "players can read their own letters"
  on public.letter_stories for select to authenticated
  using ((select auth.uid()) = player_id);

-- Stores a day's letter unless one is already stored (the first one wins),
-- then keeps only the newest 30 for the player. Returns the stored reply.
create function public.store_letter_story(p_player uuid, p_game_day integer, p_reply jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reply jsonb;
begin
  insert into public.letter_stories (player_id, game_day, reply)
  values (p_player, p_game_day, p_reply)
  on conflict (player_id, game_day) do nothing;

  delete from public.letter_stories
  where player_id = p_player
    and game_day not in (
      select game_day from public.letter_stories
      where player_id = p_player
      order by game_day desc
      limit 30
    );

  select reply into v_reply from public.letter_stories
  where player_id = p_player and game_day = p_game_day;
  return v_reply;
end;
$$;

-- The stored letter for a day, or null.
create function public.get_letter_story(p_player uuid, p_game_day integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select reply from public.letter_stories
  where player_id = p_player and game_day = p_game_day;
$$;

revoke execute on function public.store_letter_story(uuid, integer, jsonb)
  from public, anon, authenticated;
revoke execute on function public.get_letter_story(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.store_letter_story(uuid, integer, jsonb) to service_role;
grant execute on function public.get_letter_story(uuid, integer) to service_role;
