extends GutTest
## GameState with a fake server: chat and the evening story with AI, the
## fallbacks when the server can't help, and saves on the server.

const PATH := "user://test_flows_save.json"
const SESSION := "user://test_flows_session.cfg"

var fake: FakeTransport
var _saved_path: String
var _saved_backend: BackendService


func before_each() -> void:
	SaveStore.delete(PATH)
	if FileAccess.file_exists(SESSION):
		DirAccess.remove_absolute(SESSION)
	_saved_path = GameState.save_path
	_saved_backend = GameState.backend
	GameState.save_path = PATH
	fake = FakeTransport.new()
	fake.handler = FakeTransport.happy_server()
	GameState.backend = _backend()


func after_each() -> void:
	GameState.save_path = _saved_path
	GameState.backend = _saved_backend
	SaveStore.delete(PATH)


func _backend() -> BackendService:
	var b := BackendService.new()
	b.transport = fake
	b.session_path = SESSION
	b.configure("https://example.test", "pk_test")
	add_child_autofree(b)
	return b


func _gateway_bodies() -> Array:
	return fake.requests.filter(func(r: Dictionary) -> bool: return r["path"] == "/functions/v1/ai-gateway").map(func(r: Dictionary) -> Dictionary: return r["body"])


func _first_disciple() -> Disciple:
	return GameState.sect.disciples[0]


func test_an_ai_chat_reply_moves_mood_within_the_rules_and_leaves_a_wish() -> void:
	GameState.new_game(5)
	var d := _first_disciple()
	var mood_before := d.mood
	var line: Dictionary = await GameState.send_chat(d.id, "  How was training?  ")
	assert_eq([line["text"], line["source"], line["expression"]], ["Master!", "ai", "happy"])
	assert_eq(line["mood"], Balance.TALK_MOOD + 1, "talk bonus plus the reply's +1")
	assert_eq(d.mood, mood_before + 2)
	assert_eq(d.wants, "rest")
	var sent: Dictionary = _gateway_bodies()[0]
	assert_eq([sent["kind"], sent["message"], sent["disciple"]["id"]], ["chat", "How was training?", d.id])
	assert_eq(GameState.chats[d.id].size(), 2)

	# The next message carries the conversation so far.
	await GameState.send_chat(d.id, "And lunch?")
	assert_eq(_gateway_bodies()[1]["recent"].size(), 2)


func test_with_no_spirit_energy_the_gateways_written_line_is_used() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": {"source": "fallback", "reason": "no_energy", "reply": "*yawns* Tomorrow?", "expression": "sad", "spirit_energy_left": 0}},
	})
	GameState.new_game(5)
	var d := _first_disciple()
	var line: Dictionary = await GameState.send_chat(d.id, "Hi")
	assert_eq([line["text"], line["source"]], ["*yawns* Tomorrow?", "fallback"])
	assert_eq(line["mood"], Balance.TALK_MOOD, "only the talk bonus")
	assert_eq(int(GameState.backend.energy["left"]), 0)


func test_a_distress_reply_is_marked_and_changes_no_mood() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": {"source": "ai", "safety": "distress", "reply": "I'm sorry you're going through this.", "expression": "thinking", "mood_change": 0, "memory": null, "wants_action": null}},
	})
	GameState.new_game(5)
	var d := _first_disciple()
	d.talked_today = true
	var before := d.mood
	var line: Dictionary = await GameState.send_chat(d.id, "I don't want to be alive.")
	assert_eq(line["safety"], "distress")
	assert_eq(d.mood, before)


func test_the_elder_answers_and_never_changes_mood() -> void:
	GameState.new_game(5)
	var moods := GameState.sect.disciples.map(func(d: Disciple) -> int: return d.mood)
	var line: Dictionary = await GameState.send_chat(GameState.ELDER, "What should I build?")
	assert_eq(line["source"], "ai")
	assert_eq(_gateway_bodies()[0]["kind"], "elder")
	assert_eq(GameState.sect.disciples.map(func(d: Disciple) -> int: return d.mood), moods)


