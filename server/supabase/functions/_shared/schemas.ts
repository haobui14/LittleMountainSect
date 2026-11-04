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

// Evening story (M4) --------------------------------------------------------
//
// The game sends the day as typed facts with ids and numbers, never sentences:
// the server writes the facts up itself (facts.ts), so the only free text a
// player controls stays in chat messages.

const DiscipleIdSchema = z.string().regex(/^[a-z0-9-]{1,32}$/);
const DiscipleIdsSchema = z.array(DiscipleIdSchema).min(1).max(12);
export const MISSIONS = [
  "gather_herbs",
  "hunt_monster",
  "escort_merchant",
  "explore_secret_realm",
] as const;
export const TIERS = ["great", "success", "partial", "failure", "disaster"] as const;
export const RESOURCES = ["stones", "food", "herbs", "reputation"] as const;
export const RANKS = ["unknown_mountain", "rising_sect", "famous_sect"] as const;
const Amount = z.int().min(0).max(1_000_000);

export const FactSchema = z.discriminatedUnion("type", [
  z.strictObject({
    type: z.literal("trained"),
    disciple: DiscipleIdSchema,
    gain: z.int().min(0).max(100),
    ready: z.boolean(),
  }),
  z.strictObject({
    type: z.literal("worked"),
    disciples: DiscipleIdsSchema,
    food: Amount,
    herbs: Amount,
  }),
  z.strictObject({
    type: z.literal("rested"),
    disciple: DiscipleIdSchema,
    mood: z.int().min(-20).max(20),
  }),
  z.strictObject({ type: z.literal("healed"), disciple: DiscipleIdSchema }),
  z.strictObject({
    type: z.literal("mission_departed"),
    mission: z.enum(MISSIONS),
    team: DiscipleIdsSchema,
    return_day: z.int().min(1),
  }),
  z.strictObject({
    type: z.literal("mission_returned"),
    mission: z.enum(MISSIONS),
    tier: z.enum(TIERS),
    team: DiscipleIdsSchema,
    rewards: z.partialRecord(z.enum(RESOURCES), Amount),
  }),
  z.strictObject({
    type: z.literal("injured"),
    disciple: DiscipleIdSchema,
    days: z.int().min(1).max(60),
    mission: z.enum(MISSIONS),
  }),
  z.strictObject({
    type: z.literal("lost_cultivation"),
    disciple: DiscipleIdSchema,
    amount: z.int().min(0).max(100),
    mission: z.enum(MISSIONS),
  }),
  z.strictObject({ type: z.literal("ate"), food: Amount }),
  z.strictObject({ type: z.literal("hungry"), disciples: DiscipleIdsSchema }),
]);
export type Fact = z.infer<typeof FactSchema>;

export const EveningRequestSchema = z.strictObject({
  kind: z.literal("evening"),
  locale: LocaleSchema,
  game_day: z.int().min(1).max(1_000_000),
  sect: z.strictObject({
    rank: z.enum(RANKS),
    resources: z.strictObject({ stones: Amount, food: Amount, herbs: Amount, reputation: Amount }),
  }),
  /** Every disciple, with the actions the rules allow tomorrow (none when away). */
  disciples: z.array(z.strictObject({
    card: DiscipleCardSchema,
    allowed_actions: z.array(z.enum(ACTIONS)).max(ACTIONS.length),
  })).min(1).max(12),
  relationships: z.array(z.strictObject({
    a: DiscipleIdSchema,
    b: DiscipleIdSchema,
    score: z.int().min(-20).max(20),
  })).max(66).default([]),
  facts: z.array(FactSchema).max(40),
}).superRefine((request, ctx) => {
  // Every id a fact or relationship names must be one of the given disciples.
  const ids = new Set(request.disciples.map((d) => d.card.id));
  if (ids.size !== request.disciples.length) {
    ctx.addIssue({ code: "custom", message: "duplicate disciple id", path: ["disciples"] });
  }
  const named = (fact: Fact): string[] =>
    "disciple" in fact
      ? [fact.disciple]
      : "disciples" in fact
      ? fact.disciples
      : "team" in fact
      ? fact.team
      : [];
  request.facts.forEach((fact, i) => {
    for (const id of named(fact)) {
      if (!ids.has(id)) {
        ctx.addIssue({ code: "custom", message: `unknown disciple ${id}`, path: ["facts", i] });
      }
    }
  });
  request.relationships.forEach((r, i) => {
    if (!ids.has(r.a) || !ids.has(r.b) || r.a === r.b) {
      ctx.addIssue({
        code: "custom",
        message: "bad relationship pair",
        path: ["relationships", i],
      });
    }
  });
});
export type EveningRequest = z.infer<typeof EveningRequestSchema>;

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
  EveningRequestSchema,
]);
export type GatewayRequest = z.infer<typeof GatewayRequestSchema>;
/** A chat line with a disciple or the Elder. */
export type ChatRequest = Extract<GatewayRequest, { kind: "chat" | "elder" }>;

// What Claude returns. These schemas avoid numeric and length limits because
// the API cannot enforce them; validate.ts clamps values instead. `safety`
// comes first so the model decides it before writing the reply.

/**
 * "boundary": the player pushed against the safety rules (such as flirting)
 * and the reply declines. "distress": the player seems to be in real trouble.
 */
export const SAFETY = ["ok", "boundary", "distress"] as const;
export type Safety = typeof SAFETY[number];

export const ChatReplySchema = z.object({
  safety: z.enum(SAFETY),
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
