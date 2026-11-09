extends GutTest
## The game's requests must match the server's schemas. The game writes two
## example requests to game/tests/fixtures/; this test checks the game still
## produces them exactly, and a Deno test (server/supabase/functions/tests/
## contract_test.ts) checks the server accepts them.
##
## After an intended change, rewrite the fixtures with:
##   LMS_UPDATE_FIXTURES=1 godot --headless --path game -s addons/gut/gut_cmdln.gd

const DIR := "res://tests/fixtures/"


## A small, fixed sect after one busy day.
func _fixture_sect() -> Dictionary:
	var sect := NewGame.create(4242)
	BuildingRules.upgrade(sect, "spirit_field")
	var plan := DayPlan.defaults(sect)
	plan.add_mission("hunt_monster", [sect.disciples[0].id, sect.disciples[1].id] as Array[String])
	plan.tasks[sect.disciples[2].id] = "work"
	var report := DayResolver.resolve(sect, plan)
	Relationships.change(sect, sect.disciples[0].id, sect.disciples[2].id, 2)
	return {"sect": sect, "report": report}


func _check(file: String, value: Dictionary) -> void:
	var path := DIR + file
	if OS.get_environment("LMS_UPDATE_FIXTURES") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify(value, "  ") + "\n")
		out.close()
		pass_test("wrote %s" % path)
		return
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	# Compare as JSON text so number types (int vs float) don't matter.
	assert_eq(JSON.stringify(saved, "", true), JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true), file)


func test_the_disciple_card_fixture_is_what_the_game_sends() -> void:
	var sect: Sect = _fixture_sect()["sect"]
	_check("disciple_card.json", DiscipleCard.build(sect.disciples[0], "vi"))


func test_the_evening_request_fixture_is_what_the_game_sends() -> void:
	var fixture := _fixture_sect()
	_check("evening_request.json", EveningRules.request(fixture["sect"], fixture["report"], "vi"))


func test_the_chat_request_fixture_is_what_the_game_sends() -> void:
	var sect: Sect = _fixture_sect()["sect"]
	var recent := [{"from": "player", "text": "Con có ăn viên đan không?"}, {"from": "character", "text": "Dạ không!"}]
	_check("chat_request.json", ChatRules.request(sect.disciples[2], recent, "Thật không?", "vi"))


func test_the_event_catalog_fixture_has_the_games_ids() -> void:
	_check("event_catalog.json", EventCatalog.ids())
