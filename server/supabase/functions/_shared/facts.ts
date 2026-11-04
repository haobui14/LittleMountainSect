// Writes the game's typed facts (see FactSchema) as plain English sentences
// for the evening prompt. The game sends ids and numbers only, so every word
// Claude reads here comes from the server.

import type { EveningRequest, Fact } from "./schemas.ts";

const MISSION_NAMES: Record<string, string> = {
  gather_herbs: "Gather Herbs",
  hunt_monster: "Hunt a Monster",
  escort_merchant: "Escort a Merchant",
  explore_secret_realm: "Explore a Secret Realm",
};

const TIER_WORDS: Record<string, string> = {
  great: "a great success",
  success: "a success",
  partial: "a so-so result",
  failure: "a failure",
  disaster: "a disaster, though everyone came home",
};

const RESOURCE_NAMES: Record<string, string> = {
  stones: "Spirit Stones",
  food: "Food",
  herbs: "Herbs",
  reputation: "Reputation",
};

const RANK_NAMES: Record<string, string> = {
  unknown_mountain: "Unknown Mountain",
  rising_sect: "Rising Sect",
  famous_sect: "Famous Sect",
};

/** "Lin", "Lin and Bao", "Lin, Bao and Mei". */
export function joinNames(names: string[]): string {
  if (names.length <= 1) return names.join("");
  return `${names.slice(0, -1).join(", ")} and ${names.at(-1)}`;
}

export function rankName(rank: string): string {
  return RANK_NAMES[rank] ?? rank;
}

export function resourceList(amounts: Partial<Record<string, number>>): string {
  return Object.entries(amounts)
    .filter(([, n]) => (n ?? 0) > 0)
    .map(([resource, n]) => `${n} ${RESOURCE_NAMES[resource] ?? resource}`)
    .join(", ");
}

/** One fact as a sentence. `name` turns a disciple id into a display name. */
export function factSentence(fact: Fact, name: (id: string) => string): string {
  switch (fact.type) {
    case "trained":
      return fact.ready
        ? `${name(fact.disciple)} trained and is now ready to break through to the next realm.`
        : `${name(fact.disciple)} trained and gained ${fact.gain} cultivation progress.`;
    case "worked": {
      const who = joinNames(fact.disciples.map(name));
      return fact.herbs > 0
        ? `${who} worked the Spirit Field and grew ${fact.food} Food and ${fact.herbs} Herbs.`
        : `${who} foraged on the slopes for ${fact.food} Food.`;
    }
    case "rested":
      return `${name(fact.disciple)} rested.`;
    case "healed":
      return `${name(fact.disciple)} recovered from an injury.`;
    case "mission_departed":
      return `${joinNames(fact.team.map(name))} set out on ${
        MISSION_NAMES[fact.mission]
      } and will be back on day ${fact.return_day}.`;
    case "mission_returned": {
      const gained = resourceList(fact.rewards);
      return `${joinNames(fact.team.map(name))} came back from ${MISSION_NAMES[fact.mission]}: ${
        TIER_WORDS[fact.tier]
      }.${gained ? ` They brought back ${gained}.` : " They brought back nothing."}`;
    }
    case "injured":
      return `${name(fact.disciple)} was injured on ${
        MISSION_NAMES[fact.mission]
      } and must rest for ${fact.days} days.`;
    case "lost_cultivation":
      return `${name(fact.disciple)} lost ${fact.amount} cultivation progress on ${
        MISSION_NAMES[fact.mission]
      }.`;
    case "ate":
      return `The sect ate ${fact.food} Food.`;
    case "hungry":
      return `There wasn't enough Food: ${joinNames(fact.disciples.map(name))} went to bed hungry.`;
  }
}

/** How two disciples get along, in words, from a score of -20 to 20. */
export function relationshipWords(score: number): string {
  if (score <= -10) return "rivals";
  if (score <= -4) return "a little cool with each other";
  if (score < 4) return "on ordinary terms";
  if (score < 10) return "friendly";
  return "close friends";
}

/** Every fact of the request as sentences, in order. */
export function factSentences(request: EveningRequest): string[] {
  const names = new Map(request.disciples.map((d) => [d.card.id, d.card.name]));
  const name = (id: string) => names.get(id) ?? id;
  return request.facts.map((fact) => factSentence(fact, name));
}
