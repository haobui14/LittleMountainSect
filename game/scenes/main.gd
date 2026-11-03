extends Control
## Milestone 1 placeholder title screen.
##
## Shows translated text in the game font, switches between English and
## Vietnamese, and has a text box for the Vietnamese typing test in M2.

@onready var _english: Button = %English
@onready var _vietnamese: Button = %Vietnamese


func _ready() -> void:
	var language_group := ButtonGroup.new()
	_english.button_group = language_group
	_vietnamese.button_group = language_group
	_english.pressed.connect(Settings.set_locale.bind("en"))
	_vietnamese.pressed.connect(Settings.set_locale.bind("vi"))
	Events.language_changed.connect(_on_language_changed)
	_on_language_changed(Settings.locale)


func _on_language_changed(locale: String) -> void:
	_english.set_pressed_no_signal(locale == "en")
	_vietnamese.set_pressed_no_signal(locale == "vi")
