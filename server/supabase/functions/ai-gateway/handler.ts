// The AI gateway's request logic, with its database and Claude client passed
// in, so tests can run it with fakes. index.ts wires in the real ones.
//
// Flow: validate → spend Spirit Energy → (memories) → Claude → check and clamp
// → record usage → save memory → reply. Any failure after the spend refunds
// the Spirit Energy and answers with a written line, so the game never breaks.

import { type CallSettings, callStructured, type MessagesClient } from "../_shared/claude.ts";
import type { CacheTtl } from "../_shared/config.ts";
import { LIMITS } from "../_shared/config.ts";
import { costUsd, tokenBreakdown } from "../_shared/cost.ts";
import { fallbackLine, type FallbackReason, type Speaker } from "../_shared/fallbacks.ts";
import { buildChat } from "../_shared/prompts.ts";
import { type GatewayRequest, GatewayRequestSchema } from "../_shared/schemas.ts";
import { type CleanChatReply, cleanChatReply } from "../_shared/validate.ts";
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
  request: GatewayRequest,
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
