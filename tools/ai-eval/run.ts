// Runs the eval scenarios through the same prompt builders and call path the
// AI gateway uses, and checks what a script can check. People rate the rest.

import type { Locale } from "../../server/supabase/functions/_shared/cast.ts";
import {
  type CallSettings,
  callStructured,
  type MessagesClient,
} from "../../server/supabase/functions/_shared/claude.ts";
import {
  type CacheTtl,
  DEFAULT_MODEL,
  type Effort,
  LIMITS,
  type RequestKind,
} from "../../server/supabase/functions/_shared/config.ts";
import {
  costUsd,
  type TokenBreakdown,
  tokenBreakdown,
} from "../../server/supabase/functions/_shared/cost.ts";
import { fallbackLine } from "../../server/supabase/functions/_shared/fallbacks.ts";
import {
  buildChat,
  buildEvening,
  buildEvent,
} from "../../server/supabase/functions/_shared/prompts.ts";
import {
  type EveningInput,
  EveningInputSchema,
  type EventInput,
  EventInputSchema,
  type GatewayRequest,
  GatewayRequestSchema,
  type Turn,
} from "../../server/supabase/functions/_shared/schemas.ts";
import { cleanChatReply } from "../../server/supabase/functions/_shared/validate.ts";
import type { ChatScenario, SafetyExpectation, Tag } from "./scenarios.ts";

/** Letters only Vietnamese uses, so they should never appear in English text. */
const VIETNAMESE_WORD =
  /[\p{L}]*[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ][\p{L}]*/iu;

/** Glossary words that should never appear untranslated in Vietnamese text. */
const ENGLISH_TERMS = [
  "Master",
  "Sect",
  "Disciple",
  "Elder",
  "Spirit Stone",
  "Spirit Energy",
  "Secret Realm",
  "Qi Refining",
  "Foundation Building",
  "Golden Core",
  "Nascent Soul",
  "Iron Frog",
  "Moonlit Tea",
  "Perfect Hair",
  "Patience",
];
const ENGLISH_TERM = new RegExp(`\\b(${ENGLISH_TERMS.join("|")})`, "u");

/** The first word from the other language in `text`, or null. */
export function otherLanguageWord(text: string, locale: Locale): string | null {
  const match = text.match(locale === "en" ? VIETNAMESE_WORD : ENGLISH_TERM);
  return match ? match[0] : null;
}

function expectedSafety(scenario: ChatScenario, turn: number): SafetyExpectation {
  const strict = scenario.tag === "funny" || scenario.tag === "advice";
  return scenario.expectSafety?.[turn] ?? (strict ? "ok" : "not distress");
}

export interface EvalConfig {
  name: string;
  effort: Effort;
  thinking: "adaptive" | "disabled";
}

export const CONFIGS: Record<string, EvalConfig> = {
  "low": { name: "low", effort: "low", thinking: "adaptive" },
  "medium": { name: "medium", effort: "medium", thinking: "adaptive" },
  "low-nothink": { name: "low-nothink", effort: "low", thinking: "disabled" },
};

/** Longer outputs need longer timeouts. */
const TIMEOUT_MS: Record<RequestKind, number> = {
  chat: 15_000,
  elder: 15_000,
  event: 30_000,
  evening: 60_000,
};

export interface Check {
  name: string;
  pass: boolean;
  note?: string;
}

export interface CallRecord {
  config: string;
  kind: RequestKind;
  scenario: string;
  locale: Locale;
  tag: Tag | "event" | "evening";
  turn: number;
  /** The player's line (chat only). */
  player: string | null;
  ok: boolean;
  /** Failure reason when not ok. */
  reason: string | null;
  detail: string | null;
  /** The checked reply: a clean chat reply, or the event or evening JSON. */
  output: unknown;
  tokens: TokenBreakdown | null;
  costUsd: number;
  latencyMs: number;
  checks: Check[];
}

export interface RunOptions {
  model?: string;
  cacheTtl: CacheTtl;
  concurrency: number;
}

// Distinctive pieces of the hidden prompt. If a reply repeats one, the prompt leaked.
const LEAK_MARKERS = [
  "You voice the characters",
  "funny, warm game about running",
  "player_message",
  "wants_action",
  "mood_change",
  "This request:",
];

function settings(config: EvalConfig, kind: RequestKind, options: RunOptions): CallSettings {
  return {
    model: options.model ?? DEFAULT_MODEL,
    effort: config.effort,
    thinking: config.thinking,
    timeoutMs: TIMEOUT_MS[kind],
  };
}

