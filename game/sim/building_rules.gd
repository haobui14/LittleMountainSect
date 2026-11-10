class_name BuildingRules
extends RefCounted
## Building upgrades and what each building does. Upgrades happen at once,
## during the day plan, and cost Spirit Stones.


static func in_play(building: String) -> bool:
	return building in Balance.BUILDINGS_IN_PLAY


## Spirit Stones to raise [param building] to [param to_level], or -1 when
## that level can't be built.
static func upgrade_cost(building: String, to_level: int) -> int:
	if not in_play(building) or to_level < 1 or to_level > Balance.MAX_LEVEL:
		return -1
	var cost := int(Balance.UPGRADE_COST[building][to_level])
	return cost if cost > 0 else -1


## Reputation needed (not spent) to reach [param to_level]; 0 when none.
static func reputation_needed(building: String, to_level: int) -> int:
	var needs: Array = Balance.UPGRADE_REPUTATION.get(building, [])
	return int(needs[to_level]) if to_level < needs.size() else 0


## {"ok": bool, "reason": "" | "not_in_play" | "max_level" | "not_enough_stones"
## | "not_enough_reputation", "cost": int, "reputation": int}
static func can_upgrade(sect: Sect, building: String) -> Dictionary:
	if not in_play(building):
		return {"ok": false, "reason": "not_in_play", "cost": -1, "reputation": 0}
	var next := sect.level(building) + 1
	var cost := upgrade_cost(building, next)
	if next > Balance.MAX_LEVEL or cost < 0:
		return {"ok": false, "reason": "max_level", "cost": -1, "reputation": 0}
	var reputation := reputation_needed(building, next)
	if int(sect.resources["reputation"]) < reputation:
		return {"ok": false, "reason": "not_enough_reputation", "cost": cost, "reputation": reputation}
	if int(sect.resources["stones"]) < cost:
		return {"ok": false, "reason": "not_enough_stones", "cost": cost, "reputation": reputation}
	return {"ok": true, "reason": "", "cost": cost, "reputation": reputation}


## Pays for and applies one level. Returns false (and changes nothing) when
## the upgrade isn't possible.
static func upgrade(sect: Sect, building: String) -> bool:
	var check := can_upgrade(sect, building)
	if not check["ok"]:
		return false
	sect.add_resource("stones", -int(check["cost"]))
	sect.buildings[building] = sect.level(building) + 1
	if building == "main_hall":
		# The Main Hall sets the rank: the evening story hears about it.
		sect.pending_facts.append({"type": "rank_up", "rank": sect.rank()})
		sect.chronicle_add("rank_up", {"rank": sect.rank()})
	return true


## Progress from a day of training: stats, the Training Yard, the realm (higher
## realms are slower), technique, the sect's Elders, Mood and side effects.
static func training_gain(sect: Sect, d: Disciple) -> int:
	@warning_ignore("integer_division")
	var base := Balance.TRAIN_BASE + d.stat("talent") + d.stat("spirit") / 2
	var gain := float(base) * (1.0 + Balance.TRAIN_YARD_BONUS * sect.level("training_yard"))
	gain *= Balance.REALM_TRAIN[clampi(d.realm_index(), 0, Balance.REALM_TRAIN.size() - 1)]
	gain *= 1.0 + Balance.TECHNIQUE_TRAIN * d.technique
	gain *= 1.0 + Generations.training_bonus(sect)
	gain *= d.effect_factor("train")
	if d.mood < 0:
		gain *= Balance.TRAIN_LOW_MOOD_FACTOR
	return roundi(gain)


## Food and Herbs from one worker in the Spirit Field (or foraging before it
## is built); a disciple who keeps floating away does half the work.
static func worker_food(sect: Sect, d: Disciple = null) -> int:
	var food := Balance.WORK_FOOD[sect.level("spirit_field")]
	return roundi(food * d.effect_factor("work")) if d else food


static func worker_herbs(sect: Sect, d: Disciple = null) -> int:
	var herbs := Balance.WORK_HERBS[sect.level("spirit_field")]
	return roundi(herbs * d.effect_factor("work")) if d else herbs


static func work_food(sect: Sect) -> int:
	return worker_food(sect)


static func work_herbs(sect: Sect) -> int:
	return worker_herbs(sect)


static func rest_mood(sect: Sect, d: Disciple = null) -> int:
	var mood := Balance.REST_MOOD + sect.level("disciple_huts")
	return roundi(mood * d.effect_factor("rest")) if d else mood


## Mood each fed disciple gains from the Kitchen's meals.
static func kitchen_mood(sect: Sect) -> int:
	return Balance.KITCHEN_MOOD[sect.level("kitchen")]


## Extra Food the Kitchen's meals cost for [param home] disciples at home.
static func kitchen_food(sect: Sect, home: int) -> int:
	var per: int = Balance.KITCHEN_FOOD_PER[sect.level("kitchen")]
	return ceili(float(home) / per) if per > 0 and home > 0 else 0


## Days an injury heals per day of rest.
static func heal_per_day(sect: Sect) -> int:
	return 2 if sect.level("disciple_huts") >= Balance.HUTS_FAST_HEAL_LEVEL else 1
