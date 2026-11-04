class_name DayPlan
extends RefCounted
## The player's plan for one day: a home task for each disciple (train, work
## or rest) and teams sent on missions. [method validate] lists every problem,
## so the day plan screen can show them before the day runs.

## Disciple id -> "train" | "work" | "rest". Disciples left out rest.
var tasks: Dictionary = {}
## [{"mission": id, "team": [disciple ids]}]
var missions: Array[Dictionary] = []


## For disciples at home: their own decision for today if they made one,
## otherwise yesterday's task. Injured disciples rest.
static func defaults(sect: Sect) -> DayPlan:
	var plan := DayPlan.new()
	for d in sect.disciples:
		if sect.is_away(d.id):
			continue
		var task := Decisions.task_for_today(sect, d.id)
		if task == "":
			task = String(sect.last_tasks.get(d.id, "rest"))
		plan.tasks[d.id] = "rest" if d.is_injured() else task
	return plan


func set_task(id: String, task: String) -> void:
	remove_from_missions(id)
	tasks[id] = task


func add_mission(mission: String, team: Array[String]) -> void:
	for id in team:
		tasks.erase(id)
		remove_from_missions(id)
	missions.append({"mission": mission, "team": team.duplicate()})


## Puts a disciple in the team for [param mission], starting the team if
## needed. Each mission takes one team per day.
func join_mission(mission: String, id: String) -> void:
	tasks.erase(id)
	remove_from_missions(id)
	for entry in missions:
		if entry["mission"] == mission:
			entry["team"].append(id)
			return
	missions.append({"mission": mission, "team": [id]})


## The mission a disciple is planned for, or "".
func mission_of(id: String) -> String:
	for entry in missions:
		if id in entry["team"]:
			return String(entry["mission"])
	return ""


func remove_from_missions(id: String) -> void:
	for entry in missions:
		entry["team"].erase(id)
	missions.assign(missions.filter(func(e: Dictionary) -> bool: return not e["team"].is_empty()))


## Error codes, empty when the plan is valid. Each is "code" or "code:detail":
## unknown_disciple, away, injured_must_rest, bad_task, unknown_mission,
## team_size, double_booked.
func validate(sect: Sect) -> Array[String]:
	var errors: Array[String] = []
	var booked := {}
	for id: String in tasks:
		var d := sect.disciple(id)
		if d == null:
			errors.append("unknown_disciple:" + id)
			continue
		if sect.is_away(id):
			errors.append("away:" + id)
		if not String(tasks[id]) in Balance.HOME_TASKS:
			errors.append("bad_task:" + id)
		elif d.is_injured() and tasks[id] != "rest":
			errors.append("injured_must_rest:" + id)
		booked[id] = true
	for entry in missions:
		var mission := String(entry["mission"])
		if not Balance.MISSIONS.has(mission):
			errors.append("unknown_mission:" + mission)
		var team: Array = entry["team"]
		if team.size() < Balance.TEAM_MIN or team.size() > Balance.TEAM_MAX:
			errors.append("team_size:" + mission)
		for id: String in team:
			var d := sect.disciple(id)
			if d == null:
				errors.append("unknown_disciple:" + id)
				continue
			if booked.has(id):
				errors.append("double_booked:" + id)
			booked[id] = true
			if sect.is_away(id):
				errors.append("away:" + id)
			if d.is_injured():
				errors.append("injured_must_rest:" + id)
	return errors


## The home task a disciple will do, or "mission" when they are in a team.
func task_of(id: String) -> String:
	for entry in missions:
		if id in entry["team"]:
			return "mission"
	return String(tasks.get(id, "rest"))
