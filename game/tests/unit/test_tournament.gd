extends GutTest
## Seasons and the tournament on each season's last day (M6).


func _tournament_sect(seed_value: int = 1, stat_value: int = 5) -> Sect:
	var sect := SimFixtures.sect([
		SimFixtures.disciple("a", stat_value), SimFixtures.disciple("b", stat_value),
		SimFixtures.disciple("c", stat_value), SimFixtures.disciple("d", stat_value),
	], seed_value)
	sect.day = Balance.SEASON_DAYS
	Tournament.night(sect)
	return sect


func test_the_calendar_has_four_seasons_of_thirty_days() -> void:
	assert_eq([Seasons.season(1), Seasons.season(30), Seasons.season(31), Seasons.season(120), Seasons.season(121)],
		["spring", "spring", "summer", "winter", "spring"])
	assert_eq([Seasons.year(120), Seasons.year(121)], [1, 2])
	assert_eq([Seasons.number(1), Seasons.number(31), Seasons.number(121)], [1, 2, 5])
	assert_eq([Seasons.days_to_tournament(1), Seasons.days_to_tournament(30)], [29, 0])
	assert_true(Seasons.is_tournament_day(60))
	assert_false(Seasons.is_season_start(1), "the first day isn't news")
	assert_true(Seasons.is_season_start(61))


func test_a_tournament_opens_on_the_last_day_and_waits_for_the_sect_master() -> void:
	var sect := SimFixtures.sect()
	sect.day = 29
	Tournament.night(sect)
	assert_true(sect.tournament.is_empty())
	sect.day = 30
	Tournament.night(sect)
	assert_true(Tournament.pending(sect))
	assert_eq(World.pending(sect), ["tournament"] as Array[String])


func test_champions_are_checked() -> void:
	var sect := _tournament_sect()
	sect.disciple("d").injure(2)
	assert_eq(Tournament.check(sect, []), ["team_size"] as Array[String])
	assert_eq(Tournament.check(sect, ["a", "b", "c", "d"]).has("team_size"), true)
	assert_eq(Tournament.check(sect, ["d"]), ["not_eligible:d"] as Array[String], "injured")
	assert_eq(Tournament.check(sect, ["a", "a"]), ["not_eligible:a"] as Array[String])
	assert_eq(Tournament.enter(sect, ["d"]), {})


func test_the_bracket_gives_a_place_rewards_and_moods() -> void:
	var places := {}
	for seed_value in 60:
		var sect := _tournament_sect(seed_value)
		var stones := int(sect.resources["stones"])
		var result := Tournament.enter(sect, ["a", "b", "c"])
		var place := int(result["place"])
		places[place] = int(places.get(place, 0)) + 1
		assert_eq(result["matches"].size(), 2)
		var semi: Dictionary = result["matches"][0]
		var second: Dictionary = result["matches"][1]
		assert_eq(place, (1 if second["won"] else 2) if semi["won"] else (3 if second["won"] else 4))
		assert_ne(semi["rival"], second["rival"])
		assert_eq(sect.resources["stones"], stones + int(Balance.TOURNAMENT_REWARDS[place].get("stones", 0)))
		var mood := Balance.TOURNAMENT_PODIUM_MOOD if place <= 3 else Balance.TOURNAMENT_LAST_MOOD
		assert_eq(sect.disciple("a").mood, mood)
		assert_eq(sect.disciple("d").mood, 0, "not a champion")
		assert_false(Tournament.pending(sect))
		var fact: Dictionary = sect.pending_facts[-1]
		assert_eq(fact["type"], "tournament")
		assert_eq(fact["champions"], ["a", "b", "c"])
		assert_eq(sect.chronicle[-1]["type"], "tournament")
	assert_eq(places.size(), 4, "every place happens: %s" % [places])


func test_champions_spend_the_day_at_the_tournament() -> void:
	var sect := _tournament_sect()
	Tournament.enter(sect, ["a", "b"])
	assert_true(sect.is_away("a"))
	assert_false(sect.is_away("c"))
	assert_eq(DayPlan.defaults(sect).tasks.keys(), ["c", "d"])
	var report := DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(report.of_type("tournament").size(), 1, "told in the evening")
	assert_true(sect.tournament.is_empty(), "cleared at night")
	assert_false(sect.is_away("a"))


func test_stronger_champions_place_better_and_rivals_grow_each_season() -> void:
	var weak := _tournament_sect(1, 2)
	var strong := _tournament_sect(1, 10)
	assert_eq(Tournament.likely_place(weak, ["a", "b", "c"]), 4)
	assert_eq(Tournament.likely_place(strong, ["a", "b", "c"]), 1)
	var chances := Tournament.place_chances(weak, ["a", "b", "c"])
	assert_almost_eq(chances[1] + chances[2] + chances[3] + chances[4], 1.0, 0.0001)
	var later := _tournament_sect()
	later.day = Balance.SEASON_DAYS * 4
	assert_almost_eq(Tournament.rival_strength(later, "iron_frog") - Tournament.rival_strength(strong, "iron_frog"), Balance.RIVAL_GROWTH * 3, 0.001)


func test_beating_a_rival_cools_it_and_an_ally_minds_less() -> void:
	var cooled := {}
	for seed_value in 40:
		var sect := _tournament_sect(seed_value, 10)
		sect.rival("moonlit_tea")["ally"] = true
		var before := {}
		for rival in RivalCatalog.ids():
			before[rival] = Rivals.attitude(sect, rival)
		var result := Tournament.enter(sect, ["a", "b", "c"])
		for m: Dictionary in result["matches"]:
			var rival := String(m["rival"])
			var expected := Balance.TOURNAMENT_LOST_ATTITUDE
			if m["won"]:
				expected = Balance.TOURNAMENT_BEAT_ALLY_ATTITUDE if rival == "moonlit_tea" else Balance.TOURNAMENT_BEAT_ATTITUDE
			if int(result["place"]) == 1 and rival != "moonlit_tea":
				expected += Balance.TOURNAMENT_ENVY_ATTITUDE
			assert_eq(Rivals.attitude(sect, rival) - int(before[rival]), expected, rival)
			cooled[rival] = true
	assert_eq(cooled.size(), 3)


func test_sitting_it_out_costs_reputation_and_an_undecided_day_sits_it_out() -> void:
	var sect := _tournament_sect()
	assert_true(Tournament.skip(sect))
	assert_eq(sect.resources["reputation"], 0, "never below zero")
	assert_eq(sect.pending_facts[-1], {"type": "tournament_skipped"})
	var other := _tournament_sect()
	other.resources["reputation"] = 5
	var report := DayResolver.resolve(other, DayPlan.defaults(other))
	assert_eq(other.resources["reputation"], 5 + Balance.TOURNAMENT_SKIP_REPUTATION)
	assert_eq(report.of_type("tournament_skipped").size(), 1)
