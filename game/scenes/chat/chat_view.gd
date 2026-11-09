class_name ChatView
extends VBoxContainer
## Chatting with one disciple or the Elder. Built once and kept while open,
## so the text box keeps what the player is typing; only the messages and
## the status refresh when GameState changes.
##
## On the web the text box is the browser's own (WebTextInput), which handles
## Vietnamese input methods and phone keyboards; Settings.use_godot_box
## switches to Godot's box for comparison (see docs/playtests/typing-test.md).

signal closed

const FONT_PX := 18

var target: String

var _portrait: Portrait
var _list: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _energy: Label
var _support: PanelContainer
var _input: LineEdit
var _counter: Label
var _send: Button
var _web: WebTextInput
var _dots := 0
var _shown := -1


func _init(target_id: String) -> void:
	target = target_id
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var d := _disciple()
	var header := UiKit.hbox(10)
	header.add_child(UiKit.button(tr("UI_BACK"), "chat_back", func() -> void: closed.emit()))
	_portrait = Portrait.of(d) if d else Portrait.new("", true)
	header.add_child(_portrait)
	var names := UiKit.vbox(2)
	names.add_child(UiKit.label(_name(), UiKit.FONT_SIZE + 2, UiKit.JADE))
	_energy = UiKit.label("", UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	names.add_child(_energy)
	header.add_child(names)
	add_child(header)
	add_child(UiKit.label(tr("UI_AI_NOTICE"), UiKit.SMALL_SIZE - 2, UiKit.SOFT_INK))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = UiKit.vbox(8)
	_scroll.add_child(_list)
	add_child(_scroll)

	_support = UiKit.card()
	var support := UiKit.vbox(4)
	support.add_child(UiKit.label(tr("SUPPORT_TITLE"), UiKit.FONT_SIZE, UiKit.WARN))
	support.add_child(UiKit.label(tr("SUPPORT_BODY"), UiKit.SMALL_SIZE))
	_support.add_child(support)
	_support.visible = false
	add_child(_support)

	_status = UiKit.label("", UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	add_child(_status)

	var row := UiKit.hbox(6)
	_input = LineEdit.new()
	_input.max_length = ChatRules.MAX_MESSAGE_CHARS
	_input.placeholder_text = tr("UI_CHAT_PLACEHOLDER").format({"name": _name()})
	_input.custom_minimum_size = Vector2(0, UiKit.BUTTON_HEIGHT)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.probe(_input, "chat_input")
	row.add_child(_input)
	_send = UiKit.button(tr("UI_SEND"), "chat_send", _submit)
	row.add_child(_send)
	add_child(row)

	var footer := UiKit.hbox(8)
	_counter = UiKit.label("0/%d" % ChatRules.MAX_MESSAGE_CHARS, UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	footer.add_child(_counter)
	if WebTextInput.available():
		var box := CheckButton.new()
		box.text = tr("UI_USE_GODOT_BOX")
		box.button_pressed = Settings.use_godot_box
		box.add_theme_font_size_override("font_size", UiKit.SMALL_SIZE)
		box.toggled.connect(_switch_box)
		UiKit.probe(box, "godot_box")
		footer.add_child(box)
	add_child(footer)

	_attach_input()
	Events.state_changed.connect(_refresh)
	var backend: BackendService = get_node_or_null("/root/Backend")
	if backend:
		backend.energy_changed.connect(func(_e: Dictionary) -> void: _refresh())
	var timer := Timer.new()
	timer.wait_time = 0.4
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_refresh()


func _disciple() -> Disciple:
	return GameState.sect.disciple(target) if target != GameState.ELDER else null


func _name() -> String:
	var d := _disciple()
	return d.display_name(Settings.locale) if d else tr("UI_ELDER_NAME")


func _attach_input() -> void:
	if _web:
		_web.queue_free()
		_web = null
	if WebTextInput.available() and not Settings.use_godot_box:
		_input.editable = false
		_input.focus_mode = Control.FOCUS_NONE
		_web = WebTextInput.new()
		add_child(_web)
		_web.text_changed.connect(_on_text)
		_web.submitted.connect(func(_t: String) -> void: _submit())
		_web.attach(_input, _input.placeholder_text, FONT_PX, ChatRules.MAX_MESSAGE_CHARS)
	else:
		_input.editable = true
		_input.focus_mode = Control.FOCUS_ALL
		if not _input.text_changed.is_connected(_on_text):
			_input.text_changed.connect(_on_text)
			_input.text_submitted.connect(func(_t: String) -> void: _submit())


func _switch_box(on: bool) -> void:
	Settings.set_use_godot_box(on)
	_input.clear()
	_on_text("")
	_attach_input()


func _on_text(text: String) -> void:
	_counter.text = "%d/%d" % [text.length(), ChatRules.MAX_MESSAGE_CHARS]


func _submit() -> void:
	var text := _web.text() if _web else _input.text
	if text.strip_edges() == "" or GameState.waiting.has(target):
		return
	if _web:
		_web.clear()
	else:
		_input.clear()
	_on_text("")
	await GameState.send_chat(target, text)


func _tick() -> void:
	if GameState.waiting.has(target):
		_dots = (_dots + 1) % 4
		_status.text = tr("UI_THINKING").format({"name": _name()}) + ".".repeat(_dots)


## Shows the conversation and the status. Rebuilds the list only when the
## number of lines changed.
func _refresh() -> void:
	if not is_inside_tree() or GameState.sect == null:
		return
	var lines: Array = GameState.chats.get(target, [])
	var waiting := GameState.waiting.has(target)
	_send.disabled = waiting
	if _web:
		_web.set_enabled(not waiting)
	_status.text = tr("UI_THINKING").format({"name": _name()}) if waiting else ""
	_energy.text = _energy_text()
	if lines.size() == _shown:
		return
	_shown = lines.size()
	UiKit.clear(_list)
	var distress := false
	for line: Dictionary in lines:
		_list.add_child(_line_label(line))
		if line.get("safety") == "distress":
			distress = true
	for i in range(lines.size() - 1, -1, -1):
		if lines[i]["from"] == "character":
			_portrait.expression = String(lines[i].get("expression", "thinking"))
			break
	_support.visible = distress
	_scroll_to_end.call_deferred()


func _line_label(line: Dictionary) -> Label:
	if line["from"] == "player":
		var mine := UiKit.label("%s: %s" % [tr("UI_YOU"), line["text"]], UiKit.FONT_SIZE, UiKit.JADE)
		mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return mine
	var notes: Array[String] = []
	if line.get("source") != "ai":
		notes.append(tr("UI_WRITTEN"))
	if int(line.get("mood", 0)) != 0:
		notes.append(tr("UI_MOOD_CHANGE").format({"mood": "%+d" % int(line["mood"])}))
	var suffix := "  (%s)" % ", ".join(notes) if not notes.is_empty() else ""
	# The game's own written lines already start with the speaker's name.
	var text := String(line["text"])
	if not text.begins_with(_name()):
		text = "%s: %s" % [_name(), text]
	return UiKit.label(text + suffix)


func _energy_text() -> String:
	var backend: BackendService = get_node_or_null("/root/Backend")
	if backend == null or backend.status == "offline":
		return tr("UI_OFFLINE")
	var left: Variant = backend.energy.get("left")
	return tr("UI_ENERGY").format({"left": str(left) if left != null else "…"})


func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
