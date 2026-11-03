# Little Mountain Sect

> Found a tiny sect on a leaky mountain. Raise strange, lovable disciples who talk back, remember everything, and cause trouble you never planned.

*Little Mountain Sect* (working name) is a funny, warm management game set in a xianxia world, where people train to become immortal. You are the new Sect Master. Each in-game day you teach disciples, build the mountain, send out missions and deal with rival sects.

Claude makes the disciples feel alive: they talk freely, make choices, remember the past and create new stories. Code decides all results and Claude decides the words.

- **Platform:** a single-player web game made with Godot 4 (GDScript), with Supabase as a small server
- **AI:** Claude Haiku 5.5, limited by a daily Spirit Energy budget
- **Languages:** English and Vietnamese

## Status

Planning is done and Milestone 1 (Foundations) is in progress, tracked in [#1](https://github.com/haobui14/LittleMountainSect/issues/1). See the [milestones](docs/MILESTONES.md) for the full plan.

## Working on the game

You need **Godot 4.7.2**, the version pinned in CI. Open `game/project.godot` in the editor, or use the command line from the repo root:

```bash
godot --headless --path game --import
```

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd
```

The first command imports assets. The second runs the GUT unit tests.

Database tests need Docker and the Supabase CLI:

```bash
cd server && npx supabase@3.0.0 db start && npx supabase@3.0.0 test db
```

CI runs all of these on every push, exports a web build, and keeps it as a downloadable artifact. To publish the build on GitHub Pages:

1. Go to **Settings → Pages** and set the source to "GitHub Actions".
2. Add the repository variable `DEPLOY_PAGES` with the value `true`.

[CLAUDE.md](CLAUDE.md) lists the project rules that every change follows.

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
