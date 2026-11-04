-- Little Mountain Sect: Spirit Energy, the daily budget and memories (Milestone 2).
--
-- The AI gateway Edge Function calls these functions with the service role.
-- Each one runs in a single transaction and locks the player's row, so two
-- requests at once can never spend the same Spirit Energy twice. Players and
-- signed-out visitors cannot call them.
--
-- Known limit: requests already in flight when the daily cap is reached can
-- overshoot it by the cost of those requests (a fraction of a cent each).

-- Settings -----------------------------------------------------------------

create table public.ai_settings (
  -- Exactly one row: the primary key can only be true.
  id boolean primary key default true check (id),
  enabled boolean not null default true,
  spirit_energy_per_day integer not null default 50 check (spirit_energy_per_day >= 0),
  cost_chat integer not null default 1 check (cost_chat >= 0),
  cost_elder integer not null default 1 check (cost_elder >= 0),
  cost_event integer not null default 2 check (cost_event >= 0),
  cost_evening integer not null default 3 check (cost_evening >= 0),
  daily_cap_usd numeric(12, 6) not null default 0.60 check (daily_cap_usd >= 0),
  updated_at timestamptz not null default now()
);

comment on table public.ai_settings is
  'AI limits in one row, so they can change without a redeploy. enabled is a kill '
  'switch: when false, every AI request gets a written line instead. Server-only.';

insert into public.ai_settings default values;

alter table public.ai_settings enable row level security;
revoke all on public.ai_settings from anon, authenticated;

-- Requests refused before Claude is called are logged too (with zero tokens),
-- so the outcome list gains 'disabled' and 'max_tokens'.
alter table public.ai_usage drop constraint ai_usage_outcome_check;
alter table public.ai_usage add constraint ai_usage_outcome_check check (
  outcome in (
    'ok', 'invalid', 'refusal', 'max_tokens', 'timeout', 'error',
    'no_energy', 'budget_cap', 'disabled'
  )
);

-- Spend --------------------------------------------------------------------

-- Spends the Spirit Energy for one AI request, after refilling it on a new
-- UTC day. Returns {"ok", "reason", "spirit_energy_left"}; reason is one of
-- ok, no_energy, budget_cap, disabled or no_player.
create function public.spend_spirit_energy(p_player uuid, p_kind text)
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
  v_cost := case p_kind
    when 'chat' then s.cost_chat
    when 'elder' then s.cost_elder
    when 'event' then s.cost_event
    when 'evening' then s.cost_evening
  end;
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

-- Gives back the Spirit Energy of a request whose reply failed. Never goes
-- over the daily amount, and does nothing once the day has rolled over.
-- Returns the Spirit Energy left.
create function public.refund_spirit_energy(p_player uuid, p_kind text)
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
  v_cost := case p_kind
    when 'chat' then s.cost_chat
    when 'elder' then s.cost_elder
    when 'event' then s.cost_event
    when 'evening' then s.cost_evening
  end;
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

-- Logs one AI request and adds its cost to today's budget, atomically.
create function public.record_ai_usage(
  p_player uuid,
  p_kind text,
  p_model text,
  p_input_tokens integer,
  p_cache_read_tokens integer,
  p_cache_write_tokens integer,
  p_output_tokens integer,
  p_cost_usd numeric,
  p_latency_ms integer,
  p_outcome text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'utc')::date;
begin
  insert into public.ai_usage (
    player_id, kind, model, input_tokens, cache_read_tokens, cache_write_tokens,
    output_tokens, cost_usd, latency_ms, outcome
  ) values (
    p_player, p_kind, p_model, p_input_tokens, p_cache_read_tokens, p_cache_write_tokens,
    p_output_tokens, p_cost_usd, p_latency_ms, p_outcome
  );

  insert into public.daily_budget as b (day, cap_usd, spent_usd)
  values (v_today, (select daily_cap_usd from public.ai_settings where id), p_cost_usd)
  on conflict (day) do update set spent_usd = b.spent_usd + excluded.spent_usd;
end;
$$;

-- Memories -----------------------------------------------------------------

-- Saves a key memory and keeps only the newest 10 for that disciple.
-- The nightly job that merges old memories into summaries arrives in M6.
create function public.add_memory(
  p_player uuid,
  p_subject text,
  p_content text,
  p_game_day integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.memories (player_id, subject, kind, content, game_day)
  values (p_player, p_subject, 'key', p_content, p_game_day);

  delete from public.memories
  where id in (
    select id from public.memories
    where player_id = p_player and subject = p_subject and kind = 'key'
    order by id desc
    offset 10
  );
end;
$$;

-- Only the server (service role) may call these functions.
revoke execute on function public.spend_spirit_energy(uuid, text) from public, anon, authenticated;
revoke execute on function public.refund_spirit_energy(uuid, text) from public, anon, authenticated;
revoke execute on function public.record_ai_usage(
  uuid, text, text, integer, integer, integer, integer, numeric, integer, text
) from public, anon, authenticated;
revoke execute on function public.add_memory(uuid, text, text, integer)
  from public, anon, authenticated;

grant execute on function public.spend_spirit_energy(uuid, text) to service_role;
grant execute on function public.refund_spirit_energy(uuid, text) to service_role;
grant execute on function public.record_ai_usage(
  uuid, text, text, integer, integer, integer, integer, numeric, integer, text
) to service_role;
grant execute on function public.add_memory(uuid, text, text, integer) to service_role;
