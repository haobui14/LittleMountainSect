extends GutTest
## The rival sects (M6): Attitude and Trust, gifts, trades, alliances,
## betrayal, and the rival problems among the surprise events.


func _sect() -> Sect:
	var sect := SimFixtures.sect()
	sect.resources = {"stones": 500, "food": 100, "herbs": 100, "reputation": 10}
	sect.day = 10
	return sect


func test_rivals_start_at_their_own_attitude_and_drift_back_to_it() -> void:
	var sect := _sect()
	assert_eq(Rivals.attitude(sect, "iron_frog"), -20)
	assert_eq(Rivals.attitude(sect, "moonlit_tea"), 10)
	assert_eq(Rivals.trust(sect, "perfect_hair"), Balance.START_TRUST)
	sect.rival("iron_frog")["attitude"] = -23
	sect.rival("moonlit_tea")["attitude"] = 12
	sect.day = Balance.ATTITUDE_DRIFT_EVERY * 4
	Rivals.night(sect)
	assert_eq(Rivals.attitude(sect, "iron_frog"), -22)
	assert_eq(Rivals.attitude(sect, "moonlit_tea"), 11)
	sect.day += 1
	Rivals.night(sect)
	assert_eq(Rivals.attitude(sect, "moonlit_tea"), 11, "only every few days")
	assert_eq(Rivals.attitude(sect, "perfect_hair"), 0, "already home")


func test_attitude_reads_as_words() -> void:
	var sect := _sect()
	var words := []
	for a in [-80, -25, -10, 0, 20, 40]:
		sect.rival("iron_frog")["attitude"] = a
		words.append(Rivals.mood_word(sect, "iron_frog"))
	assert_eq(words, ["hostile", "cold", "wary", "neutral", "friendly", "warm"])
	sect.rival("iron_frog")["ally"] = true
	assert_eq(Rivals.mood_word(sect, "iron_frog"), "allied")


func test_a_favourite_gift_counts_more_and_gifts_wait_five_days() -> void:
	var sect := _sect()
	assert_eq(Rivals.gift(sect, "iron_frog", "food"), Balance.GIFT_FAVOURITE_ATTITUDE)
	assert_eq(sect.resources["food"], 100 - Balance.GIFT_COST["food"])
	assert_eq(Rivals.trust(sect, "iron_frog"), Balance.START_TRUST + Balance.GIFT_TRUST)
	assert_eq(sect.pending_facts[-1], {"type": "gift", "rival": "iron_frog", "resource": "food", "amount": 10})
	assert_eq(Rivals.can_gift(sect, "iron_frog", "stones")["reason"], "too_soon")
	assert_eq(Rivals.gift(sect, "iron_frog", "stones"), -1)
	assert_eq(Rivals.gift(sect, "moonlit_tea", "stones"), Balance.GIFT_ATTITUDE, "another rival is fine")
	sect.day += Balance.GIFT_EVERY
	assert_true(Rivals.can_gift(sect, "iron_frog", "stones")["ok"])
	sect.resources["herbs"] = 3
	assert_eq(Rivals.can_gift(sect, "perfect_hair", "herbs")["reason"], "not_enough")


func test_each_rival_offers_one_trade_a_period() -> void:
	var sect := _sect()
	var deal := Rivals.offer(sect, "moonlit_tea")
	assert_eq(deal, RivalCatalog.RIVALS["moonlit_tea"]["trades"][0])
	assert_true(Rivals.trade(sect, "moonlit_tea"))
	assert_eq(sect.resources["herbs"], 100 - 15)
	assert_eq(sect.resources["stones"], 500 + 30)
	assert_eq(Rivals.attitude(sect, "moonlit_tea"), 10 + Balance.TRADE_ATTITUDE)
	assert_eq(sect.pending_facts[-1], {"type": "trade", "rival": "moonlit_tea", "gave": {"herbs": 15}, "got": {"stones": 30}})
	assert_eq(Rivals.can_trade(sect, "moonlit_tea")["reason"], "done")
	sect.day = Rivals.next_trade_day(sect)
	assert_eq(Rivals.offer(sect, "moonlit_tea"), RivalCatalog.RIVALS["moonlit_tea"]["trades"][1], "the next deal")
	assert_true(Rivals.can_trade(sect, "moonlit_tea")["ok"])
	sect.rival("iron_frog")["attitude"] = -40
	assert_eq(Rivals.can_trade(sect, "iron_frog")["reason"], "cold")


