class_name Generations
extends RefCounted
## Generations (M6): Elders, ascension, and travel with letters home.
##
## - A senior, loyal disciple may be promoted to Elder. Elders take no tasks,
##   don't count toward the Main Hall's limit, and help everyone train and
##   study.
## - A Nascent Soul disciple at full progress may try to ascend. On success
##   they leave for the heavens: they stay in sect.disciples (status
##   "ascended") for that evening's story, then join sect.alumni.
## - A senior disciple may ask to travel. Away, they write home every few
##   days with a small gift (Claude writes the letter for 1 Spirit Energy, or
##   a written one is used), and come home stronger.


# Elders -------------------------------------------------------------------------

static func max_elders(sect: Sect) -> int:
	return sect.level("main_hall")


static func days_in_sect(sect: Sect, d: Disciple) -> int:
	return sect.day - d.joined_day


## {"ok", "reason": "" | "elder" | "away" | "realm" | "loyalty" | "days" | "full"}
static func can_promote(sect: Sect, d: Disciple) -> Dictionary:
	if d == null or d.is_elder():
		return {"ok": false, "reason": "elder"}
	if sect.is_away(d.id):
		return {"ok": false, "reason": "away"}
	if d.realm_index() < Balance.REALMS.find(Balance.ELDER_REALM):
		return {"ok": false, "reason": "realm"}
	if d.loyalty < Balance.ELDER_LOYALTY:
		return {"ok": false, "reason": "loyalty"}
	if days_in_sect(sect, d) < Balance.ELDER_DAYS:
		return {"ok": false, "reason": "days"}
	if sect.elder_count() >= max_elders(sect):
		return {"ok": false, "reason": "full"}
	return {"ok": true, "reason": ""}


static func promote(sect: Sect, id: String) -> bool:
	var d := sect.disciple(id)
	if not can_promote(sect, d)["ok"]:
		return false
	d.role = "elder"
	sect.decisions.erase(id)
	sect.last_tasks.erase(id)
	sect.pending_facts.append({"type": "promoted", "disciple": id})
	sect.chronicle_add("promoted", {"disciple": id})
	return true


## The share Elders add to every disciple's training.
static func training_bonus(sect: Sect) -> float:
	return Balance.ELDER_TRAIN_BONUS * sect.elder_count()


static func study_bonus(sect: Sect) -> int:
	return Balance.ELDER_STUDY * sect.elder_count()


# Ascension ----------------------------------------------------------------------

static func can_ascend(d: Disciple) -> bool:
	return d.realm_index() == Balance.REALMS.size() - 1 \
		and d.progress >= Balance.PROGRESS_MAX \
		and not d.is_injured() \
		and not d.is_elder()


static func ascend_chance(sect: Sect, d: Disciple, pill: String = "") -> float:
	if pill == "":
		pill = CultivationRules.best_pill(sect)
	var value := Balance.ASCEND_BASE \
		+ Balance.ASCEND_STAT * (d.stat("talent") + d.stat("spirit")) \
		+ float(Balance.PILL_BREAKTHROUGH.get(pill, 0.0))
	return clampf(value, Balance.BREAKTHROUGH_MIN, Balance.BREAKTHROUGH_MAX)


## Tries to ascend (the "ascend" home task). Returns true on success.
static func attempt_ascension(sect: Sect, d: Disciple, report: DayReport) -> bool:
	var pill := CultivationRules.best_pill(sect)
	var odds := ascend_chance(sect, d, pill)
	if pill != "none":
		sect.add_item(pill, -1)
	if sect.rng.chance(odds):
		d.status = "ascended"
		sect.add_resource("reputation", Balance.ASCEND_REPUTATION)
		report.add("ascended", {"disciple": d.id})
		sect.chronicle_add("ascended", {"disciple": d.id})
		return true
	var lost := mini(d.progress, Balance.ASCEND_FAIL_PROGRESS)
	d.progress -= lost
	var effect: String = sect.rng.pick(Balance.SIDE_EFFECTS)
	var days := sect.rng.randi_range(Balance.SIDE_EFFECT_DAYS[0], Balance.SIDE_EFFECT_DAYS[1])
	d.add_effect(effect, days)
	d.clamp_values()
	report.add("ascension_failed", {"disciple": d.id, "effect": effect, "days": days, "lost": lost})
	return false


