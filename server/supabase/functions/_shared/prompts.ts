import type { Anthropic, z } from "./deps.ts";
import { ELDER, type Locale, QUIRKS, REALM_NAMES, SPIRIT_ROOT_NAMES } from "./cast.ts";
import { type CacheTtl, MAX_TOKENS, type RequestKind } from "./config.ts";
import {
  type ChatReply,
  ChatReplySchema,
  type DiscipleCard,
  type EveningInput,
  type EveningReply,
  EveningReplySchema,
  type EventInput,
  type EventReply,
  EventReplySchema,
  type GatewayRequest,
} from "./schemas.ts";
import { TASK_CHAT, TASK_EVENING, TASK_EVENT, WORLD_RULES } from "./world.ts";

/** Everything needed for one Messages API call, minus the model settings. */
export interface BuiltPrompt<T> {
  kind: RequestKind;
  system: Anthropic.TextBlockParam[];
  messages: Anthropic.MessageParam[];
  maxTokens: number;
  schema: z.ZodType<T>;
}

export interface PromptOptions {
  /** TTL for the shared world and task blocks. Character blocks always use 5 minutes. */
  cacheTtl: CacheTtl;
}

const PRONOUNS: Record<DiscipleCard["pronouns"], string> = {
  he: "he/him",
  she: "she/her",
  they: "they/them",
};

/**
 * Player-written text goes inside tags, so it must not be able to close them.
 * Angle brackets become look-alike guillemets; the meaning survives.
 */
export function defuse(text: string): string {
  return text.replaceAll("<", "‹").replaceAll(">", "›");
}

function sharedBlocks(task: string, options: PromptOptions): Anthropic.TextBlockParam[] {
  const cache = { type: "ephemeral" as const, ttl: options.cacheTtl };
  return [
    { type: "text", text: WORLD_RULES, cache_control: cache },
    { type: "text", text: task, cache_control: cache },
  ];
}

function characterBlock(text: string): Anthropic.TextBlockParam {
  return { type: "text", text, cache_control: { type: "ephemeral", ttl: "5m" } };
}

export function describeDisciple(card: DiscipleCard, locale: Locale): string {
  const quirks = card.quirks.map((id) => QUIRKS[id][locale]).join("; ");
  return [
    `Name: ${card.name} (${PRONOUNS[card.pronouns]}), a disciple of the sect. Id: ${card.id}.`,
    `Spirit root: ${SPIRIT_ROOT_NAMES[card.spirit_root][locale]}. ` +
    `Realm: ${REALM_NAMES[card.realm][locale]}.`,
    `Quirks: ${quirks}.`,
    `Mood: ${card.mood} (from -10, miserable, to 10, delighted). ` +
    `Loyalty to the Sect Master: ${card.loyalty} of 100.`,
  ].join("\n");
}

function memoriesSection(name: string, memories: string[]): string {
  if (memories.length === 0) return `${name} has no memories of the Sect Master yet.`;
  return `What ${name} remembers, oldest first:\n` +
    memories.map((m) => `- ${defuse(m)}`).join("\n");
}

function conversation(
  request: GatewayRequest,
  speaker: string,
): Anthropic.MessageParam[] {
  const lines = request.recent.map((turn) =>
    `${turn.from === "player" ? "Sect Master" : speaker}: ${defuse(turn.text)}`
  );
  const history = lines.length > 0
    ? `<recent_conversation>\n${lines.join("\n")}\n</recent_conversation>\n`
    : "";
  return [{
    role: "user",
    content: `Locale: ${request.locale}\n${history}` +
      `<player_message>${defuse(request.message)}</player_message>`,
  }];
}

/** A chat line from a disciple or the Elder. `memories` are oldest first. */
export function buildChat(
  request: GatewayRequest,
  memories: string[],
  options: PromptOptions,
): BuiltPrompt<ChatReply> {
  let character: string;
  let speaker: string;
  if (request.kind === "chat") {
    speaker = request.disciple.name;
    character = `# The character\n${describeDisciple(request.disciple, request.locale)}\n\n` +
      memoriesSection(speaker, memories);
  } else {
    speaker = ELDER.name[request.locale];
    character = `# The character\nName: ${speaker}\n${ELDER.card}\n\n${ELDER.knowledge}`;
  }
  return {
    kind: request.kind,
    system: [...sharedBlocks(TASK_CHAT, options), characterBlock(character)],
    messages: conversation(request, speaker),
    maxTokens: MAX_TOKENS[request.kind],
    schema: ChatReplySchema,
  };
}

export function buildEvent(input: EventInput, options: PromptOptions): BuiltPrompt<EventReply> {
  const disciples = input.disciples.map((d) => describeDisciple(d, input.locale)).join("\n\n");
  const choices = input.choices.map((c) => `- id: ${c.id}; effect hint: ${c.effect_hint}`)
    .join("\n");
  return {
    kind: "event",
    system: sharedBlocks(TASK_EVENT, options),
    messages: [{
      role: "user",
      content: `Locale: ${input.locale}\n# The event\nPlace: ${input.place}\n` +
        `Problem: ${input.problem}\n\n# The disciples involved\n${disciples}\n\n` +
        `# The choices\n${choices}`,
    }],
    maxTokens: MAX_TOKENS.event,
    schema: EventReplySchema,
  };
}

export function buildEvening(
  input: EveningInput,
  options: PromptOptions,
): BuiltPrompt<EveningReply> {
  const disciples = input.disciples.map((d) =>
    `${describeDisciple(d.card, input.locale)}\nToday: ${d.today}\n` +
    `Allowed actions tomorrow: ${d.allowed_actions.join(", ")}`
  ).join("\n\n");
  const facts = input.facts.map((f) => `- ${f}`).join("\n");
  return {
    kind: "evening",
    system: sharedBlocks(TASK_EVENING, options),
    messages: [{
      role: "user",
      content: `Locale: ${input.locale}\nDay ${input.day}. Sect rank: ${input.sect.rank}. ` +
        `Resources: ${input.sect.resources}\n\n# The disciples\n${disciples}\n\n` +
        `# What happened today\n${facts}`,
    }],
    maxTokens: MAX_TOKENS.evening,
    schema: EveningReplySchema,
  };
}
