class_name ReportText
extends RefCounted
## Writes the rules' facts (see DayReport) as sentences, from tr() templates in
## strings.csv. These written reports are the game's text whenever there is no
## AI story, and the only text in M3. Templates use {placeholders}.


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func name_of(sect: Sect, id: String, locale: String) -> String:
	return sect.name_of(id, locale)


## "Lin", "Lin and Bao", "Lin, Bao and Mei" (or "và" in Vietnamese).
static func names(sect: Sect, ids: Array, locale: String) -> String:
	var list: Array[String] = []
	for id: String in ids:
		list.append(name_of(sect, id, locale))
	if list.size() <= 1:
		return "".join(list)
	return ", ".join(list.slice(0, -1)) + t("UI_AND") + list[-1]


static func mission_name(mission: String) -> String:
	return t("MISSION_" + mission.to_upper())


static func resource_name(resource: String) -> String:
	return t("RES_" + resource.to_upper())


static func realm_name(realm: String) -> String:
	return t("REALM_" + realm.to_upper())


static func pill_name(pill: String) -> String:
	return t("PILL_" + pill.to_upper())


static func side_effect_name(effect: String) -> String:
	return t("SIDE_" + effect.to_upper())


static func technique_name(technique: String) -> String:
	return t("TECHNIQUE_" + technique.to_upper())


static func place_name(place: String) -> String:
	return t("PLACE_" + place.to_upper())


static func rival_name(rival: String) -> String:
	return t("RIVAL_" + rival.to_upper())


static func season_name(season: String) -> String:
	return t("SEASON_" + season.to_upper())


static func travel_place_name(place: String) -> String:
	return t("TRAVEL_" + place.to_upper())


## A gift or a haul: amounts and a pill, or "" when there is nothing.
static func gift_text(resources: Dictionary, item: String) -> String:
	var parts: Array[String] = []
	var listed := quantities(resources)
	if listed != "":
		parts.append(listed)
	if item != "" and item != "none":
		parts.append(pill_name(item))
	return t("UI_AND").join(parts)


# Surprise events ---------------------------------------------------------------
# Claude's words when it wrote them (sect.event["words"]), the written text
# from strings.csv otherwise. Written text names the disciples {a} and {b}.

static func _event_names(sect: Sect, event: Dictionary, locale: String) -> Dictionary:
	var ids: Array = event.get("disciples", [])
	return {
		"a": name_of(sect, String(ids[0]), locale) if ids.size() > 0 else "",
		"b": name_of(sect, String(ids[1]), locale) if ids.size() > 1 else "",
		"place": place_name(String(event.get("place", ""))),
	}


static func event_title(sect: Sect, event: Dictionary, locale: String) -> String:
	var words: Dictionary = event.get("words", {})
	if words.has("title"):
		return String(words["title"])
	return t("EVENT_%s_TITLE" % String(event["problem"]).to_upper())


static func event_story(sect: Sect, event: Dictionary, locale: String) -> String:
	var words: Dictionary = event.get("words", {})
	if words.has("story"):
		return String(words["story"])
	return t("EVENT_%s_STORY" % String(event["problem"]).to_upper()).format(_event_names(sect, event, locale))


static func event_choice(sect: Sect, event: Dictionary, choice: String, locale: String) -> String:
	var written: Dictionary = event.get("words", {}).get("choices", {})
	if written.has(choice):
		return String(written[choice])
	return t("EVENT_%s_%s" % [String(event["problem"]).to_upper(), choice.to_upper()]).format(_event_names(sect, event, locale))


