extends Control
## The root of the game: a paper background and one screen at a time (title,
## game or typing test). Screens ask to move on through their `navigate`
## signal. A language change rebuilds the current screen.

const TYPING_TEST := preload("res://scenes/typing/typing_test.tscn")

var _current := ""
var _screen: Node


func _ready() -> void:
	theme = UiKit.theme()
	var background := ColorRect.new()
	background.color = UiKit.PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	Events.language_changed.connect(func(_locale: String) -> void: show_screen(_current))
	show_screen("title" if Settings.age_confirmed else "first_launch")


func show_screen(target: String) -> void:
	if _screen:
		remove_child(_screen)
		_screen.queue_free()
	match target:
		"game":
			_screen = GameScreen.new()
		"first_launch":
			_screen = FirstLaunchScreen.new()
		"typing_test":
			_screen = TYPING_TEST.instantiate()
		_:
			target = "title"
			_screen = TitleScreen.new()
	_current = target
	if _screen is Control:
		(_screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _screen.has_signal("navigate"):
		_screen.connect("navigate", show_screen)
	add_child(_screen)
