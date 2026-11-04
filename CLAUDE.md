# Little Mountain Sect — notes for Claude

A funny, warm xianxia sect-management web game. It is built with Godot 4 (GDScript) and exported to the web, with Supabase as the server and Claude Haiku 5.5 voicing the disciples.

- Read [docs/GDD.md](docs/GDD.md) for the design and [docs/MILESTONES.md](docs/MILESTONES.md) for the build plan.
- GitHub issues #1–#8 track progress, one per milestone. `docs/MILESTONES.md` is the plan of record.

## Rules that always apply

1. **Code decides results; Claude decides words.**
   - Claude's replies never set numbers directly.
   - The rules engine and the server check, clamp or reject every value Claude suggests: mood changes, actions, rewards and memories.
2. **The Claude API key exists only on the server**, as a Supabase secret or in a local `.env` for tools.
   - Never put it in `game/` or commit it.
   - The web build is public and anyone can read its files.
3. **Every AI feature has a written-text fallback, built first.** The game must stay playable when:
   - Spirit Energy is 0
   - The daily budget cap is hit
   - Claude refuses a request
   - The server is down
4. **All player-facing text goes through `tr()`.**
   - Keys live in `game/i18n/strings.csv`, with an `en` and a `vi` column, and every key needs both.
   - Use the GDD's word list for xianxia terms, such as Sect Master = Chưởng môn and Spirit Stones = Linh thạch.
   - Vietnamese text is a draft until a native speaker reviews it in M7.
5. **`game/sim/` is the pure rules engine.**
   - No nodes, scenes, UI, autoloads or `OS`/`Time` calls.
   - All randomness goes through `SimRng`, whose state is stored in the save.
   - Every rule gets a GUT test.
6. **The web export has constraints:**
   - GDScript only (C# can't export to the web)
   - The Compatibility renderer
   - A single-threaded export
   - No streamed HTTP replies, so show a "thinking" animation instead
7. **Claude API settings** (see "Claude API settings" in docs/GDD.md):
   - The model name `claude-haiku-5-5` lives in one server setting.
   - Use structured outputs (`output_config.format`) and set `effort` explicitly. Build the schema with `_shared/json_schema.ts`, not the SDK's `zodOutputFormat`, which in SDK 1.4.0 turns `enum` into a description.
   - Call through `_shared/claude.ts` (`messages.create`, then parse), so a failed reply is still costed and logged.
   - Never send `temperature`, `top_p` or `top_k`, and never prefill the assistant turn.
   - Read reply content blocks by `type`.
   - Handle `stop_reason: "refusal"`.
8. **Safety:**
   - No romance or sexual content, ever.
   - Disciples never die.
   - When a player seems to be in real distress, the character steps out of the story and shows support resources.

## Commands

Godot is pinned to **4.7.2**, matching `GODOT_VERSION` in `.github/workflows/ci.yml`. Run these from the repo root:

```bash
godot --headless --path game --import
```

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd
```

The test command uses `game/.gutconfig.json`, which runs `game/tests/` and exits with a non-zero code on failure.

```bash
godot --headless --path game --export-release Web ../build/web/index.html
```

Web export needs the 4.7.2 export templates installed.

Database tests run against the local Supabase stack. They need Docker:

```bash
cd server && npx supabase@3.0.0 db start && npx supabase@3.0.0 test db
```

Edge Function and tool code is TypeScript on **Deno 2.9.6**, matching `DENO_VERSION` in CI. Third-party imports are pinned in `server/supabase/functions/_shared/deps.ts`. Run these from the repo root:

```bash
deno fmt --check && deno lint && deno check server/supabase/functions/ tools/
```

```bash
deno test --allow-read=.
```

The tests need no network and no secrets; Claude and the database are faked.

The AI eval checks every scenario and builds every prompt without calling Claude:

```bash
deno run --allow-read --allow-env tools/ai-eval/main.ts --dry-run
```

Live evals and the gateway smoke test run in the manual **AI live tests** workflow (`.github/workflows/ai-live.yml`). Each full eval costs about $0.10–0.25, and the report is committed to `docs/evals/`.

## Secrets

- `ANTHROPIC_API_KEY`: on the `ai-gateway` Edge Function, set in the Supabase dashboard (Edge Functions → Secrets). Without it, the gateway answers with written lines and spends nothing.
- `LMS_ANTHROPIC_API_KEY`: a GitHub repository secret for the eval. Tools read this name, never `ANTHROPIC_API_KEY`, so it can't mix with other Claude credentials.
- Optional function secrets: `AI_MODEL` (overrides `claude-haiku-5-5`) and `ALLOWED_ORIGINS` (comma-separated; the defaults are in `ai-gateway/cors.ts`).
- `game/config/backend.json` holds the project URL and the publishable key. Both are public by design; never put a secret there.

## Hosted services

**Supabase** hosts the project `little-mountain-sect`:
- Project ref `qeciplcjdlcygcxbeddg`, in us-west-1 (Northern California), on the free plan.
- Its migration history must match `server/supabase/migrations/`. Apply new migrations with the Supabase connector, or with `supabase db push` after running `supabase link`.
- If the project records a different version number for a migration, rename the local file to match.
- Free projects pause after 7 days without use and have no automatic backups.
- The `ai-gateway` Edge Function is deployed with the Supabase connector. Upload every file under `server/supabase/functions/` that it imports, named relative to that folder (`ai-gateway/index.ts`, `_shared/deps.ts` and so on), with entrypoint `ai-gateway/index.ts` and `verify_jwt` on.

## Layout

| Path | Contents |
|---|---|
| `game/` | The Godot project: `autoload/`, `scenes/`, `sim/` (the rules engine), `i18n/`, `assets/` and `tests/` (GUT) |
| `game/config/` | `backend.json`: the public Supabase URL and publishable key |
| `server/supabase/` | `config.toml`, `migrations/` and `tests/database/` (pgTAP) |
| `server/supabase/functions/` | `_shared/` (prompts, schemas, the Claude call path, validation, costs), `ai-gateway/`, and `tests/` (Deno) |
| `tools/` | `ai-eval/` (live AI tests), `smoke/` (gateway smoke test), `web-check/` (browser typing check), and `balance-sim/` (M3) |
| `docs/` | The GDD, the milestones, `evals/` (AI eval reports) and `playtests/` |
