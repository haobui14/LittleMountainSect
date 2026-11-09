import type { Anthropic, z } from "./deps.ts";
import {
  ELDER,
  type Locale,
  QUIRKS,
  REALM_NAMES,
  SIDE_EFFECT_TEXT,
  type SideEffect,
  SPIRIT_ROOT_NAMES,
  SPIRIT_ROOTS,
  TECHNIQUE_NAMES,
  TECHNIQUES,
} from "./cast.ts";
import { type CacheTtl, MAX_TOKENS, type RequestKind } from "./config.ts";
import { fill, PLACES, PROBLEMS } from "./events.ts";
import { factSentences, rankName, relationshipWords, resourceList } from "./facts.ts";
import {
  type ChatReply,
  ChatReplySchema,
  type ChatRequest,
  type DiscipleCard,
  type EveningReply,
  EveningReplySchema,
  type EveningRequest,
  type EventReply,
  EventReplySchema,
  type EventRequest,
} from "./schemas.ts";
import { LANGUAGE_RULES, TASK_CHAT, TASK_EVENING, TASK_EVENT, WORLD_RULES } from "./world.ts";

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

/**
 * The cached start of every prompt: the world rules, the language block for
 * the request's language, then the task. Each is a cache breakpoint, so all
 * requests share the world rules and requests in one language share more.
 */
function sharedBlocks(
  task: string,
  locale: Locale,
  options: PromptOptions,
): Anthropic.TextBlockParam[] {
  const cache = { type: "ephemeral" as const, ttl: options.cacheTtl };
  return [
    { type: "text", text: WORLD_RULES, cache_control: cache },
    { type: "text", text: LANGUAGE_RULES[locale], cache_control: cache },
    { type: "text", text: task, cache_control: cache },
  ];
}

function characterBlock(text: string): Anthropic.TextBlockParam {
  return { type: "text", text, cache_control: { type: "ephemeral", ttl: "5m" } };
}

/** Why a disciple can't choose what to do tomorrow. */
const AWAY: Record<string, string> = {
  home: "Can't choose tomorrow",
  mission: "Away on a mission tomorrow",
  lost: "Lost on the mountain",
  left: "Has left the sect for now",
};

/** First line of every user message: the reply language, stated plainly. */
function localeLine(locale: Locale): string {
  return `Locale: ${locale} (write only in ${locale === "vi" ? "Vietnamese" : "English"})`;
}

export function describeDisciple(card: DiscipleCard, locale: Locale): string {
  const quirks = card.quirks.map((id) => QUIRKS[id][locale]).join("; ");
  const lines = [
    `Name: ${card.name} (${PRONOUNS[card.pronouns]}), a disciple of the sect. Id: ${card.id}.`,
    `Spirit root: ${SPIRIT_ROOT_NAMES[card.spirit_root][locale]}. ` +
    `Realm: ${REALM_NAMES[card.realm][locale]}.`,
    `Quirks: ${quirks}.`,
    `Mood: ${card.mood} (from -10, miserable, to 10, delighted). ` +
    `Loyalty to the Sect Master: ${card.loyalty} of 100.`,
  ];
  if (card.technique) {
    const technique = TECHNIQUES[SPIRIT_ROOTS.indexOf(card.spirit_root)];
    lines.push(`Technique: ${TECHNIQUE_NAMES[technique]}, level ${card.technique} of 3.`);
  }
  const now = (card.effects ?? []).map((e) =>
    e === "injured" ? "is injured" : SIDE_EFFECT_TEXT[e as SideEffect]
  );
  if (card.status === "lost") now.push("is lost on the mountain");
  if (card.status === "left") now.push("has left the sect for a while");
  if (card.status === "mission") now.push("is away on a mission");
  if (now.length > 0) lines.push(`Right now: ${card.name} ${now.join("; ")}.`);
  return lines.join("\n");
}

