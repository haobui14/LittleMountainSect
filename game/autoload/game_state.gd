extends Node
## The game in play: the sect, the step of the day, the plan being made, the
## day's chats and the evening story. Screens read from here and call these
## methods; the rules live in game/sim.
##
## A day goes: morning (report, a surprise event, a hopeful at the gate,
## pills, and the world's decisions: a tournament, a battle, a traveller, a
## letter) -> plan (tasks, missions, upgrades) -> free_time (chat) -> results
## (what happened, the evening story) -> morning.
##
## AI is never required: when the server can't help (no Spirit Energy, the
## daily cap, a refusal, or no connection), chats and the evening use written
## text and the day goes on (CLAUDE.md rule 3).

signal chat_finished(target: String)
signal evening_finished
## The save on the server was newer (another tab or device) and was loaded.
signal loaded_newer_save

const STEPS: Array[String] = ["morning", "plan", "free_time", "results"]
const ELDER := "elder"

var sect: Sect = null
var step: String = "morning"
var plan: DayPlan = null
## The last finished day, shown on the results screen.
var report: DayReport = null
## False after a save failed (for example in a private browser window).
var saving_works: bool = true
## Tests point these somewhere else so they never touch a player's save or
## the real server.
var save_path: String = SaveStore.DEFAULT_PATH
var backend: BackendService = null
## Today's chats: target ("elder" or a disciple id) -> [{from, text,
## expression, source, safety}]. Not saved: only memories outlive the day.
var chats: Dictionary = {}
## Targets waiting for a reply ("thinking").
var waiting: Dictionary = {}
## "idle", "waiting" (the evening story is being written) or "done".
var evening_state: String = "idle"
## True while Claude writes the words of tomorrow's surprise event.
var event_waiting: bool = false
## True while Claude writes tomorrow's letter home.
var letter_waiting: bool = false
## Who is picked for the morning's "tournament" or "battle": kind -> [ids].
## Not saved; each starts as the strongest who can go.
var picks: Dictionary = {}

var _syncing := false
var _sync_again := false


func _ready() -> void:
	if backend == null:
		backend = get_node_or_null("/root/Backend")


func has_game() -> bool:
	return sect != null


func has_save() -> bool:
	return SaveStore.has_save(save_path)


## Starts a new sect. A seed of -1 picks one at random.
func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	var previous := _known_revision()
	sect = NewGame.create(seed_value)
	# Saves must only move forward, so a new game outranks any older one.
	sect.revision = previous
	report = null
	chats = {}
	evening_state = "idle"
	_go("morning")
	_save()


## Loads the newest save, local or on the server, and opens its morning.
## Returns false (and keeps the current game) when there is no usable save.
func load_game() -> bool:
	var local := SaveStore.read(save_path)
	var best: Sect = local["sect"] if local["ok"] else null
	var server := await _server_save()
	if server and (best == null or server.revision > best.revision):
		best = server
	if best == null:
		return false
	_open(best)
	return true


## Opens the day plan. Returns false while a morning decision (a surprise
## event, the tournament, a battle or a traveller's request) waits for the
## Sect Master.
func start_planning() -> bool:
	if not World.pending(sect).is_empty():
		return false
	plan = DayPlan.defaults(sect)
	_go("plan")
	return true


## Everything a disciple can be planned to do, in screen order.
func choices() -> Array[String]:
	var out: Array[String] = Balance.HOME_TASKS.duplicate()
	for mission: String in Balance.MISSIONS:
		out.append(mission)
	return out


## What [param id] can be planned to do today: the home tasks they can do
## and the missions the Mission Hall allows.
func choices_for(id: String) -> Array[String]:
	var d := sect.disciple(id)
	var out: Array[String] = []
	for task in Balance.HOME_TASKS:
		if d and DayPlan.task_allowed(sect, d, task):
			out.append(task)
	if d and not d.is_injured():
		for mission: String in Balance.MISSIONS:
			if MissionResolver.unlocked(sect, mission):
				out.append(mission)
	return out


# The morning: surprise events, hopefuls and pills -----------------------------------

