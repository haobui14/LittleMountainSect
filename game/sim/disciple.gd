class_name Disciple
extends RefCounted
## One disciple: who they are (name, quirks, spirit root) and how they are
## doing (stats, cultivation, Mood, Loyalty, injuries). Rules change these
## values; Claude never does.

var id: String
var name_en: String
var name_vi: String
var pronouns: String = "they"
## talent, body, spirit and wit, each from Balance.STAT_MIN to STAT_MAX.
var stats: Dictionary = {"talent": 1, "body": 1, "spirit": 1, "wit": 1}
var spirit_root: String = "earth"
var quirks: Array[String] = []
var realm: String = "qi_refining"
## Cultivation progress toward the next realm, 0 to Balance.PROGRESS_MAX.
var progress: int = 0
var mood: int = Balance.START_MOOD
var loyalty: int = Balance.START_LOYALTY
var effects: Array[StatusEffect] = []
## Free time allows one chat bonus per day.
var talked_today: bool = false


## The disciple's name in the given language ("en" or "vi").
func display_name(locale: String) -> String:
	return name_vi if locale == "vi" else name_en


func stat(name: String) -> int:
	return int(stats[name])


func realm_index() -> int:
	return Balance.REALMS.find(realm)


func injury_days() -> int:
	for effect in effects:
		if effect.kind == "injured":
			return effect.days_left
	return 0


func is_injured() -> bool:
	return injury_days() > 0


## Adds an injury, or extends the current one if it is shorter.
func injure(days: int) -> void:
	for effect in effects:
		if effect.kind == "injured":
			effect.days_left = maxi(effect.days_left, days)
			return
	effects.append(StatusEffect.new("injured", days))


## Keeps every value inside its limits. Rules call this after each change.
func clamp_values() -> void:
	for name in Balance.STATS:
		stats[name] = clampi(int(stats[name]), Balance.STAT_MIN, Balance.STAT_MAX)
	progress = clampi(progress, 0, Balance.PROGRESS_MAX)
	mood = clampi(mood, Balance.MOOD_MIN, Balance.MOOD_MAX)
	loyalty = clampi(loyalty, Balance.LOYALTY_MIN, Balance.LOYALTY_MAX)
	effects.assign(effects.filter(func(e: StatusEffect) -> bool: return e.days_left > 0))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_en": name_en,
		"name_vi": name_vi,
		"pronouns": pronouns,
		"stats": stats.duplicate(),
		"spirit_root": spirit_root,
		"quirks": quirks.duplicate(),
		"realm": realm,
		"progress": progress,
		"mood": mood,
		"loyalty": loyalty,
		"effects": effects.map(func(e: StatusEffect) -> Dictionary: return e.to_dict()),
		"talked_today": talked_today,
	}


static func from_dict(data: Dictionary) -> Disciple:
	var d := Disciple.new()
	d.id = String(data["id"])
	d.name_en = String(data["name_en"])
	d.name_vi = String(data["name_vi"])
	d.pronouns = String(data["pronouns"])
	for name in Balance.STATS:
		d.stats[name] = int(data["stats"][name])
	d.spirit_root = String(data["spirit_root"])
	d.quirks.assign(Array(data["quirks"]).map(func(q: Variant) -> String: return String(q)))
	d.realm = String(data["realm"])
	d.progress = int(data["progress"])
	d.mood = int(data["mood"])
	d.loyalty = int(data["loyalty"])
	for effect in data["effects"]:
		d.effects.append(StatusEffect.from_dict(effect))
	d.talked_today = bool(data["talked_today"])
	return d