function memoriesSection(name: string, memories: string[]): string {
  if (memories.length === 0) return `${name} has no memories of the Sect Master yet.`;
  return `What ${name} remembers, oldest first:\n` +
    memories.map((m) => `- ${defuse(m)}`).join("\n");
}

function conversation(
  request: ChatRequest,
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
    content: `${localeLine(request.locale)}\n${history}` +
      `<player_message>${defuse(request.message)}</player_message>`,
  }];
}

/** A chat line from a disciple or the Elder. `memories` are oldest first. */
export function buildChat(
  request: ChatRequest,
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
    system: [...sharedBlocks(TASK_CHAT, request.locale, options), characterBlock(character)],
    messages: conversation(request, speaker),
    maxTokens: MAX_TOKENS[request.kind],
    schema: ChatReplySchema,
  };
}

/**
 * A surprise event. The game sends only ids; the catalog (events.ts) says
 * what the problem, the place and each choice mean.
 */
export function buildEvent(request: EventRequest, options: PromptOptions): BuiltPrompt<EventReply> {
  const problem = PROBLEMS[request.problem];
  const names = request.disciples.map((d) => d.name);
  const place = PLACES[request.place];
  const disciples = request.disciples.map((d) => describeDisciple(d, request.locale))
    .join("\n\n");
  const choices = Object.entries(problem.choices)
    .map(([id, hint]) => `- id: ${id}; what it does: ${fill(hint, names, place)}`)
    .join("\n");
  return {
    kind: "event",
    system: sharedBlocks(TASK_EVENT, request.locale, options),
    messages: [{
      role: "user",
      content: `${localeLine(request.locale)}\nDay ${request.game_day}.\n# The event\n` +
        `Place: ${place}\nProblem: ${fill(problem.setup, names, place)}\n\n` +
        `# The disciples involved\n${disciples}\n\n# The choices\n${choices}`,
    }],
    maxTokens: MAX_TOKENS.event,
    schema: EventReplySchema,
  };
}

/**
 * The evening story. [memories] maps a disciple id to their newest memories,
 * oldest first; the facts are written up by the server (facts.ts).
 */
export function buildEvening(
  request: EveningRequest,
  memories: Record<string, string[]>,
  options: PromptOptions,
): BuiltPrompt<EveningReply> {
  const disciples = request.disciples.map(({ card, allowed_actions }) => {
    const remembered = memories[card.id] ?? [];
    return [
      describeDisciple(card, request.locale),
      remembered.length > 0
        ? `Remembers: ${remembered.map(defuse).join(" / ")}`
        : "Remembers nothing special yet.",
      allowed_actions.length > 0
        ? `Allowed actions tomorrow: ${allowed_actions.join(", ")}`
        : `${AWAY[card.status ?? "mission"]}: no allowed actions.`,
    ].join("\n");
  }).join("\n\n");
  const names = new Map(request.disciples.map((d) => [d.card.id, d.card.name]));
  const bonds = request.relationships.map((r) =>
    `- ${names.get(r.a)} and ${names.get(r.b)} are ${relationshipWords(r.score)} (${r.score}).`
  );
  const facts = factSentences(request).map((f) => `- ${f}`);
  return {
    kind: "evening",
    system: sharedBlocks(TASK_EVENING, request.locale, options),
    messages: [{
      role: "user",
      content: `${localeLine(request.locale)}\nDay ${request.game_day}. ` +
        `Sect rank: ${rankName(request.sect.rank)}. ` +
        `Resources: ${resourceList(request.sect.resources) || "nothing at all"}.\n\n` +
        `# The disciples\n${disciples}\n\n` +
        (bonds.length > 0 ? `# Between the disciples\n${bonds.join("\n")}\n\n` : "") +
        `# What happened today\n${facts.length > 0 ? facts.join("\n") : "- A quiet day."}`,
    }],
    maxTokens: MAX_TOKENS.evening,
    schema: EveningReplySchema,
  };
}
