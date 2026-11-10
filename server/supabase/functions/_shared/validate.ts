import { type Action, ACTIONS, type Expression } from "./cast.ts";
import { LIMITS } from "./config.ts";
import { choiceIds } from "./events.ts";
import type {
  ChatReply,
  EveningReply,
  EveningRequest,
  EventReply,
  EventRequest,
  LetterReply,
  Safety,
} from "./schemas.ts";

/** A chat reply after the server's checks: every value is safe for the rules to use. */
export interface CleanChatReply {
  safety: Safety;
  reply: string;
  expression: Expression;
  mood_change: -2 | -1 | 0 | 1 | 2;
  memory: string | null;
  wants_action: Action | null;
}

export type CleanResult =
  | { ok: true; value: CleanChatReply }
  | { ok: false; detail: string };

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/** Shortens text to a character limit at a word boundary, adding an ellipsis. */
export function shorten(text: string, maxChars: number): string {
  const chars = Array.from(text);
  if (chars.length <= maxChars) return text;
  const cut = chars.slice(0, maxChars - 1).join("");
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > maxChars / 2 ? cut.slice(0, lastSpace) : cut).trimEnd() + "…";
}

/**
 * Checks and clamps a chat reply. Code decides results, so Claude's numbers
 * are only suggestions: mood changes are clamped and unknown actions dropped.
 * A distress or boundary reply never changes mood or stores a memory, so a
 * crisis or a flirting attempt is never brought up again.
 */
export function cleanChatReply(raw: ChatReply): CleanResult {
  const reply = raw.reply.trim();
  if (reply.length === 0) return { ok: false, detail: "empty reply" };
  if (Array.from(reply).length > LIMITS.replyChars) {
    return { ok: false, detail: `reply longer than ${LIMITS.replyChars} characters` };
  }

  if (raw.safety === "distress") {
    return {
      ok: true,
      value: {
        safety: "distress",
        reply,
        expression: "thinking",
        mood_change: 0,
        memory: null,
        wants_action: null,
      },
    };
  }

  const boundary = raw.safety === "boundary";
  const memoryText = boundary ? "" : raw.memory?.trim() ?? "";
  const action = (ACTIONS as readonly string[]).includes(raw.wants_action ?? "")
    ? raw.wants_action
    : null;
  return {
    ok: true,
    value: {
      safety: boundary ? "boundary" : "ok",
      reply,
      expression: raw.expression,
      mood_change: boundary
        ? 0
        : clamp(Math.round(raw.mood_change), -2, 2) as CleanChatReply["mood_change"],
      memory: memoryText.length > 0 ? shorten(memoryText, LIMITS.memoryChars) : null,
      wants_action: action,
    },
  };
}

// Evening story -----------------------------------------------------------------

export interface CleanEveningReply {
  story: string;
  morning_report: string;
  /** At most LIMITS.decisions, one per disciple, each from that disciple's allowed actions. */
  decisions: Array<{ disciple_id: string; action: Action; reason: string }>;
  /** At most one per disciple, shortened to LIMITS.memoryChars. */
  memories: Array<{ disciple_id: string; text: string }>;
  /** At most LIMITS.relationshipChanges distinct pairs, each change -2..2 and never 0. */
  relationship_changes: Array<{ from: string; to: string; change: number; reason: string }>;
}

export type CleanEveningResult =
  | { ok: true; value: CleanEveningReply }
  | { ok: false; detail: string };

/**
 * Checks an evening story against the request it answers. Anything that names
 * a disciple who isn't in the request, an action the rules don't allow, or a
 * change beyond the limits is dropped; only an empty story is rejected.
 */
