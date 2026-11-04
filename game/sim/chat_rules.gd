class_name ChatRules
extends RefCounted
## What a chat reply may change. The server already checks every reply; these
## rules decide again, because code decides results: Mood moves at most
## Balance.CHAT_MOOD_STEP per reply and CHAT_MOOD_PER_DAY in total per day,
## and a wished-for action is only a hint for the plan.

const MAX_RECENT := 6
const MAX_MESSAGE_CHARS := 280


## The request body for the gateway. [param recent] is [{from, text}] with
## from "player" or "character", oldest first.
static func request(d: Disciple, recent: Array, message: String, locale: String) -> Dictionary:
	var body := {
		"kind": "chat" if d else "elder",
		"locale": locale,
		"recent": recent.slice(-MAX_RECENT),
		"message": message.strip_edges().left(MAX_MESSAGE_CHARS),
	}
	if d:
		body["disciple"] = DiscipleCard.build(d, locale)
	return body


## Applies a chat reply ({mood_change, wants_action, safety}) to a disciple,
## plus the once-a-day talk bonus. Returns {"bonus", "mood"}: the Mood each
## part actually added.
static func apply(sect: Sect, d: Disciple, reply: Dictionary) -> Dictionary:
	var bonus := FreeTime.talk(d)
	var change := 0
	if text_of(reply.get("safety"), "ok") == "ok":
		var raw: Variant = reply.get("mood_change")
		var step := clampi(int(raw) if raw is int or raw is float else 0, -Balance.CHAT_MOOD_STEP, Balance.CHAT_MOOD_STEP)
		var room_up := Balance.CHAT_MOOD_PER_DAY - d.chat_mood_today
		var room_down := -Balance.CHAT_MOOD_PER_DAY - d.chat_mood_today
		change = clampi(step, room_down, room_up)
		var before := d.mood
		d.mood += change
		d.clamp_values()
		change = d.mood - before
		d.chat_mood_today += change
		var wants := text_of(reply.get("wants_action"))
		if Balance.ACTION_TASK.has(wants):
			d.wants = wants
			d.wants_day = sect.day
	return {"bonus": bonus, "mood": change}


## The plan task a disciple's chat wish points to, or "" when there is none
## (wishes last for the day after they were made).
static func wished_task(sect: Sect, d: Disciple) -> String:
	if d.wants == "" or d.wants_day < sect.day - 1:
		return ""
	return String(Balance.ACTION_TASK.get(d.wants, ""))


## A reply value as text: JSON null (or anything that isn't text) becomes the default.
static func text_of(value: Variant, default: String = "") -> String:
	return value if value is String else default