## Moves disciples who ascended into the alumni. Runs at the start of the
## next day, after their evening story was told.
static func settle_ascended(sect: Sect) -> void:
	var stay: Array[Disciple] = []
	for d in sect.disciples:
		if d.status != "ascended":
			stay.append(d)
			continue
		sect.alumni.append({"id": d.id, "name_en": d.name_en, "name_vi": d.name_vi, "realm": d.realm, "day": sect.day - 1})
		for pair: String in sect.relationships.keys():
			if d.id in pair.split("|"):
				sect.relationships.erase(pair)
		sect.decisions.erase(d.id)
		sect.last_tasks.erase(d.id)
	sect.disciples = stay


# Travel -------------------------------------------------------------------------

## Whether [param d] could ask to travel: senior, settled in, and at home.
static func can_travel(sect: Sect, d: Disciple) -> bool:
	return not d.is_elder() \
		and d.status == "home" \
		and not sect.is_away(d.id) \
		and not d.is_injured() \
		and d.realm_index() >= Balance.REALMS.find(Balance.TRAVEL_REALM) \
		and days_in_sect(sect, d) >= Balance.TRAVEL_DAYS_IN_SECT


static func travellers(sect: Sect) -> Array[Disciple]:
	var out: Array[Disciple] = []
	out.assign(sect.disciples.filter(func(d: Disciple) -> bool: return d.status == "travel"))
	return out


static func travel_pending(sect: Sect) -> bool:
	return not sect.travel_request.is_empty()


## At night, a senior disciple may ask to see the world, while enough others
## would stay home.
static func roll_travel(sect: Sect) -> void:
	if travel_pending(sect) or sect.day < sect.next_travel_day:
		return
	var home_members := sect.disciples.filter(func(d: Disciple) -> bool: return not d.is_elder() and d.status == "home").size()
	if home_members <= Balance.TRAVEL_MIN_MEMBERS:
		return
	var who: Array[Disciple] = []
	who.assign(sect.disciples.filter(func(d: Disciple) -> bool: return can_travel(sect, d)))
	if who.is_empty() or not sect.rng.chance(Balance.TRAVEL_CHANCE):
		return
	var d: Disciple = sect.rng.pick(who)
	sect.travel_request = {
		"disciple": d.id,
		"place": sect.rng.pick(TravelCatalog.PLACES),
		"days": sect.rng.randi_range(Balance.TRAVEL_LENGTH[0], Balance.TRAVEL_LENGTH[1]),
		"day": sect.day,
	}


## Lets the disciple go (a champion or defender leaves after today's
## contest). Returns false when there is no request, or they are no longer
## at the sect to leave from (an Elder now, or away).
static func let_go(sect: Sect) -> bool:
	if not travel_pending(sect):
		return false
	var d := sect.disciple(String(sect.travel_request["disciple"]))
	if d == null or d.is_elder() or d.status != "home" or sect.mission_of(d.id) != null:
		sect.travel_request = {}
		return false
	var place := String(sect.travel_request["place"])
	d.status = "travel"
	d.return_day = sect.day + int(sect.travel_request["days"])
	d.travel = {
		"place": place,
		"left_day": sect.day,
		"next_letter_day": sect.day + sect.rng.randi_range(Balance.LETTER_EVERY[0], Balance.LETTER_EVERY[1]),
	}
	sect.decisions.erase(d.id)
	sect.travel_request = {}
	sect.next_travel_day = sect.day + sect.rng.randi_range(Balance.TRAVEL_COOLDOWN[0], Balance.TRAVEL_COOLDOWN[1])
	sect.pending_facts.append({"type": "travel_left", "disciple": d.id, "place": place, "return_day": d.return_day})
	sect.chronicle_add("travel_left", {"disciple": d.id, "place": place})
	return true


