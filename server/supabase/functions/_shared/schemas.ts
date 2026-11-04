import { z } from "./deps.ts";
import { ACTIONS, EXPRESSIONS, QUIRK_IDS, REALMS, SPIRIT_ROOTS } from "./cast.ts";
import { LIMITS } from "./config.ts";

export const LocaleSchema = z.enum(["en", "vi"]);

/** A letter first, then letters (any script, with Vietnamese marks), spaces, ' or -. */
const NAME_PATTERN = /^\p{L}[\p{L}\p{M} '-]{0,39}$/u;

/**
 * A disciple as the client describes them. Personality comes only from catalog
 * quirk ids and enums, so the only free text a player controls is their message.
 */
export const DiscipleCardSchema = z.strictObject({
  id: z.string().regex(/^[a-z0-9-]{1,32}$/),
  name: z.string().regex(NAME_PATTERN),
  pronouns: z.enum(["he", "she", "they"]),
  quirks: z.array(z.enum(QUIRK_IDS)).min(1).max(3),
  spirit_root: z.enum(SPIRIT_ROOTS),
  realm: z.enum(REALMS),
  mood: z.int().min(-10).max(10),
  loyalty: z.int().min(0).max(100),
});
export type DiscipleCard = z.infer<typeof DiscipleCardSchema>;

const TurnSchema = z.discriminatedUnion("from", [
  z.strictObject({ from: z.literal("player"), text: z.string().min(1).max(LIMITS.messageChars) }),
  z.strictObject({ from: z.literal("character"), text: z.string().min(1).max(LIMITS.replyChars) }),
]);
export type Turn = z.infer<typeof TurnSchema>;

const RecentSchema = z.array(TurnSchema).max(LIMITS.recentTurns).default([]);
const MessageSchema = z.string().trim().min(1).max(LIMITS.messageChars);

/** What the game sends to the AI gateway. */
export const GatewayRequestSchema = z.discriminatedUnion("kind", [
  z.strictObject({
    kind: z.literal("chat"),
    locale: LocaleSchema,
    disciple: DiscipleCardSchema,
    recent: RecentSchema,
    message: MessageSchema,
  }),
  z.strictObject({
    kind: z.literal("elder"),
    locale: LocaleSchema,
    recent: RecentSchema,
    message: MessageSchema,
  }),
]);
export type GatewayRequest = z.infer<typeof GatewayRequestSchema>;

// What Claude returns. These schemas avoid numeric and length limits because
// the API cannot enforce them; validate.ts clamps values instead. `safety`
// comes first so the model decides it before writing the reply.

export const ChatReplySchema = z.object({
  safety: z.enum(["ok", "distress"]),
  reply: z.string(),
  expression: z.enum(EXPRESSIONS),
  mood_change: z.int(),
  memory: z.string().nullable(),
  wants_action: z.enum(ACTIONS).nullable(),
});
export type ChatReply = z.infer<typeof ChatReplySchema>;

// Surprise events and evening stories. In M2 only tools/ai-eval uses these, to
// measure real token counts; the gateway serves them from M4 and M5.

export const EventInputSchema = z.strictObject({
  locale: LocaleSchema,
  place: z.string().min(1).max(80),
  problem: z.string().min(1).max(200),
  disciples: z.array(DiscipleCardSchema).min(1).max(4),
  choices: z.array(z.strictObject({
    id: z.string().regex(/^[a-z0-9_]{1,32}$/),
    effect_hint: z.string().min(1).max(120),
  })).min(2).max(3),
});
export type EventInput = z.infer<typeof EventInputSchema>;

export const EventReplySchema = z.object({
  title: z.string(),
  story: z.string(),
  choices: z.array(z.object({ id: z.string(), text: z.string() })),
});
export type EventReply = z.infer<typeof EventReplySchema>;

export const EveningInputSchema = z.strictObject({
  locale: LocaleSchema,
  day: z.int().min(1),
  sect: z.strictObject({
    rank: z.string().min(1).max(40),
    resources: z.string().min(1).max(200),
  }),
  disciples: z.array(z.strictObject({
    card: DiscipleCardSchema,
    today: z.string().min(1).max(240),
    allowed_actions: z.array(z.enum(ACTIONS)).min(1),
  })).min(1).max(12),
  facts: z.array(z.string().min(1).max(200)).max(12),
});
export type EveningInput = z.infer<typeof EveningInputSchema>;

export const EveningReplySchema = z.object({
  story: z.string(),
  morning_report: z.string(),
  decisions: z.array(z.object({
    disciple_id: z.string(),
    action: z.enum(ACTIONS),
    reason: z.string(),
  })),
  memories: z.array(z.object({ disciple_id: z.string(), text: z.string() })),
  relationship_changes: z.array(z.object({
    from: z.string(),
    to: z.string(),
    change: z.int(),
    reason: z.string(),
  })),
});
export type EveningReply = z.infer<typeof EveningReplySchema>;
