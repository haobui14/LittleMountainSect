class_name CultivationRules
extends RefCounted
## Breakthroughs, the side effects of a failed one, and study in the Library.
##
## A disciple at full progress may try to break through to the next realm
## (the "breakthrough" home task). The chance comes from the realm, Talent and
## Spirit, the Training Yard, Mood and the best breakthrough pill in stock,
## which is used up by the attempt. Failure costs progress and adds a timed,
## funny side effect; nobody is ever hurt by it.


static func can_break_through(d: Disciple) -> bool:
	return d.progress >= Balance.PROGRESS_MAX \
		and d.realm_index() < Balance.REALMS.size() - 1 \
		and not d.is_injured()


## The breakthrough pill an attempt would use: the strongest in stock, or "none".
static func best_pill(sect: Sect) -> String:
	for pill: String in Balance.PILL_BREAKTHROUGH:
		if sect.item(pill) > 0:
			return pill
	return "none"


## The chance (0 to 1) that [param d] breaks through with [param pill].
static func chance(sect: Sect, d: Disciple, pill: String = "") -> float:
	if pill == "":
		pill = best_pill(sect)
	var realm := clampi(d.realm_index(), 0, Balance.BREAKTHROUGH_BASE.size() - 1)
	var value := Balance.BREAKTHROUGH_BASE[realm] \
		+ Balance.BREAKTHROUGH_STAT * (d.stat("talent") + d.stat("spirit")) \
		+ Balance.BREAKTHROUGH_YARD * sect.level("training_yard") \
		+ Balance.BREAKTHROUGH_MOOD * d.mood \
		+ float(Balance.PILL_BREAKTHROUGH.get(pill, 0.0))
	return clampf(value, Balance.BREAKTHROUGH_MIN, Balance.BREAKTHROUGH_MAX)


## Tries to break through. Returns true on success. Adds a "breakthrough" or
## "breakthrough_failed" fact.
static func attempt(sect: Sect, d: Disciple, report: DayReport) -> bool:
	var pill := best_pill(sect)
	var odds := chance(sect, d, pill)
	if pill != "none":
		sect.add_item(pill, -1)
	var target: String = Balance.REALMS[d.realm_index() + 1]
	if sect.rng.chance(odds):
		d.realm = target
		d.progress = 0
		d.mood += Balance.BREAKTHROUGH_MOOD_GAIN
		d.loyalty += Balance.BREAKTHROUGH_LOYALTY_GAIN
		d.clamp_values()
		report.add("breakthrough", {"disciple": d.id, "realm": target, "pill": pill})
		sect.chronicle_add("breakthrough", {"disciple": d.id, "realm": target})
		return true
	var lost := mini(d.progress, Balance.BREAKTHROUGH_FAIL_PROGRESS)
	d.progress -= lost
	d.mood += Balance.BREAKTHROUGH_FAIL_MOOD
	var effect: String = sect.rng.pick(Balance.SIDE_EFFECTS)
	var days := sect.rng.randi_range(Balance.SIDE_EFFECT_DAYS[0], Balance.SIDE_EFFECT_DAYS[1])
	d.add_effect(effect, days)
	d.clamp_values()
	report.add("breakthrough_failed", {
		"disciple": d.id,
		"realm": target,
		"pill": pill,
		"effect": effect,
		"days": days,
		"lost": lost,
	})
	return false


## Side effects wear off a day at a time; injuries heal only by resting.
static func tick_effects(d: Disciple, report: DayReport) -> void:
	for effect in d.side_effects():
		effect.days_left -= 1
		if effect.days_left <= 0:
			report.add("effect_ended", {"disciple": d.id, "effect": effect.kind})
	d.clamp_values()


## Whether the Library can still teach [param d] something.
static func can_study(sect: Sect, d: Disciple) -> bool:
	return sect.level("library") >= 1 and d.technique < mini(sect.level("library"), Balance.TECHNIQUE_MAX)


## A day of study (Elders help). At Balance.STUDY_MAX the disciple learns
## the next level of their root's technique.
static func study(sect: Sect, d: Disciple, report: DayReport) -> void:
	var gain := mini(Balance.STUDY_BASE + d.stat("wit") + Generations.study_bonus(sect), Balance.STUDY_MAX - d.study)
	d.study += gain
	report.add("studied", {"disciple": d.id, "gain": gain})
	if d.study >= Balance.STUDY_MAX and can_study(sect, d):
		d.technique += 1
		d.study = 0
		report.add("learned", {"disciple": d.id, "technique": technique_of(d), "tier": d.technique})
	d.clamp_values()


## The technique a disciple's spirit root teaches.
static func technique_of(d: Disciple) -> String:
	return Balance.TECHNIQUES[maxi(0, Balance.SPIRIT_ROOTS.find(d.spirit_root))]
