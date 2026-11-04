class_name Balance
extends RefCounted
## Every tunable number of the rules engine, in one place. The balance sim
## (res://tools/balance_sim.gd) plays many seeds against these values, so tune
## here and rerun it instead of changing numbers inside the rules.
##
## The id lists must match the server's enums in
## server/supabase/functions/_shared/cast.ts; a Deno contract test checks them.

# Ids ------------------------------------------------------------------------

const RESOURCES: Array[String] = ["stones", "food", "herbs", "reputation"]
const STATS: Array[String] = ["talent", "body", "spirit", "wit"]
const SPIRIT_ROOTS: Array[String] = ["metal", "wood", "water", "fire", "earth"]
const REALMS: Array[String] = ["qi_refining", "foundation_building", "golden_core", "nascent_soul"]
const PRONOUNS: Array[String] = ["he", "she", "they"]

## What a disciple can do for a day at home. Missions are planned separately.
const HOME_TASKS: Array[String] = ["train", "work", "rest"]

## Actions a character may want or decide on: the server's ACTIONS in
## server/supabase/functions/_shared/cast.ts (the contract test checks them).
const ACTIONS: Array[String] = ["train", "rest", "meditate", "cook", "tend_field", "study", "explore", "hide"]
## The home task each action means on the day plan. Actions missing here
## ("explore") can't be chosen yet.
const ACTION_TASK := {
	"train": "train",
	"meditate": "train",
	"study": "train",
	"cook": "work",
	"tend_field": "work",
	"rest": "rest",
	"hide": "rest",
}

## The mountain's 8 fixed slots, in screen order. M3 plays the first four.
const BUILDINGS: Array[String] = [
	"main_hall",
	"disciple_huts",
	"training_yard",
	"spirit_field",
	"kitchen",
	"alchemy_room",
	"library",
	"mission_hall",
]
const BUILDINGS_IN_PLAY: Array[String] = [
	"main_hall",
	"disciple_huts",
	"training_yard",
	"spirit_field",
]

# The start (GDD: a leaky hut, 3 disciples, a small bag of Spirit Stones) ---

const START_DISCIPLES := 3
const START_RESOURCES := {"stones": 60, "food": 20, "herbs": 0, "reputation": 0}
const START_BUILDINGS := {"main_hall": 1}
const START_MOOD := 2
const START_LOYALTY := 50

# Limits ---------------------------------------------------------------------

const STAT_MIN := 1
const STAT_MAX := 10
const STAT_ROLL_MIN := 2
const STAT_ROLL_MAX := 7
const MOOD_MIN := -10
const MOOD_MAX := 10
const LOYALTY_MIN := 0
const LOYALTY_MAX := 100
## Cultivation progress toward the next realm. At the maximum a disciple is
## ready to break through; breakthroughs arrive in M5.
const PROGRESS_MAX := 100
const QUIRKS_PER_DISCIPLE := 2

# Buildings ------------------------------------------------------------------

const MAX_LEVEL := 3
## Spirit Stones to reach each level, by index (index 0 is unused).
const UPGRADE_COST := {
	"main_hall": [0, 0, 150, 300],
	"disciple_huts": [0, 40, 100, 200],
	"training_yard": [0, 40, 100, 200],
	"spirit_field": [0, 30, 80, 160],
}
## Main Hall level -> how many disciples the sect can hold (recruiting is M5).
const DISCIPLE_LIMIT: Array[int] = [0, 4, 8, 12]
## Main Hall level -> the sect's rank.
const RANKS: Array[String] = ["", "unknown_mountain", "rising_sect", "famous_sect"]

# A day at home --------------------------------------------------------------

const FOOD_PER_DISCIPLE := 1
## Mood lost by each disciple who could not eat.
const HUNGRY_MOOD := -2
## Food per worker by Spirit Field level; level 0 means foraging on the slopes.
const WORK_FOOD: Array[int] = [2, 3, 4, 5]
const WORK_HERBS: Array[int] = [0, 1, 2, 3]
const WORK_MOOD := 0

const TRAIN_BASE := 6
## Each Training Yard level adds this share to training gains.
const TRAIN_YARD_BONUS := 0.25
## Training gains are multiplied by this while Mood is below 0.
const TRAIN_LOW_MOOD_FACTOR := 0.8
const TRAIN_MOOD := -1

## Resting raises Mood by this, plus the Disciple Huts' level.
const REST_MOOD := 2
## From this Huts level, an injury heals one extra day per day.
const HUTS_FAST_HEAL_LEVEL := 2

## Above this Mood, Mood drifts 1 point down each day.
const MOOD_DRIFT_ABOVE := 3
## A chat in free time, once per disciple per day.
const TALK_MOOD := 1
## Loyalty rises 1 a day at or above this Mood, and falls 1 a day at or below
## the low mark.
const LOYALTY_UP_MOOD := 3
const LOYALTY_DOWN_MOOD := -3
const LOYALTY_STEP := 1

# Missions -------------------------------------------------------------------

const TEAM_MIN := 1
const TEAM_MAX := 4
## Ids, durations (days, inclusive range), difficulty, the two stats that
## matter, and rewards at the "success" tier (inclusive ranges).
const MISSIONS := {
	"gather_herbs": {
		"days": [1, 2],
		"difficulty": 8.0,
		"stats": ["wit", "spirit"],
		"rewards": {"herbs": [6, 12], "food": [3, 6]},
	},
	"hunt_monster": {
		"days": [2, 3],
		"difficulty": 14.0,
		"stats": ["body", "talent"],
		"rewards": {"stones": [20, 45], "reputation": [1, 3]},
	},
}
## Each realm above Qi Refining adds this to a member's power.
const REALM_POWER := 3.0
## Each point of Mood adds this to a member's power (negative Mood subtracts).
const MOOD_POWER := 0.3
## The random part of a mission's score: roll (0 to 1) minus 0.5, times this.
const MISSION_LUCK := 0.8
## Result tiers, best first, with the lowest score that reaches each one.
const TIERS: Array[String] = ["great", "success", "partial", "failure", "disaster"]
const TIER_MIN_SCORE := {"great": 1.5, "success": 1.0, "partial": 0.7, "failure": 0.4}
const TIER_REWARD := {"great": 1.5, "success": 1.0, "partial": 0.5, "failure": 0.0, "disaster": 0.0}
const TIER_MOOD := {"great": 2, "success": 1, "partial": 0, "failure": -1, "disaster": -2}
const TIER_LOYALTY := {"great": 1, "success": 0, "partial": 0, "failure": 0, "disaster": -1}
## On a failure, the chance that one team member is injured.
const FAILURE_INJURY_CHANCE := 0.5
const INJURY_DAYS: Array[int] = [2, 4]
const LOST_PROGRESS: Array[int] = [15, 30]

# Living disciples (M4) ------------------------------------------------------

## How two disciples get along, from rivals to close friends.
const RELATIONSHIP_MIN := -20
const RELATIONSHIP_MAX := 20
## The most one evening can move a pair, and how many pairs it can move.
const RELATIONSHIP_STEP := 2
const RELATIONSHIP_CHANGES := 3
## How many disciples may decide what they do tomorrow, each evening.
const DECISIONS_PER_EVENING := 2
## Mood lost when the Sect Master overrules a disciple's own decision (once a day).
const OVERRULE_MOOD := -1
## Chat moves Mood by at most this per reply, and by at most this in total
## per disciple per day, so chatting can't farm Mood.
const CHAT_MOOD_STEP := 2
const CHAT_MOOD_PER_DAY := 2
## Reasons and memories longer than this are shortened.
const REASON_CHARS := 160
