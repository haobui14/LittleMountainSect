extends Node
## The game in play: the sect, the step of the day, and the plan being made.
## Screens read from here and call these methods; the rules live in game/sim.
##
## A day goes: morning (report) -> plan (tasks, missions, upgrades) ->
## free_time (talk) -> results (what happened, the evening) -> next morning.

const STEPS: Array[String] = ["morning", "plan", "free_time", "results"]

var sect: Sect = null
var step: String = "morning"
var plan: DayPlan = null
## The last finished day, shown on the results screen.
var report: DayReport = null
## False after a save failed (for example in a private browser window).
var saving_works: bool = true
## Tests point this somewhere else so they never touch a player's save.
var save_path: String = SaveStore.DEFAULT_PATH


func has_game() -> bool:
	return sect != null


func has_save() -> bool:
	return SaveStore.has_save(save_path)


## Starts a new sect. A seed of -1 picks one at random.
func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	sect = NewGame.create(seed_value)
	report = null
	_go("morning")
	_save()


## Loads the saved sect and opens its morning. Returns false (and keeps the
## current game) when there is no usable save.
func load_game() -> bool:
	var result := SaveStore.read(save_path)
	if not result["ok"]:
		return false
	sect = result["sect"]
	report = sect.last_report
	_go("morning")
	return true


func start_planning() -> void:
	plan = DayPlan.defaults(sect)
	_go("plan")


func set_task(id: String, task: String) -> void:
	plan.set_task(id, task)
	Events.state_changed.emit()


func add_mission(mission: String, team: Array[String]) -> void:
	plan.add_mission(mission, team)
	Events.state_changed.emit()


func cancel_mission(mission_index: int) -> void:
	var entry: Dictionary = plan.missions[mission_index]
	for id: String in entry["team"].duplicate():
		plan.set_task(id, "rest")
	Events.state_changed.emit()


func plan_errors() -> Array[String]:
	return plan.validate(sect) if plan else ([] as Array[String])


## Builds or upgrades a building right away. Returns false when it can't.
func upgrade(building: String) -> bool:
	if not BuildingRules.upgrade(sect, building):
		return false
	_save()
	Events.state_changed.emit()
	return true


## Moves on from planning to free time, when the plan is valid.
func finish_planning() -> bool:
	if not plan_errors().is_empty():
		return false
	_go("free_time")
	return true


## Talks with a disciple in free time. Returns the Mood gained (0 if they
## already talked today).
func talk(id: String) -> int:
	var gained := FreeTime.talk(sect.disciple(id))
	Events.state_changed.emit()
	return gained


## Runs the day's rules, saves, and opens the results.
func end_day() -> DayReport:
	var result := DayResolver.resolve(sect, plan)
	if result == null:
		return null
	report = result
	plan = null
	_save()
	_go("results")
	Events.day_resolved.emit(result)
	return result


func next_morning() -> void:
	_go("morning")


func _go(next_step: String) -> void:
	assert(next_step in STEPS)
	step = next_step
	Events.state_changed.emit()


func _save() -> void:
	saving_works = SaveStore.write(sect, save_path)
