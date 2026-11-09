class_name EventRules
extends RefCounted
## Surprise events. Each night, after the day number goes up, the rules may
## start an event for the next morning: a problem from EventCatalog, a place
## the mountain has, and a pair of disciples at home. A lost disciple's
## rescue always comes first. In the morning the Sect Master picks one of
## the choices, and the rules roll and apply its outcome; the words come
## from Claude, or from strings.csv without it.
##
## sect.event is {} or:
##   {day, problem, place, disciples: [ids], resolved, choice, result,
##    applied: {res, mood, rel, progress, effect, injure, item, return_day},
##    words: {title, story, choices: {id: text}} (Claude's, when it wrote them)}


## Rolls the next morning's event. Runs after the day number goes up.
static func roll(sect: Sect) -> void:
	sect.event = {}
	for d in sect.disciples:
		if d.status == "lost" and d.return_day == 0:
			sect.event = _start(sect, EventCatalog.RESCUE, "mountain_path", [d.id])
			return
	if sect.day < maxi(Balance.EVENT_FIRST_DAY, sect.next_event_day):
		return
	var home := sect.available_disciples()
	if home.size() < 2:
		return
	if not sect.rng.chance(Balance.EVENT_CHANCE):
		return
	var problems: Array[String] = []
	for problem in EventCatalog.random_problems():
		if not problem in sect.recent_problems and not places_for(sect, problem).is_empty():
			problems.append(problem)
	if problems.is_empty():
		return
	var problem: String = sect.rng.pick(problems)
	var place: String = sect.rng.pick(places_for(sect, problem))
	var a: Disciple = home.pop_at(sect.rng.randi_range(0, home.size() - 1))
	var b: Disciple = home.pop_at(sect.rng.randi_range(0, home.size() - 1))
	sect.event = _start(sect, problem, place, [a.id, b.id])
	sect.next_event_day = sect.day + sect.rng.randi_range(Balance.EVENT_COOLDOWN[0], Balance.EVENT_COOLDOWN[1])
	sect.recent_problems.append(problem)
	if sect.recent_problems.size() > Balance.EVENT_NO_REPEAT:
		sect.recent_problems = sect.recent_problems.slice(sect.recent_problems.size() - Balance.EVENT_NO_REPEAT)


static func _start(sect: Sect, problem: String, place: String, ids: Array[String]) -> Dictionary:
	return {
		"day": sect.day,
		"problem": problem,
		"place": place,
		"disciples": Array(ids),
		"resolved": false,
		"choice": "",
		"result": "",
		"applied": {},
		"words": {},
	}


## The places a problem can happen at, given the buildings the sect has.
static func places_for(sect: Sect, problem: String) -> Array[String]:
	var out: Array[String] = []
	for place: String in EventCatalog.PROBLEMS[problem]["places"]:
		var building: String = EventCatalog.PLACES[place]
		if building == "" or sect.level(building) >= 1:
			out.append(place)
	return out


## An event is waiting for the Sect Master's choice.
static func pending(sect: Sect) -> bool:
	return not sect.event.is_empty() and not bool(sect.event["resolved"])


static func affordable(sect: Sect, cost: Dictionary) -> bool:
	for resource: String in cost:
		if int(sect.resources[resource]) < int(cost[resource]):
			return false
	return true


## The choices with whether each can be afforded: [{id, ok}].
static func choices(sect: Sect) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sect.event.is_empty():
		return out
	for choice: Dictionary in EventCatalog.PROBLEMS[sect.event["problem"]]["choices"]:
		out.append({"id": choice["id"], "ok": affordable(sect, choice.get("cost", {}))})
	return out


static func can_choose(sect: Sect, choice_id: String) -> bool:
	if not pending(sect):
		return false
	var choice := EventCatalog.choice(sect.event["problem"], choice_id)
	return not choice.is_empty() and affordable(sect, choice.get("cost", {}))


