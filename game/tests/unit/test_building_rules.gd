extends GutTest
## Building upgrades and building effects.


func test_an_upgrade_costs_spirit_stones_and_raises_the_level() -> void:
	var sect := SimFixtures.sect()
	sect.resources["stones"] = 35
	assert_true(BuildingRules.upgrade(sect, "spirit_field"))
	assert_eq(sect.level("spirit_field"), 1)
	assert_eq(sect.resources["stones"], 5)


func test_an_upgrade_without_enough_stones_changes_nothing() -> void:
	var sect := SimFixtures.sect()
	sect.resources["stones"] = 10
	var check := BuildingRules.can_upgrade(sect, "training_yard")
	assert_eq(check["reason"], "not_enough_stones")
	assert_eq(check["cost"], 40)
	assert_false(BuildingRules.upgrade(sect, "training_yard"))
	assert_eq(sect.level("training_yard"), 0)
	assert_eq(sect.resources["stones"], 10)


func test_buildings_stop_at_level_three() -> void:
	var sect := SimFixtures.sect()
	sect.resources["stones"] = 10_000
	for i in 3:
		assert_true(BuildingRules.upgrade(sect, "disciple_huts"))
	assert_eq(BuildingRules.can_upgrade(sect, "disciple_huts")["reason"], "max_level")
	assert_false(BuildingRules.upgrade(sect, "disciple_huts"))
	assert_eq(sect.level("disciple_huts"), 3)


func test_all_eight_buildings_can_be_built_to_level_three() -> void:
	var sect := SimFixtures.sect()
	sect.resources["stones"] = 100_000
	sect.resources["reputation"] = 100
	for building in Balance.BUILDINGS:
		while sect.level(building) < Balance.MAX_LEVEL:
			assert_true(BuildingRules.upgrade(sect, building), building)
		assert_eq(BuildingRules.can_upgrade(sect, building)["reason"], "max_level", building)


func test_the_main_hall_sets_rank_and_disciple_limit_and_needs_reputation() -> void:
	var sect := SimFixtures.sect()
	assert_eq([sect.rank(), sect.disciple_limit()], ["unknown_mountain", 4])
	sect.resources["reputation"] = 14
	var check := BuildingRules.can_upgrade(sect, "main_hall")
	assert_eq([check["reason"], check["reputation"]], ["not_enough_reputation", 15])
	assert_false(BuildingRules.upgrade(sect, "main_hall"))
	sect.resources["reputation"] = 15
	assert_true(BuildingRules.upgrade(sect, "main_hall"))
	assert_eq([sect.rank(), sect.disciple_limit()], ["rising_sect", 8])
	assert_eq(int(sect.resources["reputation"]), 15, "Reputation is needed, not spent")
	assert_eq(sect.pending_facts, [{"type": "rank_up", "rank": "rising_sect"}] as Array[Dictionary])
	assert_eq(sect.chronicle.back()["type"], "rank_up")


func test_the_spirit_field_raises_work_output() -> void:
	var sect := SimFixtures.sect()
	assert_eq([BuildingRules.work_food(sect), BuildingRules.work_herbs(sect)], [2, 0], "foraging")
	sect.buildings["spirit_field"] = 3
	assert_eq([BuildingRules.work_food(sect), BuildingRules.work_herbs(sect)], [5, 3])


func test_the_training_yard_speeds_training_and_low_mood_slows_it() -> void:
	var sect := SimFixtures.sect()
	var d := SimFixtures.disciple("a", 4, 0)
	# 6 + talent 4 + spirit 4 / 2 = 12
	assert_eq(BuildingRules.training_gain(sect, d), 12)
	sect.buildings["training_yard"] = 2
	assert_eq(BuildingRules.training_gain(sect, d), 18)
	d.mood = -1
	assert_eq(BuildingRules.training_gain(sect, d), roundi(18 * 0.8))


func test_the_huts_improve_rest_and_healing() -> void:
	var sect := SimFixtures.sect()
	assert_eq([BuildingRules.rest_mood(sect), BuildingRules.heal_per_day(sect)], [2, 1])
	sect.buildings["disciple_huts"] = 2
	assert_eq([BuildingRules.rest_mood(sect), BuildingRules.heal_per_day(sect)], [4, 2])


func test_talking_gives_mood_once_a_day() -> void:
	var d := SimFixtures.disciple("a", 5, 0)
	assert_eq(FreeTime.talk(d), Balance.TALK_MOOD)
	assert_eq(FreeTime.talk(d), 0)
	assert_eq(d.mood, Balance.TALK_MOOD)
	assert_false(FreeTime.can_talk(d))
