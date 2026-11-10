class_name Sect
extends RefCounted
## The whole game state: the day, resources, buildings, disciples, missions
## and the random generator. [method to_dict] is the save; it carries a
## version number so older saves can be upgraded (see SaveMigration).

const SAVE_VERSION := 4

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
## How each pair of disciples gets along: "a|b" (ids in sorted order) -> score.
var relationships: Dictionary = {}
## Choices disciples made for themselves in the evening story:
## id -> {action, task, reason, day, overruled}.
var decisions: Dictionary = {}
## Goes up on every save; the server keeps the save with the highest one.
var revision: int = 0
## The last evening story (AI or written), so a reload can show it and the
## next morning can use its report: {day, source, story, morning_report,
## decisions, relationships}, or {}.
var evening: Dictionary = {}
## Pills in the Alchemy Room's store (id -> count), and how many were brewed
## today.
var items: Dictionary = {}
var brews_today: int = 0
## This morning's surprise event (EventRules), or {} when there is none.
var event: Dictionary = {}
## The first day the next random event may start, and the latest problems,
## so they don't repeat too soon.
var next_event_day: int = 0
var recent_problems: Array[String] = []
## A hopeful waiting at the gate (Recruiting): {disciple, until}, or {}.
var candidate: Dictionary = {}
var next_candidate_day: int = 0
## Facts from the morning (events, recruits, pills) that go into today's
## report, so the evening story can tell them.
var pending_facts: Array[Dictionary] = []
## Big moments for the Sect Chronicle (M6): [{day, type, ...}], newest last.
var chronicle: Array[Dictionary] = []

# The world beyond the mountain (M6) -------------------------------------------
## Each rival sect (RivalCatalog id) -> {attitude, trust, ally, gift_day,
## trade_period}: the last day it got a gift and the last trading period it
## traded in.
var rivals: Dictionary = {}
## How many hills the sect holds (Balance.LAND_MIN to LAND_MAX).
var land: int = Balance.LAND_START
## The current war (Wars), or {}: {rival, declared_day, battle_day,
## resolved, defenders, won}.
var war: Dictionary = {}
var last_war_day: int = -Balance.WAR_COOLDOWN
## Today's tournament (Tournament), or {}: {day, resolved, skipped,
## champions, place, matches, rewards}.
var tournament: Dictionary = {}
## A disciple asking to travel (Generations), or {}: {disciple, place, days, day}.
var travel_request: Dictionary = {}
var next_travel_day: int = 0
## This morning's letter from a traveller, or {}: {day, disciple, place,
## days_away, gift, item, words}.
var letter: Dictionary = {}
## Disciples who ascended, so the Chronicle can still name them:
## [{id, name_en, name_vi, realm, day}].
var alumni: Array[Dictionary] = []


func _init() -> void:
	for id in Balance.BUILDINGS:
		buildings[id] = 0
	for pill in Balance.PILLS:
		items[pill] = 0
	for rival in RivalCatalog.ids():
		rivals[rival] = {
			"attitude": int(RivalCatalog.RIVALS[rival]["attitude"]),
			"trust": Balance.START_TRUST,
			"ally": false,
			"gift_day": -Balance.GIFT_EVERY,
			"trade_period": -1,
		}


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


## On a mission, lost, left, travelling or ascended, or busy at today's
## tournament or battle: not at home for the day's tasks.
func is_away(id: String) -> bool:
	if mission_of(id) != null or busy_today(id):
		return true
	var d := disciple(id)
	return d != null and d.status != "home"


## A champion at today's tournament or a defender in today's battle.
func busy_today(id: String) -> bool:
	if not tournament.is_empty() and int(tournament["day"]) == day and id in tournament["champions"]:
		return true
	return not war.is_empty() and int(war["battle_day"]) == day and id in war["defenders"]


## "home", "mission", "lost", "left", "travel" or "ascended" (Balance.STATUSES).
func status_of(id: String) -> String:
	if mission_of(id) != null:
		return "mission"
	var d := disciple(id)
	return d.status if d else "home"


func item(pill: String) -> int:
	return int(items.get(pill, 0))


## Adds (or takes) pills, kept between 0 and Balance.PILL_MAX. Returns the change.
func add_item(pill: String, amount: int) -> int:
	assert(pill in Balance.PILLS, "Unknown pill: %s" % pill)
	var before := item(pill)
	items[pill] = clampi(before + amount, 0, Balance.PILL_MAX)
	return item(pill) - before