## What a resolved event changed, as short lines: "It worked out!",
## "+12 Spirit Stones", "Lin: Mood +1", ...
static func event_result(sect: Sect, event: Dictionary, locale: String) -> Array[String]:
	var lines: Array[String] = []
	match String(event.get("result", "")):
		"win":
			lines.append(t("EVENT_RESULT_WIN"))
		"lose":
			lines.append(t("EVENT_RESULT_LOSE"))
	var applied: Dictionary = event.get("applied", {})
	var gained := amounts(applied.get("res", {}))
	if gained != "":
		lines.append(gained)
	for id: String in applied.get("mood", {}):
		lines.append(t("UI_EVENT_MOOD").format({"name": name_of(sect, id, locale), "mood": "%+d" % int(applied["mood"][id])}))
	if int(applied.get("rel", 0)) != 0:
		var ids: Array = event["disciples"]
		var key := "UI_EVENT_CLOSER" if int(applied["rel"]) > 0 else "UI_EVENT_APART"
		lines.append(t(key).format({"a": name_of(sect, String(ids[0]), locale), "b": name_of(sect, String(ids[1]), locale)}))
	for id: String in applied.get("progress", {}):
		lines.append(t("UI_EVENT_PROGRESS").format({"name": name_of(sect, id, locale), "gain": applied["progress"][id]}))
	for id: String in applied.get("effect", {}):
		var effect: Dictionary = applied["effect"][id]
		lines.append(t("MORNING_EFFECT").format({"name": name_of(sect, id, locale), "effect": side_effect_name(effect["effect"]), "days": effect["days"]}))
	for id: String in applied.get("injure", {}):
		lines.append(t("FACT_INJURED").format({"name": name_of(sect, id, locale), "days": applied["injure"][id]}))
	if applied.has("item"):
		lines.append(t("UI_EVENT_ITEM").format({"pill": pill_name(applied["item"])}))
	if applied.has("return_day"):
		lines.append(t("MORNING_COMING_HOME").format({"name": name_of(sect, String(event["disciples"][0]), locale), "day": applied["return_day"]}))
	if lines.is_empty():
		lines.append(t("UI_EVENT_NOTHING"))
	return lines