/** Builds the gateway request for one chat turn, exactly as the game would send it. */
export function chatRequest(
  scenario: ChatScenario,
  recent: Turn[],
  message: string,
): GatewayRequest {
  const base = {
    locale: scenario.locale,
    recent: recent.slice(-LIMITS.recentTurns),
    message,
  };
  return GatewayRequestSchema.parse(
    scenario.character === "elder"
      ? { kind: "elder", ...base }
      : { kind: "chat", disciple: scenario.character, ...base },
  );
}

export async function runChatScenario(
  client: MessagesClient,
  scenario: ChatScenario,
  config: EvalConfig,
  options: RunOptions,
): Promise<CallRecord[]> {
  const records: CallRecord[] = [];
  const recent: Turn[] = [];
  const memories: string[] = [];

  for (const [turn, message] of scenario.turns.entries()) {
    const request = chatRequest(scenario, recent, message);
    const prompt = buildChat(request, memories.slice(-LIMITS.memories), {
      cacheTtl: options.cacheTtl,
    });
    const result = await callStructured(client, prompt, settings(config, request.kind, options));
    const cleaned = result.ok ? cleanChatReply(result.value) : null;

    const checks: Check[] = [];
    const expected = expectedSafety(scenario, turn);
    if (cleaned?.ok) {
      const reply = cleaned.value;
      checks.push({ name: "valid reply", pass: true });
      const safe = expected === "not distress"
        ? reply.safety !== "distress"
        : reply.safety === expected;
      checks.push({
        name: `safety is ${expected}`,
        pass: safe,
        note: safe ? undefined : `got ${reply.safety}`,
      });
      const slip = otherLanguageWord(reply.reply, scenario.locale) ??
        otherLanguageWord(reply.memory ?? "", scenario.locale);
      checks.push({
        name: "one language",
        pass: slip === null,
        note: slip ? `"${slip}" in a ${scenario.locale} reply or memory` : undefined,
      });
      const leak = LEAK_MARKERS.find((m) => reply.reply.includes(m));
      checks.push({
        name: "no prompt leak",
        pass: leak === undefined,
        note: leak ? `reply contains "${leak}"` : undefined,
      });
      if (result.ok && result.value.mood_change !== reply.mood_change) {
        checks.push({
          name: "mood change in range",
          pass: false,
          note: `clamped ${result.value.mood_change} to ${reply.mood_change}`,
        });
      }
      if (reply.memory) memories.push(reply.memory);
    } else {
      const why = result.ok ? (cleaned && !cleaned.ok ? cleaned.detail : "") : result.detail;
      checks.push({ name: "valid reply", pass: false, note: why });
    }

    const speaker = scenario.character === "elder" ? "elder" : "disciple";
    const replyText = cleaned?.ok ? cleaned.value.reply : fallbackLine(
      result.ok ? "error" : result.reason === "refusal" ? "refusal" : "error",
      speaker,
      scenario.locale,
      0,
    ).reply;
    recent.push({ from: "player", text: message });
    recent.push({ from: "character", text: replyText.slice(0, LIMITS.replyChars) });

    records.push({
      config: config.name,
      kind: request.kind,
      scenario: scenario.id,
      locale: scenario.locale,
      tag: scenario.tag,
      turn,
      player: message,
      ok: cleaned?.ok ?? false,
      reason: result.ok ? (cleaned?.ok ? null : "invalid") : result.reason,
      detail: result.ok ? (cleaned && !cleaned.ok ? cleaned.detail : null) : result.detail,
      output: cleaned?.ok ? cleaned.value : null,
      tokens: result.usage ? tokenBreakdown(result.usage) : null,
      costUsd: result.usage ? costUsd(result.usage) : 0,
      latencyMs: result.latencyMs,
      checks,
    });
  }
  return records;
}

export async function runEvent(
  client: MessagesClient,
  input: EventInput,
  index: number,
  config: EvalConfig,
  options: RunOptions,
): Promise<CallRecord> {
  const result = await callStructured(
    client,
    buildEvent(input, { cacheTtl: options.cacheTtl }),
    settings(config, "event", options),
  );
  const checks: Check[] = [{
    name: "valid reply",
    pass: result.ok,
    note: result.ok ? undefined : result.detail,
  }];
  if (result.ok) {
    const want = input.choices.map((c) => c.id).join(",");
    const got = result.value.choices.map((c) => c.id).join(",");
    checks.push({
      name: "choices match the rules' choices",
      pass: want === got,
      note: want === got ? undefined : `got ${got}`,
    });
  }
  return {
    config: config.name,
    kind: "event",
    scenario: `event_${index + 1}_${input.locale}`,
    locale: input.locale,
    tag: "event",
    turn: 0,
    player: null,
    ok: result.ok && checks.every((c) => c.pass),
    reason: result.ok ? null : result.reason,
    detail: result.ok ? null : result.detail,
    output: result.ok ? result.value : null,
    tokens: result.usage ? tokenBreakdown(result.usage) : null,
    costUsd: result.usage ? costUsd(result.usage) : 0,
    latencyMs: result.latencyMs,
    checks,
  };
}

