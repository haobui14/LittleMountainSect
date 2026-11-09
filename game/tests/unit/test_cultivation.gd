extends GutTest
## Breakthroughs, their side effects, and how realms and techniques change
## training (M5).


func _ready_disciple(id: String = "a", stat_value: int = 5) -> Disciple:
	var d := SimFixtures.disciple(id, stat_value)
	d.progress = Balance.PROGRESS_MAX
	return d


func test_only_a_ready_healthy_disciple_below_nascent_soul_can_break_through() -> void:
	var d := _ready_disciple()
	assert_true(CultivationRules.can_break_through(d))
	d.progress = Balance.PROGRESS_MAX - 1
	assert_false(CultivationRules.can_break_through(d), "not ready")
	d.progress = Balance.PROGRESS_MAX
	d.injure(2)
	assert_false(CultivationRules.can_break_through(d), "injured")
	var top := _ready_disciple("b")
	top.realm = "nascent_soul"
	assert_false(CultivationRules.can_break_through(top), "the last realm")


func test_the_chance_adds_up_its_parts_and_stays_within_limits() -> void:
	var sect := SimFixtures.sect()
	var d := _ready_disciple("a", 5)
	d.mood = 2
	sect.buildings["training_yard"] = 1
	# 0.35 base + 0.03 x 10 (Talent + Spirit) + 0.05 (yard) + 0.02 (Mood)
	assert_almost_eq(CultivationRules.chance(sect, d), 0.72, 0.0001)
	sect.items["foundation_pill"] = 1
	assert_almost_eq(CultivationRules.chance(sect, d), 0.87, 0.0001, "the Foundation Pill adds 15%")
	sect.items["golden_pill"] = 1
	assert_eq(CultivationRules.best_pill(sect), "golden_pill", "the strongest pill is used first")
	assert_almost_eq(CultivationRules.chance(sect, d), 0.95, 0.0001, "never above 95%")
	var weak := _ready_disciple("b", 1)
	weak.realm = "golden_core"
	weak.mood = -10
	assert_almost_eq(CultivationRules.chance(SimFixtures.sect(), weak), 0.05, 0.0001, "never below 5%")


func test_a_breakthrough_succeeds_or_fails_with_the_right_results() -> void:
	var successes := 0
	var failures := 0
	for seed_value in 40:
		var sect := SimFixtures.sect([], seed_value)
		sect.items["foundation_pill"] = 1
		var d := sect.disciple("a")
		d.progress = Balance.PROGRESS_MAX
		var report := DayReport.new(sect.day)
		var ok := CultivationRules.attempt(sect, d, report)
		assert_eq(sect.item("foundation_pill"), 0, "the pill is used either way")
		var fact: Dictionary = report.facts[0]
		if ok:
			successes += 1
			assert_eq([d.realm, d.progress], ["foundation_building", 0])
			assert_eq(fact, {"type": "breakthrough", "disciple": "a", "realm": "foundation_building", "pill": "foundation_pill"})
			assert_eq(sect.chronicle.back()["type"], "breakthrough")
		else:
			failures += 1
			assert_eq(d.realm, "qi_refining")
			assert_eq(d.progress, Balance.PROGRESS_MAX - Balance.BREAKTHROUGH_FAIL_PROGRESS)
			assert_eq(d.side_effects().size(), 1, "one funny side effect")
			assert_eq(fact["type"], "breakthrough_failed")
			assert_true(fact["effect"] in Balance.SIDE_EFFECTS)
			assert_between(int(fact["days"]), Balance.SIDE_EFFECT_DAYS[0], Balance.SIDE_EFFECT_DAYS[1])
	assert_gt(successes, 0)
	assert_gt(failures, 0)


func test_side_effects_wear_off_and_say_so() -> void:
	var d := SimFixtures.disciple("a")
	d.add_effect("green_hair", 2)
	d.injure(3)
	var report := DayReport.new(1)
	CultivationRules.tick_effects(d, report)
	assert_true(d.has_effect("green_hair"))
	assert_true(report.facts.is_empty())
	CultivationRules.tick_effects(d, report)
	assert_false(d.has_effect("green_hair"))
	assert_eq(report.facts, [{"type": "effect_ended", "disciple": "a", "effect": "green_hair"}] as Array[Dictionary])
	assert_eq(d.injury_days(), 3, "injuries heal by resting, not by waiting")


func test_side_effects_change_the_rules() -> void:
	var sect := SimFixtures.sect()
	sect.buildings["spirit_field"] = 1
	var d := sect.disciple("a")
	var power := MissionResolver.member_power(d, "hunt_monster")
	var train := BuildingRules.training_gain(sect, d)
	d.add_effect("hiccups", 5)
	assert_almost_eq(MissionResolver.member_power(d, "hunt_monster"), power * 0.75, 0.0001)
	d.add_effect("backwards_qi", 5)
	assert_eq(BuildingRules.training_gain(sect, d), roundi(train * 0.5))
	d.add_effect("floating", 5)
	assert_eq(BuildingRules.worker_food(sect, d), roundi(Balance.WORK_FOOD[1] * 0.5))
	d.add_effect("glowing", 5)
	assert_eq(BuildingRules.rest_mood(sect, d), roundi(BuildingRules.rest_mood(sect) * 0.5))
	var plain := sect.disciple("b")
	plain.add_effect("green_hair", 5)
	assert_almost_eq(MissionResolver.member_power(plain, "hunt_monster"), power, 0.0001, "green hair is only funny")


func test_training_slows_in_higher_realms_and_grows_with_technique() -> void:
	var sect := SimFixtures.sect()
	var d := sect.disciple("a")
	var base := BuildingRules.training_gain(sect, d)
	d.realm = "golden_core"
	assert_eq(BuildingRules.training_gain(sect, d), roundi(base * Balance.REALM_TRAIN[2]))
	d.realm = "qi_refining"
	d.technique = 2
	assert_eq(BuildingRules.training_gain(sect, d), roundi(base * 1.2))


func test_a_day_of_breakthrough_runs_in_the_day_plan() -> void:
	var sect := SimFixtures.sect()
	sect.disciple("a").progress = Balance.PROGRESS_MAX
	var plan := SimFixtures.plan_all(sect, "train")
	plan.tasks["a"] = "breakthrough"
	assert_eq(plan.validate(sect), [] as Array[String])
	var report := DayResolver.resolve(sect, plan)
	assert_eq(report.facts.filter(func(f: Dictionary) -> bool: return String(f["type"]).begins_with("breakthrough")).size(), 1)
	var bad := SimFixtures.plan_all(sect, "train")
	bad.tasks["b"] = "breakthrough"
	assert_eq(bad.validate(sect), ["not_allowed:b"] as Array[String], "b isn't ready")
	var defaults := DayPlan.defaults(sect)
	assert_eq(defaults.tasks["a"], "train", "after an attempt, back to training")
