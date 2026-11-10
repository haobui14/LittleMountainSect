// The gateway's database access: only the server-side functions from the
// ai_gateway migration, called through the admin (secret key) client.

import type { RequestKind } from "../_shared/config.ts";

export type SpendResult =
  | { ok: true; reason: "ok"; spirit_energy_left: number }
  | {
    ok: false;
    reason: "no_energy" | "budget_cap" | "disabled" | "no_player";
    spirit_energy_left: number;
  };

export type Outcome =
  | "ok"
  | "invalid"
  | "refusal"
  | "max_tokens"
  | "timeout"
  | "error"
  | "no_energy"
  | "budget_cap"
  | "disabled";

export interface UsageEntry {
  player: string;
  kind: RequestKind;
  model: string;
  inputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  outputTokens: number;
  costUsd: number;
  latencyMs: number;
  outcome: Outcome;
}

/** What the gateway needs from the database. Tests pass a fake. */
export interface GatewayDb {
  spend(player: string, kind: RequestKind): Promise<SpendResult>;
  refund(player: string, kind: RequestKind): Promise<number>;
  recordUsage(entry: UsageEntry): Promise<void>;
  recentMemories(player: string, subject: string, limit: number): Promise<string[]>;
  addMemory(player: string, subject: string, content: string, gameDay?: number): Promise<void>;
  /** The checked evening story already stored for that day, or null. */
  getEveningStory(player: string, gameDay: number): Promise<unknown | null>;
  /** Stores a day's story unless one exists; returns the one that is stored. */
  storeEveningStory(player: string, gameDay: number, reply: unknown): Promise<unknown>;
  /** The same for the surprise event that starts on a game day (M5). */
  getEventStory(player: string, gameDay: number): Promise<unknown | null>;
  storeEventStory(player: string, gameDay: number, reply: unknown): Promise<unknown>;
  /** The same for the letter home that arrives on a game day (M6). */
  getLetterStory(player: string, gameDay: number): Promise<unknown | null>;
  storeLetterStory(player: string, gameDay: number, reply: unknown): Promise<unknown>;
}

/** The one supabase-js method we use. */
export interface RpcClient {
  rpc(
    fn: string,
    args?: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string } | null }>;
}

async function call<T>(client: RpcClient, fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw new Error(`${fn} failed: ${error.message}`);
  return data as T;
}

export function supabaseDb(client: RpcClient): GatewayDb {
  return {
    spend: (player, kind) =>
      call<SpendResult>(client, "spend_spirit_energy", { p_player: player, p_kind: kind }),
    refund: (player, kind) =>
      call<number>(client, "refund_spirit_energy", { p_player: player, p_kind: kind }),
    recordUsage: (e) =>
      call<void>(client, "record_ai_usage", {
        p_player: e.player,
        p_kind: e.kind,
        p_model: e.model,
        p_input_tokens: e.inputTokens,
        p_cache_read_tokens: e.cacheReadTokens,
        p_cache_write_tokens: e.cacheWriteTokens,
        p_output_tokens: e.outputTokens,
        p_cost_usd: e.costUsd,
        p_latency_ms: e.latencyMs,
        p_outcome: e.outcome,
      }),
    recentMemories: (player, subject, limit) =>
      call<string[]>(client, "recent_memories", {
        p_player: player,
        p_subject: subject,
        p_limit: limit,
      }),
    addMemory: (player, subject, content, gameDay) =>
      call<void>(client, "add_memory", {
        p_player: player,
        p_subject: subject,
        p_content: content,
        p_game_day: gameDay ?? null,
      }),
    getEveningStory: (player, gameDay) =>
      call<unknown | null>(client, "get_evening_story", { p_player: player, p_game_day: gameDay }),
    storeEveningStory: (player, gameDay, reply) =>
      call<unknown>(client, "store_evening_story", {
        p_player: player,
        p_game_day: gameDay,
        p_reply: reply,
      }),
    getEventStory: (player, gameDay) =>
      call<unknown | null>(client, "get_event_story", { p_player: player, p_game_day: gameDay }),
    storeEventStory: (player, gameDay, reply) =>
      call<unknown>(client, "store_event_story", {
        p_player: player,
        p_game_day: gameDay,
        p_reply: reply,
      }),
    getLetterStory: (player, gameDay) =>
      call<unknown | null>(client, "get_letter_story", { p_player: player, p_game_day: gameDay }),
    storeLetterStory: (player, gameDay, reply) =>
      call<unknown>(client, "store_letter_story", {
        p_player: player,
        p_game_day: gameDay,
        p_reply: reply,
      }),
  };
}
