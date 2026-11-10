class_name Rivals
extends RefCounted
## The rival sects (M6): Attitude and Trust, gifts, trades and alliances, and
## an ally's betrayal. The catalog of sects is data/rivals.gd; every number
## is in Balance. Code decides all of it; Claude only tells it.


static func attitude(sect: Sect, rival: String) -> int:
	return int(sect.rival(rival)["attitude"])


static func trust(sect: Sect, rival: String) -> int:
	return int(sect.rival(rival)["trust"])


static func is_ally(sect: Sect, rival: String) -> bool:
	return bool(sect.rival(rival)["ally"])


## How the rival feels, as a word for the World tab: hostile, cold, wary,
## neutral, friendly, warm, or allied.
static func mood_word(sect: Sect, rival: String) -> String:
	if is_ally(sect, rival):
		return "allied"
	var a := attitude(sect, rival)
	if a <= Balance.ATTITUDE_HOSTILE:
		return "hostile"
	if a <= Balance.ATTITUDE_COLD:
		return "cold"
	if a < Balance.ATTITUDE_WARY:
		return "wary"
	if a <= Balance.ATTITUDE_FRIENDLY:
		return "neutral"
	if a < Balance.ATTITUDE_WARM:
		return "friendly"
	return "warm"


## Moves Attitude within its limits; returns how much it actually moved.
## Callers then run Wars.check_call_off, after recording their own fact, so a
## war called off by a gift is told after the gift.
static func change_attitude(sect: Sect, rival: String, amount: int) -> int:
	var state := sect.rival(rival)
	var before := int(state["attitude"])
	state["attitude"] = clampi(before + amount, Balance.ATTITUDE_MIN, Balance.ATTITUDE_MAX)
	return int(state["attitude"]) - before


static func change_trust(sect: Sect, rival: String, amount: int) -> int:
	var state := sect.rival(rival)
	var before := int(state["trust"])
	state["trust"] = clampi(before + amount, Balance.TRUST_MIN, Balance.TRUST_MAX)
	return int(state["trust"]) - before


# Gifts --------------------------------------------------------------------------

## {"ok", "reason": "" | "unknown" | "too_soon" | "not_enough"}
static func can_gift(sect: Sect, rival: String, resource: String) -> Dictionary:
	if not sect.rivals.has(rival) or not Balance.GIFT_COST.has(resource):
		return {"ok": false, "reason": "unknown"}
	if sect.day - int(sect.rival(rival)["gift_day"]) < Balance.GIFT_EVERY:
		return {"ok": false, "reason": "too_soon"}
	if int(sect.resources[resource]) < int(Balance.GIFT_COST[resource]):
		return {"ok": false, "reason": "not_enough"}
	return {"ok": true, "reason": ""}


## The first day the rival will take another gift.
static func next_gift_day(sect: Sect, rival: String) -> int:
	return int(sect.rival(rival)["gift_day"]) + Balance.GIFT_EVERY


## Sends a gift. Returns the Attitude it gained, or -1 when it isn't possible.
static func gift(sect: Sect, rival: String, resource: String) -> int:
	if not can_gift(sect, rival, resource)["ok"]:
		return -1
	var amount := int(Balance.GIFT_COST[resource])
	sect.add_resource(resource, -amount)
	sect.rival(rival)["gift_day"] = sect.day
	var favourite: bool = RivalCatalog.RIVALS[rival]["favourite"] == resource
	var gained := change_attitude(sect, rival, Balance.GIFT_FAVOURITE_ATTITUDE if favourite else Balance.GIFT_ATTITUDE)
	change_trust(sect, rival, Balance.GIFT_TRUST)
	sect.pending_facts.append({"type": "gift", "rival": rival, "resource": resource, "amount": amount})
	Wars.check_call_off(sect)
	return gained


# Trades -------------------------------------------------------------------------

static func trade_period(day: int) -> int:
	@warning_ignore("integer_division")
	return (maxi(day, 1) - 1) / Balance.TRADE_EVERY


## This period's deal: {give: {resource: n}, get: {resource: n}}.
static func offer(sect: Sect, rival: String) -> Dictionary:
	var trades: Array = RivalCatalog.RIVALS[rival]["trades"]
	return trades[trade_period(sect.day) % trades.size()]


## {"ok", "reason": "" | "unknown" | "done" | "cold" | "at_war" | "not_enough"}
static func can_trade(sect: Sect, rival: String) -> Dictionary:
	if not sect.rivals.has(rival):
		return {"ok": false, "reason": "unknown"}
	if int(sect.rival(rival)["trade_period"]) == trade_period(sect.day):
		return {"ok": false, "reason": "done"}
	if Wars.at_war_with(sect, rival):
		return {"ok": false, "reason": "at_war"}
	if attitude(sect, rival) < Balance.TRADE_MIN_ATTITUDE:
		return {"ok": false, "reason": "cold"}
	if not EventRules.affordable(sect, offer(sect, rival)["give"]):
		return {"ok": false, "reason": "not_enough"}
	return {"ok": true, "reason": ""}


