extends GutTest
## Missions: team power, result tiers, timing, rewards and setbacks.


func _team(ids: Array) -> Array[String]:
	var team: Array[String] = []
	team.assign(ids)
	return team


func test_scores_map_to_tiers() -> void:
	assert_eq(MissionResolver.tier_for(1.6), "great")
	assert_eq(MissionResolver.tier_for(1.0), "success")
	assert_eq(MissionResolver.tier_for(0.8), "partial")
	assert_eq(MissionResolver.tier_for(0.5), "failure")
	assert_eq(MissionResolver.tier_for(0.1), "disaster")


func test_power_uses_the_missions_stats_realm_and_mood() -> void:
	var d := SimFixtures.disciple("a", 4, 0)
	d.stats["body"] = 8  # hunting uses body and talent
	assert_almost_eq(MissionResolver.member_power(d, "hunt_monster"), 6.0, 0.001)
	assert_almost_eq(MissionResolver.member_power(d, "gather_herbs"), 4.0, 0.001)
	d.mood = 10
	d.realm = "foundation_building"
	assert_almost_eq(MissionResolver.member_power(d, "gather_herbs"), 4.0 + 3.0 + 3.0, 0.001)


func test_luck_moves_the_score_both_ways() -> void:
	var lucky := MissionResolver.score(8.0, "gather_herbs", 1.0)
	var unlucky := MissionResolver.score(8.0, "gather_herbs", 0.0)
	assert_almost_eq(lucky, 1.0 + Balance.MISSION_LUCK / 2.0, 0.001)
	assert_almost_eq(unlucky, 1.0 - Balance.MISSION_LUCK / 2.0, 0.001)


func test_a_team_leaves_skips_home_tasks_and_comes_back_on_time() -> void:
	var sect := SimFixtures.sect()
	var plan := SimFixtures.plan_all(sect, "work")
	plan.add_mission("hunt_monster", _team(["a", "b"]))
	var report := DayResolver.resolve(sect, plan)
	var departed := report.of_type("mission_departed")[0]
	assert_eq(departed["team"], ["a", "b"])
	assert_eq(report.of_type("worked")[0]["disciples"], ["c"])
	assert_true(sect.is_away("a"))
	var return_day: int = departed["return_day"]
	assert_between(return_day, 2, 3, "hunts take 2 to 3 days, counting today")

	var came_home := false
	while sect.day <= return_day:
		var next := DayResolver.resolve(sect, DayPlan.defaults(sect))
		came_home = not next.of_type("mission_returned").is_empty()
	assert_true(came_home)
	assert_false(sect.is_away("a"))
	assert_true(sect.missions.is_empty())


func test_a_one_day_mission_returns_the_same_evening() -> void:
	var sect := SimFixtures.sect()
	var m := ActiveMission.new()
	m.mission = "gather_herbs"
	m.team = _team(["a"])
	m.departed_day = 1
	m.return_day = 1
	m.tier = "success"
	sect.missions.append(m)
	var report := DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(report.of_type("mission_returned").size(), 1)


func _complete(tier: String, mission: String = "hunt_monster", seed_value: int = 1) -> Dictionary:
	var sect := SimFixtures.sect([SimFixtures.disciple("a", 5, 0), SimFixtures.disciple("b", 5, 0)], seed_value)
	sect.disciple("a").progress = 50
	sect.disciple("b").progress = 50
	var m := ActiveMission.new()
	m.mission = mission
	m.team = _team(["a", "b"])
	m.tier = tier
	var report := DayReport.new(1)
	MissionResolver.complete(sect, m, report)
	return {"sect": sect, "report": report}


func test_rewards_scale_with_the_tier() -> void:
	for tier in ["great", "success", "partial", "failure", "disaster"]:
		var result := _complete(tier)
		var stones: int = result["report"].of_type("mission_returned")[0]["rewards"]["stones"]
		var share: float = Balance.TIER_REWARD[tier]
		var span: Array = Balance.MISSIONS["hunt_monster"]["rewards"]["stones"]
		assert_between(stones, roundi(span[0] * share), roundi(span[1] * share), tier)
		assert_eq(result["sect"].resources["stones"], 500 + stones, tier)


func test_great_missions_lift_mood_and_disasters_hurt() -> void:
	var great: Sect = _complete("great")["sect"]
	assert_eq(great.disciple("a").mood, Balance.TIER_MOOD["great"])
	assert_eq(great.disciple("a").loyalty, 50 + Balance.TIER_LOYALTY["great"])
	var bad: Sect = _complete("disaster")["sect"]
	assert_eq(bad.disciple("a").mood, Balance.TIER_MOOD["disaster"])


func test_a_disaster_always_costs_someone_and_nobody_ever_dies() -> void:
	var injuries := 0
	var losses := 0
	for seed_value in 40:
		var result := _complete("disaster", "hunt_monster", seed_value)
		var report: DayReport = result["report"]
		var sect: Sect = result["sect"]
		var setbacks := report.of_type("injured").size() + report.of_type("lost_cultivation").size()
		assert_eq(setbacks, 1, "seed %d" % seed_value)
		injuries += report.of_type("injured").size()
		for fact in report.of_type("lost_cultivation"):
			losses += 1
			var d := sect.disciple(fact["disciple"])
			assert_eq(d.progress, 50 - int(fact["amount"]))
			assert_between(int(fact["amount"]), Balance.LOST_PROGRESS[0], Balance.LOST_PROGRESS[1])
		assert_eq(sect.disciples.size(), 2)
	assert_gt(injuries, 0)
	assert_gt(losses, 0)


func test_failures_sometimes_injure_and_successes_never_do() -> void:
	var failure_injuries := 0
	for seed_value in 40:
		failure_injuries += _complete("failure", "hunt_monster", seed_value)["report"].of_type("injured").size()
		var success: DayReport = _complete("success", "hunt_monster", seed_value)["report"]
		assert_eq(success.of_type("injured").size(), 0)
	assert_between(failure_injuries, 1, 39, "about half of failures injure someone")


func test_a_strong_full_team_usually_does_well_and_a_weak_one_struggles() -> void:
	var strong := SimFixtures.sect([
		SimFixtures.disciple("a", 7, 4), SimFixtures.disciple("b", 7, 4), SimFixtures.disciple("c", 7, 4),
	])
	assert_has(["great", "success"], MissionResolver.expected_tier(strong, "hunt_monster", ["a", "b", "c"]))
	var weak := SimFixtures.sect([SimFixtures.disciple("a", 2, -5)])
	assert_has(["failure", "disaster"], MissionResolver.expected_tier(weak, "hunt_monster", ["a"]))