func test_the_evening_story_arrives_and_its_decisions_shape_tomorrow() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(r: Dictionary) -> Dictionary:
			var id: String = r["body"]["disciples"][0]["card"]["id"]
			return {"code": 200, "body": {
				"source": "ai", "stored": false, "spirit_energy_left": 46,
				"story": "The sect slept well.", "morning_report": "Something stirs in the field.",
				"decisions": [{"disciple_id": id, "action": "cook", "reason": "I smell soup."}],
				"memories": [],
				"relationship_changes": [{"from": id, "to": r["body"]["disciples"][1]["card"]["id"], "change": 2, "reason": "Shared soup."}],
			}},
	})
	GameState.new_game(5)
	GameState.start_planning()
	GameState.finish_planning()
	GameState.end_day()
	assert_eq(GameState.evening_state, "done")
	var evening := GameState.sect.evening
	assert_eq([evening["source"], evening["story"]], ["ai", "The sect slept well."])
	var d := _first_disciple()
	assert_eq(Decisions.task_for_today(GameState.sect, d.id), "work")
	assert_eq(Relationships.score(GameState.sect, d.id, GameState.sect.disciples[1].id), 2)
	var sent: Dictionary = _gateway_bodies()[0]
	assert_eq([sent["kind"], int(sent["game_day"])], ["evening", 1])

	GameState.next_morning()
	var morning := ReportText.morning(GameState.sect, "en")
	assert_has(morning, "Something stirs in the field.")
	assert_true(morning.any(func(l: String) -> bool: return l.contains("I smell soup.")))

	# Overruling the decision costs Mood once.
	GameState.start_planning()
	assert_eq(GameState.choice_of(d.id), "work", "the decision is the default")
	var before := d.mood
	GameState.choose(d.id, "train")
	GameState.choose(d.id, "rest")
	assert_eq(d.mood, before + Balance.OVERRULE_MOOD)


func test_without_the_server_the_written_evening_stays() -> void:
	fake.handler = func(_r: Dictionary) -> Dictionary: return {"code": 0, "error": "network"}
	GameState.new_game(5)
	GameState.start_planning()
	GameState.finish_planning()
	GameState.end_day()
	assert_eq(GameState.evening_state, "done")
	assert_eq(GameState.sect.evening, {"day": 1, "source": "written"})
	assert_true(GameState.sect.decisions.is_empty())


func test_a_timed_out_evening_is_picked_up_from_the_server() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary: return {"code": 0, "error": "timeout"},
		"/rest/v1/evening_stories": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"reply": {"story": "Finished after all.", "morning_report": "Hi.", "decisions": [], "relationship_changes": []}}]},
	})
	GameState.new_game(5)
	GameState.start_planning()
	GameState.finish_planning()
	GameState.end_day()
	assert_eq(GameState.sect.evening["story"], "Finished after all.")


func test_every_save_goes_to_the_server_with_a_rising_revision() -> void:
	GameState.new_game(5)
	GameState.upgrade("spirit_field")
	var writes := fake.requests.filter(func(r: Dictionary) -> bool:
		return r["path"].begins_with("/rest/v1/saves") and r["method"] != HTTPClient.METHOD_GET)
	var revisions: Array = writes.map(func(r: Dictionary) -> int: return int(r["body"]["revision"]))
	assert_eq(revisions.size(), 2)
	assert_eq(revisions[1], revisions[0] + 1, "each save goes up by one")
	assert_eq(int(writes[1]["body"]["data"]["buildings"]["spirit_field"]), 1)


func test_a_newer_save_on_the_server_wins() -> void:
	var newer := NewGame.create(99)
	newer.day = 12
	newer.revision = 40
	fake.handler = FakeTransport.happy_server({
		"/rest/v1/saves?select": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"revision": 40, "schema_version": 2, "data": newer.to_dict()}]},
	})
	var older := NewGame.create(1)
	older.revision = 3
	SaveStore.write(older, PATH)
	assert_true(await GameState.load_game())
	assert_eq(GameState.sect.day, 12)