## "+30 Spirit Stones, +2 Reputation", or "" when nothing was gained.
static func amounts(changes: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in Balance.RESOURCES:
		var amount := int(changes.get(resource, 0))
		if amount != 0:
			parts.append("%+d %s" % [amount, resource_name(resource)])
	return ", ".join(parts)


## Amounts without signs, for gifts and trades: "10 Food, 5 Herbs".
static func quantities(changes: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in Balance.RESOURCES:
		var amount := absi(int(changes.get(resource, 0)))
		if amount != 0:
			parts.append("%d %s" % [amount, resource_name(resource)])
	return ", ".join(parts)


## "Talent 4 · Body 2 · Spirit 3 · Wit 5"
static func stats_line(d: Disciple) -> String:
	var stats: Array[String] = []
	for stat in Balance.STATS:
		stats.append("%s %d" % [t("STAT_" + stat.to_upper()), d.stat(stat)])
	return " · ".join(stats)


## "Quirks: loves noodles, scared of geese"
static func quirks_line(d: Disciple) -> String:
	var quirks: Array[String] = []
	for quirk in d.quirks:
		quirks.append(t(Quirks.text_key(quirk)))
	return t("UI_QUIRKS").format({"quirks": ", ".join(quirks)})


## A price: "8 Herbs, 10 Spirit Stones".
static func cost(price: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in Balance.RESOURCES:
		var amount := int(price.get(resource, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_name(resource)])
	return ", ".join(parts)


## One fact as a sentence. "rested" facts are grouped by [method evening].
static func describe(fact: Dictionary, sect: Sect, locale: String) -> String:
	var who := name_of(sect, String(fact.get("disciple", "")), locale)
	match String(fact["type"]):
		"trained":
			var key := "FACT_TRAINED_READY" if fact["ready"] else "FACT_TRAINED"
			return t(key).format({"name": who, "gain": fact["gain"]})
		"worked":
			var group := names(sect, fact["disciples"], locale)
			if int(fact["herbs"]) > 0:
				return t("FACT_WORKED_FIELD").format({"names": group, "food": fact["food"], "herbs": fact["herbs"]})
			return t("FACT_WORKED_FORAGE").format({"names": group, "food": fact["food"]})
		"rested":
			return t("FACT_RESTED").format({"names": who})
		"healed":
			return t("FACT_HEALED").format({"name": who})
		"mission_departed":
			return t("FACT_MISSION_DEPARTED").format({
				"names": names(sect, fact["team"], locale),
				"mission": mission_name(fact["mission"]),
				"day": fact["return_day"],
			})
		"mission_returned":
			var line := t("FACT_MISSION_" + String(fact["tier"]).to_upper()).format({
				"names": names(sect, fact["team"], locale),
				"mission": mission_name(fact["mission"]),
			})
			var gained := amounts(fact["rewards"])
			if gained != "":
				line += " " + t("FACT_REWARDS").format({"rewards": gained})
			return line
		"injured":
			return t("FACT_INJURED").format({"name": who, "days": fact["days"]})
		"lost_cultivation":
			return t("FACT_LOST_CULTIVATION").format({"name": who, "amount": fact["amount"]})
		"ate":
			return t("FACT_ATE").format({"food": fact["food"]})
		"hungry":
			return t("FACT_HUNGRY").format({"names": names(sect, fact["disciples"], locale)})
		"breakthrough":
			var line := t("FACT_BREAKTHROUGH").format({"name": who, "realm": realm_name(fact["realm"])})
			if fact["pill"] != "none":
				line += " " + t("FACT_PILL_USED").format({"pill": pill_name(fact["pill"])})
			return line
		"breakthrough_failed":
			var line := t("FACT_BREAKTHROUGH_FAILED").format({
				"name": who,
				"realm": realm_name(fact["realm"]),
				"lost": fact["lost"],
				"days": fact["days"],
				"effect": side_effect_name(fact["effect"]),
			})
			if fact["pill"] != "none":
				line += " " + t("FACT_PILL_USED").format({"pill": pill_name(fact["pill"])})
			return line
		"effect_ended":
			return t("FACT_EFFECT_ENDED").format({"name": who, "effect": side_effect_name(fact["effect"])})
		"studied":
			return t("FACT_STUDIED").format({"name": who, "gain": fact["gain"]})
		"learned":
			return t("FACT_LEARNED").format({"name": who, "technique": technique_name(fact["technique"]), "tier": fact["tier"]})
		"lost":
			return t("FACT_LOST").format({"name": who, "mission": mission_name(fact["mission"])})
		"left":
			return t("FACT_LEFT").format({"name": who, "mission": mission_name(fact["mission"])})
		"returned":
			return t("FACT_RETURNED_" + String(fact["from"]).to_upper()).format({"name": who})
		"recruited":
			return t("FACT_RECRUITED").format({"name": who})
		"rank_up":
			return t("FACT_RANK_UP").format({"rank": t("RANK_" + String(fact["rank"]).to_upper())})
		"brewed":
			return t("FACT_BREWED").format({"pill": pill_name(fact["pill"])})
		"cured":
			return t("FACT_CURED").format({"name": who})
		"found_item":
			return t("FACT_FOUND_ITEM").format({"mission": mission_name(fact["mission"]), "pill": pill_name(fact["item"])})
		"event":
			var event := {"problem": fact["problem"], "place": fact["place"], "disciples": fact["disciples"]}
			var line := t("FACT_EVENT").format({
				"title": t("EVENT_%s_TITLE" % String(fact["problem"]).to_upper()),
				"choice": event_choice(sect, event, String(fact["choice"]), locale),
			})
			if fact["result"] != "done":
				line += " " + t("EVENT_RESULT_" + String(fact["result"]).to_upper())
			return line
	return _describe_world(fact, sect, locale, who)


## The world's facts (M6): seasons, rivals, wars and generations.
static func _describe_world(fact: Dictionary, sect: Sect, locale: String, who: String) -> String:
	var rival := rival_name(String(fact.get("rival", "")))
	match String(fact["type"]):
		"season":
			return t("FACT_SEASON").format({"season": season_name(fact["season"]), "year": fact["year"]})
		"tournament":
			var matches: Array[String] = []
			for m: Dictionary in fact["matches"]:
				matches.append(t("MATCH_WON" if m["won"] else "MATCH_LOST").format({"rival": rival_name(m["rival"])}))
			var line := t("FACT_TOURNAMENT").format({
				"names": names(sect, fact["champions"], locale),
				"matches": t("MATCH_THEN").join(matches),
				"place": t("PLACE_WORD_%d" % int(fact["place"])),
			})
			var won := amounts(fact["rewards"])
			if won != "":
				line += " " + t("FACT_REWARDS").format({"rewards": won})
			return line
		"tournament_skipped":
			return t("FACT_TOURNAMENT_SKIPPED")
		"gift":
			return t("FACT_GIFT").format({"rival": rival, "gift": quantities({fact["resource"]: fact["amount"]})})
		"trade":
			return t("FACT_TRADE").format({"rival": rival, "gave": quantities(fact["gave"]), "got": quantities(fact["got"])})
		"alliance":
			return t("FACT_ALLIANCE").format({"rival": rival})
		"alliance_ended":
			return t("FACT_ALLIANCE_ENDED_" + String(fact["by"]).to_upper()).format({"rival": rival})
		"betrayal":
			var taken := gift_text({"stones": fact["stones"]}, String(fact["item"]))
			if taken == "":
				return t("FACT_BETRAYAL_EMPTY").format({"rival": rival})
			return t("FACT_BETRAYAL").format({"rival": rival, "taken": taken})
		"ally_gift":
			return t("FACT_ALLY_GIFT").format({"rival": rival, "stones": fact["stones"]})
		"war_declared":
			return t("FACT_WAR_DECLARED").format({"rival": rival, "day": fact["battle_day"]})
		"war_result":
			var defenders: Array = fact["defenders"]
			var key := ("FACT_WAR_WON" if fact["won"] else "FACT_WAR_LOST") if not defenders.is_empty() \
				else ("FACT_WAR_ALLIES_WON" if fact["won"] else "FACT_WAR_UNDEFENDED")
			return t(key).format({"names": names(sect, defenders, locale), "rival": rival, "land": fact["land"]})
		"peace":
			if int(fact["paid"]) > 0:
				return t("FACT_PEACE_PAID").format({"rival": rival, "stones": fact["paid"]})
			return t("FACT_PEACE_FREE").format({"rival": rival})
		"promoted":
			return t("FACT_PROMOTED").format({"name": who})
		"ascended":
			return t("FACT_ASCENDED").format({"name": who})
		"ascension_failed":
			return t("FACT_ASCENSION_FAILED").format({
				"name": who, "lost": fact["lost"], "days": fact["days"], "effect": side_effect_name(fact["effect"]),
			})
		"travel_left":
			return t("FACT_TRAVEL_LEFT").format({"name": who, "place": travel_place_name(fact["place"]), "day": fact["return_day"]})
		"travel_returned":
			var line := t("FACT_TRAVEL_RETURNED").format({"name": who, "place": travel_place_name(fact["place"])})
			if fact["souvenir"] != "none":
				line += " " + t("FACT_SOUVENIR").format({"pill": pill_name(fact["souvenir"])})
			return line
		"letter":
			var line := t("FACT_LETTER").format({"name": who, "place": travel_place_name(fact["place"])})
			var gift := gift_text(fact["gift"], String(fact["item"]))
			if gift != "":
				line += " " + t("FACT_LETTER_GIFT").format({"gift": gift})
			return line
	push_warning("No template for fact type %s" % fact["type"])
	return ""


## The evening report: every fact as a sentence (rests grouped into one), then
## one funny line about a disciple's quirk.
static func evening(report: DayReport, sect: Sect, locale: String) -> Array[String]:
	var lines: Array[String] = []
	for item in evening_items(report, sect, locale):
		lines.append(item["text"])
	return lines


## The evening's lines, each with an icon (see Icons): [{text, icon}].
static func evening_items(report: DayReport, sect: Sect, locale: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var rested: Array = []
	for fact in report.facts:
		if fact["type"] == "rested":
			rested.append(fact["disciple"])
		else:
			items.append({"text": describe(fact, sect, locale), "icon": fact_icon(fact)})
	if not rested.is_empty():
		items.append({"text": t("FACT_RESTED").format({"names": names(sect, rested, locale)}), "icon": "rest"})
	if not sect.disciples.is_empty():
		var d: Disciple = sect.disciples[(report.day * 7) % sect.disciples.size()]
		var quirk: String = d.quirks[report.day % d.quirks.size()]
		items.append({"text": t("EVENING_" + quirk.to_upper()).format({"name": d.display_name(locale)}), "icon": "chat"})
	return items


## The icon for a fact's line in the evening.
static func fact_icon(fact: Dictionary) -> String:
	var type := String(fact["type"])
	match type:
		"trained":
			return "train"
		"worked":
			return "work"
		"healed", "cured", "effect_ended":
			return "heal"
		"mission_departed", "mission_returned":
			return Icons.task_kind(String(fact.get("mission", "")))
		"injured", "lost_cultivation", "breakthrough_failed":
			return "mood_sad"
		"ate", "hungry":
			return "food"
		"breakthrough":
			return "breakthrough"
		"studied", "learned":
			return "study"
		"lost":
			return "mountain"
		"left", "returned":
			return "gate"
		"recruited":
			return "disciples"
		"rank_up":
			return "reputation"
		"brewed":
			return "brew"
		"found_item":
			return String(fact.get("item", "golden_pill"))
		"event":
			return "event"
		"season":
			return "today"
		"tournament", "tournament_skipped":
			return "reputation"
		"gift", "trade", "ally_gift":
			return "stones"
		"alliance", "alliance_ended", "betrayal":
			return "gate"
		"war_declared", "war_result", "peace", "travel_left", "travel_returned":
			return "mountain"
		"promoted":
			return "elder"
		"ascended", "ascension_failed":
			return "breakthrough"
		"letter":
			return "chat"
	return "sparkle"


## The morning report for the sect's current day.
static func morning(sect: Sect, locale: String) -> Array[String]:
	var lines: Array[String] = [t("MORNING_DAY").format({"day": sect.day})]
	if sect.day == 1:
		lines.append(t("MORNING_FIRST"))
	if sect.day <= 5:
		lines.append(t("ELDER_TIP_%d" % sect.day))
	for m in sect.missions:
		lines.append(t("MORNING_AWAY").format({
			"names": names(sect, m.team, locale),
			"mission": mission_name(m.mission),
			"day": m.return_day,
		}))
	for d in sect.disciples:
		var who := d.display_name(locale)
		if d.status == "lost":
			if d.return_day > 0:
				lines.append(t("MORNING_COMING_HOME").format({"name": who, "day": d.return_day}))
			else:
				lines.append(t("MORNING_LOST").format({"name": who}))
			continue
		if d.status == "left":
			lines.append(t("MORNING_LEFT").format({"name": who}))
			continue
		if d.status == "travel":
			lines.append(t("MORNING_TRAVELLING").format({
				"name": who, "place": travel_place_name(String(d.travel.get("place", ""))), "day": d.return_day,
			}))
			continue
		if d.status == "ascended":
			continue
		if d.is_injured():
			lines.append(t("MORNING_INJURED").format({"name": who, "days": d.injury_days()}))
		elif CultivationRules.can_break_through(d):
			lines.append(t("MORNING_READY").format({"name": who}))
		for effect in d.side_effects():
			lines.append(t("MORNING_EFFECT").format({"name": who, "effect": side_effect_name(effect.kind), "days": effect.days_left}))
	var hopeful := Recruiting.candidate(sect)
	if hopeful:
		lines.append(t("MORNING_CANDIDATE").format({"name": hopeful.display_name(locale)}))
	if int(sect.resources["food"]) == 0:
		lines.append(t("MORNING_NO_FOOD"))
	# Last night's AI story leaves a morning report and the disciples' decisions.
	var evening := sect.evening
	if evening.get("source") == "ai" and int(evening.get("day", 0)) == sect.day - 1:
		var report_text := String(evening.get("morning_report", ""))
		if report_text != "":
			lines.append(report_text)
		for decision: Dictionary in evening.get("decisions", []):
			lines.append(decision_line(sect, decision, locale))
	return lines


## "Lin decided to rest today: ‘My arms are noodles.’"
static func decision_line(sect: Sect, decision: Dictionary, locale: String) -> String:
	return t("MORNING_DECISION").format({
		"name": name_of(sect, String(decision["disciple"]), locale),
		"action": t("ACTION_" + String(decision["action"]).to_upper()),
		"reason": String(decision.get("reason", "")),
	})


## "Lin and Bao got along better: ‘Shared rice.’"
static func relationship_line(sect: Sect, change: Dictionary, locale: String) -> String:
	var key := "EVENING_RELATIONSHIP_UP" if int(change["change"]) > 0 else "EVENING_RELATIONSHIP_DOWN"
	return t(key).format({
		"a": name_of(sect, String(change["a"]), locale),
		"b": name_of(sect, String(change["b"]), locale),
		"reason": String(change.get("reason", "")),
	})


const CHAT_EXPRESSIONS: Array[String] = ["happy", "sad", "angry", "nervous", "proud", "thinking"]


## A written chat line for when the server can't answer: a disciple's quirk
## line or a line for their mood, or one of the Elder's lines.
static func offline_chat(d: Disciple, turn: int, locale: String) -> Dictionary:
	if d == null:
		return {"text": t("ELDER_OFFLINE_%d" % (turn % 3 + 1)), "expression": "thinking"}
	var expression: String = "happy" if d.mood >= 3 else ("sad" if d.mood <= -3 else ["nervous", "thinking", "proud"][turn % 3])
	if turn % 4 == 1:
		return {"text": talk_line(d, turn, locale), "expression": expression}
	var key := "CHAT_%s_%d" % [expression.to_upper(), turn % 2 + 1]
	return {"text": t(key).format({"name": d.display_name(locale)}), "expression": expression}


## A written free-time line from a disciple, chosen by their quirks.
static func talk_line(d: Disciple, day: int, locale: String) -> String:
	var quirk: String = d.quirks[absi(day + d.id.hash()) % d.quirks.size()]
	return t("TALK_" + quirk.to_upper()).format({"name": d.display_name(locale)})
