class_name EventCatalog
extends RefCounted
## Surprise events: a problem, a place and one or two disciples, with two or
## three choices. Rules decide when an event starts (EventRules) and what each
## choice does (the outcomes below); Claude only writes the story and the
## words of each choice, for 2 Spirit Energy. Without Claude, the written
## text in strings.csv (EVENT_<PROBLEM>_TITLE, _STORY, _<CHOICE>) is used.
##
## The ids must match server/supabase/functions/_shared/events.ts: the game
## writes game/tests/fixtures/event_catalog.json and a Deno test compares it.
##
## A choice is {"id", "cost" (paid when chosen; the choice is unavailable
## without it), and either "outcome", or "chance" with "win" and "lose"}.
## An outcome may hold:
##   res       {resource: amount or [min, max]} (amounts can be negative)
##   mood      {"a" | "b" | "all": amount}
##   rel       change between the two disciples
##   progress  {"a" | "b": amount or [min, max]}
##   effect    {"a" | "b": side effect id}
##   injure    {"a" | "b": days}
##   item      a pill id, or "random_pill"
##   return_in [min, max] days until a lost disciple is home (rescue only)

## Places, and the building each needs to exist ("" means none).
const PLACES := {
	"main_gate": "",
	"spirit_field": "spirit_field",
	"kitchen": "kitchen",
	"training_yard": "training_yard",
	"bamboo_grove": "",
	"hot_spring": "",
	"mountain_path": "",
	"village_market": "",
	"library": "library",
	"misty_pond": "",
}

## The rescue for a lost disciple; never picked at random.
const RESCUE := "rescue"