## Picks a choice in the morning's surprise event. Returns what changed, or {}.
func choose_event(choice: String) -> Dictionary:
	var applied := EventRules.choose(sect, choice)
	if sect.event.get("resolved", false):
		_save()
		Events.state_changed.emit()
	return applied


# The world (M6): tournaments, wars, travel, rivals and Elders ------------------------

## The ids picked for the morning's "tournament" or "battle", among those who
## can still go.
func picks_for(kind: String) -> Array[String]:
	var free := Tournament.eligible(sect)
	var most := Balance.CHAMPIONS_MAX if kind == "tournament" else Balance.DEFENDERS_MAX
	if not picks.has(kind):
		picks[kind] = Tournament.strongest(free, most)
	var ids := free.map(func(d: Disciple) -> String: return d.id)
	var out: Array[String] = []
	out.assign(picks[kind].filter(func(id: String) -> bool: return id in ids))
	picks[kind] = out
	return out


## Adds or removes a disciple from the morning's picks (at most 3 champions
## or 4 defenders).
func toggle_pick(kind: String, id: String) -> void:
	var current := picks_for(kind)
	var most := Balance.CHAMPIONS_MAX if kind == "tournament" else Balance.DEFENDERS_MAX
	if id in current:
		current.erase(id)
	elif current.size() < most:
		current.append(id)
	picks[kind] = current
	Events.state_changed.emit()


## Plays the tournament with the picked champions. Returns the result, or {}.
func enter_tournament() -> Dictionary:
	var result := Tournament.enter(sect, picks_for("tournament"))
	if not result.is_empty():
		_world_changed()
	return result


func skip_tournament() -> bool:
	return _world_done(Tournament.skip(sect))


## Fights today's battle with the picked defenders. Returns the war, or {}.
func defend() -> Dictionary:
	var result := Wars.defend(sect, picks_for("battle"))
	if not result.is_empty():
		_world_changed()
	return result


func make_peace() -> bool:
	return _world_done(Wars.make_peace(sect))


## Lets the disciple who asked go travelling, or asks them to stay.
func answer_travel(go: bool) -> bool:
	return _world_done(Generations.let_go(sect) if go else Generations.ask_to_stay(sect))


func gift(rival: String, resource: String) -> bool:
	return _world_done(Rivals.gift(sect, rival, resource) >= 0)


func trade(rival: String) -> bool:
	return _world_done(Rivals.trade(sect, rival))


func ally(rival: String) -> bool:
	return _world_done(Rivals.ally(sect, rival))


func end_alliance(rival: String) -> bool:
	return _world_done(Rivals.end_alliance(sect, rival))


func promote(id: String) -> bool:
	return _world_done(Generations.promote(sect, id))


func _world_done(done: bool) -> bool:
	if done:
		_world_changed()
	return done


func _world_changed() -> void:
	_save()
	Events.state_changed.emit()


## Takes in (or sends away) the hopeful at the gate.
func recruit(accept: bool) -> bool:
	var done := Recruiting.accept(sect) if accept else true
	if not accept:
		Recruiting.decline(sect)
	if done:
		_save()
		Events.state_changed.emit()
	return done


func brew(pill: String) -> bool:
	if not Alchemy.brew(sect, pill):
		return false
	_save()
	Events.state_changed.emit()
	return true


## Gives a disciple a Healing Pill.
func heal(id: String) -> bool:
	var d := sect.disciple(id)
	if d == null or not Alchemy.heal(sect, d):
		return false
	_save()
	Events.state_changed.emit()
	return true


## One tap on the day plan: a home task, or joining a mission's team. Going
## against a disciple's own decision costs them Mood, once a day.
func choose(id: String, choice: String) -> void:
	if choice in Balance.HOME_TASKS:
		plan.set_task(id, choice)
	else:
		plan.join_mission(choice, id)
	var decided := Decisions.task_for_today(sect, id)
	if decided != "" and decided != plan.task_of(id):
		Decisions.overrule(sect, id)
	Events.state_changed.emit()


func choice_of(id: String) -> String:
	var mission := plan.mission_of(id)
	return mission if mission != "" else plan.task_of(id)


