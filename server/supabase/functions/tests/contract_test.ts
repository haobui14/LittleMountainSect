// The game (GDScript) and the server (TypeScript) share ids: quirks, spirit
// roots, realms and pronouns. The game sends them in chat requests from M4,
// and the server's schemas reject anything else, so the two lists must match.

import { assertEquals } from "jsr:@std/assert@1";
import { QUIRK_IDS, REALMS, SPIRIT_ROOTS } from "../_shared/cast.ts";
import { DiscipleCardSchema } from "../_shared/schemas.ts";

const GAME = new URL("../../../../game/sim/", import.meta.url);

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
});
