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