## Applies the chosen outcome and returns what changed (also kept in
## sect.event["applied"]), or {} when the choice isn't possible.
static func choose(sect: Sect, choice_id: String) -> Dictionary:
	if not can_choose(sect, choice_id):
		return {}
	var event := sect.event
	var ids: Array[String] = []
	ids.assign(Array(event["disciples"]).map(func(id: Variant) -> String: return String(id)))
	var choice := EventCatalog.choice(event["problem"], choice_id)
	var applied := {}
	var cost: Dictionary = choice.get("cost", {})
	for resource: String in cost:
		_count(applied, "res", resource, sect.add_resource(resource, -int(cost[resource])))

	var result := "done"
	var outcome: Dictionary = choice.get("outcome", {})
	if choice.has("chance"):
		var win := sect.rng.chance(float(choice["chance"]))
		result = "win" if win else "lose"
		outcome = choice["win"] if win else choice["lose"]
	_apply(sect, outcome, ids, applied)

	event["resolved"] = true
	event["choice"] = choice_id
	event["result"] = result
	event["applied"] = applied
	sect.pending_facts.append({
		"type": "event",
		"problem": event["problem"],
		"place": event["place"],
		"choice": choice_id,
		"result": result,
		"disciples": ids.duplicate(),
	})
	return applied


static func _apply(sect: Sect, outcome: Dictionary, ids: Array[String], applied: Dictionary) -> void:
	for resource: String in outcome.get("res", {}):
		_count(applied, "res", resource, sect.add_resource(resource, _roll(sect, outcome["res"][resource])))
	for who: String in outcome.get("mood", {}):
		for d in _targets(sect, who, ids):
			var before := d.mood
			d.mood += int(outcome["mood"][who])
			d.clamp_values()
			_count(applied, "mood", d.id, d.mood - before)
	if outcome.has("rel") and ids.size() == 2:
		applied["rel"] = Relationships.change(sect, ids[0], ids[1], int(outcome["rel"]))
	for who: String in outcome.get("progress", {}):
		for d in _targets(sect, who, ids):
			var gain := mini(_roll(sect, outcome["progress"][who]), Balance.PROGRESS_MAX - d.progress)
			d.progress += gain
			_count(applied, "progress", d.id, gain)
	for who: String in outcome.get("effect", {}):
		for d in _targets(sect, who, ids):
			var days := sect.rng.randi_range(Balance.SIDE_EFFECT_DAYS[0], Balance.SIDE_EFFECT_DAYS[1])
			d.add_effect(String(outcome["effect"][who]), days)
			applied.get_or_add("effect", {})[d.id] = {"effect": String(outcome["effect"][who]), "days": days}
	for who: String in outcome.get("injure", {}):
		for d in _targets(sect, who, ids):
			d.injure(int(outcome["injure"][who]))
			applied.get_or_add("injure", {})[d.id] = int(outcome["injure"][who])
	if outcome.has("item"):
		var pill := String(outcome["item"])
		if pill == "random_pill":
			pill = sect.rng.pick(Balance.PILLS)
		if sect.add_item(pill, 1) > 0:
			applied["item"] = pill
	if outcome.has("return_in"):
		var lost := sect.disciple(ids[0])
		var span: Array = outcome["return_in"]
		lost.return_day = sect.day + sect.rng.randi_range(int(span[0]), int(span[1]))
		applied["return_day"] = lost.return_day


## "a" and "b" are the event's disciples; "all" is everyone at home.
static func _targets(sect: Sect, who: String, ids: Array[String]) -> Array[Disciple]:
	var out: Array[Disciple] = []
	match who:
		"a":
			out.append(sect.disciple(ids[0]))
		"b":
			if ids.size() > 1:
				out.append(sect.disciple(ids[1]))
		"all":
			out.assign(sect.disciples.filter(func(d: Disciple) -> bool: return not sect.is_away(d.id)))
	return out


## An amount, or a random one from an inclusive [min, max] range.
static func _roll(sect: Sect, amount: Variant) -> int:
	if amount is Array:
		return sect.rng.randi_range(int(amount[0]), int(amount[1]))
	return int(amount)


static func _count(applied: Dictionary, group: String, key: String, amount: int) -> void:
	if amount == 0:
		return
	var bucket: Dictionary = applied.get_or_add(group, {})
	bucket[key] = int(bucket.get(key, 0)) + amount


## The gateway request for the event's words: ids only (the server's catalog
## says what they mean).
static func request(sect: Sect, locale: String) -> Dictionary:
	var cards: Array[Dictionary] = []
	for id in sect.event["disciples"]:
		cards.append(DiscipleCard.build(sect.disciple(String(id)), locale, sect))
	return {
		"kind": "event",
		"locale": locale,
		"game_day": int(sect.event["day"]),
		"problem": sect.event["problem"],
		"place": sect.event["place"],
		"disciples": cards,
	}
