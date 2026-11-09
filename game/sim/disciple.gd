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
## Mood moved by chat replies today; capped by Balance.CHAT_MOOD_PER_DAY.
var chat_mood_today: int = 0
## An action the disciple said they want in chat (a hint for the plan), and
## the day they said it; "" when none.
var wants: String = ""
var wants_day: int = 0
## "home", or "lost" (on the mountain, until a rescue brings them home) or
## "left" (the sect, for a while). Missions are tracked by the sect.
var status: String = "home"
## The day a lost or left disciple comes home (0: not decided yet).
var return_day: int = 0
## Level of their spirit root's technique (0 to Balance.TECHNIQUE_MAX), and
## study toward the next level (0 to Balance.STUDY_MAX).
var technique: int = 0
var study: int = 0


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


func has_effect(effect_kind: String) -> bool:
	return effects.any(func(e: StatusEffect) -> bool: return e.kind == effect_kind and e.days_left > 0)


func side_effects() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	out.assign(effects.filter(func(e: StatusEffect) -> bool: return e.is_side_effect()))
	return out


## Adds a side effect, or extends the same one if it is shorter.
func add_effect(effect_kind: String, days: int) -> void:
	for effect in effects:
		if effect.kind == effect_kind:
			effect.days_left = maxi(effect.days_left, days)
			return
	effects.append(StatusEffect.new(effect_kind, days))


## The product of every active side effect's multiplier for one rule
## ("mission", "work", "train" or "rest"); 1.0 when none applies.
func effect_factor(rule: String) -> float:
	var factor := 1.0
	for effect in effects:
		factor *= float(Balance.SIDE_EFFECT_RULES.get(effect.kind, {}).get(rule, 1.0))
	return factor


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
	technique = clampi(technique, 0, Balance.TECHNIQUE_MAX)
	study = clampi(study, 0, Balance.STUDY_MAX)
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
		"chat_mood_today": chat_mood_today,
		"wants": wants,
		"wants_day": wants_day,
		"status": status,
		"return_day": return_day,
		"technique": technique,
		"study": study,
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
	d.chat_mood_today = int(data["chat_mood_today"])
	d.wants = String(data["wants"])
	d.wants_day = int(data["wants_day"])
	d.status = String(data["status"])
	d.return_day = int(data["return_day"])
	d.technique = int(data["technique"])
	d.study = int(data["study"])
	return d
