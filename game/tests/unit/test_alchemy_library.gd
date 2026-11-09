extends GutTest
## The Alchemy Room, the Library, the Kitchen and the Mission Hall (M5).


func _sect() -> Sect:
	var sect := SimFixtures.sect()
	sect.resources["herbs"] = 200
	return sect


func test_pills_need_the_room_its_level_and_the_recipe() -> void:
	var sect := _sect()
	assert_eq(Alchemy.can_brew(sect, "foundation_pill")["reason"], "locked")
	sect.buildings["alchemy_room"] = 1
	assert_eq(Alchemy.can_brew(sect, "healing_pill")["reason"], "locked", "Healing Pills need level 2")
	assert_true(Alchemy.brew(sect, "foundation_pill"))
	assert_eq(sect.item("foundation_pill"), 1)
	assert_eq(int(sect.resources["herbs"]), 190)
	assert_eq(sect.pending_facts, [{"type": "brewed", "pill": "foundation_pill"}] as Array[Dictionary])
	assert_eq(Alchemy.can_brew(sect, "foundation_pill")["reason"], "no_brews_left", "one brew a day at level 1")
	sect.resources["herbs"] = 0
	sect.brews_today = 0
	assert_eq(Alchemy.can_brew(sect, "foundation_pill")["reason"], "too_expensive")
	sect.resources["herbs"] = 200
	sect.items["foundation_pill"] = Balance.PILL_MAX
	assert_eq(Alchemy.can_brew(sect, "foundation_pill")["reason"], "full")


func test_brews_reset_each_day() -> void:
	var sect := _sect()
	sect.buildings["alchemy_room"] = 2
	assert_true(Alchemy.brew(sect, "foundation_pill"))
	assert_true(Alchemy.brew(sect, "healing_pill"))
	assert_false(Alchemy.brew(sect, "foundation_pill"))
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
	assert_eq(report.of_type("brewed").size(), 2, "the morning's brews are in the day's report")
	assert_eq(sect.brews_today, 0)
	assert_true(Alchemy.brew(sect, "foundation_pill"))


func test_a_healing_pill_cures_injuries_and_side_effects() -> void:
	var sect := _sect()
	var d := sect.disciple("a")
	assert_false(Alchemy.can_heal(sect, d), "nothing to heal and no pill")
	d.injure(4)
	d.add_effect("hiccups", 6)
	assert_false(Alchemy.can_heal(sect, d), "no pill")
	sect.items["healing_pill"] = 1
	assert_true(Alchemy.heal(sect, d))
	assert_true(d.effects.is_empty())
	assert_eq(sect.item("healing_pill"), 0)
	assert_eq(sect.pending_facts.back(), {"type": "cured", "disciple": "a"})


func test_study_teaches_techniques_up_to_the_librarys_level() -> void:
	var sect := _sect()
	var d := sect.disciple("a")
	assert_false(CultivationRules.can_study(sect, d), "no Library")
	sect.buildings["library"] = 1
	assert_true(DayPlan.task_allowed(sect, d, "study"))
	var report := DayReport.new(1)
	for day in 7:
		CultivationRules.study(sect, d, report)
	assert_eq(d.technique, 1, "10 + Wit (5) a day: level 1 after 7 days")
	assert_eq(report.of_type("learned"), [{"type": "learned", "disciple": "a", "technique": CultivationRules.technique_of(d), "tier": 1}] as Array[Dictionary])
	assert_false(CultivationRules.can_study(sect, d), "the Library has nothing more until level 2")
	assert_false(DayPlan.task_allowed(sect, d, "study"))
	var power := MissionResolver.member_power(sect.disciple("b"), "hunt_monster")
	assert_almost_eq(MissionResolver.member_power(d, "hunt_monster"), power + Balance.TECHNIQUE_POWER, 0.0001)


func test_the_kitchen_turns_food_into_mood() -> void:
	var plain := _sect()
	var cooked := _sect()
	cooked.buildings["kitchen"] = 1
	DayResolver.resolve(plain, SimFixtures.plan_all(plain, "work"))
	DayResolver.resolve(cooked, SimFixtures.plan_all(cooked, "work"))
	assert_eq(cooked.disciple("a").mood, plain.disciple("a").mood + 1)
	# Three at home: 3 Food, plus 2 more for the Kitchen's meals (1 per 2).
	assert_eq(int(plain.resources["food"]) - int(cooked.resources["food"]), 2)


func test_the_mission_hall_unlocks_missions_and_raises_rewards() -> void:
	var sect := _sect()
	var plan := DayPlan.new()
	plan.add_mission("escort_merchant", ["a"] as Array[String])
	assert_eq(plan.validate(sect), ["locked_mission:escort_merchant"] as Array[String])
	sect.buildings["mission_hall"] = 1
	assert_eq(plan.validate(sect), [] as Array[String])
	assert_false(MissionResolver.unlocked(sect, "explore_secret_realm"))
	sect.buildings["mission_hall"] = 2
	assert_true(MissionResolver.unlocked(sect, "explore_secret_realm"))
