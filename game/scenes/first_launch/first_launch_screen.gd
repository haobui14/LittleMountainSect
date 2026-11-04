class_name FirstLaunchScreen
extends Control
## First launch: choose a language, confirm 18+, and read the AI and privacy
## notice (GDD: Safety rules). M8 finishes this flow.

signal navigate(target: String)

var _start: Button


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := UiKit.vbox(12)
	column.custom_minimum_size = Vector2(minf(420.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(column)

	var title := UiKit.heading(tr("UI_GAME_TITLE"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UiKit.label(tr("FIRST_TITLE"), UiKit.FONT_SIZE + 2, UiKit.JADE))

	var languages := UiKit.hbox()
	languages.alignment = BoxContainer.ALIGNMENT_CENTER
	languages.add_child(UiKit.choice("English", "lang_en", Settings.locale == "en", func() -> void: Settings.set_locale("en")))
	languages.add_child(UiKit.choice("Tiếng Việt", "lang_vi", Settings.locale == "vi", func() -> void: Settings.set_locale("vi")))
	column.add_child(languages)

	var notice := UiKit.card()
	notice.add_child(UiKit.label(tr("FIRST_AI_NOTICE"), UiKit.SMALL_SIZE))
	column.add_child(notice)

	var age := CheckButton.new()
	age.text = tr("FIRST_AGE")
	age.add_theme_color_override("font_color", UiKit.INK)
	age.add_theme_color_override("font_pressed_color", UiKit.INK)
	age.add_theme_color_override("font_hover_color", UiKit.INK)
	age.add_theme_color_override("font_hover_pressed_color", UiKit.INK)
	age.add_theme_color_override("font_focus_color", UiKit.INK)
	age.toggled.connect(func(on: bool) -> void: _start.disabled = not on)
	UiKit.probe(age, "age_check")
	column.add_child(age)
	column.add_child(UiKit.label(tr("FIRST_ADULTS_ONLY"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))

	_start = UiKit.button(tr("FIRST_START"), "first_start", _confirm, true)
	_start.disabled = true
	column.add_child(_start)


func _confirm() -> void:
	Settings.confirm_age()
	navigate.emit("title")
