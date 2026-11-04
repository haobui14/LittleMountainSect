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
