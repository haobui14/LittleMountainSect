extends GutTest
## Wars over land (M6): declarations, calling them off, peace, and battles.


func _hostile_sect(seed_value: int = 1, stat_value: int = 5) -> Sect:
	var sect := SimFixtures.sect([
		SimFixtures.disciple("a", stat_value), SimFixtures.disciple("b", stat_value),
		SimFixtures.disciple("c", stat_value), SimFixtures.disciple("d", stat_value),
	], seed_value)
	sect.resources = {"stones": 200, "food": 100, "herbs": 0, "reputation": 20}
	sect.day = 40
	sect.rival("iron_frog")["attitude"] = -80
	return sect


func _declared(seed_value: int = 1, stat_value: int = 5) -> Sect:
	var sect := _hostile_sect(seed_value, stat_value)
	while sect.war.is_empty():
		Wars.night(sect)
	return sect


func test_only_a_hostile_rival_that_is_not_an_ally_declares_war() -> void:
	var calm := SimFixtures.sect()
	calm.day = 40
	for i in 50:
		Wars.night(calm)
	assert_true(calm.war.is_empty())
	var allied := _hostile_sect()
	allied.rival("iron_frog")["ally"] = true
	for i in 50:
		Wars.night(allied)
	assert_true(allied.war.is_empty())
	var sect := _declared()
	assert_eq(sect.war["rival"], "iron_frog")
	assert_eq(int(sect.war["battle_day"]), sect.day + Balance.WAR_WARNING_DAYS)
	assert_eq(sect.pending_facts[-1], {"type": "war_declared", "rival": "iron_frog", "battle_day": 43})
	assert_true(Wars.at_war_with(sect, "iron_frog"))
	assert_false(Wars.pending(sect), "the battle is days away")
	assert_eq(Rivals.can_trade(sect, "iron_frog")["reason"], "at_war")


func test_wars_wait_twenty_days_after_the_last() -> void:
	var sect := _hostile_sect()
	sect.last_war_day = sect.day - Balance.WAR_COOLDOWN + 1
	for i in 50:
		Wars.night(sect)
	assert_true(sect.war.is_empty())


func test_gifts_that_warm_the_rival_call_the_war_off() -> void:
	var sect := _declared()
	sect.rival("iron_frog")["attitude"] = -38
	Rivals.gift(sect, "iron_frog", "food")
	assert_true(sect.war.is_empty(), "-38 + 10 is above -30")
	assert_eq(sect.pending_facts[-1], {"type": "peace", "rival": "iron_frog", "paid": 0})


func test_peace_costs_stones_by_the_hill() -> void:
	var sect := _declared()
	assert_eq(Wars.peace_cost(sect), Balance.PEACE_BASE + Balance.PEACE_PER_HILL * sect.land)
	assert_true(Wars.make_peace(sect))
	assert_eq(sect.resources["stones"], 200 - 50)
	assert_eq(Rivals.attitude(sect, "iron_frog"), Balance.PEACE_ATTITUDE)
	assert_true(sect.war.is_empty())
	assert_eq(sect.pending_facts[-1]["paid"], 50)
	var poor := _declared()
	poor.resources["stones"] = 10
	assert_false(Wars.make_peace(poor))


func test_the_battle_morning_waits_and_a_win_takes_a_hill() -> void:
	var sect: Sect = null
	for seed_value in 20:
		sect = _declared(seed_value, 10)
		sect.day = int(sect.war["battle_day"])
		assert_true(Wars.pending(sect))
		assert_eq(World.pending(sect), ["battle"] as Array[String])
		assert_gt(Wars.win_chance(sect, ["a", "b", "c", "d"]), 0.9)
		assert_eq(Wars.check(sect, ["a", "b", "c", "d", "a"]).has("team_size"), true)
		if Wars.defend(sect, ["a", "b", "c", "d"])["won"]:
			break
	assert_true(sect.war["won"])
	assert_eq(sect.land, Balance.LAND_START + 1)
	assert_eq(sect.resources["stones"], 200 + Balance.WAR_WIN_STONES)
	assert_eq(sect.resources["reputation"], 20 + Balance.WAR_WIN_REPUTATION)
	assert_eq(Rivals.attitude(sect, "iron_frog"), Balance.WAR_WIN_ATTITUDE)
	assert_eq(sect.pending_facts[-1], {"type": "war_result", "rival": "iron_frog", "won": true, "defenders": ["a", "b", "c", "d"], "land": 3})
	assert_true(sect.is_away("a"), "defenders spend the day fighting")
	Wars.night(sect)
	assert_true(sect.war.is_empty())
	assert_eq(sect.last_war_day, sect.day)


func test_a_lost_battle_costs_a_hill_stones_and_maybe_light_injuries() -> void:
	var hurt := 0
	for seed_value in 30:
		var sect := _declared(seed_value, 1)
		sect.day = int(sect.war["battle_day"])
		var result := Wars.defend(sect, ["a", "b"])
		if result["won"]:
			continue
		assert_eq(sect.land, Balance.LAND_START - 1)
		assert_eq(sect.resources["stones"], 200 - 50, "a quarter, at most 60")
		assert_eq(sect.resources["reputation"], 20 + Balance.WAR_LOSE_REPUTATION)
		for id in ["a", "b"]:
			if sect.disciple(id).is_injured():
				hurt += 1
				assert_eq(sect.disciple(id).injury_days(), Balance.WAR_INJURY_DAYS)
	assert_gt(hurt, 0)
	for seed_value in 20:
		var last := _declared(seed_value, 1)
		last.land = Balance.LAND_MIN
		last.day = int(last.war["battle_day"])
		if not Wars.defend(last, [])["won"]:
			assert_eq(last.land, Balance.LAND_MIN, "never below one hill")
			assert_eq(last.pending_facts[-1]["defenders"], [], "told even with nobody home")
			return
	fail_test("no lost battle in 20 seeds")


func test_allies_fight_beside_the_sect() -> void:
	var sect := _declared()
	sect.day = int(sect.war["battle_day"])
	var alone := Wars.defense(sect, ["a"])
	sect.rival("perfect_hair")["ally"] = true
	assert_almost_eq(Wars.defense(sect, ["a"]) - alone, Tournament.rival_strength(sect, "perfect_hair") * Balance.ALLY_WAR_SHARE, 0.001)


func test_hills_give_food_and_herbs_every_day() -> void:
	var sect := SimFixtures.sect()
	sect.land = 4
	var report := DayResolver.resolve(sect, SimFixtures.plan_all(sect, "train"))
	assert_eq(report.resource_changes["herbs"], 4 * Balance.LAND_HERBS)
	assert_eq(report.resource_changes["food"], 4 * Balance.LAND_FOOD - 3)
