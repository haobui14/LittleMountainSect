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
