class_name RivalCatalog
extends RefCounted
## The three rival sects (M6). Rules use these numbers; the words for each
## sect are in strings.csv (RIVAL_<ID>) and the server's cast.ts. The ids
## must match the server's RIVALS; the contract test checks them.
##
## attitude   where its Attitude starts, and drifts back to
## favourite  the gift it likes best
## strength   its tournament team in the first season (Balance.RIVAL_GROWTH
##            adds to it every season)
## trades     the deals it offers, one per trading period, in turn

const RIVALS := {
	"iron_frog": {
		"attitude": -20,
		"favourite": "food",
		"strength": 16.0,
		"trades": [
			{"give": {"food": 15}, "get": {"stones": 30}},
			{"give": {"food": 10}, "get": {"herbs": 12}},
		],
	},
	"moonlit_tea": {
		"attitude": 10,
		"favourite": "herbs",
		"strength": 15.0,
		"trades": [
			{"give": {"herbs": 15}, "get": {"stones": 30}},
			{"give": {"herbs": 10}, "get": {"food": 15}},
		],
	},
	"perfect_hair": {
		"attitude": 0,
		"favourite": "stones",
		"strength": 17.0,
		"trades": [
			{"give": {"stones": 30}, "get": {"herbs": 20}},
			{"give": {"stones": 25}, "get": {"food": 25}},
		],
	},
}


static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(RIVALS.keys())
	return out
