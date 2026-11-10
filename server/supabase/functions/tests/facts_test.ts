import { assertEquals } from "jsr:@std/assert@1";
import { factSentence, joinNames, relationshipWords, resourceList } from "../_shared/facts.ts";
import type { Fact } from "../_shared/schemas.ts";

const names: Record<string, string> = { a: "Lin", b: "Bao", c: "Mei" };
const name = (id: string) => names[id];

Deno.test("names join the way people write them", () => {
  assertEquals(joinNames(["Lin"]), "Lin");
  assertEquals(joinNames(["Lin", "Bao"]), "Lin and Bao");
  assertEquals(joinNames(["Lin", "Bao", "Mei"]), "Lin, Bao and Mei");
});

Deno.test("every fact type becomes a sentence with the right names and numbers", () => {
  const cases: Array<[Fact, string]> = [
    [
      { type: "trained", disciple: "a", gain: 12, ready: false },
      "Lin trained and gained 12 cultivation progress.",
    ],
    [
      { type: "trained", disciple: "a", gain: 3, ready: true },
      "Lin trained and is now ready to break through to the next realm.",
    ],
    [
      { type: "worked", disciples: ["a", "b"], food: 8, herbs: 2 },
      "Lin and Bao worked the Spirit Field and grew 8 Food and 2 Herbs.",
    ],
    [
      { type: "worked", disciples: ["c"], food: 2, herbs: 0 },
      "Mei foraged on the slopes for 2 Food.",
    ],
    [{ type: "rested", disciple: "b", mood: 2 }, "Bao rested."],
    [{ type: "healed", disciple: "b" }, "Bao recovered from an injury."],
    [
      { type: "mission_departed", mission: "hunt_monster", team: ["a", "b"], return_day: 6 },
      "Lin and Bao set out on Hunt a Monster and will be back on day 6.",
    ],
    [
      {
        type: "mission_returned",
        mission: "gather_herbs",
        tier: "great",
        team: ["c"],
        rewards: { herbs: 9, food: 0 },
      },
      "Mei came back from Gather Herbs: a great success. They brought back 9 Herbs.",
    ],
    [
      {
        type: "mission_returned",
        mission: "hunt_monster",
        tier: "failure",
        team: ["a"],
        rewards: { stones: 0 },
      },
      "Lin came back from Hunt a Monster: a failure. They brought back nothing.",
    ],
    [
      { type: "injured", disciple: "a", days: 3, mission: "hunt_monster" },
      "Lin was injured on Hunt a Monster and must rest for 3 days.",
    ],
    [
      { type: "lost_cultivation", disciple: "a", amount: 20, mission: "hunt_monster" },
      "Lin lost 20 cultivation progress on Hunt a Monster.",
    ],
    [{ type: "ate", food: 3 }, "The sect ate 3 Food."],
    [
      { type: "hungry", disciples: ["a", "c"] },
      "There wasn't enough Food: Lin and Mei went to bed hungry.",
    ],
    [
      {
        type: "breakthrough",
        disciple: "a",
        realm: "foundation_building",
        pill: "foundation_pill",
      },
      "Lin broke through to Foundation Building, with help from a Foundation Pill.",
    ],
    [
      {
        type: "breakthrough_failed",
        disciple: "b",
        realm: "golden_core",
        pill: "none",
        effect: "green_hair",
        days: 7,
        lost: 30,
      },
      "Bao tried to break through to Golden Core and failed, losing 30 progress. " +
      "Now Bao has bright green hair, for 7 days.",
    ],
    [
      { type: "effect_ended", disciple: "b", effect: "hiccups" },
      "Bao's hiccups wore off.",
    ],
    [{ type: "studied", disciple: "c", gain: 14 }, "Mei studied in the Library."],
    [
      { type: "learned", disciple: "c", technique: "puddle_mirror_art", tier: 2 },
      "Mei learned the Puddle Mirror Art, level 2 of 3.",
    ],
    [
      { type: "lost", disciple: "a", mission: "explore_secret_realm" },
      "Lin got lost on Explore a Secret Realm and hasn't come home.",
    ],
    [
      { type: "returned", disciple: "a", from: "lost" },
      "Lin found the way home after being lost.",
    ],
    [{ type: "recruited", disciple: "c" }, "Mei joined the sect as a new disciple."],
    [{ type: "rank_up", rank: "rising_sect" }, "The sect is now known as a Rising Sect."],
    [{ type: "brewed", pill: "healing_pill" }, "The Alchemy Room brewed a Healing Pill."],
    [
      { type: "found_item", mission: "explore_secret_realm", item: "golden_pill" },
      "On Explore a Secret Realm, the team found a Golden Core Pill.",
    ],
    [
      {
        type: "event",
        problem: "spirit_goose",
        place: "misty_pond",
        choice: "chase",
        result: "lose",
        disciples: ["a", "b"],
      },
      "Surprise: A spirit goose has claimed the misty pond and honks at anyone who comes near. " +
      "The Sect Master's choice: Lin and Bao chase it off. Risky: they may find Herbs, or get " +
      "bitten. It didn't go to plan.",
    ],
  ];
  for (const [fact, sentence] of cases) assertEquals(factSentence(fact, name), sentence);
});

