# Little Mountain Sect — Milestones

This is the build plan for the first version described in the [Game Design Document](GDD.md). It has 8 milestones in 4 phases. Each phase ends with a **gate**: a short checklist that must pass before the next phase starts. If a gate fails, fix that problem first.

- **No dates.** The milestones run in order. Each has a rough estimate of your own time, about 130 hours in total. Claude writes most of the code, and your time goes to reviews, playtests, rating chats and decisions.
- **Tracking.** Each milestone has a GitHub issue for progress. This file is the plan of record.
- **Rebuilt diagrams.** The GDD's daily-loop and roadmap diagrams were lost when the document was exported. The phases, gates and loop steps here are rebuilt from the GDD's text. They follow its rules:
  - Test the riskiest ideas first.
  - Use simple placeholders until the game is fun.
  - Cut rival sects and buildings before disciple personality.

## At a glance

| # | Milestone | Phase | Effort | Ends with | Tracking |
|---|---|---|---|---|---|
| M1 | Foundations | 1 · Prove it | ~5 h | — | [#1](https://github.com/haobui14/LittleMountainSect/issues/1) |
| M2 | Risk tests | 1 · Prove it | ~15 h | **Gate 1: The idea works** | [#2](https://github.com/haobui14/LittleMountainSect/issues/2) |
| M3 | Core simulation | 2 · Fun core | ~20 h | — | [#3](https://github.com/haobui14/LittleMountainSect/issues/3) |
| M4 | Living disciples | 2 · Fun core | ~20 h | **Gate 2: Fun with placeholders** | [#4](https://github.com/haobui14/LittleMountainSect/issues/4) |
| M5 | Sect growth | 3 · Full first version | ~20 h | — | [#5](https://github.com/haobui14/LittleMountainSect/issues/5) |
| M6 | Rivals and history | 3 · Full first version | ~20 h | **Gate 3: Content complete** | [#6](https://github.com/haobui14/LittleMountainSect/issues/6) |
| M7 | Look, sound and language | 4 · Beta | ~10 h, with art work alongside | — | [#7](https://github.com/haobui14/LittleMountainSect/issues/7) |
| M8 | Safe launch | 4 · Beta | ~20 h | **Gate 4: Ready for Founding Disciples** | [#8](https://github.com/haobui14/LittleMountainSect/issues/8) |

Art work starts during M5 and runs alongside the other milestones until M7.

## Design decisions the milestones rely on

- **Repo layout:**
  - `game/`: the Godot 4 project, in GDScript.
  - `server/supabase/`: SQL migrations and TypeScript Edge Functions.
  - `tools/`: the `ai-eval` and `balance-sim` scripts.
  - `docs/`: design and planning documents.
- **Rules engine.** The rules are pure GDScript in `game/sim/`, with no scene or UI code. The random seed is stored in the save, so results can be repeated. This lets the rules be unit-tested headless in CI.
- **Claude never sets a number.** Code checks and limits every value Claude suggests.
- **One AI gateway.** A single Supabase Edge Function handles every AI request in these steps:
  1. Check the player's sign-in, message length and rate.
  2. Spend Spirit Energy and check the global $0.60-a-day cap. One atomic Postgres function does both.
  3. Build the prompt on the server.
  4. Call Claude.
  5. Check and limit every value in the reply.
  6. Log the request to `ai_usage`.
  7. Return the reply. If any step fails, return a written line instead and refund the Spirit Energy.

  The model name, Spirit Energy amounts and prices, and the cap all live in one server setting.
- **The server builds the prompt.** The client sends only these things, each with a size limit:
  - IDs
  - The player's text
  - A small snapshot of game state

  The server builds the prompt from its own templates and stored memories. The shared rules go first so they can be cached: world rules, tone, safety, the word list and the reply format. Because the client never sends a full prompt, nobody can use the gateway as a free Claude proxy.
- **Claude Haiku 5.5 settings** (checked against current API docs):
  - Use the model name `claude-haiku-5-5`. The GDD's prices ($0.10 per million input tokens, $0.50 per million output tokens) are correct.
  - Use structured outputs (`output_config.format` with a JSON schema) so every reply can be parsed.
  - Set effort explicitly. Start at `low`; the default is `medium`.
  - Thinking is on by default and counts toward `max_tokens`. Read reply blocks by `type`, and leave extra room in `max_tokens`.
  - Don't send `temperature`, `top_p` or `top_k`, and don't prefill the assistant turn.
  - Handle `stop_reason: "refusal"` in code, because Haiku 5.5 has no server-side fallback.
  - The shortest prompt that can be cached is 512 tokens. Players will be spread across the day, so also test the 1-hour cache, which costs twice as much to write.
  - Use the Batch API, which is 50% cheaper, for nightly jobs.
- **Written text before AI.** Each AI feature ships its written-text version first. The game stays playable when Spirit Energy is 0, when the daily cap is hit, or when the server is down.
- **Translation from day 1.** Every string goes through `tr()` keys in `game/i18n/strings.csv`, which has `en` and `vi` columns. Vietnamese is filled in as the game grows and finished in M7.
- **Test builds.** CI publishes web builds to GitHub Pages, which compresses files (itch.io doesn't). The size and load test in M2 picks the final host.

---

## Phase 1 — Prove it

### M1 — Foundations · ~5 h

**Goal:** an empty but real project that tests, builds and deploys.

- [x] Set up the repo skeleton, with `CLAUDE.md` holding the project rules so future Claude sessions follow them.
- [x] Create the Godot project on the newest stable 4.7.x:
  - The Compatibility renderer and a single-threaded "Web" export preset
  - GUT for unit tests
  - A seeded random number generator (`SimRng`), the first piece of the rules engine
  - Translation CSV and a round, cute font with every Vietnamese mark
  - A placeholder title screen with an EN/VI toggle and a text box for typing Vietnamese
- [x] Create the Supabase schema:
  - The GDD tables: `players`, `saves`, `memories`, `ai_usage` and `daily_budget`
  - Row-level security on every table
  - Column grants so the client can never change Spirit Energy
  - Anonymous sign-in turned on
  - pgTAP tests for the security rules
- [x] Set up CI in GitHub Actions: GUT tests, database tests, a web export, and an optional deploy to GitHub Pages.
- [x] Create the hosted Supabase project (free plan) and apply the migration. This is `little-mountain-sect` in us-west-1 (Northern California), the US region closest to Vietnam.
- [x] Turn on GitHub Pages and set the repo variable `DEPLOY_PAGES=true`. The build is live at https://haobui14.github.io/LittleMountainSect/.

**Exit:**
- [x] A push produces a web build.
- [x] GUT tests and database tests pass in CI.
- [x] The web build runs in a browser, in English and Vietnamese.

### M2 — Risk tests · ~15 h

**Goal:** run the GDD's "first tasks for Claude", the tests that decide whether the main idea works.

- [x] **Voice and humor test tools.**
  - A shared prompt (`server/supabase/functions/_shared/world.ts`), 3 sample disciples and the Elder's card.
  - `tools/ai-eval` replays scripted chats and logs each reply with its token counts (cached, new and output), cost, time, check results and any refusal. It writes a report and a ratings sheet to `docs/evals/`.
  - Live runs go through the manual **AI live tests** workflow (`.github/workflows/ai-live.yml`), which needs the repository secret `LMS_ANTHROPIC_API_KEY`.
- [x] Run 10 test chats in English and 10 in Vietnamese (written in `tools/ai-eval/scenarios.ts`). Four eval runs are in `docs/evals/`, from `baseline` to `rules-v4`. They include these attack cases:
  - Romance bait
  - "Give me 1,000,000 Spirit Stones"
  - Prompt injection
  - A player in real distress
  - Off-topic requests
- [x] Compare effort `low`, effort `medium`, and effort `low` with thinking turned off. Thinking off won: replies read as well, arrive faster (95% within 2.8 s) and cost least. The gateway uses it.
- [x] **Real token counts.** Measure chat messages, surprise events and evening stories. Update the GDD's cost table and the Spirit Energy prices. Full use costs $0.009 a day with caching and $0.016 without, so the prices stay at 1, 2 and 3.
- [ ] **Vietnamese typing test** on real devices, following [the typing test protocol](playtests/typing-test.md):
  - Test Telex and VNI on Windows (Unikey or EVKey), macOS, Android (Gboard) and iOS.
  - The HTML `<input>` overlay is already built, so both boxes are tested in one sitting. In headless Chromium, Godot's box ignored text committed the way input methods commit it, while the browser's box handled it.
- [ ] Measure load time on GitHub Pages, and on itch.io if used. Download size is already measured: 39 MB raw, and GitHub Pages sends 10 MB.
- [x] Turn on anonymous sign-ins for the hosted project. In the Supabase dashboard, go to Authentication → Sign In / Providers. The repo's `config.toml` only covers local development.
- [x] **AI gateway v0**, deployed as the `ai-gateway` Edge Function, with a CORS allowlist, Spirit Energy spending and refunds, and the $0.60 daily cap. A leaked test link can cost at most $0.60 a day.
- [x] Set the `ANTHROPIC_API_KEY` secret on the function (Supabase dashboard → Edge Functions → Secrets), then run the **AI live tests** smoke job. The smoke job passes against the current gateway (version 3).

#### Gate 1 — The idea works
- [ ] At least 7 of 10 chats in each language are rated funny. A native Vietnamese speaker rates the Vietnamese chats.
- [x] Every attack case is handled safely (rules-v4: no free resources, no prompt leak, flirting turned down with no memory kept, distress answered with support).
- [x] At least 98% of replies pass the server's checks (rules-v4: 70 of 70).
- [x] 95% of replies arrive within 5 seconds (rules-v4: chat replies 2.8 s at the 95th percentile).
- [x] Full use costs $0.015 or less per player per day. If it costs more, change the Spirit Energy prices until it doesn't. Measured: $0.009 with caching, $0.016 if caching never helps; the true cost falls between, so the beta usage log decides.
- [ ] Vietnamese typing works on desktop and on at least one phone.

---

## Phase 2 — Fun core

### M3 — Core simulation · ~20 h

**Goal:** 10 in-game days are playable with placeholder screens and no AI.

- [x] **Data model.** Typed classes (`Sect`, `Disciple`, `ActiveMission`, `StatusEffect`, `DayReport`) that convert to and from dictionaries. Building levels live in `Sect.buildings`. Saves carry a version number, are checked by `SaveMigration`, and are local (`user://`) for now.
- [x] **Disciple generator.** Each disciple gets:
  - Talent, Body, Spirit and Wit stats
  - A spirit root
  - 2 quirks from a tagged list
  - A name with an English form (pinyin) and a Vietnamese form (Hán-Việt)
- [x] **Daily loop:** Morning report → Day plan → Free time (chat) → Results → Evening story.
  - Players assign each disciple to train, work, rest or go on a mission.
  - The rules cover training progress, Mood and Loyalty drift, food upkeep and production.
- [x] **Buildings:** Main Hall, Disciple Huts, Training Yard and Spirit Field, each with 3 levels.
- [x] **Missions:** Gather Herbs and Hunt a Monster, with result tiers and the setbacks Injured and Lost cultivation.
- [x] **The GDD's start:** a leaky hut, 3 disciples, a small bag of Spirit Stones and the strange Elder. The Elder gives written tips on days 1–5.
- [x] **Placeholder screens:** Mountain (8 slots), Disciples, Day Plan, Results, and an Evening report written from templates. They work on an upright phone and on desktop.
- [x] **Tests:**
  - A GUT test for each rule (80 GUT tests in all).
  - The balance sim (`game/tools/balance_sim.gd`), which plays many seeds headless and reports resource curves and softlocks. See [docs/balance](balance/README.md).

**Exit:**
- [x] 10 days play from start to finish without AI. A GUT test plays them through `GameState`, and `tools/web-check/play_check.cjs` plays them in the web build at phone and desktop sizes.
- [x] CI is green.
- [x] 100 seeds × 60 days run without a softlock or negative resources. CI runs this on every push; 1,000 × 120 also passes.

### M4 — Living disciples · ~20 h

**Goal:** Claude makes the cast feel alive inside the real loop, with saves on the server.

- [ ] **`Backend` service:**
  - Anonymous sign-in and a saved session
  - Request helpers with timeouts and retries
  - A "thinking" animation, because web builds can't stream replies
- [ ] **Server saves.** The save is JSON in `saves`, with a version check. The game loads it at start.
- [ ] **Chat screen:**
  - A placeholder portrait with 6 expressions
  - A Spirit Energy counter and the AI notice
  - The once-a-day Mood bonus
  - A message length limit
- [ ] **Evening story (3 Spirit Energy).** One request returns:
  - The story and the next morning report
  - 1 or 2 disciple decisions, chosen from actions the rules allow
  - Small relationship changes, within the rules' limits
  - New memories

  The server keeps the finished reply, so a background tab can load it later.
- [ ] **The Elder.** Advisor chat costs 1 Spirit Energy. The first 5 days have free written tips.
- [ ] **Memory v1.** A disciple card plus up to 10 key memories in `memories`.
- [ ] **Written fallbacks v1:**
  - Chat lines for each quirk and expression
  - Evening story templates
- [ ] **First launch basics:** choose a language, confirm 18+, and see the AI notice. M8 finishes this flow.

#### Gate 2 — Fun with placeholders
- [ ] You and 3–5 friends each play at least 10 days.
- [ ] At least 3 testers want to keep playing.
- [ ] Each tester can retell at least one funny moment.
- [ ] The game is fully playable with Spirit Energy at 0 and with the server off.
- [ ] `ai_usage` shows all three of these:
  - $0.015 or less per active player per day
  - 95% of replies within 5 seconds
  - Under 2% of replies rejected

---

## Phase 3 — Full first version

### M5 — Sect growth · ~20 h

**Goal:** the full breadth of the core systems for the first version.

- [ ] **Cultivation.** Disciples move through 4 realms. Each breakthrough is a test based on stats, pills and buildings. Failure costs progress and adds a timed funny side effect.
- [ ] **All 8 buildings, each with 3 levels.** This adds the Kitchen, Alchemy Room (pills), Library (techniques by spirit root) and Mission Hall.
- [ ] **All 4 missions.** This adds Escort a Merchant and Explore a Secret Realm, plus two setbacks:
  - Lost, which starts a rescue event
  - Left the sect, where the disciple may return later
- [ ] **Growth.** Recruit up to 12 disciples. The sect's rank rises from Unknown Mountain to Famous Sect.
- [ ] **Surprise events:**
  - Rules decide triggers, cooldowns and rewards.
  - Claude writes the story and the choices, for 2 Spirit Energy.
  - About 20 written fallback events.
  - Each story gets a random place, problem and pair of disciples, so stories don't repeat.
- [ ] Start art work with a style test.

**Exit:**
- [ ] Every system above is unit-tested and playable.
- [ ] 100 seeds × 120 days run cleanly in the balance sim.
- [ ] One 30-day playthrough by hand.

### M6 — Rivals and history · ~20 h

**Goal:** the world outside the mountain and the long-term story. **If time runs short, cut here first** (see the cut list).

- [ ] **3 rival sects:** Iron Frog Sect, Moonlit Tea Society and Perfect Hair Pavilion.
  - Each has an Attitude score from −100 to 100.
  - Players can trade, send gifts and form alliances.
  - A friendly sect with low trust can betray the player.
- [ ] **Seasons of 30 days.** Each season ends in a tournament. The rules decide results and Claude tells the story.
- [ ] **Wars.** A simple contest for land and Reputation.
- [ ] **Generations.**
  - Senior disciples can become Elders.
  - Others ascend or leave to travel, and send letters home.
- [ ] **Sect Chronicle** screen.
- [ ] **Nightly jobs.** Supabase Cron calls an Edge Function that sends work to the Batch API:
  - Merge old memories into shorter notes.
  - Summarize the Chronicle.
  - Write shared world news, 10 items per language.

  A second job collects the results.

#### Gate 3 — Content complete
- [ ] All in-scope systems are playable.
- [ ] 100 seeds × 2 seasons run cleanly.
- [ ] Nightly jobs succeed 3 nights in a row, with batch costs logged.
- [ ] Scope is frozen. Anything unfinished is cut or moved to after the beta.

---

## Phase 4 — Beta

### M7 — Look, sound and language · ~10 h (art work starts during M5)

- [ ] **Art:**
  - Layered portraits (body, hair, robe, face) with 6 expressions
  - One mountain illustration with art for each building level
  - Mist and bird animations
  - A soft, rounded style on all 7 main screens
- [ ] **Audio:**
  - Guzheng and flute music loops
  - Short, playful sound effects
  - Audio starts after the player's first click
- [ ] **Vietnamese:**
  - Translate all menus, content and fallback text.
  - A native speaker reviews the word list and tone.
  - Check the layout of every screen in both languages, at phone and desktop sizes.
- [ ] Polish the Elder's 5-day tutorial.

**Exit:**
- [ ] No placeholder art and no missing translations on the main screens.
- [ ] The native reviewer signs off.

### M8 — Safe launch · ~20 h

- [ ] **Safety:**
  - The full rules go in the shared prompt: no romance or sexual content, the content limits, prompt tricks become jokes, and a line saying the rules always hold.
  - A refusal shows a funny written line.
  - When a player seems to be in real distress, the character leaves the story and shows support resources in English and Vietnamese.
  - A distress keyword check also runs when Spirit Energy is 0, so a canned joke never answers a real call for help.
  - The attack test set in `ai-eval` must pass before any prompt change ships.
- [ ] **Privacy and age:**
  - First launch: language → 18+ check → AI notice → privacy notice explaining that messages go to the server and to Anthropic.
  - The AI notice stays on the chat screen.
  - A "Delete my data" button.
  - No raw chat logs are kept.
- [ ] **Abuse and budget protection:**
  - Invite codes for the 40 Founding Disciples
  - CAPTCHA and a per-player rate limit
  - An end-to-end test of the daily cap
  - In the Anthropic Console, auto-reload off and a spend limit set
- [ ] **Operations:**
  - SQL views for the beta measures below
  - A weekly review
  - A weekly database export, because the free plan has no backups
  - Error reporting
- [ ] **Release:**
  - Check the production build's size and load time.
  - Test in Chrome, Firefox and Safari, and on Android and iOS.
  - Set the final host and CORS.
  - Add version tags and a hotfix routine.
- [ ] **Community:** a Discord server with English and Vietnamese channels, plus feedback and bug channels. Add a "Copy story" button if chosen.

#### Gate 4 — Ready for Founding Disciples
- [ ] Every safety and privacy item is done.
- [ ] The attack test set passes in both languages.
- [ ] 3 outside players per language reach day 10 without help.
- [ ] There are no known crash bugs or lost-save bugs.
- [ ] A test proves the daily cap and Spirit Energy limits work.

Then invite the 40 Founding Disciples and check the beta measures every week.

---

## Cut list

If time runs short, cut in this order:

1. Wars
2. Betrayal and alliances. Keep gifts, trade and tournaments.
3. Rival sects, from 3 down to 1
4. Buildings, from 8 down to 6. Fold the Library and Mission Hall into other buildings.
5. Shared world news
6. Ascension and travel letters. Keep promotion to Elder.

**Never cut:** disciple voice and memory, written fallbacks, safety, budget protection, Vietnamese.

## Decisions needed

| Decision | Needed before |
|---|---|
| ~~OK to create the hosted Supabase project (free plan)~~ | Done: `little-mountain-sect`, us-west-1 |
| ~~Turn on GitHub Pages and set the `DEPLOY_PAGES` variable~~ | Done |
| An Anthropic API key for the game. Is server hosting paid from the $20 budget? Are there API credits from a Max or Team plan? | M2 |
| A native Vietnamese speaker to rate the Vietnamese chats | Gate 1 |
| Who makes the art, and the art budget | Gate 2, so the style test can start early in M5 |
| Music and sound effects, with licences | M6 |
| Final game name in English and Vietnamese | M7 |
| Stay 18+? Add a "Copy story" button? | M8 |
| Donations or more budget | When the beta nears about 75 daily players |

## Beta success measures (from the GDD)

| Measure | Target |
|---|---|
| Players who return on day 7 | 30% or more |
| Messages per active player each day | 8 or more |
| AI cost per active player each day | $0.015 or less |
| Time to receive a reply | 5 seconds or less |
| Claude replies rejected by the server | Under 2% |
| Discord members by the end of the beta | 100 or more |

## How each milestone is checked

- GUT tests run headless in CI for every rule.
- Deno tests on local Supabase cover the gateway's checks, the Spirit Energy and cap race conditions, and the fallback paths.
- `tools/ai-eval` produces a report on every prompt change, in both languages: humor ratings, checks passed, tokens, cost and reply time.
- `tools/balance-sim` plays many seeds to check the game's economy.
- CI publishes a web build on every push. Gates 1 and 4 add tests on real devices.
- Playtest notes go in `docs/playtests/`.
