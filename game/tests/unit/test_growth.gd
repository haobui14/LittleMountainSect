extends GutTest
## Recruiting, setbacks (lost and left) and the version 3 save (M5).


func test_a_hopeful_comes_to_the_gate_from_day_three_and_waits_two_days() -> void:
	var sect := SimFixtures.sect()
	sect.day = 2
	Recruiting.roll(sect)
	assert_true(sect.candidate.is_empty(), "not before day 3")
	sect.day = 3
	Recruiting.roll(sect)
	assert_false(sect.candidate.is_empty())
	assert_eq(int(sect.candidate["until"]), 4)
	assert_between(sect.next_candidate_day, 3 + Balance.RECRUIT_EVERY[0], 3 + Balance.RECRUIT_EVERY[1])
	sect.day = 5
	Recruiting.roll(sect)
	assert_true(sect.candidate.is_empty(), "gone after two days")


func test_recruiting_costs_stones_and_needs_room() -> void:
	var sect := SimFixtures.sect()
	sect.day = 3
	Recruiting.roll(sect)
	var hopeful := Recruiting.candidate(sect)
	assert_eq(Recruiting.cost(sect), 50, "20 + 10 per disciple")
	sect.resources["stones"] = 49
	assert_eq(Recruiting.can_accept(sect)["reason"], "not_enough_stones")
	sect.resources["stones"] = 50
	assert_true(Recruiting.accept(sect))
	assert_eq(sect.disciples.size(), 4)
	assert_eq(sect.disciples.back().id, hopeful.id)
	assert_eq(int(sect.resources["stones"]), 0)
	assert_eq(sect.pending_facts.back(), {"type": "recruited", "disciple": hopeful.id})
	sect.day = 20
	Recruiting.roll(sect)
	assert_true(sect.candidate.is_empty(), "the Main Hall holds only 4 at level 1")


func test_a_famous_sect_attracts_talent() -> void:
	var talents := {1: 0, 3: 0}
	for level: int in talents:
		for seed_value in 30:
			var sect := SimFixtures.sect([], seed_value)
			sect.buildings["main_hall"] = level
			sect.day = 3
			Recruiting.roll(sect)
			talents[level] += Recruiting.candidate(sect).stat("talent")
	assert_gt(talents[3], talents[1])


func _disaster(sect: Sect, mission: String, days: int) -> DayReport:
	var m := ActiveMission.new()
	m.mission = mission
	m.team.assign(["a"])
	m.departed_day = sect.day
	m.return_day = sect.day + days - 1
	m.tier = "disaster"
	var report := DayReport.new(sect.day)
	MissionResolver.complete(sect, m, report)
	return report


func test_an_unhappy_disciple_may_leave_and_comes_back_later() -> void:
	var left := 0
	for seed_value in 30:
		var sect := SimFixtures.sect([], seed_value)
		sect.disciple("a").mood = -5
		var report := _disaster(sect, "hunt_monster", 2)
		if report.of_type("left").is_empty():
			continue
		left += 1
		var d := sect.disciple("a")
		assert_eq(d.status, "left")
		assert_true(sect.is_away("a"))
		assert_between(d.return_day, sect.day + Balance.LEFT_DAYS[0], sect.day + Balance.LEFT_DAYS[1])
		sect.day = d.return_day
		var home := DayReport.new(sect.day)
		MissionResolver.bring_home(sect, home)
		assert_eq(home.facts, [{"type": "returned", "disciple": "a", "from": "left"}] as Array[Dictionary])
		assert_eq([d.status, d.mood], ["home", Balance.RETURN_MOOD])
		assert_gte(d.loyalty, Balance.RETURN_LOYALTY)
	assert_gt(left, 0)


func test_a_happy_disciple_never_leaves_and_short_missions_never_lose_anyone() -> void:
	for seed_value in 30:
		var sect := SimFixtures.sect([], seed_value)
		var report := _disaster(sect, "hunt_monster", 2)
		assert_true(report.of_type("left").is_empty())
		assert_true(report.of_type("lost").is_empty())


