class_name TravelCatalog
extends RefCounted
## Where travelling disciples go (M6). The ids must match the server's
## TRAVEL_PLACES (server/supabase/functions/_shared/travel.ts), which says
## what each place is like for Claude; a contract test checks them. Without
## Claude, a letter is one of the written ones in strings.csv:
## LETTER_<PLACE>_1 and LETTER_<PLACE>_2.

const PLACES: Array[String] = [
	"eastern_sea",
	"noodle_town",
	"singing_sands",
	"snow_peaks",
	"capital_market",
	"bamboo_sea",
	"cloud_temple",
	"frog_swamp",
]
## Written letters per place.
const LETTERS_PER_PLACE := 2
