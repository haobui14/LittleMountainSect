-- Little Mountain Sect: surprise events (Milestone 5).
--
-- event_stories keeps the words Claude wrote for each player's surprise event
-- (one per game day at most), like evening_stories: asking twice for the same
-- day's event returns the stored words instead of paying again, and a tab
-- that was in the background can load them later. The AI gateway writes it
-- with the service role; players can only read their own.

create table public.event_stories (
  player_id uuid not null references public.players (id) on delete cascade,
  game_day integer not null check (game_day >= 1),
  reply jsonb not null,
  created_at timestamptz not null default now(),
  primary key (player_id, game_day),
  constraint event_stories_reply_size check (pg_column_size(reply) <= 16 * 1024)
);

comment on table public.event_stories is
  'The words of each surprise event, one per player per game day, already checked by the '
  'AI gateway. Only the newest 30 per player are kept.';

alter table public.event_stories enable row level security;
revoke all on public.event_stories from anon, authenticated;
grant select on public.event_stories to authenticated;

create policy "players can read their own event stories"
  on public.event_stories for select to authenticated
  using ((select auth.uid()) = player_id);

-- Stores a day's event words unless some are already stored (the first one
-- wins), then keeps only the newest 30 for the player. Returns the stored reply.
create function public.store_event_story(p_player uuid, p_game_day integer, p_reply jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reply jsonb;
begin
  insert into public.event_stories (player_id, game_day, reply)
  values (p_player, p_game_day, p_reply)
  on conflict (player_id, game_day) do nothing;

  delete from public.event_stories
  where player_id = p_player
    and game_day not in (
      select game_day from public.event_stories
      where player_id = p_player
      order by game_day desc
      limit 30
    );

  select reply into v_reply from public.event_stories
  where player_id = p_player and game_day = p_game_day;
  return v_reply;
end;
$$;

-- The stored event words for a day, or null.
create function public.get_event_story(p_player uuid, p_game_day integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select reply from public.event_stories
  where player_id = p_player and game_day = p_game_day;
$$;

revoke execute on function public.store_event_story(uuid, integer, jsonb)
  from public, anon, authenticated;
revoke execute on function public.get_event_story(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.store_event_story(uuid, integer, jsonb) to service_role;
grant execute on function public.get_event_story(uuid, integer) to service_role;
