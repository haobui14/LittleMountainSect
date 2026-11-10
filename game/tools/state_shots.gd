extends SceneTree
## Screenshots of the game screen in states a short browser check rarely
## reaches, from Showcase.sect(): the surprise event before and after a
## choice with a hopeful at the gate, the day plan with a breakthrough and a
## Healing Pill, the Mountain with all 8 buildings and the Alchemy Room, and
## the Disciples tab; from Showcase.world_sect() (M6): the morning with the
## tournament, a letter, a war on its way and a traveller's request, the
## tournament's result, a battle morning, the World tab and an evening with
## a tournament and a battle; and a sheet of portraits (each hair style with the 6
## faces, the Elder and the side effects that show). For reviewing the
## layout and the art style by eye; it checks nothing.
## Needs a display, so run it under Xvfb, from the repo root, once per window
## size: a phone width (tall, so the whole list shows) and a desktop.
##
##   for size in 390x1700 1280x720; do
##     xvfb-run -a -s "-screen 0 1280x1800x24" godot --path game --rendering-driver opengl3 \
##       --resolution $size -s res://tools/state_shots.gd -- --out /tmp/shots [--locale vi]
##   done
##
## Files are named <width>x<height>_<state>.png. Nothing is saved and nothing
## goes to the server.

const STATES: Array[String] = [
	"title", "event", "event_done", "plan", "free_time", "chat", "evening", "mountain", "disciples",
	"world_morning", "tournament_done", "battle", "world", "world_disciples", "world_evening", "portraits",
]
const SAVE_PATH := "user://state_shots_save.json"
## Loaded when used: a main-loop script is compiled before the autoloads
## exist, and the game screen uses them.
const GAME_SCREEN := "res://scenes/game/game_screen.gd"
const TITLE_SCREEN := "res://scenes/title/title_screen.gd"


