# Gate 2 — Fun with placeholders

Gate 2 closes Phase 2 ("Fun core"). M4 brings Claude into the game loop, so this gate asks whether the game is fun with placeholder art. It also checks that the AI stays cheap, quick and reliable once real people play.

| Criterion | Status | Evidence |
|---|---|---|
| You and 3–5 friends each play at least 10 days | **Waiting on testers** | Follow [For testers](#for-testers) below. |
| At least 3 testers want to keep playing | **Waiting on testers** | The tester notes. |
| Each tester can retell at least one funny moment | **Waiting on testers** | The tester notes. |
| The game is fully playable with Spirit Energy at 0 and with the server off | **Met in automated checks; confirm by hand** | CI plays 10 days in Chromium at phone and desktop sizes with the server blocked (`play_check.cjs --offline`). GUT covers the no-Spirit-Energy path (`test_with_no_spirit_energy_the_gateways_written_line_is_used`) and the written evening (`test_without_the_server_the_written_evening_stays`). To check by hand, see [Without the AI](#without-the-ai). |
| `ai_usage`: $0.015 or less per active player per day | **Waiting on play data** | Before the playtest: $0.0007 per player per day (smoke tests only). The [m4 eval](../evals/20261104-2157-m4/report.md) costs an evening story at $0.0005 with caching and $0.0007 without. |
| `ai_usage`: 95% of replies within 5 seconds | **Waiting on play data** | Before the playtest, 95% of chat replies arrived within 2.5 s (eval) and 1.9 s (deployed gateway). Evening stories take 5–6 s; see the note below. |
| `ai_usage`: under 2% of replies rejected | **Waiting on play data** | Before the playtest: 0 of 64 eval calls and 0 of 7 gateway calls. |

**Evening stories and the 5-second target:** evening stories take longer than 5 s (p95 5.7 s in the eval and 5.1 s on the gateway). The game shows the written evening at once and swaps in the story when it arrives, so nobody waits on it. The queries below report each kind separately. Judge the 5-second target on chat and Elder replies, and keep an eye on evenings.

## For testers

Play on the [live build](https://haobui14.github.io/LittleMountainSect/), on a phone or a computer. Each tester:

1. **Starts the game.** On first launch, choose a language, read the AI notice and confirm you are 18 or older.
2. **Plays at least 10 in-game days.** That can be in one sitting or across several. Each day:
   - Plan the day: training, work, rest or missions.
   - Chat with a disciple or two in free time, and ask the Elder something now and then.
   - Read the evening story the next morning.
3. **Tries both text boxes.** The chat box is the browser's own by default. Turn on "Use the game's own text box" below it for a few messages. Note any trouble with either one, especially with Vietnamese typing.
4. **Writes a few notes** (template below).

### What to expect

- **Spirit Energy:** each player has 50 a day, refilled at midnight UTC.
  - A chat line or an Elder question costs 1. An evening story costs 3.
  - Ten days in one sitting use about 30 on evening stories alone.
  - When Spirit Energy runs out, replies and evenings switch to written text and the game carries on. That is expected, not a bug.
- **Decisions:** disciples sometimes decide what they'll do tomorrow. The plan marks it. Overruling them is allowed but costs that disciple 1 Mood.
- **Reloading:** the page continues from your save on the server. In a private window the save lasts only as long as the window.

### Tester notes (copy one per tester)

```
Tester:            (first name or nickname)
Device / browser:  (e.g. iPhone 15 Safari, Windows Chrome)
Language played:   en / vi
Days played:
Want to keep playing? yes / no / maybe, and why
A funny moment, retold in your own words:
Text box problems (browser box / game's box):
Anything confusing, broken or unfair:
```

## Without the AI

Both of these are checked automatically, but one hand check each is worth doing on the live build.

- **Server off:** load the game, then go offline. Use airplane mode, or DevTools → Network → Offline.
  - Play a day. Chats get written lines marked "(written)", and the evening is the written report.
  - Nothing should freeze or show an error.
- **Spirit Energy at 0:** chat once on the live build, then run this in the Supabase SQL editor:

  ```sql
  update public.players set spirit_energy = 0
  where id = (select player_id from public.ai_usage order by created_at desc limit 1);
  ```

  - Chats now get the sleepy written lines, and the evening is the written report.
  - Spirit Energy refills at the next UTC midnight.

## Reading `ai_usage` after the playtest

Run these in the Supabase SQL editor. Set the date to the first day of the playtest, so earlier smoke tests are left out.

**Cost per active player per day:**

```sql
with per_player as (
  select player_id, (created_at at time zone 'utc')::date as day, sum(cost_usd) as cost
  from public.ai_usage
  where created_at >= '2026-11-05'
  group by 1, 2
)
select day, count(*) as players, round(avg(cost), 4) as avg_usd, round(max(cost), 4) as max_usd
from per_player group by day order by day;
```

**Reply time, by kind** (only requests that reached Claude):

```sql
select kind, count(*) as replies,
  percentile_cont(0.95) within group (order by latency_ms) as p95_ms,
  round(100.0 * avg((latency_ms <= 5000)::int), 1) as pct_within_5s
from public.ai_usage
where created_at >= '2026-11-05' and outcome not in ('no_energy', 'budget_cap', 'disabled')
group by kind order by kind;
```

**Rejected replies.** These are replies the server's checks turned down (`invalid`), refusals, timeouts and errors. Each one got a written line instead.

```sql
select count(*) as claude_calls,
  count(*) filter (where outcome <> 'ok') as rejected,
  round(100.0 * count(*) filter (where outcome <> 'ok') / greatest(count(*), 1), 1) as pct_rejected
from public.ai_usage
where created_at >= '2026-11-05' and outcome not in ('no_energy', 'budget_cap', 'disabled');
```

## Gate 1 follow-ups closed in M4

- **Mixed languages:** each language's forms of address moved out of the shared rules and into a block for that language only. In the m4 eval, none of the 32 English replies used a Vietnamese form of address.
- **Distress resources:** when a reply is marked `distress`, the chat screen shows a support panel:
  - 988 in the US
  - 115 for emergencies in Vietnam
  - findahelpline.com

  M8 reviews the final wording.
- **Vietnamese review:** still open for M7, along with every Vietnamese string in `game/i18n/strings.csv`.
