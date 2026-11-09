extends GutTest
## Surprise events: when they start, what they pick, and what each choice
## does (M5). The words come from Claude or strings.csv; these rules decide.


func _rich_sect(seed_value: int = 1) -> Sect:
	var sect := SimFixtures.sect([], seed_value)
	sect.resources = {"stones": 500, "food": 100, "herbs": 100, "reputation": 10}
	for building in Balance.BUILDINGS:
		sect.buildings[building] = 1
	sect.day = Balance.EVENT_FIRST_DAY
	return sect


func test_no_event_before_day_three_or_without_two_free_disciples() -> void:
	var sect := _rich_sect()
	sect.day = 2
	for i in 20:
		EventRules.roll(sect)
		assert_true(sect.event.is_empty())
	sect.day = 3
	sect.disciple("a").injure(3)
	sect.disciple("b").status = "left"
	for i in 20:
		EventRules.roll(sect)
		assert_true(sect.event.is_empty(), "only c is free")


func test_an_event_picks_a_problem_a_place_and_a_pair_then_rests() -> void:
	var sect := _rich_sect()
	while sect.event.is_empty():
		EventRules.roll(sect)
	var event := sect.event
	assert_true(event["problem"] in EventCatalog.random_problems())
	assert_true(event["place"] in EventRules.places_for(sect, event["problem"]))
	assert_eq(event["disciples"].size(), 2)
	assert_ne(event["disciples"][0], event["disciples"][1])
	assert_eq(int(event["day"]), sect.day)
	assert_true(EventRules.pending(sect))
	assert_between(sect.next_event_day, sect.day + Balance.EVENT_COOLDOWN[0], sect.day + Balance.EVENT_COOLDOWN[1])
	EventRules.roll(sect)
	assert_true(sect.event.is_empty(), "a cooldown between events")


func test_problems_do_not_repeat_too_soon_and_places_need_their_buildings() -> void:
	var sect := _rich_sect()
	var seen: Array[String] = []
	for day in 200:
		sect.day = day + 3
		sect.next_event_day = 0
		EventRules.roll(sect)
		if sect.event.is_empty():
			continue
		var problem := String(sect.event["problem"])
		assert_false(problem in seen.slice(maxi(0, seen.size() - Balance.EVENT_NO_REPEAT)), problem)
		seen.append(problem)
	var bare := SimFixtures.sect()
	assert_eq(EventRules.places_for(bare, "noodle_thief"), [] as Array[String], "the noodles live in the Kitchen")
	assert_eq(EventRules.places_for(bare, "spirit_goose"), ["misty_pond", "main_gate"] as Array[String])


func test_choosing_pays_the_cost_applies_the_outcome_and_reports_it() -> void:
	var sect := _rich_sect()
	sect.event = EventRules._start(sect, "leaky_roof", "kitchen", ["a", "b"] as Array[String])
	sect.resources["stones"] = 5
	assert_false(EventRules.can_choose(sect, "fix"), "fixing the roof costs 12 Spirit Stones")
	assert_eq(EventRules.choices(sect).map(func(c: Dictionary) -> bool: return c["ok"]), [false, true, true])
	var applied := EventRules.choose(sect, "buckets")
	assert_eq(applied["mood"], {"a": -1, "b": -1})
	assert_eq(applied["rel"], 2)
	assert_eq(Relationships.score(sect, "a", "b"), 2)
	assert_false(EventRules.pending(sect))
	assert_eq([sect.event["choice"], sect.event["result"]], ["buckets", "done"])
	assert_eq(sect.pending_facts, [{"type": "event", "problem": "leaky_roof", "place": "kitchen", "choice": "buckets", "result": "done", "disciples": ["a", "b"]}] as Array[Dictionary])
	assert_eq(EventRules.choose(sect, "ignore"), {}, "only one choice per event")


func test_every_choice_in_the_catalog_can_be_applied() -> void:
	for problem: String in EventCatalog.PROBLEMS:
		for choice_id in EventCatalog.choice_ids(problem):
			for seed_value in 3:
				var sect := _rich_sect(seed_value)
				var ids: Array[String] = ["a"]
				if int(EventCatalog.PROBLEMS[problem]["pair"]) == 2:
					ids.append("b")
				if problem == EventCatalog.RESCUE:
					sect.disciple("a").status = "lost"
				sect.event = EventRules._start(sect, problem, EventCatalog.PROBLEMS[problem]["places"][0], ids)
				var applied := EventRules.choose(sect, choice_id)
				assert_true(sect.event["resolved"], "%s/%s" % [problem, choice_id])
				assert_true(sect.event["result"] in ["win", "lose", "done"])
				for d in sect.disciples:
					assert_between(d.mood, Balance.MOOD_MIN, Balance.MOOD_MAX)
				for resource: String in sect.resources:
					assert_gte(int(sect.resources[resource]), 0)
				if problem == EventCatalog.RESCUE:
					assert_gte(int(applied["return_day"]), sect.day, choice_id)
	assert_eq(EventCatalog.random_problems().size(), 20, "about 20 written events, plus the rescue")


func test_every_problem_has_a_free_choice() -> void:
	for problem: String in EventCatalog.PROBLEMS:
		var free: Array = EventCatalog.PROBLEMS[problem]["choices"].filter(func(c: Dictionary) -> bool: return c.get("cost", {}).is_empty())
		assert_false(free.is_empty(), problem)


func test_the_gateway_request_holds_only_ids() -> void:
	var sect := _rich_sect()
	sect.disciple("b").add_effect("green_hair", 4)
	sect.event = EventRules._start(sect, "frog_duel", "main_gate", ["a", "b"] as Array[String])
	var request := EventRules.request(sect, "vi")
	assert_eq(request.keys(), ["kind", "locale", "game_day", "problem", "place", "disciples"])
	assert_eq([request["kind"], request["problem"], request["place"]], ["event", "frog_duel", "main_gate"])
	assert_eq(request["disciples"][1]["effects"], ["green_hair"])
	assert_eq(request["disciples"][0]["name"], "Thử a")
