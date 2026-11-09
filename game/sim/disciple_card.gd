class_name DiscipleCard
extends RefCounted
## A disciple as the AI gateway sees them: exactly the fields of the server's
## DiscipleCardSchema (server/supabase/functions/_shared/schemas.ts). A GUT
## test and a Deno test both check game/tests/fixtures/disciple_card.json, so
## the two sides can't drift apart.


## [param sect], when given, adds where the disciple is (M5). Status, effects
## and technique are left out when there is nothing to say, so most cards
## stay the same from day to day (and the chat prompt's cache keeps hitting).
static func build(d: Disciple, locale: String, sect: Sect = null) -> Dictionary:
	var card := {
		"id": d.id,
		"name": d.display_name(locale),
		"pronouns": d.pronouns,
		"quirks": d.quirks.duplicate(),
		"spirit_root": d.spirit_root,
		"realm": d.realm,
		"mood": clampi(d.mood, Balance.MOOD_MIN, Balance.MOOD_MAX),
		"loyalty": clampi(d.loyalty, Balance.LOYALTY_MIN, Balance.LOYALTY_MAX),
	}
	var status := sect.status_of(d.id) if sect else d.status
	if status != "home":
		card["status"] = status
	var effects: Array[String] = []
	for effect in d.effects:
		if effect.days_left > 0 and not effect.kind in effects:
			effects.append(effect.kind)
	if not effects.is_empty():
		card["effects"] = effects
	if d.technique > 0:
		card["technique"] = d.technique
	return card