func test_an_alliance_needs_attitude_and_trust_and_ending_it_hurts() -> void:
	var sect := _sect()
	assert_eq(Rivals.can_ally(sect, "perfect_hair")["reason"], "attitude")
	sect.rival("perfect_hair")["attitude"] = 55
	assert_eq(Rivals.can_ally(sect, "perfect_hair")["reason"], "trust")
	sect.rival("perfect_hair")["trust"] = 50
	assert_true(Rivals.ally(sect, "perfect_hair"))
	assert_eq(Rivals.mood_word(sect, "perfect_hair"), "allied")
	assert_eq(sect.chronicle[-1]["type"], "alliance")
	assert_true(Rivals.end_alliance(sect, "perfect_hair"))
	assert_false(Rivals.is_ally(sect, "perfect_hair"))
	assert_eq(Rivals.attitude(sect, "perfect_hair"), 55 + Balance.END_ALLIANCE_ATTITUDE)
	assert_eq(Rivals.trust(sect, "perfect_hair"), 50 + Balance.END_ALLIANCE_TRUST)
	assert_eq(sect.pending_facts[-1]["by"], "player")


func test_allies_send_stones_each_season_and_lose_trust_unless_kept_up() -> void:
	var sect := _sect()
	sect.rival("moonlit_tea")["ally"] = true
	sect.rival("moonlit_tea")["trust"] = 60
	sect.day = Balance.SEASON_DAYS + 1
	var stones := int(sect.resources["stones"])
	Seasons.night(sect)
	assert_eq(sect.resources["stones"], stones + Balance.ALLY_SEASON_STONES)
	assert_eq(sect.pending_facts[0], {"type": "season", "season": "summer", "year": 1})
	assert_eq(sect.pending_facts[1], {"type": "ally_gift", "rival": "moonlit_tea", "stones": 20})
	for day in 30:
		sect.day = 40 + day
		Rivals.night(sect)
	assert_eq(Rivals.trust(sect, "moonlit_tea"), 60 - 10, "1 Trust every 3 days")


func test_a_neglected_ally_may_betray_the_sect() -> void:
	var betrayed := 0
	for seed_value in 300:
		var sect := SimFixtures.sect([], seed_value)
		sect.resources["stones"] = 200
		sect.rival("iron_frog")["ally"] = true
		sect.rival("iron_frog")["trust"] = Balance.BETRAYAL_TRUST - 1
		sect.day = 11
		Rivals.night(sect)
		if Rivals.is_ally(sect, "iron_frog"):
			continue
		betrayed += 1
		var fact: Dictionary = sect.pending_facts[-1]
		assert_eq(fact["type"], "betrayal")
		assert_eq(fact["stones"], 30, "15% of 200")
		assert_eq(sect.resources["stones"], 170)
		assert_eq(sect.chronicle[-1]["type"], "betrayal")
	assert_between(betrayed, 3, 30, "about 4% of nights")
	var loyal := SimFixtures.sect()
	loyal.rival("iron_frog")["ally"] = true
	loyal.rival("iron_frog")["trust"] = Balance.BETRAYAL_TRUST
	for day in 100:
		loyal.day = 100 + day * 3 + 1
		Rivals.night(loyal)
	assert_true(Rivals.is_ally(loyal, "iron_frog"), "trusting allies never betray")


func test_rival_problems_change_that_rivals_attitude() -> void:
	var rivals := {}
	for problem: String in EventCatalog.PROBLEMS:
		var rival := String(EventCatalog.PROBLEMS[problem].get("rival", ""))
		if rival != "":
			assert_true(rival in RivalCatalog.ids(), problem)
			rivals[problem] = rival
	assert_eq(rivals, {
		"frog_duel": "iron_frog",
		"rival_prank": "iron_frog",
		"tea_invitation": "moonlit_tea",
		"free_haircut": "perfect_hair",
		"hair_contest": "perfect_hair",
		"tea_spy": "moonlit_tea",
		"frog_choir": "iron_frog",
	})
	var sect := _sect()
	sect.event = {"day": 10, "problem": "tea_spy", "place": "library", "disciples": ["a", "b"], "resolved": false, "choice": "", "result": "", "applied": {}, "words": {}}
	var applied := EventRules.choose(sect, "invite_tea")
	assert_eq(applied["attitude"], {"moonlit_tea": 5})
	assert_eq(Rivals.attitude(sect, "moonlit_tea"), 15)
