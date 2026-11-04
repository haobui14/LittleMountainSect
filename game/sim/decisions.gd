class_name Decisions
extends RefCounted
## Disciples' own choices for tomorrow, made in the evening story. A decision
## becomes the disciple's default on the next day plan. The Sect Master may
## overrule it, which costs the disciple Mood once (Balance.OVERRULE_MOOD).


## The decision for the sect's current day, or {} when there is none.
static func for_today(sect: Sect, id: String) -> Dictionary:
	var decision: Dictionary = sect.decisions.get(id, {})
	if decision.is_empty() or int(decision["day"]) != sect.day:
		return {}
	return decision


## The task a decision sets for today, or "" when there is none or it can't
## be done (the disciple is injured or away).
static func task_for_today(sect: Sect, id: String) -> String:
	var decision := for_today(sect, id)
	var d := sect.disciple(id)
	if decision.is_empty() or d == null or d.is_injured() or sect.is_away(id):
		return ""
	return String(decision["task"])


## Called when the plan gives a disciple something other than their own
## decision. Costs Mood the first time each day; returns the Mood lost.
static func overrule(sect: Sect, id: String) -> int:
	var decision := for_today(sect, id)
	if decision.is_empty() or decision["overruled"]:
		return 0
	decision["overruled"] = true
	var d := sect.disciple(id)
	var before := d.mood
	d.mood += Balance.OVERRULE_MOOD
	d.clamp_values()
	return d.mood - before


## Forgets decisions for days that are over.
static func expire(sect: Sect) -> void:
	for id: String in sect.decisions.keys():
		if int(sect.decisions[id]["day"]) < sect.day:
			sect.decisions.erase(id)
