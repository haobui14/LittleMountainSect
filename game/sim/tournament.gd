class_name Tournament
extends RefCounted
## The tournament on each season's last day (M6). In the morning the Sect
## Master picks up to Balance.CHAMPIONS_MAX champions, or sits it out. The
## rules draw a bracket of the four sects, then play the semi-finals, the
## final and the match for third. Champions spend the day at the
## tournament. Claude tells it in the evening story.
##
## sect.tournament is {} or {day, resolved, skipped, champions, place,
## matches: [{rival, won}], rewards}. It is cleared the next night.


## Opens today's tournament at night, when today is a tournament day.
static func night(sect: Sect) -> void:
	sect.tournament = {}
	if Seasons.is_tournament_day(sect.day):
		sect.tournament = {
			"day": sect.day,
			"resolved": false,
			"skipped": false,
			"champions": [],
			"place": 0,
			"matches": [],
			"rewards": {},
		}


static func pending(sect: Sect) -> bool:
	return not sect.tournament.is_empty() and not bool(sect.tournament["resolved"])


## Who may fight: disciples at home, not injured, and not Elders.
static func eligible(sect: Sect) -> Array[Disciple]:
	return sect.available_disciples()


## One champion's strength: Talent, Body and Spirit, plus realm, technique
## and Mood. Hiccups don't help.
static func champion_power(d: Disciple) -> float:
	var average := (d.stat("talent") + d.stat("body") + d.stat("spirit")) / 3.0
	var power := average + d.realm_index() * Balance.REALM_POWER + d.technique * Balance.TECHNIQUE_POWER \
		+ d.mood * Balance.MOOD_POWER
	return maxf(0.0, power * d.effect_factor("mission"))


static func power(sect: Sect, ids: Array) -> float:
	var total := 0.0
	for id: String in ids:
		total += champion_power(sect.disciple(id))
	return total


## A rival sect's team this season.
static func rival_strength(sect: Sect, rival: String) -> float:
	return float(RivalCatalog.RIVALS[rival]["strength"]) + Balance.RIVAL_GROWTH * (Seasons.number(sect.day) - 1)


static func win_chance(ours: float, theirs: float) -> float:
	var p := 1.0 / (1.0 + exp(-(ours - theirs) / Balance.MATCH_SCALE))
	return clampf(p, Balance.MATCH_MIN, Balance.MATCH_MAX)


## The chance of each place (index 1 to 4) for these champions, over every
## draw: a guide for the morning card.
static func place_chances(sect: Sect, ids: Array) -> Array[float]:
	var ours := power(sect, ids)
	var rivals := RivalCatalog.ids()
	var out: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	for opponent in rivals:
		var others := rivals.filter(func(r: String) -> bool: return r != opponent)
		var x: String = others[0]
		var y: String = others[1]
		var x_wins := win_chance(rival_strength(sect, x), rival_strength(sect, y))
		var semi := win_chance(ours, rival_strength(sect, opponent))
		var final_win := x_wins * win_chance(ours, rival_strength(sect, x)) \
			+ (1.0 - x_wins) * win_chance(ours, rival_strength(sect, y))
		var third_win := x_wins * win_chance(ours, rival_strength(sect, y)) \
			+ (1.0 - x_wins) * win_chance(ours, rival_strength(sect, x))
		var share := 1.0 / rivals.size()
		out[1] += share * semi * final_win
		out[2] += share * semi * (1.0 - final_win)
		out[3] += share * (1.0 - semi) * third_win
		out[4] += share * (1.0 - semi) * (1.0 - third_win)
	return out


## The most likely place for these champions.
static func likely_place(sect: Sect, ids: Array) -> int:
	var chances := place_chances(sect, ids)
	var best := 4
	for place in range(1, 5):
		if chances[place] > chances[best]:
			best = place
	return best


## Error codes for a choice of champions, empty when it is fine.
static func check(sect: Sect, ids: Array) -> Array[String]:
	var errors: Array[String] = []
	if not pending(sect):
		errors.append("no_tournament")
	if ids.is_empty() or ids.size() > Balance.CHAMPIONS_MAX:
		errors.append("team_size")
	var free := eligible(sect).map(func(d: Disciple) -> String: return d.id)
	var seen := {}
	for id: String in ids:
		if not id in free or seen.has(id):
			errors.append("not_eligible:" + id)
		seen[id] = true
	return errors


## Plays the tournament with these champions. Returns the result (also kept
## in sect.tournament), or {} when the choice isn't possible.
static func enter(sect: Sect, ids: Array) -> Dictionary:
	if not check(sect, ids).is_empty():
		return {}
	var champions: Array[String] = []
	champions.assign(ids)
	var ours := power(sect, champions)
	var rivals := RivalCatalog.ids()
	var opponent: String = sect.rng.pick(rivals)
	var others := rivals.filter(func(r: String) -> bool: return r != opponent)
	var x: String = others[0]
	var y: String = others[1]
	var x_won := sect.rng.chance(win_chance(rival_strength(sect, x), rival_strength(sect, y)))
	var winner := x if x_won else y
	var loser := y if x_won else x

	var matches: Array[Dictionary] = []
	var semi := sect.rng.chance(win_chance(ours, rival_strength(sect, opponent)))
	matches.append({"rival": opponent, "won": semi})
	var next := winner if semi else loser
	var second := sect.rng.chance(win_chance(ours, rival_strength(sect, next)))
	matches.append({"rival": next, "won": second})
	var place := (1 if second else 2) if semi else (3 if second else 4)

	var rewards := {}
	var prize: Dictionary = Balance.TOURNAMENT_REWARDS[place]
	for resource: String in prize:
		rewards[resource] = sect.add_resource(resource, int(prize[resource]))
	for id in champions:
		var d := sect.disciple(id)
		d.mood += Balance.TOURNAMENT_PODIUM_MOOD if place <= 3 else Balance.TOURNAMENT_LAST_MOOD
		d.clamp_values()
	for m in matches:
		var rival := String(m["rival"])
		if m["won"]:
			Rivals.change_attitude(sect, rival, Balance.TOURNAMENT_BEAT_ALLY_ATTITUDE if Rivals.is_ally(sect, rival) else Balance.TOURNAMENT_BEAT_ATTITUDE)
		else:
			Rivals.change_attitude(sect, rival, Balance.TOURNAMENT_LOST_ATTITUDE)

	var t := sect.tournament
	t["resolved"] = true
	t["champions"] = Array(champions)
	t["place"] = place
	t["matches"] = Array(matches)
	t["rewards"] = rewards
	sect.pending_facts.append({
		"type": "tournament",
		"place": place,
		"champions": champions.duplicate(),
		"matches": matches.duplicate(true),
		"rewards": rewards.duplicate(),
	})
	sect.chronicle_add("tournament", {"place": place, "season": Seasons.season(sect.day), "year": Seasons.year(sect.day)})
	Wars.check_call_off(sect)
	return t


## The sect sits this one out; the other sects notice.
static func skip(sect: Sect) -> bool:
	if not pending(sect):
		return false
	sect.add_resource("reputation", Balance.TOURNAMENT_SKIP_REPUTATION)
	sect.tournament["resolved"] = true
	sect.tournament["skipped"] = true
	sect.pending_facts.append({"type": "tournament_skipped"})
	return true
