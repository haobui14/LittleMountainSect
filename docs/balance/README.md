# Balance sim reports

`game/tools/balance_sim.gd` plays many seeds headless with two automatic players (`game/tools/sim_players.gd`):

- **sensible:** plays the way the Elder will advise. It keeps about 3 days of Food, rests unhappy disciples, hunts when it needs Spirit Stones, and builds the Spirit Field first.
- **random:** makes any valid plan. It stress-tests the rules' limits.

A run fails if any of these happen:
- a resource goes negative, or a disciple's value leaves its range;
- a plan is rejected;
- with the sensible player, Food stays at 0 for 5 days in a row, or no disciple is free for 5 days in a row (a softlock).

CI runs 100 seeds × 60 days on every push and adds the report to the job summary. Every tunable number lives in `game/sim/balance.gd`. To save a report, run from the repo root:

```bash
godot --headless --path game -s res://tools/balance_sim.gd -- --seeds 100 --days 60 --out "$PWD/docs/balance/<label>.md"
```

## M3 start ([m3-start.md](m3-start.md))

Both players pass 100 × 60. They also pass 1,000 seeds × 120 days.

What the curves show for the sensible player:

- **Food** holds at about 8, and never stays at 0.
- **Spirit Stones** never run out for good and never pile up: the median is 50–80 after day 10.
- **First upgrade:** the Spirit Field on day 1, then the Training Yard around day 5 and the Huts around day 8.
- **Mid-game upgrades are slow:** the Main Hall reaches level 2 in 64% of seeds, around day 36. Nothing reaches level 3 within 60 days. Revisit this after Gate 2 playtests; raising Hunt a Monster's Stone reward is the simplest fix.
- **Herbs pile up** (about 50 by day 60) because nothing uses them yet. The Alchemy Room (M5) gives them a use.
- **Cultivation:** average progress reaches about 75 by day 60, and some disciples reach 100 (ready to break through). Tune this with breakthroughs in M5.
- **Missions:** Hunt a Monster succeeds or better about half the time for the sensible player's teams, and goes badly 18% of the time.
- **Random player:** often runs out of Food and lets Mood sink, but never breaks a rule. That's the point of that player.
