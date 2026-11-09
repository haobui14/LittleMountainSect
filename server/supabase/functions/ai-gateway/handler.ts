// The AI gateway's request logic, with its database and Claude client passed
// in, so tests can run it with fakes. index.ts wires in the real ones.
//
// Flow: validate → spend Spirit Energy → (memories) → Claude → check and clamp
// → record usage → save memory → reply. Any failure after the spend refunds
// the Spirit Energy and answers with a written line, so the game never breaks.
//
// Evening stories and surprise events (kinds "evening" and "event") answer
// with the reply already stored for that game day when there is one, so
// asking twice never pays twice; on a failure they answer
// {source: "fallback"} and the game writes its own.

import { type CallSettings, callStructured, type MessagesClient } from "../_shared/claude.ts";
import type { CacheTtl } from "../_shared/config.ts";
import { LIMITS, TIMEOUT_MS } from "../_shared/config.ts";
import { costUsd, tokenBreakdown } from "../_shared/cost.ts";
import { fallbackLine, type FallbackReason, type Speaker } from "../_shared/fallbacks.ts";
import { buildChat, buildEvening, buildEvent, type BuiltPrompt } from "../_shared/prompts.ts";
import {
  type ChatRequest,
  type EveningReply,
  type EveningRequest,
  type EventReply,
  type EventRequest,
  GatewayRequestSchema,
} from "../_shared/schemas.ts";
import {
  type CleanChatReply,
  cleanChatReply,
  type CleanEveningReply,
  cleanEveningReply,
  type CleanEventReply,
  cleanEventReply,
} from "../_shared/validate.ts";
import type { GatewayDb, Outcome } from "./db.ts";

export interface GatewayDeps {
  db: GatewayDb;
  /** null when the ANTHROPIC_API_KEY secret is not set: AI is off. */
  claude: MessagesClient | null;
  settings: CallSettings & { cacheTtl: CacheTtl };
  /** 0 to 1, picks among written lines. */
  random?: () => number;
}

/** The largest request body we read. Real requests are a few kilobytes. */
const MAX_BODY_BYTES = 16_384;

type ReplyBody =
  & { source: "ai" | "fallback"; reason?: FallbackReason; spirit_energy_left: number }
  & CleanChatReply;

function json(status: number, body: unknown): Response {
  return Response.json(body, { status });
}

function fallbackBody(
  reason: FallbackReason,
  speaker: Speaker,
  request: ChatRequest,
  energyLeft: number,
  random: () => number,
): ReplyBody {
  const line = fallbackLine(reason, speaker, request.locale, random());
  return {
    source: "fallback",
    reason,
    safety: "ok",
    reply: line.reply,
    expression: line.expression,
    mood_change: 0,
    memory: null,
    wants_action: null,
    spirit_energy_left: energyLeft,
  };
}

/**
 * JSON with every object's keys sorted. Postgres jsonb reorders keys, so a
 * stored copy only compares equal to the original this way.
 */
export function canonical(value: unknown): string {
  return JSON.stringify(
    value,
    (_key, v) =>
      v !== null && typeof v === "object" && !Array.isArray(v)
        ? Object.fromEntries(
          Object.entries(v as Record<string, unknown>).sort(([a], [b]) =>
            a < b ? -1 : a > b ? 1 : 0
          ),
        )
        : v,
  );
}

/** One structured log line per request: metadata only, never chat text. */
function log(fields: Record<string, unknown>) {
  console.log(JSON.stringify({ fn: "ai-gateway", ...fields }));
}

