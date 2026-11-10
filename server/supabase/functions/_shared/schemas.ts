import { z } from "./deps.ts";
import {
  ACTIONS,
  CARD_EFFECTS,
  EXPRESSIONS,
  PILLS,
  QUIRK_IDS,
  REALMS,
  RIVALS,
  ROLES,
  SEASONS,
  SIDE_EFFECTS,
  SPIRIT_ROOTS,
  STATUSES,
  TECHNIQUES,
} from "./cast.ts";
import { LIMITS } from "./config.ts";
import { choiceIds, PLACE_IDS, PROBLEM_IDS, PROBLEMS } from "./events.ts";
import { TRAVEL_PLACE_IDS } from "./travel.ts";

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
  // M5: where they are, timed effects (such as green hair) and how far they
  // have learned their root's technique. Optional, so older games still fit.
  status: z.enum(STATUSES).optional(),
  effects: z.array(z.enum(CARD_EFFECTS)).max(CARD_EFFECTS.length).optional(),
  technique: z.int().min(0).max(3).optional(),
  // M6: an Elder teaches instead of taking tasks.
  role: z.enum(ROLES).optional(),
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
const PillOrNone = z.enum([...PILLS, "none"]);
const ChoiceIdSchema = z.string().regex(/^[a-z0-9_]{1,32}$/);
const RivalSchema = z.enum(RIVALS);
const Resources = z.partialRecord(z.enum(RESOURCES), Amount);

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
  // M5 ----------------------------------------------------------------------
  z.strictObject({
    type: z.literal("breakthrough"),
    disciple: DiscipleIdSchema,
    realm: z.enum(REALMS),
    pill: PillOrNone,
  }),
  z.strictObject({
    type: z.literal("breakthrough_failed"),
    disciple: DiscipleIdSchema,
    realm: z.enum(REALMS),
    pill: PillOrNone,
    effect: z.enum(SIDE_EFFECTS),
    days: z.int().min(1).max(60),
    lost: z.int().min(0).max(100),
  }),
  z.strictObject({
    type: z.literal("effect_ended"),
    disciple: DiscipleIdSchema,
    effect: z.enum(SIDE_EFFECTS),
  }),
  z.strictObject({
    type: z.literal("studied"),
    disciple: DiscipleIdSchema,
    gain: z.int().min(0).max(100),
  }),
  z.strictObject({
    type: z.literal("learned"),
    disciple: DiscipleIdSchema,
    technique: z.enum(TECHNIQUES),
    tier: z.int().min(1).max(3),
  }),
  z.strictObject({
    type: z.literal("lost"),
    disciple: DiscipleIdSchema,
    mission: z.enum(MISSIONS),
  }),
  z.strictObject({
    type: z.literal("left"),
    disciple: DiscipleIdSchema,
    mission: z.enum(MISSIONS),
  }),
  z.strictObject({
    type: z.literal("returned"),
    disciple: DiscipleIdSchema,
    from: z.enum(["lost", "left"]),
  }),
  z.strictObject({ type: z.literal("recruited"), disciple: DiscipleIdSchema }),
  z.strictObject({ type: z.literal("rank_up"), rank: z.enum(RANKS) }),
  z.strictObject({ type: z.literal("brewed"), pill: z.enum(PILLS) }),
  z.strictObject({ type: z.literal("cured"), disciple: DiscipleIdSchema }),
  z.strictObject({ type: z.literal("found_item"), mission: z.enum(MISSIONS), item: z.enum(PILLS) }),
  z.strictObject({
    type: z.literal("event"),
    problem: z.enum(PROBLEM_IDS),
    place: z.enum(PLACE_IDS),
    choice: ChoiceIdSchema,
    result: z.enum(["win", "lose", "done"]),
    disciples: z.array(DiscipleIdSchema).min(1).max(2),
  }),
  // M6: seasons, rivals, wars and generations ---------------------------------
  z.strictObject({
    type: z.literal("season"),
    season: z.enum(SEASONS),
    year: z.int().min(1).max(10_000),
  }),
  z.strictObject({
    type: z.literal("tournament"),
    place: z.int().min(1).max(4),
    champions: z.array(DiscipleIdSchema).min(1).max(3),
    matches: z.array(z.strictObject({ rival: RivalSchema, won: z.boolean() })).min(1).max(2),
    rewards: Resources,
  }),
  z.strictObject({ type: z.literal("tournament_skipped") }),
  z.strictObject({
    type: z.literal("gift"),
    rival: RivalSchema,
    resource: z.enum(RESOURCES),
    amount: Amount,
  }),
  z.strictObject({ type: z.literal("trade"), rival: RivalSchema, gave: Resources, got: Resources }),
  z.strictObject({ type: z.literal("alliance"), rival: RivalSchema }),
  z.strictObject({
    type: z.literal("alliance_ended"),
    rival: RivalSchema,
    by: z.enum(["player", "rival"]),
  }),
  z.strictObject({
    type: z.literal("betrayal"),
    rival: RivalSchema,
    stones: Amount,
    item: PillOrNone,
  }),
  z.strictObject({ type: z.literal("ally_gift"), rival: RivalSchema, stones: Amount }),
  z.strictObject({
    type: z.literal("war_declared"),
    rival: RivalSchema,
    battle_day: z.int().min(1),
  }),
  z.strictObject({
    type: z.literal("war_result"),
    rival: RivalSchema,
    won: z.boolean(),
    defenders: DiscipleIdsSchema,
    land: z.int().min(1).max(5),
  }),
  z.strictObject({ type: z.literal("peace"), rival: RivalSchema, paid: Amount }),
  z.strictObject({ type: z.literal("promoted"), disciple: DiscipleIdSchema }),
  z.strictObject({ type: z.literal("ascended"), disciple: DiscipleIdSchema }),
  z.strictObject({
    type: z.literal("ascension_failed"),
    disciple: DiscipleIdSchema,
    effect: z.enum(SIDE_EFFECTS),
    days: z.int().min(1).max(60),
    lost: z.int().min(0).max(100),
  }),
  z.strictObject({
    type: z.literal("travel_left"),
    disciple: DiscipleIdSchema,
    place: z.enum(TRAVEL_PLACE_IDS),
    return_day: z.int().min(1),
  }),
  z.strictObject({
    type: z.literal("travel_returned"),
    disciple: DiscipleIdSchema,
    place: z.enum(TRAVEL_PLACE_IDS),
    souvenir: PillOrNone,
  }),
  z.strictObject({
    type: z.literal("letter"),
    disciple: DiscipleIdSchema,
    place: z.enum(TRAVEL_PLACE_IDS),
    gift: Resources,
    item: PillOrNone,
  }),
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
      : "champions" in fact
      ? fact.champions
      : "defenders" in fact
      ? fact.defenders
      : [];
  request.facts.forEach((fact, i) => {
    for (const id of named(fact)) {
      if (!ids.has(id)) {
        ctx.addIssue({ code: "custom", message: `unknown disciple ${id}`, path: ["facts", i] });
      }
    }
    if (fact.type === "event" && !choiceIds(fact.problem).includes(fact.choice)) {
      ctx.addIssue({ code: "custom", message: "unknown choice", path: ["facts", i] });
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

// Surprise events (M5) -------------------------------------------------------
//
// The rules start an event and pick its problem, place and disciples; the
// game sends only those ids. The server's catalog (events.ts) says what they
// mean, and Claude writes the title, the story and every choice's words.

export const EventRequestSchema = z.strictObject({
  kind: z.literal("event"),
  locale: LocaleSchema,
  game_day: z.int().min(1).max(1_000_000),
  problem: z.enum(PROBLEM_IDS),
  place: z.enum(PLACE_IDS),
  disciples: z.array(DiscipleCardSchema).min(1).max(2),
}).superRefine((request, ctx) => {
  if (request.disciples.length !== PROBLEMS[request.problem].pair) {
    ctx.addIssue({ code: "custom", message: "wrong number of disciples", path: ["disciples"] });
  }
  if (new Set(request.disciples.map((d) => d.id)).size !== request.disciples.length) {
    ctx.addIssue({ code: "custom", message: "duplicate disciple id", path: ["disciples"] });
  }
});
export type EventRequest = z.infer<typeof EventRequestSchema>;

// Letters home (M6) ----------------------------------------------------------
//
// The rules decide when a travelling disciple writes, where they are and what
// small gift comes with the letter; Claude writes the letter itself.

export const LetterRequestSchema = z.strictObject({
  kind: z.literal("letter"),
  locale: LocaleSchema,
  game_day: z.int().min(1).max(1_000_000),
  disciple: DiscipleCardSchema,
  place: z.enum(TRAVEL_PLACE_IDS),
  days_away: z.int().min(1).max(60),
  /** A letter's gift is always small; the rules pick it. */
  gift: z.partialRecord(z.enum(RESOURCES), z.int().min(0).max(100)),
  item: PillOrNone,
});
export type LetterRequest = z.infer<typeof LetterRequestSchema>;

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
  EventRequestSchema,
  LetterRequestSchema,
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

// What Claude returns for surprise events and evening stories.

export const EventReplySchema = z.object({
  title: z.string(),
  story: z.string(),
  choices: z.array(z.object({ id: z.string(), text: z.string() })),
});
export type EventReply = z.infer<typeof EventReplySchema>;

export const LetterReplySchema = z.object({ letter: z.string() });
export type LetterReply = z.infer<typeof LetterReplySchema>;

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