export function cleanEveningReply(raw: EveningReply, request: EveningRequest): CleanEveningResult {
  const story = raw.story.trim();
  const morning = raw.morning_report.trim();
  if (story.length === 0) return { ok: false, detail: "empty story" };
  if (morning.length === 0) return { ok: false, detail: "empty morning report" };

  const allowed = new Map(request.disciples.map((d) => [d.card.id, new Set(d.allowed_actions)]));
  const decided = new Set<string>();
  const decisions: CleanEveningReply["decisions"] = [];
  for (const d of raw.decisions) {
    if (decisions.length >= LIMITS.decisions || decided.has(d.disciple_id)) continue;
    if (!allowed.get(d.disciple_id)?.has(d.action)) continue;
    decided.add(d.disciple_id);
    decisions.push({
      disciple_id: d.disciple_id,
      action: d.action,
      reason: shorten(d.reason.trim(), LIMITS.reasonChars),
    });
  }

  const remembered = new Set<string>();
  const memories: CleanEveningReply["memories"] = [];
  for (const m of raw.memories) {
    const text = m.text.trim();
    if (!allowed.has(m.disciple_id) || remembered.has(m.disciple_id) || text.length === 0) continue;
    remembered.add(m.disciple_id);
    memories.push({ disciple_id: m.disciple_id, text: shorten(text, LIMITS.memoryChars) });
  }

  const pairs = new Set<string>();
  const changes: CleanEveningReply["relationship_changes"] = [];
  for (const r of raw.relationship_changes) {
    if (changes.length >= LIMITS.relationshipChanges) break;
    if (r.from === r.to || !allowed.has(r.from) || !allowed.has(r.to)) continue;
    const key = [r.from, r.to].sort().join("|");
    const change = clamp(Math.round(r.change), -2, 2);
    if (pairs.has(key) || change === 0) continue;
    pairs.add(key);
    changes.push({
      from: r.from,
      to: r.to,
      change,
      reason: shorten(r.reason.trim(), LIMITS.reasonChars),
    });
  }

  return {
    ok: true,
    value: {
      story: shorten(story, LIMITS.storyChars),
      morning_report: shorten(morning, LIMITS.morningChars),
      decisions,
      memories,
      relationship_changes: changes,
    },
  };
}

// Surprise events ----------------------------------------------------------------

export interface CleanEventReply {
  title: string;
  story: string;
  /** One entry per choice the rules offer, in the catalog's order. */
  choices: Array<{ id: string; text: string }>;
}

export type CleanEventResult =
  | { ok: true; value: CleanEventReply }
  | { ok: false; detail: string };

/**
 * Checks an event reply against the catalog: every choice the rules offer
 * must have words, in the catalog's order. Unknown choices are dropped; a
 * missing one, an empty title or an empty story is rejected.
 */
export function cleanEventReply(raw: EventReply, request: EventRequest): CleanEventResult {
  const title = raw.title.trim();
  const story = raw.story.trim();
  if (title.length === 0) return { ok: false, detail: "empty title" };
  if (story.length === 0) return { ok: false, detail: "empty story" };
  const written = new Map<string, string>();
  for (const choice of raw.choices) {
    const text = choice.text.trim();
    if (text.length > 0 && !written.has(choice.id)) written.set(choice.id, text);
  }
  const choices: CleanEventReply["choices"] = [];
  for (const id of choiceIds(request.problem)) {
    const text = written.get(id);
    if (text === undefined) return { ok: false, detail: `no words for choice ${id}` };
    choices.push({ id, text: shorten(text, LIMITS.choiceChars) });
  }
  return {
    ok: true,
    value: {
      title: shorten(title, LIMITS.eventTitleChars),
      story: shorten(story, LIMITS.eventStoryChars),
      choices,
    },
  };
}

export type CleanLetterReply = { letter: string };
export type CleanLetterResult =
  | { ok: true; value: CleanLetterReply }
  | { ok: false; detail: string };

/** A letter home (M6): the text, trimmed and shortened; empty is a failure. */
export function cleanLetterReply(raw: LetterReply): CleanLetterResult {
  const letter = raw.letter.trim();
  if (letter.length === 0) return { ok: false, detail: "empty letter" };
  return { ok: true, value: { letter: shorten(letter, LIMITS.letterChars) } };
}