func set_task(id: String, task: String) -> void:
	plan.set_task(id, task)
	Events.state_changed.emit()


func add_mission(mission: String, team: Array[String]) -> void:
	plan.add_mission(mission, team)
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


# Chat -----------------------------------------------------------------------------

## Sends a chat line to a disciple (by id) or the Elder ("elder"). Returns the
## reply: {text, expression, source ("ai", "fallback" or "offline"), safety,
## mood}. Without the server, the reply is a written line.
func send_chat(target: String, message: String) -> Dictionary:
	var text := message.strip_edges().left(ChatRules.MAX_MESSAGE_CHARS)
	if text == "" or waiting.has(target):
		return {}
	var d := sect.disciple(target) if target != ELDER else null
	var history: Array = chats.get_or_add(target, [])
	var recent := history.map(func(line: Dictionary) -> Dictionary:
		return {"from": line["from"], "text": String(line["text"]).left(600)})
	history.append({"from": "player", "text": text})
	waiting[target] = true
	Events.state_changed.emit()

	var result := {}
	if backend:
		result = await backend.chat(ChatRules.request(d, recent, text, Settings.locale))
	var data: Variant = result.get("data")
	var line: Dictionary
	if result.get("ok", false) and data is Dictionary and data.get("reply") is String:
		line = {
			"text": String(data["reply"]),
			"expression": ChatRules.text_of(data.get("expression"), "thinking"),
			"source": ChatRules.text_of(data.get("source"), "fallback"),
			"safety": ChatRules.text_of(data.get("safety"), "ok"),
		}
	else:
		var written := ReportText.offline_chat(d, history.size(), Settings.locale)
		line = {"text": written["text"], "expression": written["expression"], "source": "offline", "safety": "ok"}

	var mood := {"bonus": 0, "mood": 0}
	if d:
		var applied: Dictionary = data if line["source"] == "ai" else {}
		mood = ChatRules.apply(sect, d, {
			"safety": line["safety"],
			"mood_change": applied.get("mood_change", 0),
			"wants_action": applied.get("wants_action"),
		})
	line["from"] = "character"
	line["mood"] = int(mood["bonus"]) + int(mood["mood"])
	history.append(line)
	waiting.erase(target)
	_save()
	Events.state_changed.emit()
	chat_finished.emit(target)
	return line


# The day's end -------------------------------------------------------------------

## Runs the day's rules, saves, opens the results, and starts the evening
## story. The written evening shows at once; the AI story replaces it when
## it arrives.
func end_day() -> DayReport:
	var result := DayResolver.resolve(sect, plan)
	if result == null:
		return null
	report = result
	plan = null
	chats = {}
	sect.evening = {"day": result.day, "source": "written"}
	_save()
	_go("results")
	Events.day_resolved.emit(result)
	_fetch_evening(result)
	return result


func _fetch_evening(day_report: DayReport) -> void:
	evening_state = "waiting"
	Events.state_changed.emit()
	var reply := {}
	if backend:
		var result: Dictionary = await backend.evening(EveningRules.request(sect, day_report, Settings.locale))
		var data: Variant = result.get("data")
		if result.get("ok", false) and data is Dictionary and data.get("source") == "ai":
			reply = data
		elif result.get("error", "") in ["timeout", "http_504"]:
			# The story may have finished on the server after we stopped waiting.
			var stored: Dictionary = await backend.stored_evening(day_report.day)
			if stored.get("ok", false) and stored["data"] is Dictionary:
				reply = stored["data"]
	if sect.evening.get("day") == day_report.day and reply.get("story") is String:
		var applied := EveningRules.apply(sect, reply)
		sect.evening = {
			"day": day_report.day,
			"source": "ai",
			"story": String(reply["story"]),
			"morning_report": ChatRules.text_of(reply.get("morning_report")),
			"decisions": applied["decisions"],
			"relationships": applied["relationships"],
		}
		_save()
	evening_state = "done"
	Events.state_changed.emit()
	evening_finished.emit()
	await _fetch_event()
	_fetch_letter()


