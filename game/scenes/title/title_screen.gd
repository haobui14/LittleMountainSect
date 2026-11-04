class_name TitleScreen
extends Control
## Title: start a new sect or continue the saved one, pick a language, or open
## the typing test (kept for the M2 device tests).

signal navigate(target: String)


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := UiKit.vbox(12)
	column.custom_minimum_size = Vector2(minf(420.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(column)

	var title := UiKit.heading(tr("UI_GAME_TITLE"))
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline := UiKit.label(tr("UI_TAGLINE"), UiKit.FONT_SIZE, UiKit.SOFT_INK)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	if GameState.has_save():
		column.add_child(UiKit.button(tr("UI_CONTINUE"), "continue", _continue, true))
	column.add_child(UiKit.button(tr("UI_NEW_GAME"), "new_game", _new_game, true))

	var languages := UiKit.hbox()
	languages.alignment = BoxContainer.ALIGNMENT_CENTER
	languages.add_child(UiKit.choice("English", "lang_en", Settings.locale == "en", func() -> void: Settings.set_locale("en")))
	languages.add_child(UiKit.choice("Tiếng Việt", "lang_vi", Settings.locale == "vi", func() -> void: Settings.set_locale("vi")))
	column.add_child(languages)

	column.add_child(UiKit.button(tr("UI_TYPING_TEST"), "typing_test", func() -> void: navigate.emit("typing_test"), true))
	var note := UiKit.label(tr("UI_BUILD_NOTE"), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)


func _continue() -> void:
	if await GameState.load_game():
		navigate.emit("game")
		return
	# Keep the save on disk: a newer version of the game may still read it.
	var center: Node = get_child(0)
	var column: Node = center.get_child(0)
	column.add_child(UiKit.label(tr("UI_SAVE_UNREADABLE"), UiKit.SMALL_SIZE, UiKit.WARN))


func _new_game() -> void:
	GameState.new_game()
	navigate.emit("game")