export async function runEvening(
  client: MessagesClient,
  input: EveningInput,
  config: EvalConfig,
  options: RunOptions,
): Promise<CallRecord> {
  const result = await callStructured(
    client,
    buildEvening(input, { cacheTtl: options.cacheTtl }),
    settings(config, "evening", options),
  );
  const checks: Check[] = [{
    name: "valid reply",
    pass: result.ok,
    note: result.ok ? undefined : result.detail,
  }];
  if (result.ok) {
    const allowed = new Map(input.disciples.map((d) => [d.card.id, d.allowed_actions as string[]]));
    const badDecision = result.value.decisions.find((d) =>
      !allowed.get(d.disciple_id)?.includes(d.action)
    );
    checks.push({
      name: "decisions use allowed actions",
      pass: badDecision === undefined,
      note: badDecision ? `${badDecision.disciple_id}: ${badDecision.action}` : undefined,
    });
    const badChange = result.value.relationship_changes.find((r) => Math.abs(r.change) > 2);
    checks.push({
      name: "relationship changes in range",
      pass: badChange === undefined,
      note: badChange ? `${badChange.from}→${badChange.to}: ${badChange.change}` : undefined,
    });
  }
  return {
    config: config.name,
    kind: "evening",
    scenario: `evening_day${input.day}_${input.locale}`,
    locale: input.locale,
    tag: "evening",
    turn: 0,
    player: null,
    ok: result.ok && checks.every((c) => c.pass),
    reason: result.ok ? null : result.reason,
    detail: result.ok ? null : result.detail,
    output: result.ok ? result.value : null,
    tokens: result.usage ? tokenBreakdown(result.usage) : null,
    costUsd: result.usage ? costUsd(result.usage) : 0,
    latencyMs: result.latencyMs,
    checks,
  };
}

/** Runs tasks with at most `limit` in flight, keeping the results in order. */
export async function pool<T>(limit: number, tasks: Array<() => Promise<T>>): Promise<T[]> {
  const results: T[] = new Array(tasks.length);
  let next = 0;
  const workers = Array.from({ length: Math.max(1, Math.min(limit, tasks.length)) }, async () => {
    while (next < tasks.length) {
      const i = next++;
      results[i] = await tasks[i]();
    }
  });
  await Promise.all(workers);
  return results;
}

export interface Selection {
  chats: ChatScenario[];
  events: EventInput[];
  evenings: EveningInput[];
}

export async function runConfig(
  client: MessagesClient,
  config: EvalConfig,
  selection: Selection,
  options: RunOptions,
): Promise<CallRecord[]> {
  const tasks: Array<() => Promise<CallRecord[]>> = [
    ...selection.chats.map((s) => () => runChatScenario(client, s, config, options)),
    ...selection.events.map((e, i) => async () => [await runEvent(client, e, i, config, options)]),
    ...selection.evenings.map(
      (e) => async () => [await runEvening(client, e, config, options)],
    ),
  ];
  return (await pool(options.concurrency, tasks)).flat();
}

/** Checks every scenario and builds every prompt without calling Claude. */
export function dryRun(selection: Selection, cacheTtl: CacheTtl): string[] {
  const problems: string[] = [];
  const ids = new Set<string>();
  for (const scenario of selection.chats) {
    if (ids.has(scenario.id)) problems.push(`duplicate scenario id ${scenario.id}`);
    ids.add(scenario.id);
    const recent: Turn[] = [];
    for (const message of scenario.turns) {
      try {
        buildChat(chatRequest(scenario, recent, message), [], { cacheTtl });
      } catch (error) {
        problems.push(`${scenario.id}: ${error instanceof Error ? error.message : error}`);
      }
      recent.push({ from: "player", text: message }, { from: "character", text: "…" });
    }
  }
  for (const input of selection.events) {
    const parsed = EventInputSchema.safeParse(input);
    if (!parsed.success) problems.push(`event ${input.place}: ${parsed.error.message}`);
    else buildEvent(parsed.data, { cacheTtl });
  }
  for (const input of selection.evenings) {
    const parsed = EveningInputSchema.safeParse(input);
    if (!parsed.success) problems.push(`evening day ${input.day}: ${parsed.error.message}`);
    else buildEvening(parsed.data, { cacheTtl });
  }
  return problems;
}
