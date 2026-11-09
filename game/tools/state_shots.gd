extends SceneTree
## Screenshots of the game screen in states a short browser check rarely
## reaches, from Showcase.sect(): the surprise event before and after a
## choice with a hopeful at the gate, the day plan with a breakthrough and a
## Healing Pill, the Mountain with all 8 buildings and the Alchemy Room, and
## the Disciples tab; and a sheet of portraits (each hair style with the 6
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

const STATES: Array[String] = ["event", "event_done", "plan", "mountain", "disciples", "portraits"]
const SAVE_PATH := "user://state_shots_save.json"
## Loaded when used: a main-loop script is compiled before the autoloads
## exist, and the game screen uses them.
const GAME_SCREEN := "res://scenes/game/game_screen.gd"


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
	game_state.sect = Showcase.sect()
	game_state.step = "morning"
	game_state.plan = null
	var tab := "today"
	match state:
		"event_done":
			EventRules.choose(game_state.sect, "take_lesson")
		"plan":
			EventRules.choose(game_state.sect, "decline")
			Recruiting.decline(game_state.sect)
			game_state.start_planning()
		"mountain", "disciples":
			tab = state

	var app := _paper()
	var screen: Control = load(GAME_SCREEN).new()
	screen.set("_tab", tab)
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
