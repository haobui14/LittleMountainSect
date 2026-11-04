class_name DiscipleCard
extends RefCounted
## A disciple as the AI gateway sees them: exactly the fields of the server's
## DiscipleCardSchema (server/supabase/functions/_shared/schemas.ts). A GUT
## test and a Deno test both check game/tests/fixtures/disciple_card.json, so
## the two sides can't drift apart.


static func build(d: Disciple, locale: String) -> Dictionary:
	return {
		"id": d.id,
		"name": d.display_name(locale),
		"pronouns": d.pronouns,
		"quirks": d.quirks.duplicate(),
		"spirit_root": d.spirit_root,
		"realm": d.realm,
		"mood": clampi(d.mood, Balance.MOOD_MIN, Balance.MOOD_MAX),
		"loyalty": clampi(d.loyalty, Balance.LOYALTY_MIN, Balance.LOYALTY_MAX),
	}