export async function handleGateway(
  req: Request,
  playerId: string,
  deps: GatewayDeps,
): Promise<Response> {
  const random = deps.random ?? Math.random;
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const raw = await req.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
    return json(413, { error: "request_too_large" });
  }
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const parsed = GatewayRequestSchema.safeParse(body);
  if (!parsed.success) {
    const issues = parsed.error.issues.slice(0, 5).map((issue) => ({
      path: issue.path.join("."),
      message: issue.message,
    }));
    return json(400, { error: "invalid_request", issues });
  }
  const request = parsed.data;
  if (request.kind === "evening") return await handleEvening(request, playerId, deps);
  if (request.kind === "event") return await handleEvent(request, playerId, deps);
  const speaker: Speaker = request.kind === "chat" ? "disciple" : "elder";
  const zeroUsage = {
    player: playerId,
    kind: request.kind,
    model: deps.settings.model,
    inputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    outputTokens: 0,
    costUsd: 0,
    latencyMs: 0,
  };

  try {
    if (deps.claude === null) {
      log({ kind: request.kind, outcome: "disabled", note: "no ANTHROPIC_API_KEY" });
      return json(200, fallbackBody("disabled", speaker, request, 0, random));
    }

    const spend = await deps.db.spend(playerId, request.kind);
    if (!spend.ok) {
      if (spend.reason === "no_player") throw new Error("no players row for this user");
      await deps.db.recordUsage({ ...zeroUsage, outcome: spend.reason });
      log({ kind: request.kind, outcome: spend.reason });
      return json(
        200,
        fallbackBody(spend.reason, speaker, request, spend.spirit_energy_left, random),
      );
    }

    const memories = request.kind === "chat"
      ? await deps.db.recentMemories(playerId, request.disciple.id, LIMITS.memories)
      : [];
    const prompt = buildChat(request, memories, { cacheTtl: deps.settings.cacheTtl });
    const result = await callStructured(deps.claude, prompt, deps.settings);

    let reply: CleanChatReply | null = null;
    let outcome: Outcome;
    if (result.ok) {
      const cleaned = cleanChatReply(result.value);
      reply = cleaned.ok ? cleaned.value : null;
      outcome = cleaned.ok ? "ok" : "invalid";
    } else {
      outcome = result.reason;
    }

    const tokens = result.usage ? tokenBreakdown(result.usage) : null;
    const cost = result.usage ? costUsd(result.usage) : 0;
    await deps.db.recordUsage({
      ...zeroUsage,
      inputTokens: tokens?.input ?? 0,
      cacheReadTokens: tokens?.cacheRead ?? 0,
      cacheWriteTokens: (tokens?.cacheWrite5m ?? 0) + (tokens?.cacheWrite1h ?? 0),
      outputTokens: tokens?.output ?? 0,
      costUsd: cost,
      latencyMs: result.latencyMs,
      outcome,
    });
    log({
      kind: request.kind,
      outcome,
      latency_ms: result.latencyMs,
      cost_usd: cost,
      tokens,
      ...(result.ok ? {} : { detail: result.detail }),
    });

    if (reply === null) {
      const left = await deps.db.refund(playerId, request.kind);
      const reason: FallbackReason = outcome === "refusal" ? "refusal" : "error";
      return json(200, fallbackBody(reason, speaker, request, left, random));
    }

    if (reply.memory !== null && request.kind === "chat") {
      await deps.db.addMemory(playerId, request.disciple.id, reply.memory);
    }
    const body: ReplyBody = {
      source: "ai",
      ...reply,
      spirit_energy_left: spend.spirit_energy_left,
    };
    return json(200, body);
  } catch (error) {
    // The database or something unexpected failed. The written line keeps the
    // game going; the 503 tells the client the server had a problem.
    log({ kind: request.kind, outcome: "server_error", detail: String(error) });
    return json(503, fallbackBody("error", speaker, request, 0, random));
  }
}

type StoryBody<T> =
  | (T & { source: "ai"; stored: boolean; spirit_energy_left: number | null })
  | { source: "fallback"; reason: FallbackReason; spirit_energy_left: number };

/** How one kind of stored story (an evening or a surprise event) is made. */
interface StoryKind<Raw, Clean> {
  kind: "evening" | "event";
  gameDay: number;
  get(): Promise<unknown | null>;
  store(reply: Clean): Promise<unknown>;
  build(): Promise<BuiltPrompt<Raw>>;
  clean(raw: Raw): { ok: true; value: Clean } | { ok: false; detail: string };
  /** Runs after a good reply, before it is stored (evening memories). */
  keep?(reply: Clean): Promise<void>;
}

/**
 * The flow both stored kinds share: return the stored reply for that game
 * day for free; otherwise spend, call Claude, check, record usage, keep and
 * store. Any failure refunds and answers {source: "fallback"}, and the game
 * writes its own text.
 */
