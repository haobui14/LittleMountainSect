// Writes the game's typed facts (see FactSchema) as plain English sentences
// for the evening prompt. The game sends ids and numbers only, so every word
// Claude reads here comes from the server.

import {
  PILL_NAMES,
  REALM_NAMES,
  SIDE_EFFECT_NAMES,
  SIDE_EFFECT_TEXT,
  TECHNIQUE_NAMES,
} from "./cast.ts";
import { fill, PLACES, PROBLEMS } from "./events.ts";
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
    case "breakthrough":
      return `${name(fact.disciple)} broke through to ${REALM_NAMES[fact.realm].en}${
        fact.pill === "none" ? "" : `, with help from ${PILL_NAMES[fact.pill]}`
      }.`;
    case "breakthrough_failed":
      return `${name(fact.disciple)} tried to break through to ${REALM_NAMES[fact.realm].en}${
        fact.pill === "none" ? "" : ` (even with ${PILL_NAMES[fact.pill]})`
      } and failed, losing ${fact.lost} progress. Now ${name(fact.disciple)} ${
        SIDE_EFFECT_TEXT[fact.effect]
      }, for ${fact.days} days.`;
    case "effect_ended":
      return `${name(fact.disciple)}'s ${SIDE_EFFECT_NAMES[fact.effect]} wore off.`;
    case "studied":
      return `${name(fact.disciple)} studied in the Library.`;
    case "learned":
      return `${name(fact.disciple)} learned the ${
        TECHNIQUE_NAMES[fact.technique]
      }, level ${fact.tier} of 3.`;
    case "lost":
      return `${name(fact.disciple)} got lost on ${
        MISSION_NAMES[fact.mission]
      } and hasn't come home.`;
    case "left":
      return `${name(fact.disciple)} was so unhappy after ${
        MISSION_NAMES[fact.mission]
      } that they left the sect, though they may come back one day.`;
    case "returned":
      return fact.from === "lost"
        ? `${name(fact.disciple)} found the way home after being lost.`
        : `${name(fact.disciple)} came back to the sect.`;
    case "recruited":
      return `${name(fact.disciple)} joined the sect as a new disciple.`;
    case "rank_up":
      return `The sect is now known as a ${rankName(fact.rank)}.`;
    case "brewed":
      return `The Alchemy Room brewed ${PILL_NAMES[fact.pill]}.`;
    case "cured":
      return `${name(fact.disciple)} took a Healing Pill and feels fine again.`;
    case "found_item":
      return `On ${MISSION_NAMES[fact.mission]}, the team found ${PILL_NAMES[fact.item]}.`;
    case "event": {
      const names = fact.disciples.map(name);
      const place = PLACES[fact.place];
      const problem = PROBLEMS[fact.problem];
      const hint = (problem.choices as Record<string, string>)[fact.choice] ?? fact.choice;
      const result = fact.result === "win"
        ? " It worked out."
        : fact.result === "lose"
        ? " It didn't go to plan."
        : "";
      return `Surprise: ${fill(problem.setup, names, place)} The Sect Master's choice: ${
        fill(hint, names, place)
      }${result}`;
    }
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
