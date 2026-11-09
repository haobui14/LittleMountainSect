class_name SimPlayers
extends RefCounted
## Automatic players for the balance sim. Each handles the morning (the
## surprise event, a hopeful at the gate, pills), makes the upgrades it wants
## and returns a valid plan for the day. They roll their own dice
## (policy_rng), so the sect's luck comes only from the rules.

## Upgrades the sensible player buys, in order, keeping a small reserve. A
## step that needs more Reputation is skipped until the sect has it.
const SENSIBLE_BUILD_ORDER: Array[String] = [
	"spirit_field",
	"training_yard",
	"disciple_huts",
	"spirit_field",
	"mission_hall",
	"alchemy_room",
	"main_hall",
	"kitchen",
	"library",
	"mission_hall",
	"main_hall",
	"training_yard",
	"disciple_huts",
	"alchemy_room",
	"spirit_field",
	"library",
	"training_yard",
	"kitchen",
	"disciple_huts",
	"alchemy_room",
	"mission_hall",
	"library",
	"kitchen",
]
const STONE_RESERVE := 15
## Days of food the sensible player keeps in store.
const FOOD_DAYS := 3
## The sensible player breaks through at this chance or better.
const BREAKTHROUGH_AT := 0.45


## Plays the way the Elder will advise: keep food up, rest unhappy disciples,
## build in a sensible order, break through with good odds, brew pills for
## it, study, recruit when there's room and money, and pick missions the
## team can win.
static func sensible(sect: Sect, policy_rng: SimRng) -> DayPlan:
	_sensible_morning(sect)
	_build_next(sect)
	var plan := DayPlan.new()
	var free: Array[Disciple] = sect.available_disciples()

	# Ready disciples with good odds try to break through.
	for d in free.duplicate():
		if CultivationRules.can_break_through(d) and CultivationRules.chance(sect, d) >= BREAKTHROUGH_AT:
			plan.tasks[d.id] = "breakthrough"
			free.erase(d)

	# Unhappy disciples rest.
	for d in free.duplicate():
		if d.mood <= -3:
			plan.tasks[d.id] = "rest"
			free.erase(d)

	# Enough workers to keep a few days of food.
	var home := sect.disciples.filter(func(d: Disciple) -> bool: return not sect.is_away(d.id)).size()
	var upkeep := home * Balance.FOOD_PER_DISCIPLE + BuildingRules.kitchen_food(sect, home)
	var shortfall := upkeep * FOOD_DAYS - int(sect.resources["food"])
	if shortfall > 0:
		var per_worker := maxi(1, BuildingRules.work_food(sect) - Balance.FOOD_PER_DISCIPLE)
		var workers := mini(free.size(), ceili(float(shortfall) / per_worker))
		free.sort_custom(func(a: Disciple, b: Disciple) -> bool: return a.stat("talent") < b.stat("talent"))
		for i in workers:
			var d: Disciple = free.pop_front()
			plan.tasks[d.id] = "work"

	# One team at a time, on the best mission it can win.
	if sect.missions.is_empty() and free.size() >= 2:
		var team := _team_for(sect, free, _mission_wanted(sect))
		if not team.is_empty():
			plan.add_mission(team["mission"], team["ids"])
			for id: String in team["ids"]:
				free.erase(sect.disciple(id))

	# One disciple studies in the Library.
	if sect.level("library") >= 1:
		free.sort_custom(func(a: Disciple, b: Disciple) -> bool: return a.stat("wit") > b.stat("wit"))
		for d in free:
			if CultivationRules.can_study(sect, d):
				plan.tasks[d.id] = "study"
				free.erase(d)
				break

	for d in free:
		plan.tasks[d.id] = "train"
	return plan


static func _sensible_morning(sect: Sect) -> void:
	if EventRules.pending(sect):
		# Spirit Stones are for buildings: the first choice that doesn't
		# cost any, unless only paid ones are left.
		var options := EventRules.choices(sect).filter(func(c: Dictionary) -> bool: return c["ok"])
		var pick: Dictionary = options[0]
		for choice: Dictionary in options:
			if not EventCatalog.choice(sect.event["problem"], choice["id"]).get("cost", {}).has("stones"):
				pick = choice
				break
		EventRules.choose(sect, pick["id"])
	if not sect.candidate.is_empty():
		var fed := int(sect.resources["food"]) >= (sect.disciples.size() + 1) * FOOD_DAYS
		var spare := int(sect.resources["stones"]) >= Recruiting.cost(sect) + STONE_RESERVE
		if fed and spare and Recruiting.can_accept(sect)["ok"]:
			Recruiting.accept(sect)
		else:
			Recruiting.decline(sect)
	for d in sect.disciples:
		if d.is_injured() and Alchemy.can_heal(sect, d):
			Alchemy.heal(sect, d)
	# A small stock of breakthrough pills, the better ones first.
	for pill in ["golden_pill", "foundation_pill"]:
		if sect.item(pill) < 2 and Alchemy.brew(sect, pill):
			break
	if sect.item("healing_pill") == 0:
		Alchemy.brew(sect, "healing_pill")