func _init() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var out := _arg("--out", OS.get_user_data_dir().path_join("state_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var game_state := root.get_node("GameState")
	game_state.save_path = SAVE_PATH
	game_state.backend = null
	root.get_node("Backend").transport = FakeTransport.new()
	TranslationServer.set_locale(_arg("--locale", "en"))
	# Still pictures: no fades or pops half way through.
	root.get_node("Settings").reduce_motion = true
	var window := DisplayServer.window_get_size()
	await _frames(3)
	for state in STATES:
		var app := _show(state)
		await _frames(5)
		var path := out.path_join("%dx%d_%s.png" % [window.x, window.y, state])
		root.get_texture().get_image().save_png(path)
		print(path)
		app.queue_free()
		await _frames(1)
	SaveStore.delete(SAVE_PATH)
	quit()


func _show(state: String) -> Control:
	if state == "portraits":
		return _portraits()
	var game_state := root.get_node("GameState")
	game_state.sect = Showcase.world_sect() if state.begins_with("world") or state in ["tournament_done", "battle"] else Showcase.sect()
	game_state.picks = {}
	game_state.step = "morning"
	game_state.plan = null
	game_state.chats = {}
	var tab := "today"
	var chat := ""
	if state == "title":
		var title_app := _paper()
		var title: Control = load(TITLE_SCREEN).new()
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_app.add_child(title)
		root.add_child(title_app)
		return title_app
	var sect: Sect = game_state.sect
	match state:
		"event_done":
			EventRules.choose(game_state.sect, "take_lesson")
		"plan":
			EventRules.choose(game_state.sect, "decline")
			Recruiting.decline(game_state.sect)
			game_state.start_planning()
		"mountain", "disciples":
			tab = state
		"free_time", "chat":
			EventRules.choose(sect, "decline")
			game_state.step = "free_time"
			var d: Disciple = sect.disciples[1]
			game_state.chats[d.id] = [
				{"from": "player", "text": "How is the green hair?"},
				{"from": "character", "text": "Master, the frogs think I am one of them now. It is an honour, I suppose.", "expression": "nervous", "source": "ai", "mood": 1},
				{"from": "player", "text": "It suits you."},
				{"from": "character", "text": d.display_name("en") + ": I will wear it proudly.", "expression": "proud", "source": "fallback", "mood": 0},
			]
			if state == "chat":
				chat = d.id
		"evening":
			EventRules.choose(sect, "decline")
			game_state.step = "results"
			var report := DayReport.new(sect.day)
			var ready: Disciple = sect.disciples[0]
			var green: Disciple = sect.disciples[1]
			ready.realm = "foundation_building"
			report.add("breakthrough", {"disciple": ready.id, "realm": "foundation_building", "pill": "foundation_pill"})
			report.add("breakthrough_failed", {"disciple": green.id, "realm": "foundation_building", "lost": 40, "effect": "green_hair", "days": 4, "pill": "none"})
			report.add("trained", {"disciple": sect.disciples[4].id, "gain": 9, "ready": false})
			report.add("worked", {"disciples": [sect.disciples[2].id], "food": 3, "herbs": 1})
			report.add("ate", {"food": 4})
			report.resource_changes = {"food": -1, "herbs": 1}
			game_state.report = report
			game_state.evening_state = "done"
		"tournament_done":
			game_state.enter_tournament()
		"battle":
			Tournament.skip(sect)
			sect.day = int(sect.war["battle_day"])
			sect.tournament = {}
			sect.letter = {}
		"world", "world_disciples":
			tab = "world" if state == "world" else "disciples"
		"world_evening":
			game_state.step = "results"
			var report := DayReport.new(sect.day)
			report.add("tournament", {"place": 1, "champions": [sect.disciples[1].id, sect.disciples[3].id], "matches": [{"rival": "perfect_hair", "won": true}, {"rival": "iron_frog", "won": true}], "rewards": {"reputation": 15, "stones": 40}})
			report.add("war_result", {"rival": "iron_frog", "won": false, "defenders": [sect.disciples[3].id], "land": 1})
			report.add("letter", {"disciple": sect.disciples[2].id, "place": "noodle_town", "gift": {"food": 7}, "item": "none"})
			report.resource_changes = {"stones": 40, "reputation": 15}
			game_state.report = report
			game_state.evening_state = "done"

	var app := _paper()
	var screen: Control = load(GAME_SCREEN).new()
	screen.set("_tab", tab)
	screen.set("_chat_target", chat)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(screen)
	root.add_child(app)
	return app


## Rows: each hair style with the 6 faces (one root and hair colour per
## row); then the Elder, green hair, glowing and a few generated disciples.
func _portraits() -> Control:
	var app := _paper()
	var grid := GridContainer.new()
	grid.columns = Portrait.EXPRESSIONS.size()
	grid.position = Vector2(12, 12)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var roots: Array = Portrait.ROOT_COLORS.keys()
	for row in Portrait.HAIR_STYLES.size():
		for expression in Portrait.EXPRESSIONS:
			var p := Portrait.new(roots[row])
			p.hair_style = Portrait.HAIR_STYLES[row]
			p.hair_color = Portrait.HAIR_COLORS[row]
			grid.add_child(_sized(p, expression))
	var elder := Portrait.new("", true)
	grid.add_child(_sized(elder, "happy"))
	var green := Portrait.new("wood")
	green.hair_color = Portrait.GREEN_HAIR
	grid.add_child(_sized(green, "nervous"))
	var glow := Portrait.new("fire")
	glow.hair_style = "long"
	glow.glowing = true
	grid.add_child(_sized(glow, "proud"))
	var sect := NewGame.create(11)
	for i in 3:
		sect.disciples.append(DiscipleGenerator.generate(sect))
	for d in sect.disciples.slice(0, 3):
		grid.add_child(_sized(Portrait.of(d), "thinking"))
	app.add_child(grid)
	root.add_child(app)
	return app


func _sized(p: Portrait, expression: String) -> Portrait:
	p.custom_minimum_size = Vector2(68, 68)
	p.expression = expression
	return p


func _paper() -> Control:
	var app := Control.new()
	app.theme = UiKit.theme()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiKit.PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(background)
	return app
