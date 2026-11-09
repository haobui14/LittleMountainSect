# Balance sim reports

`game/tools/balance_sim.gd` plays many seeds headless with two automatic players (`game/tools/sim_players.gd`):

- **sensible:** plays the way the Elder will advise.
  - It keeps about 3 days of Food, rests unhappy disciples and builds in a fixed order, starting with the Spirit Field.
  - It sends one team at a time on the best mission it can win: Spirit Stones when the next upgrade needs them, Herbs when the Alchemy Room is short.
  - It breaks through at 45% odds or better, keeps a small stock of pills, keeps one disciple studying, and takes in hopefuls when there is Food and spare Spirit Stones.
  - In a surprise event, it picks the first choice that costs no Spirit Stones.
- **random:** makes any valid choice: plans, missions, upgrades, pills, hopefuls and event choices. It stress-tests the rules' limits, along with random chat and evening replies.

A run fails if any of these happen:
- a resource goes negative, or a disciple's value leaves its range;
- a plan is rejected;
- the sect holds more disciples than the Main Hall allows, or a pill stock leaves 0–9;
- a lost or departed disciple stays away more than 20 days;
- with the sensible player, Food stays at 0 for 5 days in a row, no disciple is free for 5 days in a row (a softlock), or someone stays ready to break through for 45 days.

CI runs 100 seeds × 120 days on every push and adds the report to the job summary. Every tunable number lives in `game/sim/balance.gd`. To save a report, run from the repo root:

```bash
godot --headless --path game -s res://tools/balance_sim.gd -- --seeds 100 --days 120 --out "$PWD/docs/balance/<label>.md"
```

## M5 ([m5.md](m5.md))

Both players pass 100 × 120, and 500 seeds × 120 days.

What the curves show for the sensible player:

- **Breakthroughs:** the first ones come from about day 20, and most sects have one by day 45. By day 120 the average disciple is in Foundation Building, with about 5 breakthroughs and 2 failures per seed.
- **Herbs** are used rather than piling up until the late game: about 10 from day 30 to day 60, then they grow once the pills are stocked.
- **Spirit Stones:** a median of 40–90 all game, never stuck at 0.
- **Buildings:** every building reaches level 1 in almost every seed. The last one, the Library, gets there around day 76. The Main Hall reaches level 2 (Rising Sect) around day 58. Level 3 (Famous Sect) needs 50 Reputation and 250 Spirit Stones, and only 1% of seeds reach it by day 120. That matches the GDD: becoming famous should take months of play.
- **Growth:** about 2.6 hopefuls join per seed, so a sect has 6 disciples by day 120.
- **Events:** about one every 5 days.
- **Setbacks are rare when you play well:** fewer than 1 in 10 seeds loses a disciple or sees one leave. The random player sees each 1–2 times a seed.

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
