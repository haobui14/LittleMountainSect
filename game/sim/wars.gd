class_name Wars
extends RefCounted
## Wars over land (M6). A hostile rival that isn't an ally may declare war
## at night; the battle comes a few days later. Gifts that warm it up call
## the war off; the Sect Master can also pay for peace. On the battle
## morning the Sect Master picks up to Balance.DEFENDERS_MAX defenders, and
## allies fight beside them. Nobody ever dies: the worst is a light injury.
##
## sect.war is {} or {rival, declared_day, battle_day, resolved, defenders,
## won}. A finished war is cleared the next night.


static func active(sect: Sect) -> bool:
	return not sect.war.is_empty() and not bool(sect.war["resolved"])


static func at_war_with(sect: Sect, rival: String) -> bool:
	return active(sect) and sect.war["rival"] == rival


## The battle is today and the Sect Master hasn't decided yet.
static func pending(sect: Sect) -> bool:
	return active(sect) and sect.day >= int(sect.war["battle_day"])


## At night: a finished war is cleared, and a hostile rival may declare war.
static func night(sect: Sect) -> void:
	if not sect.war.is_empty() and bool(sect.war["resolved"]):
		sect.war = {}
	if not sect.war.is_empty() or sect.day - sect.last_war_day < Balance.WAR_COOLDOWN:
		return
	for rival in RivalCatalog.ids():
		if Rivals.is_ally(sect, rival) or Rivals.attitude(sect, rival) > Balance.WAR_ATTITUDE:
			continue
		if not sect.rng.chance(Balance.WAR_CHANCE):
			continue
		sect.war = {
			"rival": rival,
			"declared_day": sect.day,
			"battle_day": sect.day + Balance.WAR_WARNING_DAYS,
			"resolved": false,
			"defenders": [],
			"won": false,
		}
		sect.last_war_day = sect.day
		sect.pending_facts.append({"type": "war_declared", "rival": rival, "battle_day": sect.day + Balance.WAR_WARNING_DAYS})
		sect.chronicle_add("war_declared", {"rival": rival})
		return


## Before the battle, a rival warmed up enough calls the war off.
static func check_call_off(sect: Sect) -> void:
	if not active(sect) or sect.day >= int(sect.war["battle_day"]):
		return
	var rival := String(sect.war["rival"])
	if int(sect.rival(rival)["attitude"]) > Balance.WAR_CALL_OFF_ATTITUDE:
		_end(sect)
		sect.pending_facts.append({"type": "peace", "rival": rival, "paid": 0})
		sect.chronicle_add("peace", {"rival": rival, "paid": 0})


static func peace_cost(sect: Sect) -> int:
	return Balance.PEACE_BASE + Balance.PEACE_PER_HILL * sect.land


static func can_make_peace(sect: Sect) -> bool:
	return active(sect) and int(sect.resources["stones"]) >= peace_cost(sect)


## Pays for peace: the rival goes from hostile to merely cold.
static func make_peace(sect: Sect) -> bool:
	if not can_make_peace(sect):
		return false
	var rival := String(sect.war["rival"])
	var paid := -sect.add_resource("stones", -peace_cost(sect))
	_end(sect)
	sect.rival(rival)["attitude"] = Balance.PEACE_ATTITUDE
	sect.pending_facts.append({"type": "peace", "rival": rival, "paid": paid})
	sect.chronicle_add("peace", {"rival": rival, "paid": paid})
	return true


static func _end(sect: Sect) -> void:
	sect.war = {}


## Who may defend: disciples at home, not injured, not Elders, and not
## already a champion today.
static func eligible(sect: Sect) -> Array[Disciple]:
	return sect.available_disciples()


## The defenders' strength, with each ally's help.
static func defense(sect: Sect, ids: Array) -> float:
	var total := Tournament.power(sect, ids)
	for rival in RivalCatalog.ids():
		if Rivals.is_ally(sect, rival):
			total += Tournament.rival_strength(sect, rival) * Balance.ALLY_WAR_SHARE
	return total


static func attack(sect: Sect) -> float:
	return Tournament.rival_strength(sect, String(sect.war["rival"])) * Balance.WAR_STRENGTH


## The chance these defenders win today's battle.
static func win_chance(sect: Sect, ids: Array) -> float:
	return Tournament.win_chance(defense(sect, ids), attack(sect))


static func check(sect: Sect, ids: Array) -> Array[String]:
	var errors: Array[String] = []
	if not pending(sect):
		errors.append("no_battle")
	if ids.size() > Balance.DEFENDERS_MAX:
		errors.append("team_size")
	var free := eligible(sect).map(func(d: Disciple) -> String: return d.id)
	var seen := {}
	for id: String in ids:
		if not id in free or seen.has(id):
			errors.append("not_eligible:" + id)
		seen[id] = true
	return errors


## Fights the battle with these defenders (none is allowed: allies may still
## win it). Returns the war's result, or {} when the choice isn't possible.
static func defend(sect: Sect, ids: Array) -> Dictionary:
	if not check(sect, ids).is_empty():
		return {}
	var defenders: Array[String] = []
	defenders.assign(ids)
	var rival := String(sect.war["rival"])
	var won := sect.rng.chance(win_chance(sect, defenders))
	if won:
		sect.add_resource("reputation", Balance.WAR_WIN_REPUTATION)
		sect.add_resource("stones", Balance.WAR_WIN_STONES)
		sect.land = mini(sect.land + 1, Balance.LAND_MAX)
		sect.rival(rival)["attitude"] = Balance.WAR_WIN_ATTITUDE
	else:
		sect.add_resource("reputation", Balance.WAR_LOSE_REPUTATION)
		var share := floori(int(sect.resources["stones"]) * Balance.WAR_LOSE_STONES_SHARE)
		sect.add_resource("stones", -mini(share, Balance.WAR_LOSE_STONES_MAX))
		sect.land = maxi(sect.land - 1, Balance.LAND_MIN)
		for id in defenders:
			if sect.rng.chance(Balance.WAR_INJURY_CHANCE):
				sect.disciple(id).injure(Balance.WAR_INJURY_DAYS)
	sect.war["resolved"] = true
	sect.war["defenders"] = Array(defenders)
	sect.war["won"] = won
	sect.last_war_day = sect.day
	sect.pending_facts.append({"type": "war_result", "rival": rival, "won": won, "defenders": defenders.duplicate(), "land": sect.land})
	sect.chronicle_add("war_result", {"rival": rival, "won": won, "land": sect.land})
	return sect.war
