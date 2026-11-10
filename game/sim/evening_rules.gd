class_name EveningRules
extends RefCounted
## The evening story request and what its reply may change. Run after
## DayResolver, so sect.day is already tomorrow: decisions are for that day.

const MAX_FACTS := 40


## What a disciple may decide to do tomorrow: nothing when away (on a
## mission, lost, left or travelling) or an Elder, resting actions when
## injured, and otherwise every action whose task the day plan allows (study
## only with the Library).
static func allowed_actions(sect: Sect, d: Disciple) -> Array[String]:
	var out: Array[String] = []
	if sect.is_away(d.id) or d.is_elder():
		return out
	for action in Balance.ACTIONS:
		if not Balance.ACTION_TASK.has(action):
			continue
		if not DayPlan.task_allowed(sect, d, String(Balance.ACTION_TASK[action])):
			continue
		out.append(action)
	return out


## The gateway request for the evening of [param report]'s day. Only ids,
## numbers and catalog values: the server writes the sentences.
static func request(sect: Sect, report: DayReport, locale: String) -> Dictionary:
	var disciples: Array[Dictionary] = []
	for d in sect.disciples:
		disciples.append({"card": DiscipleCard.build(d, locale, sect), "allowed_actions": allowed_actions(sect, d)})
	var resources := {}
	for name in Balance.RESOURCES:
		resources[name] = int(sect.resources[name])
	return {
		"kind": "evening",
		"locale": locale,
		"game_day": report.day,
		"sect": {"rank": sect.rank(), "resources": resources},
		"disciples": disciples,
		"relationships": Relationships.pairs(sect),
		"facts": report.facts.slice(0, MAX_FACTS),
	}


## Applies the parts of an evening reply the rules allow: up to
## Balance.DECISIONS_PER_EVENING decisions from each disciple's allowed
## actions, and up to RELATIONSHIP_CHANGES relationship changes. Returns what
## was applied: {"decisions": [...], "relationships": [...]}.
static func apply(sect: Sect, reply: Dictionary) -> Dictionary:
	var applied := {"decisions": [], "relationships": []}
	for decision: Dictionary in _list(reply.get("decisions")):
		if applied["decisions"].size() >= Balance.DECISIONS_PER_EVENING:
			break
		var id := ChatRules.text_of(decision.get("disciple_id"))
		var action := ChatRules.text_of(decision.get("action"))
		var d := sect.disciple(id)
		if d == null or not action in allowed_actions(sect, d):
			continue
		if applied["decisions"].any(func(a: Dictionary) -> bool: return a["disciple"] == id):
			continue
		sect.decisions[id] = {
			"action": action,
			"task": Balance.ACTION_TASK[action],
			"reason": ChatRules.text_of(decision.get("reason")).left(Balance.REASON_CHARS),
			"day": sect.day,
			"overruled": false,
		}
		applied["decisions"].append({"disciple": id, "action": action, "reason": sect.decisions[id]["reason"]})

	var pairs := {}
	for change: Dictionary in _list(reply.get("relationship_changes")):
		if applied["relationships"].size() >= Balance.RELATIONSHIP_CHANGES:
			break
		var a := ChatRules.text_of(change.get("from"))
		var b := ChatRules.text_of(change.get("to"))
		if pairs.has(Relationships.key(a, b)):
			continue
		var amount: Variant = change.get("change")
		var moved := Relationships.change(sect, a, b, int(amount) if amount is int or amount is float else 0)
		if moved == 0:
			continue
		pairs[Relationships.key(a, b)] = true
		applied["relationships"].append({
			"a": a,
			"b": b,
			"change": moved,
			"reason": ChatRules.text_of(change.get("reason")).left(Balance.REASON_CHARS),
		})
	return applied


## A reply value as a list of dictionaries; anything else is dropped.
static func _list(value: Variant) -> Array:
	if not value is Array:
		return []
	return (value as Array).filter(func(item: Variant) -> bool: return item is Dictionary)
