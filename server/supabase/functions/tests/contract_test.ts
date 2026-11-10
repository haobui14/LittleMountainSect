// The game (GDScript) and the server (TypeScript) share ids: quirks, spirit
// roots, realms and pronouns. The game sends them in chat requests from M4,
// and the server's schemas reject anything else, so the two lists must match.

import { assertEquals } from "jsr:@std/assert@1";
import {
  ACTIONS,
  PILLS,
  QUIRK_IDS,
  REALMS,
  RIVALS,
  SEASONS,
  SIDE_EFFECTS,
  SPIRIT_ROOTS,
  STATUSES,
  TECHNIQUES,
} from "../_shared/cast.ts";
import { TRAVEL_PLACE_IDS } from "../_shared/travel.ts";
import { choiceIds, PLACE_IDS, PROBLEM_IDS } from "../_shared/events.ts";
import {
  DiscipleCardSchema,
  EveningRequestSchema,
  EventRequestSchema,
  GatewayRequestSchema,
  LetterRequestSchema,
} from "../_shared/schemas.ts";

const GAME = new URL("../../../../game/sim/", import.meta.url);
const FIXTURES = new URL("../../../../game/tests/fixtures/", import.meta.url);

async function gdscript(path: string): Promise<string> {
  return await Deno.readTextFile(new URL(path, GAME));
}

/** The quoted strings in `const NAME: Array[String] = [...]`. */
function stringArray(source: string, name: string): string[] {
  const match = source.match(new RegExp(`const ${name}: Array\\[String\\] = \\[([^\\]]*)\\]`));
  if (!match) throw new Error(`const ${name} not found`);
  return [...match[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}

Deno.test("the game's quirk ids match the server's", async () => {
  const source = await gdscript("data/quirks.gd");
  const tags = source.slice(source.indexOf("const TAGS"), source.indexOf("}"));
  const ids = [...tags.matchAll(/^\t"([a-z_]+)":/gm)].map((m) => m[1]);
  assertEquals(ids.toSorted(), [...QUIRK_IDS].toSorted());
});

Deno.test("the game's spirit roots, realms and pronouns match the server's", async () => {
  const balance = await gdscript("balance.gd");
  assertEquals(stringArray(balance, "SPIRIT_ROOTS"), [...SPIRIT_ROOTS]);
  assertEquals(stringArray(balance, "REALMS"), [...REALMS]);
  assertEquals(stringArray(balance, "PRONOUNS"), DiscipleCardSchema.shape.pronouns.options);
  assertEquals(stringArray(balance, "ACTIONS"), [...ACTIONS]);
});

Deno.test("the game's M5 ids match the server's: statuses, pills, side effects, techniques", async () => {
  const balance = await gdscript("balance.gd");
  assertEquals(stringArray(balance, "STATUSES"), [...STATUSES]);
  assertEquals(stringArray(balance, "PILLS"), [...PILLS]);
  assertEquals(stringArray(balance, "SIDE_EFFECTS"), [...SIDE_EFFECTS]);
  assertEquals(stringArray(balance, "TECHNIQUES"), [...TECHNIQUES]);
});

// The game writes these files from its own code (game/tests/unit/test_contract_fixtures.gd).
async function fixture(name: string): Promise<unknown> {
  return JSON.parse(await Deno.readTextFile(new URL(name, FIXTURES)));
}

Deno.test("the game's event catalog has the server's places, problems and choices", async () => {
  const catalog = await fixture("event_catalog.json") as {
    places: string[];
    problems: Record<string, string[]>;
  };
  assertEquals(catalog.places.toSorted(), [...PLACE_IDS].toSorted());
  assertEquals(Object.keys(catalog.problems).toSorted(), [...PROBLEM_IDS].toSorted());
  for (const problem of PROBLEM_IDS) {
    assertEquals(catalog.problems[problem], choiceIds(problem), `choices of ${problem}`);
  }
});

Deno.test("the server accepts the requests the game sends", async () => {
  DiscipleCardSchema.parse(await fixture("disciple_card.json"));
  const chat = GatewayRequestSchema.parse(await fixture("chat_request.json"));
  assertEquals(chat.kind, "chat");
  const evening = EveningRequestSchema.parse(await fixture("evening_request.json"));
  assertEquals(evening.kind, "evening");
  assertEquals(GatewayRequestSchema.parse(evening).kind, "evening");
  const event = EventRequestSchema.parse(await fixture("event_request.json"));
  assertEquals([event.kind, event.problem], ["event", "frog_duel"]);
  assertEquals(event.disciples[0].effects, ["green_hair"]);
  assertEquals(event.disciples[1].status, "mission");
});

Deno.test("the game's M6 ids match the server's: rivals, seasons, travel places", async () => {
  const catalog = await fixture("world_catalog.json") as Record<string, string[]>;
  assertEquals(catalog.rivals, [...RIVALS]);
  assertEquals(catalog.seasons, [...SEASONS]);
  assertEquals(catalog.travel_places, [...TRAVEL_PLACE_IDS]);
  // The catalog fixture is written by the game, and also checked against its source.
  assertEquals(stringArray(await gdscript("data/travel.gd"), "PLACES"), [...TRAVEL_PLACE_IDS]);
  assertEquals(stringArray(await gdscript("balance.gd"), "SEASONS"), [...SEASONS]);
});

Deno.test("the server accepts the world's requests: an evening full of M6 facts and a letter", async () => {
  const evening = EveningRequestSchema.parse(await fixture("world_evening_request.json"));
  const types = evening.facts.map((f) => f.type);
  for (const type of ["tournament", "war_result", "gift", "trade", "promoted", "travel_left"]) {
    assertEquals(types.includes(type as typeof types[number]), true, type);
  }
  assertEquals(evening.disciples.some((d) => d.card.role === "elder"), true);
  assertEquals(evening.disciples.some((d) => d.card.status === "travel"), true);
  const letter = LetterRequestSchema.parse(await fixture("letter_request.json"));
  assertEquals([letter.kind, letter.place, letter.disciple.status], [
    "letter",
    "noodle_town",
    "travel",
  ]);
  assertEquals(GatewayRequestSchema.parse(letter).kind, "letter");
});
