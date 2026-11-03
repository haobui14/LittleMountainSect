# Tools

Scripts that support development. They are not shipped with the game.

| Tool | Milestone | What it will do |
|---|---|---|
| `ai-eval/` | M2 | Replays scripted chats against Claude Haiku 5.5 in English and Vietnamese. For each reply it logs tokens, cost, reply time, whether the server checks passed, and refusals. It also runs the attack test set (romance bait, prompt tricks, distress), which must pass before any prompt change ships. |
| `balance-sim/` | M3 | Plays many seeded games headless through the rules engine in `game/sim/`. It reports resource curves, softlocks and impossible states. |

Neither tool exists yet. See [docs/MILESTONES.md](../docs/MILESTONES.md).