Deno.test("the world's facts (M6) read as sentences, and the big ones start in capitals", () => {
  const cases: Array<[Fact, string]> = [
    [{ type: "season", season: "summer", year: 1 }, "A new season begins: Summer of year 1."],
    [
      {
        type: "tournament",
        place: 2,
        champions: ["a", "b"],
        matches: [{ rival: "moonlit_tea", won: true }, { rival: "iron_frog", won: false }],
        rewards: { reputation: 8, stones: 20 },
      },
      "TOURNAMENT DAY: the sect's champions Lin and Bao beat the Moonlit Tea Society, then lost " +
      "to the Iron Frog Sect, and the sect came second in the tournament. Prize: 8 Reputation, " +
      "20 Spirit Stones.",
    ],
    [
      {
        type: "tournament",
        place: 4,
        champions: ["c"],
        matches: [{ rival: "perfect_hair", won: false }],
        rewards: {},
      },
      "TOURNAMENT DAY: the sect's champion Mei lost to the Perfect Hair Pavilion, and the sect " +
      "came last in the tournament.",
    ],
    [
      { type: "trade", rival: "moonlit_tea", gave: { herbs: 15 }, got: { stones: 30 } },
      "The sect traded with the Moonlit Tea Society: gave 15 Herbs, got 30 Spirit Stones.",
    ],
    [
      { type: "alliance_ended", rival: "perfect_hair", by: "rival" },
      "The Perfect Hair Pavilion ended its alliance with the sect.",
    ],
    [
      { type: "betrayal", rival: "iron_frog", stones: 0, item: "healing_pill" },
      "BETRAYAL: The Iron Frog Sect, the sect's ally, broke the alliance and made off with a " +
      "Healing Pill.",
    ],
    [
      { type: "war_declared", rival: "iron_frog", battle_day: 33 },
      "WAR: The Iron Frog Sect declared war on the sect. The battle comes on day 33.",
    ],
    [
      { type: "war_result", rival: "iron_frog", won: false, defenders: ["a"], land: 1 },
      "THE BATTLE: Lin defended the sect against the Iron Frog Sect and lost (nobody was hurt " +
      "badly). The sect now holds 1 hill.",
    ],
    [
      { type: "peace", rival: "iron_frog", paid: 50 },
      "The sect made peace with the Iron Frog Sect for 50 Spirit Stones.",
    ],
    [
      { type: "promoted", disciple: "c" },
      "Mei was promoted to Elder of the sect, and will teach from now on.",
    ],
    [
      { type: "ascension_failed", disciple: "a", effect: "green_hair", days: 3, lost: 40 },
      "Lin tried to ascend to the heavens and fell back, losing 40 progress. Side effect for 3 " +
      "days: Lin has bright green hair.",
    ],
    [
      { type: "travel_returned", disciple: "b", place: "snow_peaks", souvenir: "none" },
      "Bao came home from the Snowy Peaks, where old hermits meditate in caves.",
    ],
    [
      { type: "letter", disciple: "b", place: "eastern_sea", gift: { herbs: 6 }, item: "none" },
      "A letter arrived from Bao, away at the Eastern Sea, where fishermen sing to the waves, " +
      "with 6 Herbs.",
    ],
  ];
  for (const [fact, sentence] of cases) assertEquals(factSentence(fact, name), sentence);
});

Deno.test("resources and relationships read as words", () => {
  assertEquals(
    resourceList({ stones: 30, food: 0, reputation: 2 }),
    "30 Spirit Stones, 2 Reputation",
  );
  assertEquals([-12, -5, 0, 6, 15].map(relationshipWords), [
    "rivals",
    "a little cool with each other",
    "on ordinary terms",
    "friendly",
    "close friends",
  ]);
});
