extends GutTest
## Generations (M6): Elders, ascension, travel, letters and homecomings, and
## the version 4 save.


func _senior(id: String, realm: String = "golden_core") -> Disciple:
	var d := SimFixtures.disciple(id)
	d.realm = realm
	d.loyalty = Balance.ELDER_LOYALTY
	d.joined_day = 1
	return d


func _sect(disciples: Array = [], seed_value: int = 1) -> Sect:
	if disciples.is_empty():
		disciples = [_senior("a"), SimFixtures.disciple("b"), SimFixtures.disciple("c"), SimFixtures.disciple("d"), SimFixtures.disciple("e")]
	var sect := SimFixtures.sect(disciples, seed_value)
	sect.day = 1 + Balance.ELDER_DAYS
	return sect


func test_a_senior_loyal_disciple_can_be_promoted_one_per_main_hall_level() -> void:
	var sect := _sect([_senior("a"), _senior("b"), SimFixtures.disciple("c")])
	assert_eq(Generations.can_promote(sect, sect.disciple("c"))["reason"], "realm")
	sect.disciple("b").loyalty = 60
	assert_eq(Generations.can_promote(sect, sect.disciple("b"))["reason"], "loyalty")
	sect.disciple("b").loyalty = 80
	sect.disciple("b").joined_day = sect.day - 10
	assert_eq(Generations.can_promote(sect, sect.disciple("b"))["reason"], "days")
	sect.disciple("b").joined_day = 1
	assert_true(Generations.promote(sect, "a"))
	assert_true(sect.disciple("a").is_elder())
	assert_eq(sect.pending_facts[-1], {"type": "promoted", "disciple": "a"})
	assert_eq(Generations.can_promote(sect, sect.disciple("b"))["reason"], "full", "Main Hall level 1")
	sect.buildings["main_hall"] = 2
	assert_true(Generations.promote(sect, "b"))
	assert_eq(Generations.can_promote(sect, sect.disciple("a"))["reason"], "elder")


func test_elders_take_no_tasks_free_a_place_and_help_everyone_train_and_study() -> void:
	var sect := _sect()
	var c := sect.disciple("c")
	var before := BuildingRules.training_gain(sect, c)
	Generations.promote(sect, "a")
	assert_eq(sect.member_count(), 4)
	assert_false(sect.disciple("a").id in sect.available_disciples().map(func(d: Disciple) -> String: return d.id))
	assert_false(DayPlan.task_allowed(sect, sect.disciple("a"), "train"))
	assert_false(DayPlan.defaults(sect).tasks.has("a"))
	var plan := DayPlan.new()
	plan.tasks["a"] = "train"
	assert_true(plan.validate(sect).has("elder:a"))
	assert_eq(EveningRules.allowed_actions(sect, sect.disciple("a")), [] as Array[String])
	assert_eq(DiscipleCard.build(sect.disciple("a"), "en", sect)["role"], "elder")
	assert_false(DiscipleCard.build(c, "en", sect).has("role"))
	assert_eq(BuildingRules.training_gain(sect, c), roundi(before * (1.0 + Balance.ELDER_TRAIN_BONUS)))
	sect.buildings["library"] = 1
	var report := DayReport.new(sect.day)
	CultivationRules.study(sect, c, report)
	assert_eq(c.study, Balance.STUDY_BASE + c.stat("wit") + Balance.ELDER_STUDY)


func test_a_nascent_soul_at_full_progress_may_ascend() -> void:
	var outcomes := {}
	for seed_value in 40:
		var sect := _sect([_senior("a", "nascent_soul"), SimFixtures.disciple("b"), SimFixtures.disciple("c")], seed_value)
		sect.disciple("a").progress = Balance.PROGRESS_MAX
		Relationships.change(sect, "a", "b", 2)
		assert_true(DayPlan.task_allowed(sect, sect.disciple("a"), "ascend"))
		var plan := DayPlan.defaults(sect)
		plan.set_task("a", "ascend")
		var reputation := int(sect.resources["reputation"])
		var report := DayResolver.resolve(sect, plan)
		if report.of_type("ascended").is_empty():
			outcomes["failed"] = true
			var failed: Dictionary = report.of_type("ascension_failed")[0]
			assert_eq(sect.disciple("a").progress, Balance.PROGRESS_MAX - Balance.ASCEND_FAIL_PROGRESS)
			assert_true(failed["effect"] in Balance.SIDE_EFFECTS)
			continue
		outcomes["ascended"] = true
		assert_eq(sect.disciple("a").status, "ascended", "here for tonight's story")
		assert_eq(DiscipleCard.build(sect.disciple("a"), "en", sect)["status"], "ascended")
		assert_eq(sect.resources["reputation"], reputation + Balance.ASCEND_REPUTATION)
		var evening := EveningRules.request(sect, report, "en")
		assert_eq(evening["disciples"].size(), 3)
		DayResolver.resolve(sect, DayPlan.defaults(sect))
		assert_null(sect.disciple("a"), "gone the next day")
		assert_eq(sect.alumni[0]["id"], "a")
		assert_eq(sect.name_of("a", "en"), "Test a")
		assert_eq(Relationships.pairs(sect), [] as Array[Dictionary])
	assert_eq(outcomes.size(), 2, "both happen")
	assert_false(Generations.can_ascend(_senior("x", "golden_core")))


func _traveller_sect(seed_value: int = 1) -> Sect:
	var a := _senior("a", "foundation_building")
	var sect := SimFixtures.sect([a, SimFixtures.disciple("b"), SimFixtures.disciple("c"), SimFixtures.disciple("d")], seed_value)
	sect.day = 1 + Balance.TRAVEL_DAYS_IN_SECT
	return sect


