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
## "study" needs the Library and "breakthrough" a disciple ready for it
## (DayPlan.task_allowed).
const HOME_TASKS: Array[String] = ["train", "work", "rest", "study", "breakthrough"]

## Actions a character may want or decide on: the server's ACTIONS in
## server/supabase/functions/_shared/cast.ts (the contract test checks them).
const ACTIONS: Array[String] = ["train", "rest", "meditate", "cook", "tend_field", "study", "explore", "hide"]
## The home task each action means on the day plan. Actions missing here
## ("explore") can't be chosen yet.
const ACTION_TASK := {
	"train": "train",
	"meditate": "train",
	"study": "study",
	"cook": "work",
	"tend_field": "work",
	"rest": "rest",
	"hide": "rest",
}

## Where a disciple is (M5). "mission" is derived from the sect's missions;
## the save stores home, lost or left.
const STATUSES: Array[String] = ["home", "mission", "lost", "left"]
## Alchemy Room pills (M5).
const PILLS: Array[String] = ["foundation_pill", "healing_pill", "golden_pill"]
## Timed funny side effects of a failed breakthrough (M5).
const SIDE_EFFECTS: Array[String] = ["green_hair", "hiccups", "floating", "backwards_qi", "squeaky_voice", "glowing"]
## Each spirit root's technique, in SPIRIT_ROOTS order (M5).
const TECHNIQUES: Array[String] = ["iron_chopsticks_palm", "swaying_bamboo_step", "puddle_mirror_art", "spicy_breath_fist", "immovable_nap_stance"]

## The mountain's 8 fixed slots, in screen order.
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
const BUILDINGS_IN_PLAY: Array[String] = BUILDINGS

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
## ready to break through (the "breakthrough" home task).
const PROGRESS_MAX := 100
const QUIRKS_PER_DISCIPLE := 2

# Buildings ------------------------------------------------------------------

const MAX_LEVEL := 3
## Spirit Stones to reach each level, by index (index 0 is unused).
const UPGRADE_COST := {
	"main_hall": [0, 0, 150, 250],
	"disciple_huts": [0, 40, 100, 200],
	"training_yard": [0, 40, 100, 200],
	"spirit_field": [0, 30, 80, 160],
	"kitchen": [0, 40, 100, 200],
	"alchemy_room": [0, 60, 140, 280],
	"library": [0, 60, 140, 280],
	"mission_hall": [0, 50, 120, 240],
}
## Reputation a level needs (not spent): a rank is earned, not only bought.
const UPGRADE_REPUTATION := {"main_hall": [0, 0, 15, 50]}
## Main Hall level -> how many disciples the sect can hold.
const DISCIPLE_LIMIT: Array[int] = [0, 4, 8, 12]
## Main Hall level -> the sect's rank.
const RANKS: Array[String] = ["", "unknown_mountain", "rising_sect", "famous_sect"]

# A day at home --------------------------------------------------------------