async function handleStory<Raw, Clean>(
  story: StoryKind<Raw, Clean>,
  playerId: string,
  deps: GatewayDeps,
): Promise<Response> {
  const kind = story.kind;
  const fallback = (reason: FallbackReason, left: number, status = 200) =>
    json(
      status,
      { source: "fallback", reason, spirit_energy_left: left } satisfies StoryBody<Clean>,
    );
  const zeroUsage = {
    player: playerId,
    kind,
    model: deps.settings.model,
    inputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    outputTokens: 0,
    costUsd: 0,
    latencyMs: 0,
  };

  try {
    if (deps.claude === null) {
      log({ kind, outcome: "disabled", note: "no ANTHROPIC_API_KEY" });
      return fallback("disabled", 0);
    }

    const stored = await story.get();
    if (stored) {
      log({ kind, outcome: "stored" });
      const body = {
        ...(stored as Clean),
        source: "ai" as const,
        stored: true,
        spirit_energy_left: null,
      };
      return json(200, body satisfies StoryBody<Clean>);
    }

    const spend = await deps.db.spend(playerId, kind);
    if (!spend.ok) {
      if (spend.reason === "no_player") throw new Error("no players row for this user");
      await deps.db.recordUsage({ ...zeroUsage, outcome: spend.reason });
      log({ kind, outcome: spend.reason });
      return fallback(spend.reason, spend.spirit_energy_left);
    }

    const prompt = await story.build();
    const result = await callStructured(deps.claude, prompt, {
      ...deps.settings,
      timeoutMs: TIMEOUT_MS[kind],
    });

    let reply: Clean | null = null;
    let outcome: Outcome;
    if (result.ok) {
      const cleaned = story.clean(result.value);
      reply = cleaned.ok ? cleaned.value : null;
      outcome = cleaned.ok ? "ok" : "invalid";
    } else {
      outcome = result.reason;
    }

    const tokens = result.usage ? tokenBreakdown(result.usage) : null;
    const cost = result.usage ? costUsd(result.usage) : 0;
    await deps.db.recordUsage({
      ...zeroUsage,
      inputTokens: tokens?.input ?? 0,
      cacheReadTokens: tokens?.cacheRead ?? 0,
      cacheWriteTokens: (tokens?.cacheWrite5m ?? 0) + (tokens?.cacheWrite1h ?? 0),
      outputTokens: tokens?.output ?? 0,
      costUsd: cost,
      latencyMs: result.latencyMs,
      outcome,
    });
    log({
      kind,
      outcome,
      latency_ms: result.latencyMs,
      cost_usd: cost,
      tokens,
      ...(result.ok ? {} : { detail: result.detail }),
    });

    if (reply === null) {
      const left = await deps.db.refund(playerId, kind);
      return fallback(outcome === "refusal" ? "refusal" : "error", left);
    }

    await story.keep?.(reply);
    const kept = await story.store(reply);
    let left = spend.spirit_energy_left;
    if (canonical(kept) !== canonical(reply)) {
      // Another request for the same day finished first and was stored; it
      // was already paid for, so this one is refunded.
      left = await deps.db.refund(playerId, kind);
    }
    const body = {
      ...(kept as Clean),
      source: "ai" as const,
      stored: false,
      spirit_energy_left: left,
    };
    return json(200, body satisfies StoryBody<Clean>);
  } catch (error) {
    log({ kind, outcome: "server_error", detail: String(error) });
    return fallback("error", 0, 503);
  }
}

function handleEvening(
  request: EveningRequest,
  playerId: string,
  deps: GatewayDeps,
): Promise<Response> {
  return handleStory<EveningReply, CleanEveningReply>(
    {
      kind: "evening",
      gameDay: request.game_day,
      get: () => deps.db.getEveningStory(playerId, request.game_day),
      store: (reply) => deps.db.storeEveningStory(playerId, request.game_day, reply),
      build: async () => {
        const memories: Record<string, string[]> = {};
        await Promise.all(request.disciples.map(async ({ card }) => {
          memories[card.id] = await deps.db.recentMemories(
            playerId,
            card.id,
            LIMITS.eveningMemories,
          );
        }));
        return buildEvening(request, memories, { cacheTtl: deps.settings.cacheTtl });
      },
      clean: (raw) => cleanEveningReply(raw, request),
      keep: async (reply) => {
        for (const memory of reply.memories) {
          await deps.db.addMemory(playerId, memory.disciple_id, memory.text, request.game_day);
        }
      },
    },
    playerId,
    deps,
  );
}

function handleEvent(
  request: EventRequest,
  playerId: string,
  deps: GatewayDeps,
): Promise<Response> {
  return handleStory<EventReply, CleanEventReply>(
    {
      kind: "event",
      gameDay: request.game_day,
      get: () => deps.db.getEventStory(playerId, request.game_day),
      store: (reply) => deps.db.storeEventStory(playerId, request.game_day, reply),
      build: () => Promise.resolve(buildEvent(request, { cacheTtl: deps.settings.cacheTtl })),
      clean: (raw) => cleanEventReply(raw, request),
    },
    playerId,
    deps,
  );
}
