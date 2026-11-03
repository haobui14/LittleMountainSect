-- Little Mountain Sect: initial schema (Milestone 1).
--
-- The five tables from the GDD: players, saves, memories, ai_usage and
-- daily_budget. The rule throughout: a player's client may touch only its own
-- rows, and never anything that controls AI access or money (Spirit Energy,
-- usage logs, the daily budget). The AI gateway Edge Function writes those
-- with the service role, which bypasses row-level security.

-- players ------------------------------------------------------------------

create table public.players (
  id uuid primary key references auth.users (id) on delete cascade,
  language text not null default 'en' check (language in ('en', 'vi')),
  age_confirmed_at timestamptz,
  spirit_energy integer not null default 50 check (spirit_energy >= 0),
  spirit_energy_day date not null default current_date,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

comment on table public.players is
  'One row per account (anonymous or email). Created by a trigger on auth.users.';
comment on column public.players.spirit_energy is
  'Daily AI allowance. Server-only: the AI gateway refills and spends it.';
comment on column public.players.spirit_energy_day is
  'UTC day of the last refill. The first request on a later day refills first.';

-- Create the players row whenever someone signs up, including anonymously.
create function public.handle_new_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.players (id) values (new.id);
  return new;
end;
$$;

revoke execute on function public.handle_new_player() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_player();

-- saves --------------------------------------------------------------------

create table public.saves (
  player_id uuid primary key references public.players (id) on delete cascade,
  schema_version integer not null default 1 check (schema_version > 0),
  revision bigint not null default 0 check (revision >= 0),
  data jsonb not null,
  updated_at timestamptz not null default now(),
  -- Keeps one save from eating the free plan's 500 MB database.
  constraint saves_data_size check (pg_column_size(data) <= 512 * 1024)
);

comment on table public.saves is
  'The full game state as JSON, one save per player.';
comment on column public.saves.revision is
  'Increases on every write; a write based on an older revision is a conflict.';

-- memories -----------------------------------------------------------------

create table public.memories (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.players (id) on delete cascade,
  subject text not null check (char_length(subject) between 1 and 64),
  kind text not null check (kind in ('key', 'summary', 'chronicle')),
  content text not null check (char_length(content) between 1 and 500),
  game_day integer check (game_day >= 0),
  created_at timestamptz not null default now()
);

comment on table public.memories is
  'Short memory notes: key memories per disciple, nightly summaries, and the Sect Chronicle.';
comment on column public.memories.subject is
  'A disciple id, or ''sect'' for Sect Chronicle entries.';

create index memories_player_subject_idx
  on public.memories (player_id, subject, created_at desc);

-- ai_usage -----------------------------------------------------------------

create table public.ai_usage (
  id bigint generated always as identity primary key,
  player_id uuid references public.players (id) on delete set null,
  kind text not null check (kind in ('chat', 'elder', 'event', 'evening', 'batch')),
  model text not null,
  input_tokens integer not null default 0 check (input_tokens >= 0),
  cache_read_tokens integer not null default 0 check (cache_read_tokens >= 0),
  cache_write_tokens integer not null default 0 check (cache_write_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  cost_usd numeric(12, 6) not null default 0 check (cost_usd >= 0),
  latency_ms integer check (latency_ms >= 0),
  outcome text not null check (
    outcome in ('ok', 'invalid', 'refusal', 'timeout', 'error', 'no_energy', 'budget_cap')
  ),
  created_at timestamptz not null default now()
);

comment on table public.ai_usage is
  'One row per AI request: tokens, cost, reply time and outcome. Server-only. '
  'Rows outlive a deleted player (player_id becomes null) so costs stay accurate.';

create index ai_usage_created_at_idx on public.ai_usage (created_at);
create index ai_usage_player_id_idx on public.ai_usage (player_id);

-- daily_budget -------------------------------------------------------------

create table public.daily_budget (
  day date primary key,
  spent_usd numeric(12, 6) not null default 0 check (spent_usd >= 0),
  cap_usd numeric(12, 6) not null default 0.60 check (cap_usd >= 0)
);

comment on table public.daily_budget is
  'Total Claude spending per UTC day. When spent_usd reaches cap_usd, the game '
  'uses written text for everyone until the next day. Server-only.';

-- Row-level security -------------------------------------------------------
--
-- Supabase grants every table privilege to anon and authenticated by default,
-- so each table first takes those back and then grants the minimum.
-- Anonymous sign-ins use the authenticated role too.

alter table public.players enable row level security;
alter table public.saves enable row level security;
alter table public.memories enable row level security;
alter table public.ai_usage enable row level security;
alter table public.daily_budget enable row level security;

-- players: read your own row; update only a few harmless columns.
revoke all on public.players from anon, authenticated;
grant select on public.players to authenticated;
grant update (language, age_confirmed_at, last_seen_at) on public.players to authenticated;

create policy "players can read their own row"
  on public.players for select to authenticated
  using ((select auth.uid()) = id);

create policy "players can update their own row"
  on public.players for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- saves: read, create and update your own save.
revoke all on public.saves from anon, authenticated;
grant select, insert, update on public.saves to authenticated;

create policy "players can read their own save"
  on public.saves for select to authenticated
  using ((select auth.uid()) = player_id);

create policy "players can create their own save"
  on public.saves for insert to authenticated
  with check ((select auth.uid()) = player_id);

create policy "players can update their own save"
  on public.saves for update to authenticated
  using ((select auth.uid()) = player_id)
  with check ((select auth.uid()) = player_id);

-- memories: read your own; only the server writes them.
revoke all on public.memories from anon, authenticated;
grant select on public.memories to authenticated;

create policy "players can read their own memories"
  on public.memories for select to authenticated
  using ((select auth.uid()) = player_id);

-- ai_usage and daily_budget: server only. No grants and no policies, on purpose.
revoke all on public.ai_usage from anon, authenticated;
revoke all on public.daily_budget from anon, authenticated;
