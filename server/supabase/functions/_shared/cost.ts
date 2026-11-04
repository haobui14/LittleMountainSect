import { LONG_PROMPT_MULTIPLIER, LONG_PROMPT_TOKENS, PRICES_PER_MTOK } from "./config.ts";

/** The parts of the API's usage object that affect cost. */
export interface UsageLike {
  input_tokens: number;
  output_tokens: number;
  cache_read_input_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
  cache_creation?: {
    ephemeral_5m_input_tokens: number;
    ephemeral_1h_input_tokens: number;
  } | null;
}

export interface TokenBreakdown {
  input: number;
  cacheRead: number;
  cacheWrite5m: number;
  cacheWrite1h: number;
  output: number;
}

export function tokenBreakdown(usage: UsageLike): TokenBreakdown {
  const cacheWrite1h = usage.cache_creation?.ephemeral_1h_input_tokens ?? 0;
  const cacheWrite5m = usage.cache_creation?.ephemeral_5m_input_tokens ??
    Math.max(0, (usage.cache_creation_input_tokens ?? 0) - cacheWrite1h);
  return {
    input: usage.input_tokens,
    cacheRead: usage.cache_read_input_tokens ?? 0,
    cacheWrite5m,
    cacheWrite1h,
    output: usage.output_tokens,
  };
}

/** Cost of one request in US dollars. */
export function costUsd(usage: UsageLike): number {
  const t = tokenBreakdown(usage);
  const promptTokens = t.input + t.cacheRead + t.cacheWrite5m + t.cacheWrite1h;
  const rate = promptTokens > LONG_PROMPT_TOKENS ? LONG_PROMPT_MULTIPLIER : 1;
  const p = PRICES_PER_MTOK;
  const dollars = t.input * p.input +
    t.cacheRead * p.cacheRead +
    t.cacheWrite5m * p.cacheWrite5m +
    t.cacheWrite1h * p.cacheWrite1h +
    t.output * p.output;
  return (dollars * rate) / 1_000_000;
}
