class_name ReportText
extends RefCounted
## Writes the rules' facts (see DayReport) as sentences, from tr() templates in
## strings.csv. These written reports are the game's text whenever there is no
## AI story, and the only text in M3. Templates use {placeholders}.


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func name_of(sect: Sect, id: String, locale: String) -> String:
	var d := sect.disciple(id)
	return d.display_name(locale) if d else id


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


## "+30 Spirit Stones, +2 Reputation", or "" when nothing was gained.
static func amounts(changes: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in Balance.RESOURCES:
		var amount := int(changes.get(resource, 0))
		if amount != 0:
			parts.append("%+d %s" % [amount, resource_name(resource)])
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
	push_warning("No template for fact type %s" % fact["type"])
	return ""


## The evening report: every fact as a sentence (rests grouped into one), then
## one funny line about a disciple's quirk.
static func evening(report: DayReport, sect: Sect, locale: String) -> Array[String]:
	var lines: Array[String] = []
	var rested: Array = []
	for fact in report.facts:
		if fact["type"] == "rested":
			rested.append(fact["disciple"])
		else:
			lines.append(describe(fact, sect, locale))
	if not rested.is_empty():
		lines.append(t("FACT_RESTED").format({"names": names(sect, rested, locale)}))
	if not sect.disciples.is_empty():
		var d: Disciple = sect.disciples[(report.day * 7) % sect.disciples.size()]
		var quirk: String = d.quirks[report.day % d.quirks.size()]
		lines.append(t("EVENING_" + quirk.to_upper()).format({"name": d.display_name(locale)}))
	return lines


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
		if d.is_injured():
			lines.append(t("MORNING_INJURED").format({"name": d.display_name(locale), "days": d.injury_days()}))
		elif d.progress >= Balance.PROGRESS_MAX:
			lines.append(t("MORNING_READY").format({"name": d.display_name(locale)}))
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
