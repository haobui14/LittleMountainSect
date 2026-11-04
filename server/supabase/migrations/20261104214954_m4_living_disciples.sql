-- Little Mountain Sect: evening stories and the Spirit Energy display (Milestone 4).
--
-- evening_stories keeps each finished evening story, so a tab that was in the
-- background can load it later, and asking twice for the same day's story
-- returns the stored one instead of paying again. The AI gateway writes it
-- with the service role; players can only read their own.
--
-- spirit_energy_status() lets the game show a player's Spirit Energy and the
-- costs without spending anything.

-- evening_stories ------------------------------------------------------------

create table public.evening_stories (
  player_id uuid not null references public.players (id) on delete cascade,
  game_day integer not null check (game_day >= 1),
  reply jsonb not null,
  created_at timestamptz not null default now(),
  primary key (player_id, game_day),
  constraint evening_stories_reply_size check (pg_column_size(reply) <= 32 * 1024)
);

comment on table public.evening_stories is
  'Finished evening stories, one per player per game day, already checked by the '
  'AI gateway. Only the newest 30 per player are kept.';

alter table public.evening_stories enable row level security;
revoke all on public.evening_stories from anon, authenticated;
grant select on public.evening_stories to authenticated;

create policy "players can read their own evening stories"
  on public.evening_stories for select to authenticated
  using ((select auth.uid()) = player_id);

-- Stores a day's story unless one is already stored (the first one wins),
-- then keeps only the newest 30 for the player. Returns the stored reply.
create function public.store_evening_story(p_player uuid, p_game_day integer, p_reply jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reply jsonb;
begin
  insert into public.evening_stories (player_id, game_day, reply)
  values (p_player, p_game_day, p_reply)
  on conflict (player_id, game_day) do nothing;

  delete from public.evening_stories
  where player_id = p_player
    and game_day not in (
      select game_day from public.evening_stories
      where player_id = p_player
      order by game_day desc
      limit 30
    );

  select reply into v_reply from public.evening_stories
  where player_id = p_player and game_day = p_game_day;
  return v_reply;
end;
$$;

-- The stored story for a day, or null.
create function public.get_evening_story(p_player uuid, p_game_day integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select reply from public.evening_stories
  where player_id = p_player and game_day = p_game_day;
$$;

revoke execute on function public.store_evening_story(uuid, integer, jsonb)
  from public, anon, authenticated;
revoke execute on function public.get_evening_story(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.store_evening_story(uuid, integer, jsonb) to service_role;
grant execute on function public.get_evening_story(uuid, integer) to service_role;

-- spirit_energy_status -------------------------------------------------------

-- The signed-in player's Spirit Energy for today, and what each request costs.
-- Read-only: on a new UTC day it reports the full amount without refilling;
-- the next spend does the refill. Returns null when there is no players row.
create function public.spirit_energy_status()
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
      'evening', s.cost_evening
    )
  );
end;
$$;

revoke execute on function public.spirit_energy_status() from public, anon;
grant execute on function public.spirit_energy_status() to authenticated;
