class_name DiscipleGenerator
extends RefCounted
## Makes new disciples from the sect's random generator. The same seed always
## makes the same disciples, because every roll goes through sect.rng in a
## fixed order.

const NAME_TRIES := 30
## Chance of a two-syllable given name ("Xiaohe") rather than one ("Ming").
const TWO_SYLLABLE_CHANCE := 0.6
## A talent at or above this gives one other stat +1.
const GIFTED_TALENT := 6


static func generate(sect: Sect) -> Disciple:
	var rng := sect.rng
	var d := Disciple.new()
	d.id = sect.new_disciple_id()

	var name := _unique_name(sect)
	d.name_en = name["en"]
	d.name_vi = name["vi"]
	d.pronouns = rng.pick(Balance.PRONOUNS)

	for stat in Balance.STATS:
		d.stats[stat] = rng.randi_range(Balance.STAT_ROLL_MIN, Balance.STAT_ROLL_MAX)
	var helped: String = rng.pick(["body", "spirit", "wit"])
	if d.stat("talent") >= GIFTED_TALENT:
		d.stats[helped] = d.stat(helped) + 1

	d.spirit_root = rng.pick(Balance.SPIRIT_ROOTS)
	d.quirks = _quirks(rng)
	d.realm = "qi_refining"
	d.progress = rng.randi_range(0, 20)
	d.clamp_values()
	return d


static func _unique_name(sect: Sect) -> Dictionary:
	var taken := {}
	for other in sect.disciples:
		taken[other.name_en] = true
	var name := {}
	for attempt in NAME_TRIES:
		var surname := sect.rng.randi_range(0, Names.SURNAMES.size() - 1)
		var given: Array[int] = [sect.rng.randi_range(0, Names.GIVEN.size() - 1)]
		if sect.rng.chance(TWO_SYLLABLE_CHANCE):
			var second := sect.rng.randi_range(0, Names.GIVEN.size() - 2)
			given.append(second if second < given[0] else second + 1)
		name = Names.compose(surname, given)
		if not taken.has(name["en"]):
			return name
	return name  # Thousands of combinations; a repeat after 30 tries is harmless.


static func _quirks(rng: SimRng) -> Array[String]:
	var ids := Quirks.ids()
	var first: String = rng.pick(ids)
	var partners := ids.filter(func(q: String) -> bool: return Quirks.compatible(first, q))
	var second: String = rng.pick(partners)
	var picked: Array[String] = [first, second]
	return picked
