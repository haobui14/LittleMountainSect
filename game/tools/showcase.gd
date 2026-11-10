class_name Showcase
extends RefCounted
## A sect with a bit of everything M5 adds, for the screen test
## (tests/unit/test_screens.gd) and the screenshot tool (state_shots.gd):
## a surprise event waiting for a choice, a hopeful at the gate, pills and
## the Alchemy Room to brew more, a disciple ready to break through, a side
## effect, an injury, a learned technique and a disciple who left.


static func sect() -> Sect:
	var sect := NewGame.create(7)
	sect.day = 12
	var levels := {
		"main_hall": 2, "disciple_huts": 1, "training_yard": 1, "spirit_field": 2,
		"kitchen": 1, "alchemy_room": 3, "library": 1, "mission_hall": 2,
	}
	for building: String in levels:
		sect.buildings[building] = levels[building]
	sect.resources["stones"] = 140
	sect.resources["food"] = 30
	sect.resources["herbs"] = 40
	sect.resources["reputation"] = 22
	sect.items["foundation_pill"] = 1
	sect.items["healing_pill"] = 1
	for i in 2:
		sect.disciples.append(DiscipleGenerator.generate(sect))

	var ready := sect.disciples[0]
	ready.progress = Balance.PROGRESS_MAX
	ready.mood = 3
	var green := sect.disciples[1]
	green.add_effect("green_hair", 4)
	green.technique = 1
	green.study = 40
	sect.disciples[2].injure(2)
	var gone := sect.disciples[3]
	gone.status = "left"
	gone.return_day = 20

	sect.event = EventRules._start(sect, "wandering_master", "bamboo_grove", [green.id, ready.id])
	sect.next_candidate_day = sect.day
	Recruiting.roll(sect)
	return sect


## A sect deep into its first year, with everything the world (M6) adds: the
## season's tournament waiting for champions, a war on its way, an ally, an
## Elder, a traveller's letter, another disciple asking to travel, and a
## Chronicle with a few seasons in it.
static func world_sect() -> Sect:
	var sect := NewGame.create(9)
	sect.day = Balance.SEASON_DAYS * 2
	for building: String in Balance.BUILDINGS:
		sect.buildings[building] = 2
	sect.resources = {"stones": 260, "food": 60, "herbs": 70, "reputation": 48}
	for i in 3:
		var d := DiscipleGenerator.generate(sect)
		d.joined_day = 1
		sect.disciples.append(d)
	var elder := sect.disciples[0]
	elder.realm = "golden_core"
	elder.loyalty = 82
	elder.role = "elder"
	var asking := sect.disciples[1]
	asking.realm = "foundation_building"
	var traveller := sect.disciples[2]
	traveller.realm = "foundation_building"
	traveller.status = "travel"
	traveller.return_day = sect.day + 9
	traveller.travel = {"place": "noodle_town", "left_day": sect.day - 12, "next_letter_day": sect.day + 7}
	sect.letter = {"day": sect.day, "disciple": traveller.id, "place": "noodle_town", "days_away": 12, "gift": {"food": 7}, "item": "none", "words": ""}
	sect.travel_request = {"disciple": asking.id, "place": "snow_peaks", "days": 20, "day": sect.day}

	sect.rival("moonlit_tea")["attitude"] = 58
	sect.rival("moonlit_tea")["trust"] = 61
	sect.rival("moonlit_tea")["ally"] = true
	sect.rival("perfect_hair")["attitude"] = 22
	sect.rival("perfect_hair")["trust"] = 44
	sect.rival("iron_frog")["attitude"] = -44
	sect.war = {"rival": "iron_frog", "declared_day": sect.day - 1, "battle_day": sect.day + 2, "resolved": false, "defenders": [], "won": false}
	Tournament.night(sect)

	# A Chronicle with two seasons in it.
	for entry: Dictionary in [
		{"day": 9, "type": "recruited", "disciple": sect.disciples[3].id},
		{"day": 21, "type": "breakthrough", "disciple": asking.id, "realm": "foundation_building"},
		{"day": 30, "type": "tournament", "place": 2, "season": "spring", "year": 1},
		{"day": 38, "type": "rank_up", "rank": "rising_sect"},
		{"day": 44, "type": "alliance", "rival": "moonlit_tea"},
		{"day": 48, "type": "travel_left", "disciple": traveller.id, "place": "noodle_town"},
		{"day": 59, "type": "war_declared", "rival": "iron_frog"},
	]:
		sect.chronicle.append(entry)
	sect.chronicle.append({"day": sect.day, "type": "promoted", "disciple": elder.id})
	return sect