## Asks Claude for the words of tomorrow's surprise event (2 Spirit Energy).
## Without them, the event uses the written text in strings.csv.
func _fetch_event() -> void:
	if backend == null or sect == null or not EventRules.pending(sect) or sect.event.get("words", {}).has("title"):
		return
	var day := int(sect.event["day"])
	event_waiting = true
	Events.state_changed.emit()
	var reply := {}
	var result: Dictionary = await backend.event(EventRules.request(sect, Settings.locale))
	var data: Variant = result.get("data")
	if result.get("ok", false) and data is Dictionary and data.get("source") == "ai":
		reply = data
	elif result.get("error", "") in ["timeout", "http_504"]:
		var stored: Dictionary = await backend.stored_event(day)
		if stored.get("ok", false) and stored["data"] is Dictionary:
			reply = stored["data"]
	event_waiting = false
	if EventRules.pending(sect) and int(sect.event["day"]) == day and reply.get("title") is String:
		var words := {"title": String(reply["title"]), "story": ChatRules.text_of(reply.get("story")), "choices": {}}
		for choice: Variant in reply.get("choices", []):
			if choice is Dictionary and choice.get("id") is String and choice.get("text") is String:
				words["choices"][choice["id"]] = choice["text"]
		sect.event["words"] = words
		_save()
	Events.state_changed.emit()


## Asks Claude to write the letter that arrives tomorrow (1 Spirit Energy).
## Without it, the letter is one of the written ones in strings.csv.
func _fetch_letter() -> void:
	if backend == null or sect == null or sect.letter.is_empty() or String(sect.letter.get("words", "")) != "":
		return
	var day := int(sect.letter["day"])
	letter_waiting = true
	Events.state_changed.emit()
	var reply := {}
	var result: Dictionary = await backend.letter(Generations.letter_request(sect, Settings.locale))
	var data: Variant = result.get("data")
	if result.get("ok", false) and data is Dictionary and data.get("source") == "ai":
		reply = data
	elif result.get("error", "") in ["timeout", "http_504"]:
		var stored: Dictionary = await backend.stored_letter(day)
		if stored.get("ok", false) and stored["data"] is Dictionary:
			reply = stored["data"]
	letter_waiting = false
	if not sect.letter.is_empty() and int(sect.letter["day"]) == day and reply.get("letter") is String:
		sect.letter["words"] = String(reply["letter"]).strip_edges()
		_save()
	Events.state_changed.emit()


func next_morning() -> void:
	if backend:
		backend.refresh_energy()
	picks = {}
	_go("morning")


# Saves -----------------------------------------------------------------------------

## Writes the local save, then the server's copy in the background.
func _save() -> void:
	sect.revision += 1
	saving_works = SaveStore.write(sect, save_path)
	_sync_server()


func _sync_server() -> void:
	if backend == null:
		return
	if _syncing:
		_sync_again = true
		return
	_syncing = true
	var result: Dictionary = await backend.write_save(sect.to_dict(), sect.revision)
	if result.get("error", "") == "conflict":
		var newer := await _server_save()
		if newer and newer.revision > sect.revision:
			_open(newer)
			loaded_newer_save.emit()
		else:
			_sync_again = true
	_syncing = false
	if _sync_again:
		_sync_again = false
		_sync_server()


func _server_save() -> Sect:
	if backend == null:
		return null
	var result: Dictionary = await backend.load_save()
	if not result.get("ok", false) or not result["data"] is Dictionary:
		return null
	var migrated := SaveMigration.migrate(result["data"]["data"])
	return Sect.from_dict(migrated["data"]) if migrated["ok"] else null


func _known_revision() -> int:
	var known := sect.revision if sect else 0
	var local := SaveStore.read(save_path)
	if local["ok"]:
		known = maxi(known, local["sect"].revision)
	if backend:
		known = maxi(known, backend.server_revision)
	return known


func _open(loaded: Sect) -> void:
	sect = loaded
	report = sect.last_report
	plan = null
	chats = {}
	evening_state = "done" if not sect.evening.is_empty() else "idle"
	picks = {}
	_go("morning")
	await _fetch_event()
	_fetch_letter()


func _go(next_step: String) -> void:
	assert(next_step in STEPS)
	step = next_step
	Events.state_changed.emit()
