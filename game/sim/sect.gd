class_name Sect
extends RefCounted
## The whole game state: the day, resources, buildings, disciples, missions
## and the random generator. [method to_dict] is the save; it carries a
## version number so older saves can be upgraded (see SaveMigration).

const SAVE_VERSION := 1

var day: int = 1
var resources: Dictionary = {"stones": 0, "food": 0, "herbs": 0, "reputation": 0}
## Building id -> level (0 means not built). Every id in Balance.BUILDINGS.
var buildings: Dictionary = {}
var disciples: Array[Disciple] = []
var missions: Array[ActiveMission] = []
var rng: SimRng = SimRng.new()
## Used to give each new disciple a unique id ("d1", "d2", ...).
var next_disciple_number: int = 1
## Each disciple's home task yesterday, so the day plan can repeat it.
var last_tasks: Dictionary = {}
## The report of the last finished day, or null before day 1 ends.
var last_report: DayReport = null


func _init() -> void:
	for id in Balance.BUILDINGS:
		buildings[id] = 0


func level(building: String) -> int:
	return int(buildings.get(building, 0))


func disciple(id: String) -> Disciple:
	for d in disciples:
		if d.id == id:
			return d
	return null


## The mission a disciple is away on, or null when they are home.
func mission_of(id: String) -> ActiveMission:
	for m in missions:
		if id in m.team:
			return m
	return null


func is_away(id: String) -> bool:
	return mission_of(id) != null


## Disciples at home and not injured: the ones the player can plan for freely.
func available_disciples() -> Array[Disciple]:
	var out: Array[Disciple] = []
	out.assign(disciples.filter(func(d: Disciple) -> bool: return not is_away(d.id) and not d.is_injured()))
	return out


func rank() -> String:
	return Balance.RANKS[clampi(level("main_hall"), 0, Balance.MAX_LEVEL)]


func disciple_limit() -> int:
	return Balance.DISCIPLE_LIMIT[clampi(level("main_hall"), 0, Balance.MAX_LEVEL)]


## Adds (or, with a negative amount, takes) a resource. Resources never go
## below zero; returns the amount actually changed.
func add_resource(name: String, amount: int) -> int:
	assert(name in Balance.RESOURCES, "Unknown resource: %s" % name)
	var before := int(resources[name])
	resources[name] = maxi(0, before + amount)
	return int(resources[name]) - before


func new_disciple_id() -> String:
	var id := "d%d" % next_disciple_number
	next_disciple_number += 1
	return id


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"resources": resources.duplicate(),
		"buildings": buildings.duplicate(),
		"disciples": disciples.map(func(d: Disciple) -> Dictionary: return d.to_dict()),
		"missions": missions.map(func(m: ActiveMission) -> Dictionary: return m.to_dict()),
		"rng": rng.to_dict(),
		"next_disciple_number": next_disciple_number,
		"last_tasks": last_tasks.duplicate(),
		"last_report": last_report.to_dict() if last_report else null,
	}


## Builds a sect from a save. Call SaveMigration.migrate() first for saves
## that may be older than SAVE_VERSION.
static func from_dict(data: Dictionary) -> Sect:
	assert(int(data.get("version", 0)) == SAVE_VERSION, "Migrate the save before loading it")
	var s := Sect.new()
	s.day = int(data["day"])
	for name in Balance.RESOURCES:
		s.resources[name] = int(data["resources"][name])
	for id in Balance.BUILDINGS:
		s.buildings[id] = int(data["buildings"].get(id, 0))
	for d: Dictionary in data["disciples"]:
		s.disciples.append(Disciple.from_dict(d))
	for m: Dictionary in data["missions"]:
		s.missions.append(ActiveMission.from_dict(m))
	s.rng = SimRng.from_dict(data["rng"])
	s.next_disciple_number = int(data["next_disciple_number"])
	for id: String in data["last_tasks"]:
		s.last_tasks[id] = String(data["last_tasks"][id])
	if data["last_report"] != null:
		s.last_report = DayReport.from_dict(data["last_report"])
	return s
