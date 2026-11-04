extends Node
## Settings stored on this device, separate from the game save.
##
## On the web, user:// is the browser's storage. It can be empty in private
## windows, so every setting has a safe default.

const SUPPORTED_LOCALES: Array[String] = ["en", "vi"]
const _PATH := "user://settings.cfg"

var locale: String = "en"
## The player confirmed they are 18 or older and saw the AI notice (first launch).
var age_confirmed: bool = false
## Chat on the web uses the browser's own text box unless this is on (for
## comparing the two during Gate 2; see docs/playtests/typing-test.md).
var use_godot_box: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(_PATH) == OK
	locale = _load_locale(config if loaded else null)
	age_confirmed = bool(config.get_value("general", "age_confirmed", false)) if loaded else false
	use_godot_box = bool(config.get_value("general", "use_godot_box", false)) if loaded else false
	TranslationServer.set_locale(locale)


## Switches the game's language and remembers the choice.
func set_locale(new_locale: String) -> void:
	if new_locale not in SUPPORTED_LOCALES or new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save()
	Events.language_changed.emit(locale)


## First launch: the player confirmed 18+ and read the AI notice. Also tells
## the server, when it can be reached.
func confirm_age() -> void:
	age_confirmed = true
	_save()
	var backend: BackendService = get_node_or_null("/root/Backend")
	if backend:
		backend.update_player({
			"age_confirmed_at": Time.get_datetime_string_from_system(true) + "Z",
			"language": locale,
		})


func set_use_godot_box(on: bool) -> void:
	use_godot_box = on
	_save()


func _load_locale(config: ConfigFile) -> String:
	if config:
		var saved: String = config.get_value("general", "locale", "")
		if saved in SUPPORTED_LOCALES:
			return saved
	# First launch: follow the browser or OS language when we support it.
	var system_language := OS.get_locale_language()
	return system_language if system_language in SUPPORTED_LOCALES else "en"


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("general", "age_confirmed", age_confirmed)
	config.set_value("general", "use_godot_box", use_godot_box)
	config.save(_PATH)
