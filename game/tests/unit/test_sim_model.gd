extends GutTest
## The data model: limits hold, and a save survives a JSON round trip exactly,
## including the random generator's position.


func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func test_disciple_values_are_kept_inside_their_limits() -> void:
	var d := SimFixtures.disciple("a", 15, 30)
	d.loyalty = 140
	d.progress = -5
	d.clamp_values()
	assert_eq(d.stat("body"), Balance.STAT_MAX)
	assert_eq(d.mood, Balance.MOOD_MAX)
	assert_eq(d.loyalty, Balance.LOYALTY_MAX)
	assert_eq(d.progress, 0)


func test_an_injury_wears_off_and_a_new_one_never_shortens_it() -> void:
	var d := SimFixtures.disciple("a")
	d.injure(3)
	d.injure(2)
	assert_eq(d.injury_days(), 3)
	d.effects[0].days_left = 0
	d.clamp_values()
	assert_false(d.is_injured())
	assert_eq(d.effects.size(), 0)


func test_disciple_round_trip() -> void:
	var d := SimFixtures.disciple("a", 6, -2)
	d.injure(2)
	d.talked_today = true
	var copy := Disciple.from_dict(_json_round_trip(d.to_dict()))
	assert_eq(copy.to_dict(), d.to_dict())


func test_sect_round_trip_keeps_everything_and_the_luck() -> void:
	var sect := NewGame.create(2024)
	var plan := DayPlan.defaults(sect)
	plan.add_mission("gather_herbs", [sect.disciples[0].id] as Array[String])
	DayResolver.resolve(sect, plan)

	var saved := _json_round_trip(sect.to_dict())
	var loaded := Sect.from_dict(SaveMigration.migrate(saved)["data"])

	assert_eq(loaded.to_dict(), sect.to_dict())
	assert_eq(loaded.rng.randi_range(0, 1_000_000), sect.rng.randi_range(0, 1_000_000))


func test_saves_carry_the_version() -> void:
	assert_eq(NewGame.create(1).to_dict()["version"], Sect.SAVE_VERSION)


func test_resources_never_go_below_zero() -> void:
	var sect := SimFixtures.sect()
	sect.resources["food"] = 3
	assert_eq(sect.add_resource("food", -10), -3)
	assert_eq(sect.resources["food"], 0)


func test_migration_accepts_current_saves_and_rejects_others() -> void:
	var save := NewGame.create(1).to_dict()
	assert_true(SaveMigration.migrate(save)["ok"])
	var newer := save.duplicate()
	newer["version"] = Sect.SAVE_VERSION + 1
	assert_eq(SaveMigration.migrate(newer)["error"], "newer_version")
	assert_eq(SaveMigration.migrate({"day": 3})["error"], "not_a_save")
	assert_eq(SaveMigration.migrate("not json")["error"], "not_a_save")


func test_quirk_tags_keep_contradictions_apart() -> void:
	assert_eq(Quirks.ids().size(), 20)
	assert_false(Quirks.compatible("early_riser", "lazy_genius"))
	assert_false(Quirks.compatible("chosen_one", "chosen_one"))
	assert_true(Quirks.compatible("afraid_of_chickens", "secret_poet"))


func test_every_name_part_makes_a_name_the_server_accepts() -> void:
	# Same rule as NAME_PATTERN in server/supabase/functions/_shared/schemas.ts.
	var pattern := RegEx.create_from_string("^\\p{L}[\\p{L}\\p{M} '-]{0,39}$")
	var bad: Array[String] = []
	for s in Names.SURNAMES.size():
		for g in Names.GIVEN.size():
			var two: Array[int] = [g, (g + 1) % Names.GIVEN.size()]
			for name in [Names.compose(s, [g] as Array[int]), Names.compose(s, two)]:
				for form in ["en", "vi"]:
					if pattern.search(name[form]) == null:
						bad.append(name[form])
	assert_eq(bad, [] as Array[String])


func test_pinyin_joins_with_an_apostrophe_before_a_vowel() -> void:
	assert_eq(Names.join_pinyin(["xiao", "he"]), "Xiaohe")
	assert_eq(Names.join_pinyin(["ping", "an"]), "Ping'an")
	assert_eq(Names.compose(0, [0, 1] as Array[int]), {"en": "Lin Xiaohe", "vi": "Lâm Tiểu Hà"})
