class_name SimPlayers
extends RefCounted
## Automatic players for the balance sim. Each makes the upgrades it wants and
## returns a valid plan for the day. They roll their own dice (policy_rng), so
## the sect's luck comes only from the rules.

## Upgrades the sensible player buys, in order, keeping a small reserve.
const SENSIBLE_BUILD_ORDER: Array[String] = [
	"spirit_field",
	"training_yard",
	"disciple_huts",
	"spirit_field",
	"main_hall",
	"training_yard",
	"disciple_huts",
	"spirit_field",
	"training_yard",
	"disciple_huts",
	"main_hall",
]
const STONE_RESERVE := 15
## Days of food the sensible player keeps in store.
const FOOD_DAYS := 3


## Plays the way the Elder will advise: keep food up, rest unhappy disciples,
## hunt for Spirit Stones, and build the Spirit Field first.
static func sensible(sect: Sect, _policy_rng: SimRng) -> DayPlan:
	_build_next(sect)
	var plan := DayPlan.new()
	var free: Array[Disciple] = sect.available_disciples()

	# Unhappy disciples rest.
	for d in free.duplicate():
		if d.mood <= -3:
			plan.tasks[d.id] = "rest"
			free.erase(d)

	# Enough workers to keep a few days of food.
	var upkeep := sect.disciples.size() * Balance.FOOD_PER_DISCIPLE
	var shortfall := upkeep * FOOD_DAYS - int(sect.resources["food"])
	if shortfall > 0:
		var per_worker := maxi(1, BuildingRules.work_food(sect) - Balance.FOOD_PER_DISCIPLE)
		var workers := mini(free.size(), ceili(float(shortfall) / per_worker))
		free.sort_custom(func(a: Disciple, b: Disciple) -> bool: return a.stat("talent") < b.stat("talent"))
		for i in workers:
			var d: Disciple = free.pop_front()
			plan.tasks[d.id] = "work"

	# One team at a time: hunt when stones are short, otherwise gather herbs.
	if sect.missions.is_empty() and free.size() >= 2:
		var mission := "hunt_monster" if int(sect.resources["stones"]) < _next_cost(sect) else "gather_herbs"
		free.sort_custom(func(a: Disciple, b: Disciple) -> bool:
			return MissionResolver.member_power(a, mission) > MissionResolver.member_power(b, mission))
		var team: Array[String] = []
		for d in free:
			if team.size() >= 3:
				break
			team.append(d.id)
			if MissionResolver.expected_tier(sect, mission, team) in ["great", "success"]:
				break
		if MissionResolver.expected_tier(sect, mission, team) in ["great", "success", "partial"]:
			plan.add_mission(mission, team)
			for id in team:
				free.erase(sect.disciple(id))

	for d in free:
		plan.tasks[d.id] = "train"
	return plan


## Any valid plan, chosen at random: a stress test for the rules' limits.
static func random(sect: Sect, policy_rng: SimRng) -> DayPlan:
	if policy_rng.chance(0.3):
		BuildingRules.upgrade(sect, policy_rng.pick(Balance.BUILDINGS_IN_PLAY))
	var plan := DayPlan.new()
	var team: Array[String] = []
	for d in sect.available_disciples():
		var choice: String = policy_rng.pick(["train", "work", "rest", "mission"])
		if choice == "mission" and team.size() < Balance.TEAM_MAX:
			team.append(d.id)
		else:
			plan.tasks[d.id] = "rest" if choice == "mission" else choice
	if not team.is_empty():
		var open: Array = Balance.MISSIONS.keys().filter(func(m: String) -> bool: return MissionResolver.unlocked(sect, m))
		plan.add_mission(policy_rng.pick(open), team)
	return plan


## The next building in SENSIBLE_BUILD_ORDER that isn't built yet, or "".
static func _next_step(sect: Sect) -> String:
	var levels := Balance.START_BUILDINGS.duplicate()
	for building in SENSIBLE_BUILD_ORDER:
		levels[building] = int(levels.get(building, 0)) + 1
		if sect.level(building) < int(levels[building]):
			return building
	return ""


## Stones the sensible player wants before its next upgrade.
static func _next_cost(sect: Sect) -> int:
	var building := _next_step(sect)
	if building == "":
		return 0
	return BuildingRules.upgrade_cost(building, sect.level(building) + 1) + STONE_RESERVE


static func _build_next(sect: Sect) -> void:
	var building := _next_step(sect)
	if building != "" and int(sect.resources["stones"]) >= _next_cost(sect):
		BuildingRules.upgrade(sect, building)


## Random chat and evening replies, including out-of-range and invalid ones,
## so the balance sim stresses the M4 limits along with the day plan.
static func random_ai(sect: Sect, policy_rng: SimRng) -> void:
	for d in sect.disciples:
		if policy_rng.chance(0.5):
			ChatRules.apply(sect, d, {
				"safety": policy_rng.pick(["ok", "ok", "ok", "boundary"]),
				"mood_change": policy_rng.randi_range(-9, 9),
				"wants_action": policy_rng.pick(Balance.ACTIONS),
			})
	var decisions: Array = []
	var changes: Array = []
	for i in 4:
		var a: Disciple = policy_rng.pick(sect.disciples)
		var b: Disciple = policy_rng.pick(sect.disciples)
		decisions.append({"disciple_id": a.id, "action": policy_rng.pick(Balance.ACTIONS), "reason": "Because."})
		changes.append({"from": a.id, "to": b.id, "change": policy_rng.randi_range(-9, 9), "reason": "Hm."})
	EveningRules.apply(sect, {"decisions": decisions, "relationship_changes": changes})
