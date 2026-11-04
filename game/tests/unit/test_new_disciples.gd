extends GutTest
## New disciples and the start of a new game.


func test_new_disciples_have_stats_in_range_and_two_compatible_quirks() -> void:
	var sect := NewGame.create(7)
	for i in 40:
		var d := DiscipleGenerator.generate(sect)
		for stat in Balance.STATS:
			# Rolled 2-7; a gifted talent gives one other stat +1.
			assert_between(d.stat(stat), Balance.STAT_ROLL_MIN, Balance.STAT_ROLL_MAX + 1, stat)
		assert_eq(d.quirks.size(), Balance.QUIRKS_PER_DISCIPLE)
		assert_true(Quirks.compatible(d.quirks[0], d.quirks[1]), "%s" % [d.quirks])
		assert_has(Balance.SPIRIT_ROOTS, d.spirit_root)
		assert_has(Balance.PRONOUNS, d.pronouns)
		assert_eq(d.realm, "qi_refining")
		sect.disciples.append(d)


func test_names_are_unique_within_a_sect() -> void:
	var sect := NewGame.create(11)
	for i in 9:
		sect.disciples.append(DiscipleGenerator.generate(sect))
	var names := {}
	for d in sect.disciples:
		names[d.name_en] = true
	assert_eq(names.size(), sect.disciples.size())


func test_each_disciple_gets_a_new_id() -> void:
	var sect := NewGame.create(3)
	var ids := sect.disciples.map(func(d: Disciple) -> String: return d.id)
	assert_eq(ids, ["d1", "d2", "d3"])
	assert_eq(DiscipleGenerator.generate(sect).id, "d4")


func test_the_same_seed_makes_the_same_sect() -> void:
	assert_eq(NewGame.create(99).to_dict(), NewGame.create(99).to_dict())
	assert_ne(NewGame.create(99).to_dict(), NewGame.create(100).to_dict())


func test_a_new_game_matches_the_gdd_start() -> void:
	var sect := NewGame.create(1)
	assert_eq(sect.day, 1)
	assert_eq(sect.disciples.size(), Balance.START_DISCIPLES)
	assert_eq(sect.resources, Balance.START_RESOURCES)
	assert_eq(sect.level("main_hall"), 1, "the leaky hut")
	for building in ["disciple_huts", "training_yard", "spirit_field"]:
		assert_eq(sect.level(building), 0, building)
	assert_eq(sect.rank(), "unknown_mountain")
	assert_true(sect.missions.is_empty())
	assert_null(sect.last_report)
