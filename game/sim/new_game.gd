class_name NewGame
extends RefCounted
## The GDD's start: a leaky hut (Main Hall level 1), 3 unknown disciples and a
## small bag of Spirit Stones. The strange Elder has no stats; he arrives as a
## voice in M4.


static func create(seed_value: int) -> Sect:
	var sect := Sect.new()
	sect.rng = SimRng.new(seed_value)
	sect.day = 1
	for name in Balance.RESOURCES:
		sect.resources[name] = int(Balance.START_RESOURCES[name])
	for building: String in Balance.START_BUILDINGS:
		sect.buildings[building] = int(Balance.START_BUILDINGS[building])
	for i in Balance.START_DISCIPLES:
		sect.disciples.append(DiscipleGenerator.generate(sect))
	return sect
