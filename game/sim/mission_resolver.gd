class_name MissionResolver
extends RefCounted
## Missions: a team's power against the mission's difficulty, plus luck, gives
## a result tier. Code decides the tier, rewards and setbacks; Claude only
## tells the story (M4). Nobody ever dies: the worst is an injury or lost
## cultivation progress.


## One member's strength on a mission: the average of the mission's two stats,
## plus realm and Mood.
static func member_power(d: Disciple, mission: String) -> float:
	var stats: Array = Balance.MISSIONS[mission]["stats"]
	var average := (d.stat(stats[0]) + d.stat(stats[1])) / 2.0
	return average + d.realm_index() * Balance.REALM_POWER + d.mood * Balance.MOOD_POWER


static func team_power(sect: Sect, mission: String, team: Array) -> float:
	var total := 0.0
	for id: String in team:
		total += member_power(sect.disciple(id), mission)
	return total


## power / difficulty, moved up or down by luck ([param roll] is 0 to 1).
static func score(power: float, mission: String, roll: float) -> float:
	var difficulty := float(Balance.MISSIONS[mission]["difficulty"])
	return power / difficulty + (roll - 0.5) * Balance.MISSION_LUCK


static func tier_for(mission_score: float) -> String:
	for tier: String in Balance.TIERS:
		if not Balance.TIER_MIN_SCORE.has(tier) or mission_score >= Balance.TIER_MIN_SCORE[tier]:
			return tier
	return "disaster"


## A rough guide for the day plan screen: the tier with average luck.
static func expected_tier(sect: Sect, mission: String, team: Array) -> String:
	if team.is_empty():
		return "disaster"
	return tier_for(score(team_power(sect, mission, team), mission, 0.5))


## Sends a team out: rolls how long it takes and how it will go.
static func depart(sect: Sect, mission: String, team: Array, report: DayReport) -> ActiveMission:
	var def: Dictionary = Balance.MISSIONS[mission]
	var days := sect.rng.randi_range(int(def["days"][0]), int(def["days"][1]))
	var roll := sect.rng.randf()
	var m := ActiveMission.new()
	m.mission = mission
	m.team.assign(team)
	m.departed_day = sect.day
	m.return_day = sect.day + days - 1
	m.tier = tier_for(score(team_power(sect, mission, team), mission, roll))
	sect.missions.append(m)
	report.add("mission_departed", {"mission": mission, "team": m.team.duplicate(), "return_day": m.return_day})
	return m


## Brings a team home: rewards for the tier, Mood and Loyalty for the team,
## and a setback on a failure or disaster.
static func complete(sect: Sect, m: ActiveMission, report: DayReport) -> void:
	var def: Dictionary = Balance.MISSIONS[m.mission]
	var share := float(Balance.TIER_REWARD[m.tier])
	var rewards := {}
	for resource: String in def["rewards"]:
		var span: Array = def["rewards"][resource]
		var amount := roundi(sect.rng.randi_range(int(span[0]), int(span[1])) * share)
		rewards[resource] = sect.add_resource(resource, amount)

	for id in m.team:
		var d := sect.disciple(id)
		d.mood += int(Balance.TIER_MOOD[m.tier])
		d.loyalty += int(Balance.TIER_LOYALTY[m.tier])

	report.add("mission_returned", {
		"mission": m.mission,
		"tier": m.tier,
		"team": m.team.duplicate(),
		"rewards": rewards,
	})

	if m.tier == "failure":
		if sect.rng.chance(Balance.FAILURE_INJURY_CHANCE):
			_injure(sect, sect.disciple(sect.rng.pick(m.team)), m.mission, report)
	elif m.tier == "disaster":
		var victim := sect.disciple(sect.rng.pick(m.team))
		if sect.rng.chance(0.5):
			_injure(sect, victim, m.mission, report)
		else:
			var amount := mini(victim.progress, sect.rng.randi_range(Balance.LOST_PROGRESS[0], Balance.LOST_PROGRESS[1]))
			victim.progress -= amount
			report.add("lost_cultivation", {"disciple": victim.id, "amount": amount, "mission": m.mission})

	for id in m.team:
		sect.disciple(id).clamp_values()


static func _injure(sect: Sect, d: Disciple, mission: String, report: DayReport) -> void:
	var days := sect.rng.randi_range(Balance.INJURY_DAYS[0], Balance.INJURY_DAYS[1])
	d.injure(days)
	report.add("injured", {"disciple": d.id, "days": days, "mission": mission})