## Asks them to stay; they're a little disappointed.
static func ask_to_stay(sect: Sect) -> bool:
	if not travel_pending(sect):
		return false
	var d := sect.disciple(String(sect.travel_request["disciple"]))
	if d:
		d.mood += Balance.STAY_MOOD
		d.clamp_values()
	sect.travel_request = {}
	sect.next_travel_day = sect.day + sect.rng.randi_range(Balance.TRAVEL_COOLDOWN[0], Balance.TRAVEL_COOLDOWN[1])
	return true


## At night: yesterday's letter is put away, and a traveller whose letter is
## due writes home, with a small gift that arrives at once. At most one
## letter a day; the next waits a day.
static func roll_letters(sect: Sect) -> void:
	sect.letter = {}
	for d in travellers(sect):
		var due := int(d.travel.get("next_letter_day", 0))
		if due > sect.day or sect.day >= d.return_day:
			continue
		if not sect.letter.is_empty():
			d.travel["next_letter_day"] = sect.day + 1
			continue
		var gift := {}
		var item := "none"
		if sect.rng.chance(Balance.LETTER_PILL_CHANCE):
			var pill: String = sect.rng.pick(Balance.PILLS)
			if sect.add_item(pill, 1) > 0:
				item = pill
		if item == "none":
			var resource: String = sect.rng.pick(Balance.LETTER_GIFTS.keys())
			var span: Array = Balance.LETTER_GIFTS[resource]
			gift[resource] = sect.add_resource(resource, sect.rng.randi_range(int(span[0]), int(span[1])))
		var place := String(d.travel["place"])
		var away := sect.day - int(d.travel["left_day"])
		sect.letter = {
			"day": sect.day,
			"disciple": d.id,
			"place": place,
			"days_away": clampi(away, 1, 60),
			"gift": gift,
			"item": item,
			"words": "",
		}
		d.travel["next_letter_day"] = sect.day + sect.rng.randi_range(Balance.LETTER_EVERY[0], Balance.LETTER_EVERY[1])
		sect.pending_facts.append({"type": "letter", "disciple": d.id, "place": place, "gift": gift.duplicate(), "item": item})


## The gateway request for this morning's letter: ids and numbers only.
static func letter_request(sect: Sect, locale: String) -> Dictionary:
	return letter_request_for(sect.letter, sect, locale)


static func letter_request_for(letter: Dictionary, sect: Sect, locale: String) -> Dictionary:
	var d := sect.disciple(String(letter["disciple"]))
	return {
		"kind": "letter",
		"locale": locale,
		"game_day": int(letter["day"]),
		"disciple": DiscipleCard.build(d, locale, sect),
		"place": letter["place"],
		"days_away": int(letter["days_away"]),
		"gift": letter["gift"].duplicate(),
		"item": letter["item"],
	}


## Travellers due home arrive: progress, Loyalty and maybe a souvenir.
static func bring_home(sect: Sect, report: DayReport) -> void:
	for d in travellers(sect):
		if d.return_day > sect.day:
			continue
		var place := String(d.travel.get("place", TravelCatalog.PLACES[0]))
		d.status = "home"
		d.return_day = 0
		d.travel = {}
		d.progress = mini(d.progress + Balance.HOMECOMING_PROGRESS, Balance.PROGRESS_MAX)
		d.loyalty += Balance.HOMECOMING_LOYALTY
		d.clamp_values()
		var souvenir := "none"
		if sect.rng.chance(Balance.SOUVENIR_CHANCE):
			var pill: String = sect.rng.pick(Balance.PILLS)
			if sect.add_item(pill, 1) > 0:
				souvenir = pill
		report.add("travel_returned", {"disciple": d.id, "place": place, "souvenir": souvenir})
		sect.chronicle_add("travel_returned", {"disciple": d.id, "place": place})
