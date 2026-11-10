# Balance sim reports

`game/tools/balance_sim.gd` plays many seeds headless with two automatic players (`game/tools/sim_players.gd`):

- **sensible:** plays the way the Elder will advise.
  - It keeps about 3 days of Food, rests unhappy disciples and builds in a fixed order, starting with the Spirit Field.
  - It sends one team at a time on the best mission it can win: Spirit Stones when the next upgrade needs them, Herbs when the Alchemy Room is short.
  - It breaks through at 45% odds or better, keeps a small stock of pills, keeps one disciple studying, and takes in hopefuls when there is Food and spare Spirit Stones.
  - In a surprise event, it picks the first choice that costs no Spirit Stones.
  - The world (M6): it enters every tournament with its best 3 and keeps teams home for the week before it. In a war it makes peace when its best 4 would win less than 35% of the time and it can pay; otherwise they defend. It takes any alliance offered and trades only what it has plenty of. With its surplus it gives a gift each time it can: first to a doubtful ally, then to a rival cold enough to start a war, then to the warmest rival on the way to an alliance. It lets travellers go while 3 disciples stay home, promotes Elders once it has 5 disciples, and tries to ascend at 45% odds or better.
- **random:** makes any valid choice: plans, missions, upgrades, pills, hopefuls, event choices, and every M6 decision (tournaments, battles and peace, travel, gifts, trades, alliances, Elders). It stress-tests the rules' limits, along with random chat and evening replies.

A run fails if any of these happen:
- a resource goes negative, or a disciple's value leaves its range;
- a plan is rejected;
- the sect holds more disciples than the Main Hall allows (Elders aside), more Elders than the Main Hall's level, or a pill stock leaves 0–9;
- a rival's Attitude (−100 to 100) or Trust (0 to 100), or the sect's land (1 to 5 hills), leaves its range;
- a lost or departed disciple stays away more than 20 days, or a traveller more than 40;
- a war lasts more than 5 days after it is declared, a season ends without its tournament, or a player leaves a morning decision open (the day plan would wait forever);
- with the sensible player, Food stays at 0 for 5 days in a row, no disciple is free for 5 days in a row (a softlock), or someone stays ready to break through for 45 days.

CI runs 100 seeds × 120 days on every push and adds the report to the job summary. Every tunable number lives in `game/sim/balance.gd`. To save a report, run from the repo root:

```bash
godot --headless --path game -s res://tools/balance_sim.gd -- --seeds 100 --days 120 --out "$PWD/docs/balance/<label>.md"
```

## M6 ([m6.md](m6.md))

Both players pass 100 × 120. They also pass 300 seeds × 240 days (8 seasons) each.

What the world looks like for the sensible player:

- **Tournaments get better with time:** in the first season the sect comes 1st 23% of the time and 2nd to 4th the rest; from the second season it wins 52–62% of the time. Rivals grow 4.5 a season, so a sect that stops growing falls back: in the 8th season of the long run it wins 32%.
- **Diplomacy works when you keep at it:** about 21 gifts and 8 trades per seed, three in four seeds form an alliance by day 120, and no ally betrays a sect that keeps its Trust up.
- **Wars are rare:** 4 in 100 seeds (2 battles, both won, and 2 peaces). They come to a sect that rises in rank and wins tournaments, which makes the proud Iron Frog Sect (home Attitude −20) envious. The random player never rises enough to provoke one, so the war rules lean on their GUT tests; the 300 × 240 run sees 24 wars.
- **Generations:** about 3 travels and 6 letters per seed, 1.9 Elders promoted (2 by day 120), and no ascension within 120 days. In 240 days, about 3 disciples per seed ascend.
- **The hills' harvest** (2 Food and 2 Herbs a day) is spent: Herbs hold at 40–50 from day 20, as gifts and trades use them.
- **Safety net:** a sect with fewer than 3 disciples (Elders aside) gets a free hopeful at the gate every day. The long run found a sect left with only Elders and a traveller, with no way to earn Spirit Stones; this rule fixes that soft lock.

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
