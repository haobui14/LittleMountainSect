import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { costUsd, tokenBreakdown } from "../_shared/cost.ts";

Deno.test("cost adds every token type at Haiku 5.5 prices", () => {
  const usage = {
    input_tokens: 800,
    output_tokens: 250,
    cache_read_input_tokens: 1500,
    cache_creation_input_tokens: 0,
    cache_creation: { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0 },
  };
  // 800 × 0.10 + 1500 × 0.01 + 250 × 0.50 = 80 + 15 + 125 = 220 per million
  assertAlmostEquals(costUsd(usage), 0.000220, 1e-12);
});

Deno.test("cache writes are priced by their TTL", () => {
  const usage = {
    input_tokens: 0,
    output_tokens: 0,
    cache_creation_input_tokens: 3000,
    cache_creation: { ephemeral_5m_input_tokens: 1000, ephemeral_1h_input_tokens: 2000 },
  };
  // 1000 × 0.125 + 2000 × 0.20 = 525 per million
  assertAlmostEquals(costUsd(usage), 0.000525, 1e-12);
});

Deno.test("without a TTL breakdown, cache writes count as 5-minute writes", () => {
  const t = tokenBreakdown({ input_tokens: 1, output_tokens: 1, cache_creation_input_tokens: 700 });
  assertEquals(t.cacheWrite5m, 700);
  assertEquals(t.cacheWrite1h, 0);
  assertEquals(t.cacheRead, 0);
});

Deno.test("prompts over 100,000 tokens use the higher rate card", () => {
  const usage = { input_tokens: 100_001, output_tokens: 0 };
  assertAlmostEquals(costUsd(usage), (100_001 * 0.10 * 5) / 1e6, 1e-12);
});
