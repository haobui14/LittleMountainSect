# Little Mountain Sect

> Found a tiny sect on a leaky mountain. Raise strange, lovable disciples who talk back, remember everything, and cause trouble you never planned.

*Little Mountain Sect* (working name) is a funny, warm management game set in a xianxia world, where people train to become immortal. You are the new Sect Master. Each in-game day you teach disciples, build the mountain, send out missions and deal with rival sects.

Claude makes the disciples feel alive: they talk freely, make choices, remember the past and create new stories. Code decides all results and Claude decides the words.

- **Platform:** a single-player web game made with Godot 4 (GDScript), with Supabase as a small server
- **AI:** Claude Haiku 5.5, limited by a daily Spirit Energy budget
- **Languages:** English and Vietnamese

## Status

Planning is done and Milestone 1 (Foundations) is in progress. See the [milestones](docs/MILESTONES.md).

## Docs

- [Game Design Document](docs/GDD.md): what the game is, and why
- [Milestones](docs/MILESTONES.md): the build plan, with 8 milestones, 4 gates and a cut list

## Repo layout

| Path | What it holds |
|---|---|
| `game/` | The Godot 4 project, in GDScript |
| `server/supabase/` | Database migrations and Edge Functions |
| `tools/` | The AI evaluation and balance simulation scripts |
| `docs/` | Design and planning documents |
