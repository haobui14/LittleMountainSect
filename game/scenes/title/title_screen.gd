class_name TitleScreen
extends Control
## Title: start a new sect or continue the saved one, pick a language, or open
## the typing test (kept for the M2 device tests).

signal navigate(target: String)


## The buildings standing in the title's scenery.
const SCENERY := {"main_hall": 1, "disciple_huts": 1, "training_yard": 1, "spirit_field": 1}

var _scenery: MountainView


func _ready() -> void:
	# The mountain behind the menu: across the top of a phone, with the menu
	# on the grass below; to the left of the menu on a wide screen.
	var backdrop := Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.clip_contents = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var grass := ColorRect.new()
	grass.color = Color("#A3C792")
	grass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(grass)
	_scenery = MountainView.new(SCENERY, _scenery_width(), false)
	_scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(_scenery)
	_place_scenery()
	get_viewport().size_changed.connect(_place_scenery)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if UiKit.is_narrow(self):
		center.anchor_top = 0.42
	else:
		center.anchor_left = 0.5
	add_child(center)
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiKit.CARD, 0.93)
	box.border_color = UiKit.LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	box.shadow_color = UiKit.SHADOW
	box.shadow_size = 10
	card.add_theme_stylebox_override("panel", box)
	center.add_child(card)
	var column := UiKit.vbox(12)
	var wide_room := get_viewport_rect().size.x * (1.0 if UiKit.is_narrow(self) else 0.5)
	column.custom_minimum_size = Vector2(minf(380.0, wide_room - 72.0), 0)
	card.add_child(column)

	var title := UiKit.heading(tr("UI_GAME_TITLE"))
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline := UiKit.label(tr("UI_TAGLINE"), UiKit.FONT_SIZE, UiKit.SOFT_INK)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	# A save may also be on the server (a new device, or cleared browser data).
	var backend: BackendService = get_node_or_null("/root/Backend")
	var has_save := GameState.has_save() or (backend and backend.user_id() != "")
	if has_save:
		column.add_child(UiKit.primary(tr("UI_CONTINUE"), "continue", _continue, "today"))
	if has_save:
		column.add_child(UiKit.button(tr("UI_NEW_GAME"), "new_game", _new_game, true, "mountain"))
	else:
		column.add_child(UiKit.primary(tr("UI_NEW_GAME"), "new_game", _new_game, "mountain"))

	var options := UiKit.flow(6)
	options.alignment = FlowContainer.ALIGNMENT_CENTER
	options.add_child(UiKit.choice("English", "lang_en", Settings.locale == "en", func() -> void: Settings.set_locale("en")))
	options.add_child(UiKit.choice("Tiếng Việt", "lang_vi", Settings.locale == "vi", func() -> void: Settings.set_locale("vi")))
	options.add_child(UiKit.choice(tr("UI_LESS_MOTION"), "less_motion", Settings.reduce_motion, func() -> void: Settings.set_reduce_motion(not Settings.reduce_motion)))
	column.add_child(options)

	column.add_child(UiKit.button(tr("UI_TYPING_TEST"), "typing_test", func() -> void: navigate.emit("typing_test"), true))
	Motion.pop.call_deferred(card)


func _scenery_width() -> float:
	var screen := get_viewport_rect().size
	if UiKit.is_narrow(self):
		return screen.x * 1.25
	return maxf(screen.x * 0.75, screen.y * MountainArt.VIEW.x / MountainArt.VIEW.y)


func _place_scenery() -> void:
	if not is_instance_valid(_scenery):
		return
	var screen := get_viewport_rect().size
	var width := _scenery_width()
	_scenery.custom_minimum_size = Vector2(width, width * MountainArt.VIEW.y / MountainArt.VIEW.x)
	_scenery.size = _scenery.custom_minimum_size
	if UiKit.is_narrow(self):
		_scenery.position = Vector2((screen.x - width) / 2.0, 0.0)
	else:
		# The peak sits in the left half; the picture's lower edge is grass.
		_scenery.position = Vector2(screen.x * 0.25 - width / 2.0, minf(0.0, screen.y - _scenery.size.y))


func _continue() -> void:
	if await GameState.load_game():
		navigate.emit("game")
		return
	# Keep the save on disk: a newer version of the game may still read it.
	var center: Node = get_child(0)
	var column: Node = center.get_child(0)
	var key := "UI_SAVE_UNREADABLE" if GameState.has_save() else "UI_NO_SAVE"
	column.add_child(UiKit.label(tr(key), UiKit.SMALL_SIZE, UiKit.WARN))


func _new_game() -> void:
	GameState.new_game()
	navigate.emit("game")
