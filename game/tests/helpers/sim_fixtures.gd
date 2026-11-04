class_name SimFixtures
extends RefCounted
## Small, fully known sects and disciples for rule tests.


## A disciple with every stat at [param stat_value] and the given Mood.
static func disciple(id: String, stat_value: int = 5, mood: int = 0) -> Disciple:
	var d := Disciple.new()
	d.id = id
	d.name_en = "Test %s" % id
	d.name_vi = "Thử %s" % id
	for stat in Balance.STATS:
		d.stats[stat] = stat_value
	d.quirks.assign(["afraid_of_chickens", "secret_poet"])
	d.mood = mood
	d.loyalty = 50
	d.progress = 0
	return d


## A sect with plenty of resources, no buildings beyond the Main Hall, and the
## given disciples (default: three average ones).
static func sect(disciples: Array = [], seed_value: int = 1) -> Sect:
	var s := Sect.new()
	s.rng = SimRng.new(seed_value)
	s.resources = {"stones": 500, "food": 100, "herbs": 0, "reputation": 0}
	s.buildings["main_hall"] = 1
	if disciples.is_empty():
		disciples = [disciple("a"), disciple("b"), disciple("c")]
	for d: Disciple in disciples:
		s.disciples.append(d)
	return s


## A plan where everyone listed does [param task].
static func plan_all(sect: Sect, task: String) -> DayPlan:
	var plan := DayPlan.new()
	for d in sect.disciples:
		if not sect.is_away(d.id):
			plan.tasks[d.id] = "rest" if d.is_injured() else task
	return plan
