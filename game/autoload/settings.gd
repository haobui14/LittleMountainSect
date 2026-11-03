extends Node
## Settings stored on this device, separate from the game save.
##
## On the web, user:// is the browser's storage. It can be empty in private
## windows, so every setting has a safe default.

const SUPPORTED_LOCALES: Array[String] = ["en", "vi"]
const _PATH := "user://settings.cfg"

var locale: String = "en"


func _ready() -> void:
	locale = _load_locale()
	TranslationServer.set_locale(locale)


## Switches the game's language and remembers the choice.
func set_locale(new_locale: String) -> void:
	if new_locale not in SUPPORTED_LOCALES or new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save()
	Events.language_changed.emit(locale)


func _load_locale() -> String:
	var config := ConfigFile.new()
	if config.load(_PATH) == OK:
		var saved: String = config.get_value("general", "locale", "")
		if saved in SUPPORTED_LOCALES:
			return saved
	# First launch: follow the browser or OS language when we support it.
	var system_language := OS.get_locale_language()
	return system_language if system_language in SUPPORTED_LOCALES else "en"


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.save(_PATH)
