extends Control
## Placeholder title screen, and the Vietnamese typing test for M2.
##
## Shows translated text in the game font, switches between English and
## Vietnamese, and offers two text boxes: Godot's own, and (on the web) the
## browser's native input laid over it. Testers type in each and copy a
## report listing every code point, so we can see what their keyboard sent.

const TYPING_FONT_PX := 22

@onready var _english: Button = %English
@onready var _vietnamese: Button = %Vietnamese
@onready var _typing: LineEdit = %TypingTest
@onready var _browser_box: CheckButton = %BrowserBox
@onready var _copy: Button = %CopyReport
@onready var _code_points: Label = %CodePoints

var _typed := ""
var _web_input: WebTextInput


func _ready() -> void:
	var language_group := ButtonGroup.new()
	_english.button_group = language_group
	_vietnamese.button_group = language_group
	_english.pressed.connect(Settings.set_locale.bind("en"))
	_vietnamese.pressed.connect(Settings.set_locale.bind("vi"))
	Events.language_changed.connect(_on_language_changed)
	_on_language_changed(Settings.locale)

	_typing.text_changed.connect(_on_typed)
	_copy.pressed.connect(_copy_report)
	_browser_box.visible = WebTextInput.available()
	_browser_box.toggled.connect(_use_browser_box)
	_on_typed("")


func _on_language_changed(locale: String) -> void:
	_english.set_pressed_no_signal(locale == "en")
	_vietnamese.set_pressed_no_signal(locale == "vi")
	_show_code_points()


func _on_typed(text: String) -> void:
	_typed = text
	_show_code_points()
	_publish_report()


func _show_code_points() -> void:
	var shown := TypingReport.code_points(_typed) if _typed != "" else "—"
	_code_points.text = tr("UI_TYPING_CODE_POINTS") % shown


func _use_browser_box(on: bool) -> void:
	_typed = ""
	_typing.clear()
	_typing.editable = not on
	_typing.focus_mode = Control.FOCUS_NONE if on else Control.FOCUS_ALL
	if on:
		_web_input = WebTextInput.new()
		add_child(_web_input)
		_web_input.text_changed.connect(_on_typed)
		_web_input.attach(_typing, tr("UI_TYPING_TEST_PLACEHOLDER"), TYPING_FONT_PX)
	elif _web_input != null:
		_web_input.queue_free()
		_web_input = null
	_on_typed("")


func _report() -> String:
	var box := "browser" if _web_input != null else "godot"
	return TypingReport.build(_typed, box, _browser_name(), Settings.locale)


func _browser_name() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("navigator.userAgent"))
	return OS.get_name()


func _copy_report() -> void:
	DisplayServer.clipboard_set(_report())
	_copy.text = "UI_TYPING_COPIED"
	await get_tree().create_timer(1.5).timeout
	_copy.text = "UI_TYPING_COPY_REPORT"


## On the web, also expose the report to the page so automated browser tests
## can read it.
func _publish_report() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.lmsTypingReport = %s;" % JSON.stringify(_report()))
