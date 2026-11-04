extends GutTest
## One day of the rules: training, work, rest, food, drift, and the day's
## bookkeeping. Each rule is checked on a small, fully known sect.


func _one(id: String, stat_value: int = 5, mood: int = 0) -> Sect:
	return SimFixtures.sect([SimFixtures.disciple(id, stat_value, mood)])


func test_training_adds_progress_and_costs_mood() -> void:
	var sect := _one("a", 4, 0)
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "train"))
	var d := sect.disciple("a")
	assert_eq(d.progress, 12)  # 6 + talent 4 + spirit 4 / 2
	assert_eq(d.mood, Balance.TRAIN_MOOD)
	assert_eq(report.of_type("trained")[0], {"type": "trained", "disciple": "a", "gain": 12, "ready": false})


func test_training_stops_at_the_breakthrough_mark() -> void:
	var sect := _one("a", 9, 0)
	sect.disciple("a").progress = 95
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "train"))
	assert_eq(sect.disciple("a").progress, Balance.PROGRESS_MAX)
	assert_eq(report.of_type("trained")[0]["gain"], 5)
	assert_true(report.of_type("trained")[0]["ready"])


func test_work_grows_food_and_herbs_by_spirit_field_level() -> void:
	var sect := SimFixtures.sect()  # 3 disciples, 100 Food
	sect.buildings["spirit_field"] = 2
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "work"))
	var worked := report.of_type("worked")[0]
	assert_eq([worked["food"], worked["herbs"]], [12, 6])
	assert_eq(sect.resources["food"], 100 + 12 - 3)
	assert_eq(sect.resources["herbs"], 6)
	assert_eq(report.resource_changes["food"], 9)


func test_rest_raises_mood_and_heals_injuries() -> void:
	var sect := _one("a", 5, -4)
	sect.disciple("a").injure(2)
	DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
	assert_eq(sect.disciple("a").mood, -4 + Balance.REST_MOOD)
	assert_eq(sect.disciple("a").injury_days(), 1)

	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
	assert_false(sect.disciple("a").is_injured())
	assert_eq(report.of_type("healed").size(), 1)


func test_injured_disciples_rest_whatever_yesterday_was() -> void:
	var sect := _one("a")
	sect.disciple("a").injure(3)
	var plan := DayPlan.new()  # nothing planned: injured disciples rest
	var report := DayResolver.resolve(sect, plan)
	assert_eq(report.of_type("rested").size(), 1)
	assert_eq(report.of_type("trained").size(), 0)


func test_good_huts_heal_two_days_per_day() -> void:
	var sect := _one("a")
	sect.buildings["disciple_huts"] = 2
	sect.disciple("a").injure(4)
	DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
	assert_eq(sect.disciple("a").injury_days(), 2)


func test_everyone_eats_and_food_never_goes_negative() -> void:
	var sect := SimFixtures.sect()
	sect.resources["food"] = 1
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "train"))
	assert_eq(sect.resources["food"], 0)
	assert_eq(report.of_type("ate")[0]["food"], 1)
	var hungry: Array = report.of_type("hungry")[0]["disciples"]
	assert_eq(hungry.size(), 2)
	for id: String in hungry:
		assert_eq(sect.disciple(id).mood, Balance.TRAIN_MOOD + Balance.HUNGRY_MOOD, id)


func test_high_spirits_settle_and_mood_moves_loyalty() -> void:
	var sect := SimFixtures.sect([SimFixtures.disciple("happy", 5, 6), SimFixtures.disciple("sad", 5, -6)])
	DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
	# happy: 6 + 2 rest = 8, then settles to 7; sad: -6 + 2 = -4.
	assert_eq(sect.disciple("happy").mood, 7)
	assert_eq(sect.disciple("sad").mood, -4)
	assert_eq(sect.disciple("happy").loyalty, 51)
	assert_eq(sect.disciple("sad").loyalty, 49)


func test_the_day_ends_with_bookkeeping() -> void:
	var sect := SimFixtures.sect()
	sect.disciple("a").talked_today = true
	var plan := SimFixtures.plan_all(sect, "work")
	plan.tasks["b"] = "train"
	var report := DayResolver.resolve(sect, plan)
	assert_eq(sect.day, 2)
	assert_eq(report.day, 1)
	assert_eq(sect.last_report, report)
	assert_eq(sect.last_tasks, {"a": "work", "b": "train", "c": "work"})
	assert_false(sect.disciple("a").talked_today, "tomorrow's chats start fresh")


func test_an_invalid_plan_changes_nothing() -> void:
	var sect := SimFixtures.sect()
	var before := sect.to_dict()
	var plan := DayPlan.new()
	plan.tasks["ghost"] = "train"
	assert_null(DayResolver.resolve(sect, plan))
	assert_push_error("Invalid day plan")
	assert_eq(sect.to_dict(), before)


func test_the_same_seed_and_plans_give_the_same_days() -> void:
	var a := NewGame.create(555)
	var b := NewGame.create(555)
	for day in 12:
		for sect: Sect in [a, b]:
			var plan := DayPlan.defaults(sect)
			var home := sect.available_disciples()
			if day % 3 == 0 and home.size() >= 2:
				plan.add_mission("hunt_monster", [home[0].id, home[1].id] as Array[String])
			DayResolver.resolve(sect, plan)
	assert_eq(a.to_dict(), b.to_dict())
