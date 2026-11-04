class_name Quirks
extends RefCounted
## The quirk catalog. Ids must match QUIRKS in
## server/supabase/functions/_shared/cast.ts (a Deno contract test checks
## them); the words live in strings.csv as QUIRK_<ID>.
##
## Tags keep a disciple's two quirks from contradicting each other: two quirks
## that share a tag never go together.

const TAGS := {
	"afraid_of_chickens": ["fear"],
	"chosen_one": ["ego"],
	"always_hungry": ["food"],
	"talks_to_sword": ["weapon"],
	"overly_polite": ["manners"],
	"secret_poet": ["art"],
	"lazy_genius": ["sleep", "work_ethic"],
	"gossip": ["talk"],
	"competitive": ["rivalry"],
	"clumsy_alchemist": ["alchemy"],
	"herb_whisperer": ["plants"],
	"humble_bragger": ["ego", "honesty"],
	"stone_counter": ["money"],
	"dramatic": ["drama"],
	"grudge_keeper": ["grudge"],
	"superstitious": ["omens"],
	"cloud_watcher": ["omens"],
	"stray_collector": ["animals"],
	"honest_to_a_fault": ["honesty"],
	"early_riser": ["sleep"],
}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id in TAGS:
		out.append(id)
	return out


## True when the two quirks share no tag.
static func compatible(a: String, b: String) -> bool:
	if a == b:
		return false
	for tag in TAGS[a]:
		if tag in TAGS[b]:
			return false
	return true


static func text_key(id: String) -> String:
	return "QUIRK_" + id.to_upper()
