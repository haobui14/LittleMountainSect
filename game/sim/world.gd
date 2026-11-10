class_name World
extends RefCounted
## The world beyond the mountain (M6), tied together: what happens each
## night, and the morning decisions the day plan waits for.


## Runs at night, after the day number goes up (DayResolver step 10).
static func night(sect: Sect) -> void:
	Rivals.night(sect)
	Seasons.night(sect)
	Wars.night(sect)
	Tournament.night(sect)
	Generations.roll_letters(sect)
	Generations.roll_travel(sect)


## The morning decisions still open, in screen order: "event",
## "tournament", "battle" and "travel". The day plan waits for all of them.
static func pending(sect: Sect) -> Array[String]:
	var out: Array[String] = []
	if EventRules.pending(sect):
		out.append("event")
	if Tournament.pending(sect):
		out.append("tournament")
	if Wars.pending(sect):
		out.append("battle")
	if Generations.travel_pending(sect):
		out.append("travel")
	return out


## For a day run with a decision still open (tools and tests; the game waits
## for the player): the sect sits the tournament out and faces the battle
## with nobody.
static func settle_undecided(sect: Sect) -> void:
	if Tournament.pending(sect):
		Tournament.skip(sect)
	if Wars.pending(sect):
		Wars.defend(sect, [])