const FOOD_PER_DISCIPLE := 1
## Mood lost by each disciple who could not eat.
const HUNGRY_MOOD := -2
## Food per worker by Spirit Field level; level 0 means foraging on the slopes.
const WORK_FOOD: Array[int] = [2, 3, 4, 5]
const WORK_HERBS: Array[int] = [0, 1, 1, 2]
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
		"rewards": {"stones": [25, 50], "reputation": [1, 3]},
	},
	"escort_merchant": {
		"days": [3, 4],
		"difficulty": 18.0,
		"stats": ["body", "wit"],
		"rewards": {"stones": [35, 70], "reputation": [3, 6]},
	},
	## On success or better, the team also finds a random pill.
	"explore_secret_realm": {
		"days": [4, 5],
		"difficulty": 26.0,
		"stats": ["talent", "spirit"],
		"rewards": {"stones": [20, 40], "herbs": [10, 20], "reputation": [4, 8]},
		"treasure": true,
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

# Cultivation (M5) ------------------------------------------------------------

## Training slows in higher realms: gains are multiplied by this, by realm.
const REALM_TRAIN: Array[float] = [1.0, 0.7, 0.5, 0.35]
## Each technique level adds this share to training gains.
const TECHNIQUE_TRAIN := 0.1
## Breakthrough chance from each realm to the next, before stats, the
## Training Yard, Mood and pills; then clamped to the limits below.
const BREAKTHROUGH_BASE: Array[float] = [0.35, 0.20, 0.05]
const BREAKTHROUGH_STAT := 0.03
const BREAKTHROUGH_YARD := 0.05
const BREAKTHROUGH_MOOD := 0.01
const BREAKTHROUGH_MIN := 0.05
const BREAKTHROUGH_MAX := 0.95
## The best breakthrough pill in stock is used automatically.
const PILL_BREAKTHROUGH := {"golden_pill": 0.30, "foundation_pill": 0.15}
const BREAKTHROUGH_MOOD_GAIN := 2
const BREAKTHROUGH_LOYALTY_GAIN := 2
const BREAKTHROUGH_FAIL_PROGRESS := 40
const BREAKTHROUGH_FAIL_MOOD := -1
const SIDE_EFFECT_DAYS: Array[int] = [5, 10]
## What a side effect does to the rules, as multipliers. Green hair and the
## squeaky voice only change how people see the disciple.
const SIDE_EFFECT_RULES := {
	"hiccups": {"mission": 0.75},
	"floating": {"work": 0.5},
	"backwards_qi": {"train": 0.5},
	"glowing": {"rest": 0.5},
}

# Kitchen, Alchemy Room, Library and Mission Hall (M5) -------------------------

## Fed disciples gain this Mood, by Kitchen level...
const KITCHEN_MOOD: Array[int] = [0, 1, 1, 2]
## ...and the meals cost 1 extra Food per this many disciples at home.
const KITCHEN_FOOD_PER: Array[int] = [0, 2, 3, 3]
## Pills: the Alchemy Room level each needs and what it costs. The room
## brews as many pills a day as its level.
const RECIPES := {
	"foundation_pill": {"level": 1, "cost": {"herbs": 10}},
	"healing_pill": {"level": 2, "cost": {"herbs": 8, "stones": 10}},
	"golden_pill": {"level": 3, "cost": {"herbs": 25, "stones": 30}},
}
const PILL_MAX := 9
## Study a day in the Library is this plus Wit; at STUDY_MAX the disciple
## learns the next level of their root's technique, up to the Library's level.
const STUDY_BASE := 10
const STUDY_MAX := 100
const TECHNIQUE_MAX := 3
## Each technique level adds this to a disciple's mission power.
const TECHNIQUE_POWER := 1.5
## The Mission Hall level a mission needs; missions not listed need none.
const MISSION_HALL_NEEDED := {"escort_merchant": 1, "explore_secret_realm": 2}
## From this Mission Hall level, mission rewards grow by this share.
const MISSION_HALL_REWARD_LEVEL := 3
const MISSION_HALL_REWARD_BONUS := 0.25

# Setbacks (M5) ------------------------------------------------------------------

## On a disaster: an unhappy victim may leave; on a long mission the victim
## may get lost; otherwise an injury or lost progress (this chance: injury).
const DISASTER_INJURY_CHANCE := 0.5
const UNHAPPY_MOOD := -3
const UNHAPPY_LOYALTY := 30
const LEAVE_CHANCE := 0.5
const LOST_CHANCE := 0.25
const LOST_MIN_DAYS := 3
## A disciple who left comes back after this many days, a little humbler.
const LEFT_DAYS: Array[int] = [5, 15]
const RETURN_MOOD := 0
const RETURN_LOYALTY := 40

# Growth (M5) ----------------------------------------------------------------

## From this day, every RECRUIT_EVERY days, a hopeful waits at the gate for
## CANDIDATE_DAYS days while the sect has room.
const RECRUIT_FIRST_DAY := 3
const RECRUIT_EVERY: Array[int] = [4, 7]
const CANDIDATE_DAYS := 2
const RECRUIT_COST_BASE := 20
const RECRUIT_COST_PER := 10
## A famous sect attracts talent: candidates' Talent bonus by Main Hall level.
const RANK_TALENT: Array[int] = [0, 0, 1, 2]

# Surprise events (M5; the catalog is data/events.gd) --------------------------

const EVENT_FIRST_DAY := 3
const EVENT_CHANCE := 0.5
const EVENT_COOLDOWN: Array[int] = [2, 3]
## The same problem doesn't come back until this many others have.
const EVENT_NO_REPEAT := 5
## The Sect Chronicle keeps this many big moments (M6 reads it).
const CHRONICLE_MAX := 200

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
