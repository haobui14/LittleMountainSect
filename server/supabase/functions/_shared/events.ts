// The surprise-event catalog as Claude reads it: what each place, problem and
// choice means, in English. The game owns the rules (game/sim/data/events.gd:
// who is involved, what each choice costs and does); the ids here must match
// it, which a Deno contract test checks against
// game/tests/fixtures/event_catalog.json.
//
// Each hint tells Claude what a choice does, without numbers, so the words
// stay true to the rules. Setups name the disciples as {a} and {b}.

export const PLACES = {
  main_gate: "the mountain gate",
  spirit_field: "the Spirit Field",
  kitchen: "the Kitchen",
  training_yard: "the Training Yard",
  bamboo_grove: "the bamboo grove",
  hot_spring: "the hot spring",
  mountain_path: "the mountain path",
  village_market: "the village market",
  library: "the Library",
  misty_pond: "the misty pond",
} as const;
export type Place = keyof typeof PLACES;
export const PLACE_IDS = Object.keys(PLACES) as [Place, ...Place[]];

export interface Problem {
  /** How many disciples are involved: {a}, or {a} and {b}. */
  pair: 1 | 2;
  setup: string;
  /** Choice id -> what it does. Kept in the game's order. */
  choices: Record<string, string>;
}

export const PROBLEMS = {
  spirit_goose: {
    pair: 2,
    setup: "A spirit goose has claimed {place} and honks at anyone who comes near.",
    choices: {
      bribe: "Bribe the goose with food. Costs some Food; {a} and {b} feel good about it.",
      chase: "{a} and {b} chase it off. Risky: they may find Herbs, or get bitten.",
      ignore: "Let the goose stay. It honks all night and everyone sleeps badly.",
    },
  },
  purple_cat: {
    pair: 2,
    setup: "A purple cat sits at {place} and refuses to leave. {a} wants to keep it.",
    choices: {
      feed: "Feed the cat. Costs some Food; {a} and {b} are delighted.",
      adopt: "Make it the sect's cat. It may bring Reputation, or scratch {a}.",
      shoo: "Shoo it away. Nothing changes.",
    },
  },
  frog_duel: {
    pair: 2,
    setup: "Iron Frog Sect disciples at {place} challenge {a} to a duel.",
    choices: {
      accept: "{a} fights. Win: Reputation. Lose: a little Reputation and an injury for {a}.",
      send_b: "{b} fights instead. Win: Reputation. Lose: {b} sulks and blames {a}.",
      decline: "Decline politely. {a} feels a bit cowardly.",
    },
  },
  lost_merchant: {
    pair: 2,
    setup: "A lost merchant stumbles into {place}, asking {a} and {b} for directions.",
    choices: {
      guide:
        "{a} and {b} guide him home. Likely Spirit Stones and Reputation; they may get lost too.",
      sell_tea: "Sell him tea for the road. A few Spirit Stones.",
      point_the_way: "Point the way kindly. A little Reputation.",
    },
  },
  mysterious_egg: {
    pair: 2,
    setup: "{a} found a mysterious egg at {place}. {b} thinks it is looking at them.",
    choices: {
      keep_warm: "Keep it warm. It may hatch into something wonderful, or turn out to be a rock.",
      cook: "Cook it. Some Food, but {a} feels guilty.",
      return: "Put it back where it was found. A little Reputation; {a} feels good.",
    },
  },
  leaky_roof: {
    pair: 2,
    setup: "The roof above {place} leaks, right onto {a}'s bed.",
    choices: {
      fix: "Pay to fix it. Costs Spirit Stones; everyone is happier.",
      buckets: "{a} and {b} take bucket duty. Tiring, but they grow closer.",
      ignore: "Ignore it. {a} sleeps in a puddle and is unhappy.",
    },
  },
  inspector: {
    pair: 2,
    setup: "An inspector from the Cultivation Bureau arrives at {place} to check on the sect.",
    choices: {
      serve_tea: "Serve tea and snacks. Costs some Food; a little Reputation.",
      honest_tour: "Show the sect as it really is. May earn Reputation, or lose some.",
      hide_everyone: "Hide everyone until he leaves. {a} and {b} are cramped and grumpy.",
    },
  },
  talking_stone: {
    pair: 2,
    setup: "A stone at {place} claims to be an ancient master and offers {a} its wisdom.",
    choices: {
      listen: "{a} listens. Real wisdom would help {a}'s cultivation; it may only tell bad jokes.",
      sell_it: "Sell the stone in the village. Some Spirit Stones.",
      ignore: "Walk away. Nothing changes.",
    },
  },
  village_festival: {
    pair: 2,
    setup: "The village festival near {place} needs performers, and {a} and {b} are free.",
    choices: {
      perform: "{a} and {b} perform. Reputation, and they have fun.",
      sell_snacks: "Sell snacks. Costs some Food; brings Spirit Stones.",
      stay_home: "Stay home. {a} is disappointed.",
    },
  },
  strange_smell: {
    pair: 2,
    setup: "A strange smell drifts from {place}. {a} insists it is not their fault.",
    choices: {
      investigate: "{a} investigates. May find a pill, or end up with green hair.",
      open_windows: "Open the windows and wait. Nothing changes.",
      blame_b: "Blame {b}. {a} feels better; {b} does not.",
    },
  },
  rival_prank: {
    pair: 2,
    setup: "Someone painted a giant frog on the wall at {place} overnight.",
    choices: {
      clean: "{a} and {b} scrub it off. Tiring, but they bond.",
      paint_bigger:
        "Paint a bigger one on the Iron Frog Sect's wall. Great fun, or a little shame.",
      laugh: "Laugh it off. {a} cheers up.",
    },
  },
  sudden_storm: {
    pair: 2,
    setup: "A sudden storm catches {a} and {b} at {place}.",
    choices: {
      shelter: "Shelter together. They grow closer.",
      save_crops: "Run to save the crops. May save Food and Herbs, or they just get soaked.",
      sing: "Sing loudly at the storm. Everyone's spirits lift.",
    },
  },
  wandering_master: {
    pair: 2,
    setup: "A wandering master at {place} offers {a} a lesson.",
    choices: {
      take_lesson: "Trade a meal for a lesson. Costs some Food; helps {a}'s cultivation.",
      pay_lesson: "Pay for a full lesson. Costs Spirit Stones; helps {a}'s cultivation a lot.",
      decline: "Decline politely. Nothing changes.",
    },
  },
  beast_cub: {
    pair: 2,
    setup: "A spirit beast cub followed {a} home from {place}.",
    choices: {
      keep: "Keep the cub. Costs some Food; a little Reputation and happy disciples.",
      return_cub:
        "{a} returns it to its mother. Likely Reputation; the mother may be grumpy and hurt {a}.",
      shoo: "Shoo it away. {a} is sad.",
    },
  },
  poetry_contest: {
    pair: 2,
    setup: "{a} entered {b} in a poetry contest at {place} without asking.",
    choices: {
      support_b: "{b} competes. A win brings Reputation; a loss hurts {b}'s pride.",
      withdraw: "Withdraw {b}. {a} is embarrassed and {b} is annoyed.",
      write_together: "{a} and {b} write a poem together. They grow closer.",
    },
  },
  noodle_thief: {
    pair: 2,
    setup: "Someone keeps stealing noodles from {place}.",
    choices: {
      stake_out:
        "{a} and {b} stay up to catch the thief. They may get the noodles back, or just lose sleep.",
      buy_lock: "Buy a lock. Costs Spirit Stones.",
      share: "Leave out a bowl to share. Costs some Food; a little Reputation.",
    },
  },
  cloud_whale: {
    pair: 2,
    setup: "A cloud whale drifts over {place}, raining spirit energy.",
    choices: {
      meditate: "{a} and {b} meditate under it. Helps both their cultivation.",
      collect_rain: "Collect the rain for medicine. Some Herbs.",
      wave: "Wave at the whale. Everyone cheers up.",
    },
  },
  broken_sword: {
    pair: 2,
    setup: "{a}'s sword snapped in half at {place}.",
    choices: {
      buy_new: "Buy a new sword. Costs Spirit Stones; {a} is thrilled.",
      glue_it: "Glue it back together. It may hold, or snap again in front of everyone.",
      use_broom: "{a} trains with a broom. {a} is embarrassed; {b} finds it hilarious.",
    },
  },
  tea_invitation: {
    pair: 2,
    setup: "The Moonlit Tea Society invites {a} to tea at {place}.",
    choices: {
      attend: "{a} attends. Likely Reputation; they may charge for the tea.",
      send_gift: "Send a gift of herbs. Costs some Herbs; brings Reputation.",
      decline: "Decline politely. Nothing changes.",
    },
  },
  free_haircut: {
    pair: 2,
    setup: "The Perfect Hair Pavilion offers free haircuts at {place}.",
    choices: {
      accept: "{a} gets a haircut. They may look great, or end up with green hair.",
      send_b: "Send {b} instead. They may look great, or end up with green hair and blame {a}.",
      decline: "Decline. Nothing changes.",
    },
  },
  rescue: {
    pair: 1,
    setup: "{a} is lost somewhere along {place} after a mission went wrong.",
    choices: {
      hire_guide: "Hire a mountain guide. Costs Spirit Stones; {a} is home by tonight.",
      search_party: "Everyone searches. Tiring for all; {a} is home in a day or two.",
      wait: "Trust {a} to find the way. Takes a few days; {a} may learn something out there.",
    },
  },
} as const satisfies Record<string, Problem>;
export type ProblemId = keyof typeof PROBLEMS;
export const PROBLEM_IDS = Object.keys(PROBLEMS) as [ProblemId, ...ProblemId[]];

export function choiceIds(problem: ProblemId): string[] {
  return Object.keys(PROBLEMS[problem].choices);
}

/** A setup or hint with the disciples' names and the place filled in. */
export function fill(text: string, names: string[], place: string): string {
  return text.replaceAll("{a}", names[0] ?? "a disciple")
    .replaceAll("{b}", names[1] ?? "another disciple")
    .replaceAll("{place}", place);
}
