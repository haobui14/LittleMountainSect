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


## {"ok": bool, "reason": "" | "not_in_play" | "max_level" | "not_enough_stones",
## "cost": int}
static func can_upgrade(sect: Sect, building: String) -> Dictionary:
	if not in_play(building):
		return {"ok": false, "reason": "not_in_play", "cost": -1}
	var next := sect.level(building) + 1
	var cost := upgrade_cost(building, next)
	if next > Balance.MAX_LEVEL or cost < 0:
		return {"ok": false, "reason": "max_level", "cost": -1}
	if int(sect.resources["stones"]) < cost:
		return {"ok": false, "reason": "not_enough_stones", "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


## Pays for and applies one level. Returns false (and changes nothing) when
## the upgrade isn't possible.
static func upgrade(sect: Sect, building: String) -> bool:
	var check := can_upgrade(sect, building)
	if not check["ok"]:
		return false
	sect.add_resource("stones", -int(check["cost"]))
	sect.buildings[building] = sect.level(building) + 1
	return true


static func training_gain(sect: Sect, d: Disciple) -> int:
	@warning_ignore("integer_division")
	var base := Balance.TRAIN_BASE + d.stat("talent") + d.stat("spirit") / 2
	var gain := float(base) * (1.0 + Balance.TRAIN_YARD_BONUS * sect.level("training_yard"))
	if d.mood < 0:
		gain *= Balance.TRAIN_LOW_MOOD_FACTOR
	return roundi(gain)


static func work_food(sect: Sect) -> int:
	return Balance.WORK_FOOD[sect.level("spirit_field")]


static func work_herbs(sect: Sect) -> int:
	return Balance.WORK_HERBS[sect.level("spirit_field")]


static func rest_mood(sect: Sect) -> int:
	return Balance.REST_MOOD + sect.level("disciple_huts")


## Days an injury heals per day of rest.
static func heal_per_day(sect: Sect) -> int:
	return 2 if sect.level("disciple_huts") >= Balance.HUTS_FAST_HEAL_LEVEL else 1