const PROBLEMS := {
	"spirit_goose": {
		"places": ["spirit_field", "misty_pond", "main_gate"],
		"pair": 2,
		"choices": [
			{"id": "bribe", "cost": {"food": 4}, "outcome": {"mood": {"a": 1, "b": 1}, "rel": 1}},
			{"id": "chase", "chance": 0.5, "win": {"res": {"herbs": [3, 6]}, "mood": {"a": 1, "b": 1}}, "lose": {"mood": {"a": -1, "b": -1}}},
			{"id": "ignore", "outcome": {"mood": {"all": -1}}},
		],
	},
	"purple_cat": {
		"places": ["main_gate", "kitchen", "library"],
		"pair": 2,
		"choices": [
			{"id": "feed", "cost": {"food": 3}, "outcome": {"mood": {"a": 2, "b": 1}}},
			{"id": "adopt", "chance": 0.6, "win": {"res": {"reputation": 2}, "mood": {"a": 1}}, "lose": {"mood": {"a": -1}}},
			{"id": "shoo", "outcome": {}},
		],
	},
	"frog_duel": {
		"places": ["main_gate", "training_yard", "village_market"],
		"pair": 2,
		"choices": [
			{"id": "accept", "chance": 0.5, "win": {"res": {"reputation": [3, 5]}, "mood": {"a": 2}}, "lose": {"res": {"reputation": -1}, "injure": {"a": 2}}},
			{"id": "send_b", "chance": 0.5, "win": {"res": {"reputation": [2, 4]}, "mood": {"b": 2}, "rel": 1}, "lose": {"mood": {"b": -1}, "rel": -1}},
			{"id": "decline", "outcome": {"mood": {"a": -1}}},
		],
	},
	"lost_merchant": {
		"places": ["mountain_path", "village_market", "main_gate"],
		"pair": 2,
		"choices": [
			{"id": "guide", "chance": 0.7, "win": {"res": {"stones": [10, 20], "reputation": 1}}, "lose": {"mood": {"a": -1, "b": -1}}},
			{"id": "sell_tea", "outcome": {"res": {"stones": [4, 8]}}},
			{"id": "point_the_way", "outcome": {"res": {"reputation": 1}}},
		],
	},
	"mysterious_egg": {
		"places": ["bamboo_grove", "misty_pond", "spirit_field"],
		"pair": 2,
		"choices": [
			{"id": "keep_warm", "chance": 0.5, "win": {"res": {"reputation": 1}, "mood": {"a": 2, "b": 1}}, "lose": {"mood": {"a": -1}}},
			{"id": "cook", "outcome": {"res": {"food": [3, 5]}, "mood": {"a": -1}}},
			{"id": "return", "outcome": {"res": {"reputation": 1}, "mood": {"a": 1}}},
		],
	},
	"leaky_roof": {
		"places": ["kitchen", "library", "main_gate"],
		"pair": 2,
		"choices": [
			{"id": "fix", "cost": {"stones": 12}, "outcome": {"mood": {"all": 1}}},
			{"id": "buckets", "outcome": {"mood": {"a": -1, "b": -1}, "rel": 2}},
			{"id": "ignore", "outcome": {"mood": {"a": -2}}},
		],
	},
	"inspector": {
		"places": ["main_gate", "training_yard", "kitchen"],
		"pair": 2,
		"choices": [
			{"id": "serve_tea", "cost": {"food": 3}, "outcome": {"res": {"reputation": [1, 3]}}},
			{"id": "honest_tour", "chance": 0.6, "win": {"res": {"reputation": [2, 4]}}, "lose": {"res": {"reputation": -2}}},
			{"id": "hide_everyone", "outcome": {"mood": {"a": -1, "b": -1}}},
		],
	},
	"talking_stone": {
		"places": ["bamboo_grove", "mountain_path", "misty_pond"],
		"pair": 2,
		"choices": [
			{"id": "listen", "chance": 0.5, "win": {"progress": {"a": [10, 20]}}, "lose": {"mood": {"a": -1}}},
			{"id": "sell_it", "outcome": {"res": {"stones": [8, 15]}}},
			{"id": "ignore", "outcome": {}},
		],
	},
	"village_festival": {
		"places": ["village_market"],
		"pair": 2,
		"choices": [
			{"id": "perform", "outcome": {"res": {"reputation": [2, 3]}, "mood": {"a": 1, "b": 1}}},
			{"id": "sell_snacks", "cost": {"food": 4}, "outcome": {"res": {"stones": [10, 16]}}},
			{"id": "stay_home", "outcome": {"mood": {"a": -1}}},
		],
	},
	"strange_smell": {
		"places": ["kitchen", "training_yard", "library"],
		"pair": 2,
		"choices": [
			{"id": "investigate", "chance": 0.5, "win": {"item": "random_pill"}, "lose": {"effect": {"a": "green_hair"}}},
			{"id": "open_windows", "outcome": {}},
			{"id": "blame_b", "outcome": {"mood": {"a": 1}, "rel": -2}},
		],
	},
	"rival_prank": {
		"places": ["main_gate", "training_yard", "library"],
		"pair": 2,
		"choices": [
			{"id": "clean", "outcome": {"mood": {"a": -1, "b": -1}, "rel": 1}},
			{"id": "paint_bigger", "chance": 0.5, "win": {"res": {"reputation": 1}, "mood": {"a": 2, "b": 2}}, "lose": {"res": {"reputation": -1}}},
			{"id": "laugh", "outcome": {"mood": {"a": 1}}},
		],
	},
	"sudden_storm": {
		"places": ["spirit_field", "bamboo_grove", "mountain_path"],
		"pair": 2,
		"choices": [
			{"id": "shelter", "outcome": {"rel": 2}},
			{"id": "save_crops", "chance": 0.6, "win": {"res": {"herbs": [2, 5], "food": [2, 4]}}, "lose": {"mood": {"a": -1, "b": -1}}},
			{"id": "sing", "outcome": {"mood": {"all": 1}}},
		],
	},
	"wandering_master": {
		"places": ["mountain_path", "bamboo_grove", "hot_spring"],
		"pair": 2,
		"choices": [
			{"id": "take_lesson", "cost": {"food": 5}, "outcome": {"progress": {"a": [10, 15]}}},
			{"id": "pay_lesson", "cost": {"stones": 20}, "outcome": {"progress": {"a": [20, 30]}}},
			{"id": "decline", "outcome": {}},
		],
	},
	"beast_cub": {
		"places": ["bamboo_grove", "misty_pond", "mountain_path"],
		"pair": 2,
		"choices": [
			{"id": "keep", "cost": {"food": 3}, "outcome": {"res": {"reputation": 1}, "mood": {"a": 2, "b": 1}}},
			{"id": "return_cub", "chance": 0.7, "win": {"res": {"reputation": [2, 3]}}, "lose": {"injure": {"a": 2}}},
			{"id": "shoo", "outcome": {"mood": {"a": -1}}},
		],
	},
	"poetry_contest": {
		"places": ["village_market", "library", "misty_pond"],
		"pair": 2,
		"choices": [
			{"id": "support_b", "chance": 0.4, "win": {"res": {"reputation": [2, 4]}, "mood": {"b": 2}}, "lose": {"mood": {"b": -1}}},
			{"id": "withdraw", "outcome": {"mood": {"a": -1}, "rel": -1}},
			{"id": "write_together", "outcome": {"mood": {"a": 1, "b": 1}, "rel": 2}},
		],
	},
	"noodle_thief": {
		"places": ["kitchen"],
		"pair": 2,
		"choices": [
			{"id": "stake_out", "chance": 0.5, "win": {"res": {"food": [4, 6]}, "mood": {"a": 1, "b": 1}}, "lose": {"mood": {"a": -1, "b": -1}}},
			{"id": "buy_lock", "cost": {"stones": 8}, "outcome": {}},
			{"id": "share", "cost": {"food": 3}, "outcome": {"res": {"reputation": 1}, "mood": {"a": 1}}},
		],
	},
	"cloud_whale": {
		"places": ["misty_pond", "hot_spring", "training_yard"],
		"pair": 2,
		"choices": [
			{"id": "meditate", "outcome": {"progress": {"a": [8, 12], "b": [8, 12]}}},
			{"id": "collect_rain", "outcome": {"res": {"herbs": [4, 8]}}},
			{"id": "wave", "outcome": {"mood": {"all": 1}}},
		],
	},
	"broken_sword": {
		"places": ["training_yard", "main_gate"],
		"pair": 2,
		"choices": [
			{"id": "buy_new", "cost": {"stones": 15}, "outcome": {"mood": {"a": 2}}},
			{"id": "glue_it", "chance": 0.5, "win": {"mood": {"a": 1}}, "lose": {"mood": {"a": -2}}},
			{"id": "use_broom", "outcome": {"mood": {"a": -1, "b": 1}}},
		],
	},
	"tea_invitation": {
		"places": ["village_market", "hot_spring"],
		"pair": 2,
		"choices": [
			{"id": "attend", "chance": 0.6, "win": {"res": {"reputation": [2, 3]}}, "lose": {"res": {"stones": -6}}},
			{"id": "send_gift", "cost": {"herbs": 5}, "outcome": {"res": {"reputation": [2, 4]}}},
			{"id": "decline", "outcome": {}},
		],
	},
	"free_haircut": {
		"places": ["village_market", "main_gate"],
		"pair": 2,
		"choices": [
			{"id": "accept", "chance": 0.6, "win": {"mood": {"a": 2}}, "lose": {"effect": {"a": "green_hair"}}},
			{"id": "send_b", "chance": 0.6, "win": {"mood": {"b": 2}, "rel": 1}, "lose": {"effect": {"b": "green_hair"}, "rel": -1}},
			{"id": "decline", "outcome": {}},
		],
	},
	"rescue": {
		"places": ["mountain_path"],
		"pair": 1,
		"choices": [
			{"id": "hire_guide", "cost": {"stones": 25}, "outcome": {"return_in": [0, 0]}},
			{"id": "search_party", "outcome": {"mood": {"all": -1}, "return_in": [1, 2]}},
			{"id": "wait", "outcome": {"progress": {"a": 10}, "return_in": [3, 5]}},
		],
	},
}


## Problems that can start at random (every one but the rescue).
static func random_problems() -> Array[String]:
	var out: Array[String] = []
	for id: String in PROBLEMS:
		if id != RESCUE:
			out.append(id)
	return out


static func choice_ids(problem: String) -> Array[String]:
	var out: Array[String] = []
	for choice: Dictionary in PROBLEMS[problem]["choices"]:
		out.append(String(choice["id"]))
	return out


static func choice(problem: String, choice_id: String) -> Dictionary:
	for c: Dictionary in PROBLEMS[problem]["choices"]:
		if c["id"] == choice_id:
			return c
	return {}


## The ids only, for the contract fixture the server checks.
static func ids() -> Dictionary:
	var problems := {}
	for id: String in PROBLEMS:
		problems[id] = choice_ids(id)
	return {"places": PLACES.keys(), "problems": problems}
