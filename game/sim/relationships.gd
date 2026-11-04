class_name Relationships
extends RefCounted
## How each pair of disciples gets along, from Balance.RELATIONSHIP_MIN
## (rivals) to RELATIONSHIP_MAX (close friends). The evening story suggests
## small changes; these rules decide how much actually changes.


## The key for a pair, the same whichever way round: "d1|d2".
static func key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func score(sect: Sect, a: String, b: String) -> int:
	return int(sect.relationships.get(key(a, b), 0))


## Moves a pair by at most Balance.RELATIONSHIP_STEP, within the limits.
## Returns how much it actually moved.
static func change(sect: Sect, a: String, b: String, delta: int) -> int:
	if a == b or sect.disciple(a) == null or sect.disciple(b) == null:
		return 0
	var before := score(sect, a, b)
	var step := clampi(delta, -Balance.RELATIONSHIP_STEP, Balance.RELATIONSHIP_STEP)
	var after := clampi(before + step, Balance.RELATIONSHIP_MIN, Balance.RELATIONSHIP_MAX)
	if after == 0:
		sect.relationships.erase(key(a, b))
	else:
		sect.relationships[key(a, b)] = after
	return after - before


## Every pair that isn't neutral, for the evening request: [{a, b, score}].
static func pairs(sect: Sect) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys := sect.relationships.keys()
	keys.sort()
	for pair: String in keys:
		var ids := pair.split("|")
		if sect.disciple(ids[0]) and sect.disciple(ids[1]):
			out.append({"a": ids[0], "b": ids[1], "score": int(sect.relationships[pair])})
	return out
