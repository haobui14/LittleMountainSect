extends GutTest
## Local saves, and the game layer playing 10 full days with no AI (the M3
## exit test, without the screens).

const PATH := "user://test_save.json"

var _saved_path: String
var _saved_backend: BackendService


func before_each() -> void:
	SaveStore.delete(PATH)
	_saved_path = GameState.save_path
	GameState.save_path = PATH
	# A server that never answers: everything must still work offline.
	_saved_backend = GameState.backend
	var offline := BackendService.new()
	offline.transport = FakeTransport.new()
	offline.session_path = "user://test_offline_session.cfg"
	offline.configure("https://example.test", "pk_test")
	add_child_autofree(offline)
	GameState.backend = offline


func after_each() -> void:
	GameState.save_path = _saved_path
	GameState.backend = _saved_backend
	SaveStore.delete(PATH)


func _write_text(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_saved_sect_loads_exactly() -> void:
	var sect := NewGame.create(31)
	DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_true(SaveStore.write(sect, PATH))
	var result := SaveStore.read(PATH)
	assert_true(result["ok"])
	assert_eq(result["sect"].to_dict(), sect.to_dict())


func test_bad_saves_are_reported_not_loaded() -> void:
	assert_eq(SaveStore.read(PATH)["error"], "no_save")
	_write_text("{ not json")
	assert_eq(SaveStore.read(PATH)["error"], "unreadable")
	var newer := NewGame.create(1).to_dict()
	newer["version"] = Sect.SAVE_VERSION + 1
	_write_text(JSON.stringify(newer))
	assert_eq(SaveStore.read(PATH)["error"], "newer_version")


func test_a_failed_save_keeps_the_game_going() -> void:
	GameState.save_path = "user://no/such/folder/save.json"
	GameState.new_game(5)
	assert_false(GameState.saving_works)
	assert_true(GameState.has_game())
	GameState.start_planning()
	assert_true(GameState.finish_planning())
	assert_not_null(GameState.end_day())


func test_ten_days_play_from_start_to_finish_without_ai() -> void:
	GameState.new_game(2026)
	assert_eq(GameState.step, "morning")
	var events := 0
	for day in 10:
		assert_eq(GameState.sect.day, day + 1)
		# A surprise event must be answered before planning.
		if EventRules.pending(GameState.sect):
			events += 1
			assert_false(GameState.start_planning())
			var choice: Dictionary = EventRules.choices(GameState.sect).filter(func(c: Dictionary) -> bool: return c["ok"])[0]
			GameState.choose_event(choice["id"])
			assert_false(EventRules.pending(GameState.sect))
		if not GameState.sect.candidate.is_empty():
			GameState.recruit(false)
		GameState.start_planning()
		assert_eq(GameState.step, "plan")
		# Day 1: build the Spirit Field and send a pair to gather herbs.
		if day == 0:
			assert_true(GameState.upgrade("spirit_field"))
			var pair: Array[String] = [GameState.sect.disciples[0].id, GameState.sect.disciples[1].id]
			GameState.add_mission("gather_herbs", pair)
		assert_eq(GameState.plan_errors(), [] as Array[String])
		assert_true(GameState.finish_planning())
		var someone := GameState.sect.available_disciples()
		if not someone.is_empty():
			var line: Dictionary = await GameState.send_chat(someone[0].id, "Hello!")
			assert_eq(line["source"], "offline", "a written line with no server")
			assert_eq(line["mood"], Balance.TALK_MOOD)
		var elder: Dictionary = await GameState.send_chat(GameState.ELDER, "Any advice?")
		assert_string_starts_with(elder["text"], "Elder Mo Wen")
		var report := GameState.end_day()
		assert_not_null(report)
		assert_eq(GameState.step, "results")
		assert_eq(GameState.evening_state, "done")
		assert_eq(GameState.sect.evening["source"], "written")
		assert_false(ReportText.evening(report, GameState.sect, "en").is_empty())
		GameState.next_morning()
	assert_eq(GameState.sect.day, 11)
	assert_gt(events, 0, "ten days bring at least one surprise event")
	assert_true(GameState.saving_works)

	# The save on disk is the game in play, and loads back into it.
	var expected := GameState.sect.to_dict()
	GameState.sect = null
	assert_true(await GameState.load_game())
	assert_eq(GameState.sect.to_dict(), expected)


func test_an_invalid_plan_cannot_leave_planning() -> void:
	GameState.new_game(8)
	GameState.start_planning()
	GameState.plan.tasks[GameState.sect.disciples[0].id] = "dance"
	assert_false(GameState.finish_planning())
	assert_eq(GameState.step, "plan")
