class_name Alchemy
extends RefCounted
## The Alchemy Room's pills: brewing them from Herbs (and Spirit Stones), and
## using Healing Pills. Breakthrough pills are used by CultivationRules.
## Brewing and healing happen in the morning, so their facts wait in
## sect.pending_facts for the day's report.


## {"ok": bool, "reason": "" | "locked" | "no_brews_left" | "full" | "too_expensive"}
static func can_brew(sect: Sect, pill: String) -> Dictionary:
	var recipe: Dictionary = Balance.RECIPES[pill]
	if sect.level("alchemy_room") < int(recipe["level"]):
		return {"ok": false, "reason": "locked"}
	if sect.brews_today >= sect.level("alchemy_room"):
		return {"ok": false, "reason": "no_brews_left"}
	if sect.item(pill) >= Balance.PILL_MAX:
		return {"ok": false, "reason": "full"}
	for resource: String in recipe["cost"]:
		if int(sect.resources[resource]) < int(recipe["cost"][resource]):
			return {"ok": false, "reason": "too_expensive"}
	return {"ok": true, "reason": ""}


## Pays for and brews one pill. Returns false (and changes nothing) when it can't.
static func brew(sect: Sect, pill: String) -> bool:
	if not can_brew(sect, pill)["ok"]:
		return false
	var cost: Dictionary = Balance.RECIPES[pill]["cost"]
	for resource: String in cost:
		sect.add_resource(resource, -int(cost[resource]))
	sect.add_item(pill, 1)
	sect.brews_today += 1
	sect.pending_facts.append({"type": "brewed", "pill": pill})
	return true


## A Healing Pill helps an injured disciple or one with a side effect.
static func can_heal(sect: Sect, d: Disciple) -> bool:
	return sect.item("healing_pill") > 0 and not d.effects.is_empty() and not sect.is_away(d.id)


## Uses a Healing Pill: the injury and every side effect are gone at once.
static func heal(sect: Sect, d: Disciple) -> bool:
	if not can_heal(sect, d):
		return false
	sect.add_item("healing_pill", -1)
	d.effects.clear()
	sect.pending_facts.append({"type": "cured", "disciple": d.id})
	return true
