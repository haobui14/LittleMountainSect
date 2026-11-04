import { type Action, ACTIONS, type Expression } from "./cast.ts";
import { LIMITS } from "./config.ts";
import type { ChatReply } from "./schemas.ts";

/** A chat reply after the server's checks: every value is safe for the rules to use. */
export interface CleanChatReply {
  safety: "ok" | "distress";
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
 * are only suggestions: mood changes are clamped, unknown actions dropped, and
 * a distress reply never changes mood or stores a memory.
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

  const memoryText = raw.memory?.trim() ?? "";
  const action = (ACTIONS as readonly string[]).includes(raw.wants_action ?? "")
    ? raw.wants_action
    : null;
  return {
    ok: true,
    value: {
      safety: "ok",
      reply,
      expression: raw.expression,
      mood_change: clamp(Math.round(raw.mood_change), -2, 2) as CleanChatReply["mood_change"],
      memory: memoryText.length > 0 ? shorten(memoryText, LIMITS.memoryChars) : null,
      wants_action: action,
    },
  };
}
