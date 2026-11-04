# Little Mountain Sect

> Found a tiny sect on a leaky mountain. Raise strange, lovable disciples who talk back, remember everything, and cause trouble you never planned.

*Little Mountain Sect* (working name) is a funny, warm management game set in a xianxia world, where people train to become immortal. You are the new Sect Master. Each in-game day you teach disciples, build the mountain, send out missions and deal with rival sects.

Claude makes the disciples feel alive: they talk freely, make choices, remember the past and create new stories. Code decides all results and Claude decides the words.

- **Platform:** a single-player web game made with Godot 4 (GDScript), with Supabase as a small server
- **AI:** Claude Haiku 5.5, limited by a daily Spirit Energy budget
- **Languages:** English and Vietnamese

## Status

Milestone 1 (Foundations) is done ([#1](https://github.com/haobui14/LittleMountainSect/issues/1)). The test build is live at **https://haobui14.github.io/LittleMountainSect/**.

Milestone 2 (Risk tests) is done except for the people's part of Gate 1: rating the AI chats and testing Vietnamese typing on phones ([#2](https://github.com/haobui14/LittleMountainSect/issues/2), [Gate 1 write-up](docs/playtests/gate-1.md)).

Milestone 3 (Core simulation) is done ([#3](https://github.com/haobui14/LittleMountainSect/issues/3)): 10 in-game days play on the test build with placeholder screens and no AI. The rules engine is tested, and a balance sim checks it.

See the [milestones](docs/MILESTONES.md) for the full plan.

## Working on the game

You need **Godot 4.7.2**, the version pinned in CI. Open `game/project.godot` in the editor, or use the command line from the repo root:

```bash
godot --headless --path game --import
```

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd
```

The first command imports assets. The second runs the GUT unit tests.

Server code and tools are TypeScript on Deno 2.9.6. [CLAUDE.md](CLAUDE.md) lists their commands; `deno test --allow-read=.` runs every Deno test.

Database tests need Docker and the Supabase CLI:

```bash
cd server && npx supabase@3.0.0 db start && npx supabase@3.0.0 test db
```

CI runs all of these on every push and exports a web build, kept as a downloadable artifact. On the default branch, once every test passes, CI also publishes the build to GitHub Pages at https://haobui14.github.io/LittleMountainSect/ and checks that the live site serves it. Publishing needs Pages' source set to "GitHub Actions" (Settings → Pages) and the repository variable `DEPLOY_PAGES` set to `true`; both are done.

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