func test_a_senior_disciple_asks_to_travel_while_enough_others_stay() -> void:
	var sect := _traveller_sect()
	while sect.travel_request.is_empty():
		Generations.roll_travel(sect)
	assert_eq(sect.travel_request["disciple"], "a")
	assert_true(sect.travel_request["place"] in TravelCatalog.PLACES)
	assert_between(int(sect.travel_request["days"]), Balance.TRAVEL_LENGTH[0], Balance.TRAVEL_LENGTH[1])
	assert_eq(World.pending(sect), ["travel"] as Array[String])
	var small := _traveller_sect()
	small.disciples.pop_back()
	for i in 100:
		Generations.roll_travel(small)
	assert_true(small.travel_request.is_empty(), "three would be too few at home")


func test_a_champion_can_still_be_let_go_after_the_tournament() -> void:
	var sect := _traveller_sect()
	sect.day = Balance.SEASON_DAYS * 2
	Tournament.night(sect)
	Tournament.enter(sect, ["a"])
	sect.travel_request = {"disciple": "a", "place": "eastern_sea", "days": 20, "day": sect.day}
	assert_true(Generations.let_go(sect))
	assert_eq(sect.disciple("a").status, "travel")


func test_asking_to_stay_costs_mood() -> void:
	var sect := _traveller_sect()
	sect.travel_request = {"disciple": "a", "place": "eastern_sea", "days": 20, "day": sect.day}
	assert_true(Generations.ask_to_stay(sect))
	assert_eq(sect.disciple("a").mood, Balance.STAY_MOOD)
	assert_eq(sect.disciple("a").status, "home")
	assert_gt(sect.next_travel_day, sect.day)


func test_a_traveller_writes_home_with_a_gift_and_comes_home_stronger() -> void:
	var sect := _traveller_sect(3)
	sect.travel_request = {"disciple": "a", "place": "noodle_town", "days": 20, "day": sect.day}
	assert_true(Generations.let_go(sect))
	var a := sect.disciple("a")
	assert_eq(a.status, "travel")
	assert_true(sect.is_away("a"))
	assert_eq(a.return_day, sect.day + 20)
	assert_eq(sect.pending_facts[-1], {"type": "travel_left", "disciple": "a", "place": "noodle_town", "return_day": a.return_day})
	assert_eq(DiscipleCard.build(a, "en", sect)["status"], "travel")
	var letters: Array[Dictionary] = []
	var returned := {}
	var progress := a.progress
	var loyalty := a.loyalty
	for day in 21:
		var report := DayResolver.resolve(sect, DayPlan.defaults(sect))
		if not report.of_type("travel_returned").is_empty():
			returned = report.of_type("travel_returned")[0]
		if not sect.letter.is_empty():
			letters.append(sect.letter.duplicate(true))
			var request := Generations.letter_request(sect, "vi")
			assert_eq(request["kind"], "letter")
			assert_eq(request["disciple"]["status"], "travel")
	assert_between(letters.size(), 2, 3, "every 6 to 9 days")
	for letter in letters:
		assert_eq(letter["place"], "noodle_town")
		assert_true(letter["gift"].size() == 1 or letter["item"] != "none", "a small gift")
	assert_eq(returned["disciple"], "a")
	assert_eq(a.status, "home")
	assert_eq(a.progress, mini(progress + Balance.HOMECOMING_PROGRESS, Balance.PROGRESS_MAX))
	assert_eq(a.loyalty, loyalty + Balance.HOMECOMING_LOYALTY)
	assert_eq(sect.chronicle.filter(func(e: Dictionary) -> bool: return e["type"].begins_with("travel")).size(), 2)


func test_two_travellers_never_send_letters_the_same_day() -> void:
	var sect := _traveller_sect()
	for id in ["a", "b"]:
		var d := sect.disciple(id)
		d.status = "travel"
		d.return_day = sect.day + 30
		d.travel = {"place": "eastern_sea", "left_day": sect.day - 3, "next_letter_day": sect.day}
	Generations.roll_letters(sect)
	assert_eq(sect.letter["disciple"], "a")
	assert_eq(int(sect.disciple("b").travel["next_letter_day"]), sect.day + 1)


func test_a_version_3_save_migrates_to_version_4() -> void:
	var sect := NewGame.create(11)
	sect.candidate = {"disciple": DiscipleGenerator.generate(sect).to_dict(), "until": 3}
	var save := sect.to_dict()
	save["version"] = 3
	for key in ["rivals", "land", "war", "last_war_day", "tournament", "travel_request", "next_travel_day", "letter", "alumni"]:
		save.erase(key)
	for d: Dictionary in save["disciples"] + [save["candidate"]["disciple"]]:
		for key in ["role", "joined_day", "travel"]:
			d.erase(key)
	var migrated := SaveMigration.migrate(JSON.parse_string(JSON.stringify(save)))
	assert_true(migrated["ok"])
	var loaded := Sect.from_dict(migrated["data"])
	assert_eq(loaded.land, Balance.LAND_START)
	assert_eq(Rivals.attitude(loaded, "moonlit_tea"), 10)
	assert_eq(loaded.disciples[0].role, "disciple")
	assert_eq(loaded.disciples[0].joined_day, 1)
	assert_eq(Recruiting.candidate(loaded).role, "disciple")
	assert_eq(loaded.to_dict()["version"], 4)
	var again := Sect.from_dict(SaveMigration.migrate(JSON.parse_string(JSON.stringify(loaded.to_dict())))["data"])
	assert_eq(again.to_dict(), loaded.to_dict(), "a v4 save round-trips")