func test_a_save_conflict_loads_the_newer_copy() -> void:
	GameState.new_game(5)
	var newer := NewGame.create(77)
	newer.day = 30
	newer.revision = 500
	fake.handler = FakeTransport.happy_server({
		"/rest/v1/saves?player_id": func(_r: Dictionary) -> Dictionary: return {"code": 200, "body": []},
		"/rest/v1/saves?select": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"revision": 500, "schema_version": 2, "data": newer.to_dict()}]},
	})
	watch_signals(GameState)
	GameState.upgrade("spirit_field")
	assert_signal_emitted(GameState, "loaded_newer_save")
	assert_eq(GameState.sect.day, 30)


# Surprise events, hopefuls and pills (M5) ------------------------------------------

func _pending_event() -> void:
	var sect := GameState.sect
	sect.event = EventRules._start(sect, "spirit_goose", "main_gate", [sect.disciples[0].id, sect.disciples[1].id] as Array[String])


func test_claude_writes_tomorrows_event_and_planning_waits_for_a_choice() -> void:
	GameState.new_game(5)
	_pending_event()
	await GameState._fetch_event()
	var sent: Dictionary = _gateway_bodies().back()
	assert_eq([sent["kind"], sent["problem"], sent["place"]], ["event", "spirit_goose", "main_gate"])
	var event := GameState.sect.event
	assert_eq(ReportText.event_title(GameState.sect, event, "en"), "A Surprise!")
	assert_eq(ReportText.event_choice(GameState.sect, event, "chase", "en"), "Claude's words for chase")
	assert_false(GameState.start_planning(), "the event comes first")
	assert_eq(GameState.step, "morning")
	GameState.choose_event("ignore")
	assert_true(GameState.start_planning())
	assert_eq(GameState.sect.pending_facts.back()["type"], "event")


func test_without_the_server_an_event_uses_its_written_text() -> void:
	fake.handler = func(_r: Dictionary) -> Dictionary: return {"code": 0, "error": "network"}
	GameState.new_game(5)
	_pending_event()
	await GameState._fetch_event()
	var event := GameState.sect.event
	assert_false(event["words"].has("title"))
	assert_eq(ReportText.event_title(GameState.sect, event, "en"), "The Goose Who Would Be King")
	assert_false(GameState.event_waiting)


func test_a_timed_out_event_is_picked_up_from_the_server() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary: return {"code": 0, "error": "timeout"},
		"/rest/v1/event_stories": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"reply": {"title": "Late Goose", "story": "Honk.", "choices": [{"id": "bribe", "text": "Bread"}]}}]},
	})
	GameState.new_game(5)
	_pending_event()
	await GameState._fetch_event()
	assert_eq(ReportText.event_title(GameState.sect, GameState.sect.event, "en"), "Late Goose")
	assert_eq(ReportText.event_choice(GameState.sect, GameState.sect.event, "bribe", "en"), "Bread")


func test_recruiting_brewing_and_healing_save_the_game() -> void:
	GameState.new_game(5)
	var sect := GameState.sect
	sect.day = 3
	Recruiting.roll(sect)
	var revision := sect.revision
	assert_true(GameState.recruit(true))
	assert_eq(sect.disciples.size(), 4)
	assert_gt(sect.revision, revision)
	sect.buildings["alchemy_room"] = 2
	sect.resources["herbs"] = 50
	assert_true(GameState.brew("healing_pill"))
	sect.disciples[0].injure(3)
	assert_true(GameState.heal(sect.disciples[0].id))
	assert_false(sect.disciples[0].is_injured())
	assert_false(GameState.heal(sect.disciples[0].id), "no pills left")
	assert_eq(GameState.choices_for(sect.disciples[1].id).has("escort_merchant"), false, "no Mission Hall yet")