## The first day of the next trading period.
static func next_trade_day(sect: Sect) -> int:
	return (trade_period(sect.day) + 1) * Balance.TRADE_EVERY + 1


static func trade(sect: Sect, rival: String) -> bool:
	if not can_trade(sect, rival)["ok"]:
		return false
	var deal := offer(sect, rival)
	var gave := {}
	var got := {}
	for resource: String in deal["give"]:
		gave[resource] = -sect.add_resource(resource, -int(deal["give"][resource]))
	for resource: String in deal["get"]:
		got[resource] = sect.add_resource(resource, int(deal["get"][resource]))
	sect.rival(rival)["trade_period"] = trade_period(sect.day)
	change_attitude(sect, rival, Balance.TRADE_ATTITUDE)
	change_trust(sect, rival, Balance.TRADE_TRUST)
	sect.pending_facts.append({"type": "trade", "rival": rival, "gave": gave, "got": got})
	Wars.check_call_off(sect)
	return true


# Alliances ----------------------------------------------------------------------

## {"ok", "reason": "" | "unknown" | "allied" | "at_war" | "attitude" | "trust"}
static func can_ally(sect: Sect, rival: String) -> Dictionary:
	if not sect.rivals.has(rival):
		return {"ok": false, "reason": "unknown"}
	if is_ally(sect, rival):
		return {"ok": false, "reason": "allied"}
	if Wars.at_war_with(sect, rival):
		return {"ok": false, "reason": "at_war"}
	if attitude(sect, rival) < Balance.ALLIANCE_ATTITUDE:
		return {"ok": false, "reason": "attitude"}
	if trust(sect, rival) < Balance.ALLIANCE_TRUST:
		return {"ok": false, "reason": "trust"}
	return {"ok": true, "reason": ""}


static func ally(sect: Sect, rival: String) -> bool:
	if not can_ally(sect, rival)["ok"]:
		return false
	sect.rival(rival)["ally"] = true
	sect.pending_facts.append({"type": "alliance", "rival": rival})
	sect.chronicle_add("alliance", {"rival": rival})
	return true


## The Sect Master ends an alliance; the rival takes it badly.
static func end_alliance(sect: Sect, rival: String) -> bool:
	if not sect.rivals.has(rival) or not is_ally(sect, rival):
		return false
	sect.rival(rival)["ally"] = false
	change_attitude(sect, rival, Balance.END_ALLIANCE_ATTITUDE)
	change_trust(sect, rival, Balance.END_ALLIANCE_TRUST)
	sect.pending_facts.append({"type": "alliance_ended", "rival": rival, "by": "player"})
	sect.chronicle_add("alliance_ended", {"rival": rival, "by": "player"})
	return true


# Night --------------------------------------------------------------------------

## Attitude drifts back toward each rival's own start; allies slowly lose
## Trust; and an ally with too little Trust may betray the sect.
static func night(sect: Sect) -> void:
	for rival in RivalCatalog.ids():
		var home := int(RivalCatalog.RIVALS[rival]["attitude"])
		var now := attitude(sect, rival)
		if now != home:
			var step := mini(Balance.ATTITUDE_DRIFT, absi(home - now))
			change_attitude(sect, rival, step if home > now else -step)
		if not is_ally(sect, rival):
			continue
		if sect.day % Balance.ALLY_TRUST_DECAY_EVERY == 0:
			change_trust(sect, rival, -1)
		if trust(sect, rival) < Balance.BETRAYAL_TRUST and sect.rng.chance(Balance.BETRAYAL_CHANCE):
			_betray(sect, rival)
	Wars.check_call_off(sect)


static func _betray(sect: Sect, rival: String) -> void:
	sect.rival(rival)["ally"] = false
	change_attitude(sect, rival, Balance.BETRAYAL_ATTITUDE)
	var pills: Array[String] = []
	for pill in Balance.PILLS:
		if sect.item(pill) > 0:
			pills.append(pill)
	var stones := 0
	var item := "none"
	if not pills.is_empty() and sect.rng.chance(0.5):
		item = sect.rng.pick(pills)
		sect.add_item(item, -1)
	else:
		var share := floori(int(sect.resources["stones"]) * Balance.BETRAYAL_STONES_SHARE)
		stones = -sect.add_resource("stones", -mini(share, Balance.BETRAYAL_STONES_MAX))
	sect.pending_facts.append({"type": "betrayal", "rival": rival, "stones": stones, "item": item})
	sect.chronicle_add("betrayal", {"rival": rival})