func test_a_lost_disciple_starts_a_rescue_and_is_home_after_it() -> void:
	var lost := 0
	for seed_value in 40:
		var sect := SimFixtures.sect([], seed_value)
		var report := _disaster(sect, "escort_merchant", 3)
		if report.of_type("lost").is_empty():
			continue
		lost += 1
		assert_eq(sect.status_of("a"), "lost")
		sect.day += 1
		EventRules.roll(sect)
		assert_eq([sect.event["problem"], sect.event["disciples"]], ["rescue", ["a"]])
		sect.resources["stones"] = 100
		EventRules.choose(sect, "hire_guide")
		assert_eq(sect.disciple("a").return_day, sect.day, "a guide brings them home tonight")
		var resolved := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "rest"))
		assert_eq(resolved.of_type("returned").size(), 1)
		assert_eq(sect.status_of("a"), "home")
	assert_gt(lost, 0)


func test_lost_and_left_disciples_are_away_and_do_not_eat() -> void:
	var sect := SimFixtures.sect()
	sect.disciple("a").status = "lost"
	sect.disciple("b").status = "left"
	sect.disciple("b").return_day = 99
	assert_eq(sect.available_disciples().map(func(d: Disciple) -> String: return d.id), ["c"])
	assert_eq(DayPlan.defaults(sect).tasks.keys(), ["c"])
	var report := DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(report.of_type("ate")[0]["food"], 1)
	assert_eq(EveningRules.allowed_actions(sect, sect.disciple("a")), [] as Array[String])
	assert_eq(DiscipleCard.build(sect.disciple("a"), "en", sect)["status"], "lost")


func test_a_version_2_save_migrates_to_version_3() -> void:
	var sect := NewGame.create(7)
	var save := sect.to_dict()
	save["version"] = 2
	for key in ["items", "brews_today", "event", "next_event_day", "recent_problems", "candidate", "next_candidate_day", "pending_facts", "chronicle"]:
		save.erase(key)
	for d: Dictionary in save["disciples"]:
		for key in ["status", "return_day", "technique", "study"]:
			d.erase(key)
	var migrated := SaveMigration.migrate(JSON.parse_string(JSON.stringify(save)))
	assert_true(migrated["ok"])
	var loaded := Sect.from_dict(migrated["data"])
	assert_eq(loaded.item("foundation_pill"), 0)
	assert_true(loaded.event.is_empty())
	assert_eq(loaded.disciples[0].status, "home")
	assert_eq(loaded.disciples[0].technique, 0)
	assert_eq(loaded.to_dict()["version"], Sect.SAVE_VERSION)


func test_a_good_secret_realm_trip_brings_back_a_pill() -> void:
	for tier in ["great", "success", "partial"]:
		var sect := SimFixtures.sect()
		var m := ActiveMission.new()
		m.mission = "explore_secret_realm"
		m.team.assign(["a", "b"])
		m.departed_day = 1
		m.return_day = 4
		m.tier = tier
		var report := DayReport.new(1)
		MissionResolver.complete(sect, m, report)
		var found := report.of_type("found_item")
		if tier == "partial":
			assert_true(found.is_empty(), "only success or better")
			continue
		assert_eq(found.size(), 1, tier)
		assert_eq(sect.item(String(found[0]["item"])), 1)


func test_a_short_handed_sect_gets_a_free_hopeful_without_waiting() -> void:
	var elder := SimFixtures.disciple("e")
	elder.role = "elder"
	var sect := SimFixtures.sect([SimFixtures.disciple("a"), SimFixtures.disciple("b"), elder])
	sect.day = 3
	sect.next_candidate_day = 50
	Recruiting.roll(sect)
	assert_false(sect.candidate.is_empty(), "two disciples (and an Elder) are too few to wait")
	assert_eq(Recruiting.cost(sect), 0)
	sect.resources["stones"] = 0
	assert_true(Recruiting.accept(sect))
	assert_eq(Recruiting.cost(sect), Balance.RECRUIT_COST_BASE + Balance.RECRUIT_COST_PER * 3, "Elders don't count")
	assert_eq(sect.disciples.back().joined_day, 3)