## Records a big moment for the Sect Chronicle.
func chronicle_add(type: String, fields: Dictionary = {}) -> void:
	var entry := {"day": day, "type": type}
	entry.merge(fields)
	chronicle.append(entry)
	if chronicle.size() > Balance.CHRONICLE_MAX:
		chronicle = chronicle.slice(chronicle.size() - Balance.CHRONICLE_MAX)


## Disciples at home and not injured: the ones the player can plan for
## freely. Elders teach instead of taking tasks.
func available_disciples() -> Array[Disciple]:
	var out: Array[Disciple] = []
	out.assign(disciples.filter(func(d: Disciple) -> bool: return not is_away(d.id) and not d.is_injured() and not d.is_elder()))
	return out


## Disciples who count toward the Main Hall's limit: everyone but Elders and
## those who ascended today.
func member_count() -> int:
	return disciples.filter(func(d: Disciple) -> bool: return not d.is_elder() and d.status != "ascended").size()


func elder_count() -> int:
	return disciples.filter(func(d: Disciple) -> bool: return d.is_elder()).size()


## A rival's state (see [member rivals]).
func rival(id: String) -> Dictionary:
	return rivals[id]


## A display name for a disciple id, including those who ascended.
func name_of(id: String, locale: String) -> String:
	var d := disciple(id)
	if d:
		return d.display_name(locale)
	for alum in alumni:
		if alum["id"] == id:
			return String(alum["name_vi"] if locale == "vi" else alum["name_en"])
	return id


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
		"relationships": relationships.duplicate(),
		"decisions": decisions.duplicate(true),
		"revision": revision,
		"evening": evening.duplicate(true),
		"items": items.duplicate(),
		"brews_today": brews_today,
		"event": event.duplicate(true),
		"next_event_day": next_event_day,
		"recent_problems": recent_problems.duplicate(),
		"candidate": candidate.duplicate(true),
		"next_candidate_day": next_candidate_day,
		"pending_facts": pending_facts.duplicate(true),
		"chronicle": chronicle.duplicate(true),
		"rivals": rivals.duplicate(true),
		"land": land,
		"war": war.duplicate(true),
		"last_war_day": last_war_day,
		"tournament": tournament.duplicate(true),
		"travel_request": travel_request.duplicate(true),
		"next_travel_day": next_travel_day,
		"letter": letter.duplicate(true),
		"alumni": alumni.duplicate(true),
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
	for pair: String in data["relationships"]:
		s.relationships[pair] = int(data["relationships"][pair])
	for id: String in data["decisions"]:
		var decision: Dictionary = data["decisions"][id]
		s.decisions[id] = {
			"action": String(decision["action"]),
			"task": String(decision["task"]),
			"reason": String(decision["reason"]),
			"day": int(decision["day"]),
			"overruled": bool(decision["overruled"]),
		}
	s.revision = int(data["revision"])
	s.evening = DayReport._whole_numbers(data["evening"])
	for pill in Balance.PILLS:
		s.items[pill] = int(data["items"].get(pill, 0))
	s.brews_today = int(data["brews_today"])
	s.event = DayReport._whole_numbers(data["event"])
	s.next_event_day = int(data["next_event_day"])
	s.recent_problems.assign(Array(data["recent_problems"]).map(func(p: Variant) -> String: return String(p)))
	s.candidate = DayReport._whole_numbers(data["candidate"])
	s.next_candidate_day = int(data["next_candidate_day"])
	for fact: Dictionary in data["pending_facts"]:
		s.pending_facts.append(DayReport._whole_numbers(fact))
	for entry: Dictionary in data["chronicle"]:
		s.chronicle.append(DayReport._whole_numbers(entry))
	for rival in RivalCatalog.ids():
		var state: Dictionary = data["rivals"].get(rival, {})
		for key: String in state:
			s.rivals[rival][key] = bool(state[key]) if key == "ally" else int(state[key])
	s.land = int(data["land"])
	s.war = DayReport._whole_numbers(data["war"])
	s.last_war_day = int(data["last_war_day"])
	s.tournament = DayReport._whole_numbers(data["tournament"])
	s.travel_request = DayReport._whole_numbers(data["travel_request"])
	s.next_travel_day = int(data["next_travel_day"])
	s.letter = DayReport._whole_numbers(data["letter"])
	for alum: Dictionary in data["alumni"]:
		s.alumni.append(DayReport._whole_numbers(alum))
	return s
