class_name Recruiting
extends RefCounted
## A hopeful at the gate. From Balance.RECRUIT_FIRST_DAY, every few days, a
## candidate waits for a couple of days while the sect has room under the
## Main Hall's limit. Taking them in costs Spirit Stones; a higher rank
## attracts more talented candidates. Runs after the day number goes up.


## Spirit Stones to take the candidate in: more as the sect grows.
static func cost(sect: Sect) -> int:
	return Balance.RECRUIT_COST_BASE + Balance.RECRUIT_COST_PER * sect.disciples.size()


## Ends a candidate's wait when it's over and maybe sends a new one.
static func roll(sect: Sect) -> void:
	if not sect.candidate.is_empty() and int(sect.candidate["until"]) < sect.day:
		sect.candidate = {}
	if not sect.candidate.is_empty():
		return
	if sect.day < maxi(Balance.RECRUIT_FIRST_DAY, sect.next_candidate_day):
		return
	if sect.disciples.size() >= sect.disciple_limit():
		return
	var d := DiscipleGenerator.generate(sect)
	var bonus: int = Balance.RANK_TALENT[clampi(sect.level("main_hall"), 0, Balance.MAX_LEVEL)]
	d.stats["talent"] = d.stat("talent") + bonus
	d.clamp_values()
	sect.candidate = {"disciple": d.to_dict(), "until": sect.day + Balance.CANDIDATE_DAYS - 1}
	sect.next_candidate_day = sect.day + sect.rng.randi_range(Balance.RECRUIT_EVERY[0], Balance.RECRUIT_EVERY[1])


## The waiting candidate, or null.
static func candidate(sect: Sect) -> Disciple:
	if sect.candidate.is_empty():
		return null
	return Disciple.from_dict(DayReport._whole_numbers(sect.candidate["disciple"]))


## {"ok": bool, "reason": "" | "none" | "full" | "not_enough_stones"}
static func can_accept(sect: Sect) -> Dictionary:
	if sect.candidate.is_empty():
		return {"ok": false, "reason": "none"}
	if sect.disciples.size() >= sect.disciple_limit():
		return {"ok": false, "reason": "full"}
	if int(sect.resources["stones"]) < cost(sect):
		return {"ok": false, "reason": "not_enough_stones"}
	return {"ok": true, "reason": ""}


static func accept(sect: Sect) -> bool:
	if not can_accept(sect)["ok"]:
		return false
	var d := candidate(sect)
	sect.add_resource("stones", -cost(sect))
	sect.disciples.append(d)
	sect.candidate = {}
	sect.pending_facts.append({"type": "recruited", "disciple": d.id})
	sect.chronicle_add("recruited", {"disciple": d.id})
	return true


static func decline(sect: Sect) -> void:
	sect.candidate = {}