## The mission the sensible player wants today: Stones when the next upgrade
## needs them (escorts pay best once unlocked), the Secret Realm when it can
## be won, and Herbs when the Alchemy Room is hungry.
static func _mission_wanted(sect: Sect) -> Array[String]:
	var wanted: Array[String] = []
	if MissionResolver.unlocked(sect, "explore_secret_realm"):
		wanted.append("explore_secret_realm")
	if int(sect.resources["stones"]) < _next_cost(sect):
		if MissionResolver.unlocked(sect, "escort_merchant"):
			wanted.append("escort_merchant")
		wanted.append("hunt_monster")
	if int(sect.resources["herbs"]) < 30:
		wanted.append("gather_herbs")
	if MissionResolver.unlocked(sect, "escort_merchant"):
		wanted.append("escort_merchant")
	wanted.append("hunt_monster")
	return wanted


## The first wanted mission a team of up to 4 can win: {mission, ids}, or {}.
static func _team_for(sect: Sect, free: Array[Disciple], wanted: Array[String]) -> Dictionary:
	for mission in wanted:
		var size := 3 if mission in ["gather_herbs", "hunt_monster"] else 4
		var good := ["great", "success"] if mission == "explore_secret_realm" else ["great", "success", "partial"]
		var pool := free.duplicate()
		pool.sort_custom(func(a: Disciple, b: Disciple) -> bool:
			return MissionResolver.member_power(a, mission) > MissionResolver.member_power(b, mission))
		var ids: Array[String] = []
		for d: Disciple in pool:
			if ids.size() >= size:
				break
			ids.append(d.id)
			if MissionResolver.expected_tier(sect, mission, ids) in ["great", "success"]:
				break
		# The long Secret Realm always leaves someone at home.
		if mission == "explore_secret_realm" and ids.size() >= sect.available_disciples().size():
			continue
		if MissionResolver.expected_tier(sect, mission, ids) in good:
			return {"mission": mission, "ids": ids}
	return {}


## Any valid choices, at random: a stress test for the rules' limits.
static func random(sect: Sect, policy_rng: SimRng) -> DayPlan:
	if EventRules.pending(sect):
		var options := EventRules.choices(sect).filter(func(c: Dictionary) -> bool: return c["ok"])
		EventRules.choose(sect, policy_rng.pick(options)["id"])
	if not sect.candidate.is_empty():
		if policy_rng.chance(0.5):
			Recruiting.accept(sect)
		else:
			Recruiting.decline(sect)
	if policy_rng.chance(0.3):
		Alchemy.brew(sect, policy_rng.pick(Balance.PILLS))
	if policy_rng.chance(0.3):
		Alchemy.heal(sect, policy_rng.pick(sect.disciples))
	if policy_rng.chance(0.3):
		BuildingRules.upgrade(sect, policy_rng.pick(Balance.BUILDINGS_IN_PLAY))
	var plan := DayPlan.new()
	var team: Array[String] = []
	for d in sect.available_disciples():
		var options: Array = Balance.HOME_TASKS.duplicate()
		options.append("mission")
		var choice: String = policy_rng.pick(options)
		if choice == "mission" and team.size() < Balance.TEAM_MAX:
			team.append(d.id)
		elif choice != "mission" and DayPlan.task_allowed(sect, d, choice):
			plan.tasks[d.id] = choice
		else:
			plan.tasks[d.id] = "rest"
	if not team.is_empty():
		var open: Array = Balance.MISSIONS.keys().filter(func(m: String) -> bool: return MissionResolver.unlocked(sect, m))
		plan.add_mission(policy_rng.pick(open), team)
	return plan


## The next building in SENSIBLE_BUILD_ORDER that isn't built yet and isn't
## waiting for Reputation, or "".
static func _next_step(sect: Sect) -> String:
	var levels := Balance.START_BUILDINGS.duplicate()
	for building in SENSIBLE_BUILD_ORDER:
		levels[building] = int(levels.get(building, 0)) + 1
		if sect.level(building) >= int(levels[building]):
			continue
		if BuildingRules.can_upgrade(sect, building)["reason"] == "not_enough_reputation":
			continue
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
