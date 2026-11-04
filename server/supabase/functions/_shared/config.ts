// Claude settings and limits shared by the AI gateway and tools/ai-eval.
// The model name lives here and nowhere else (the gateway may override it
// with the AI_MODEL secret, for example to test a successor model).

export const DEFAULT_MODEL = "claude-haiku-5-5";

/** Effort levels the API accepts. Haiku 5.5 defaults to "medium"; we start lower. */
export type Effort = "low" | "medium" | "high";
export const DEFAULT_EFFORT: Effort = "low";

/**
 * Thinking is off for every request. In three evals (docs/evals/) replies
 * without thinking were as good, faster (95% of chats within 2.7 s instead
 * of 3.7 s) and cheaper, and mixed in fewer words from the other language.
 */
export type Thinking = "adaptive" | "disabled";
export const DEFAULT_THINKING: Thinking = "disabled";

export type CacheTtl = "5m" | "1h";
export const DEFAULT_CACHE_TTL: CacheTtl = "5m";

export type RequestKind = "chat" | "elder" | "event" | "evening";

/**
 * Output budget per request kind. Thinking counts toward max_tokens, so each
 * budget leaves room for it on top of the visible reply.
 */
export const MAX_TOKENS: Record<RequestKind, number> = {
  chat: 1024,
  elder: 1024,
  event: 2048,
  evening: 4096,
};

export const REQUEST_TIMEOUT_MS = 15_000;
/** Evening stories are long replies: in the evals 95% took under 7 s. */
export const TIMEOUT_MS: Record<RequestKind, number> = {
  chat: REQUEST_TIMEOUT_MS,
  elder: REQUEST_TIMEOUT_MS,
  event: 30_000,
  evening: 40_000,
};

/** Size limits for everything a client sends or Claude returns. */
export const LIMITS = {
  messageChars: 280,
  replyChars: 600,
  recentTurns: 6,
  memories: 10,
  memoryChars: 120,
  /** Memories per disciple shown in the evening prompt. */
  eveningMemories: 3,
  storyChars: 1600,
  morningChars: 500,
  reasonChars: 160,
  decisions: 2,
  relationshipChanges: 3,
} as const;

/**
 * Claude Haiku 5.5 prices in US dollars per million tokens, for prompts of
 * 100,000 tokens or fewer. Longer prompts use a rate card five times higher.
 */
export const PRICES_PER_MTOK = {
  input: 0.10,
  output: 0.50,
  cacheRead: 0.01,
  cacheWrite5m: 0.125,
  cacheWrite1h: 0.20,
} as const;

export const LONG_PROMPT_TOKENS = 100_000;
export const LONG_PROMPT_MULTIPLIER = 5;
