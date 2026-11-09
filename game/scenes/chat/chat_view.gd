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
var _typing: Control
var _typing_dots: Label
var _expression := ""


func _init(target_id: String) -> void:
	target = target_id
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var d := _disciple()
	var header := UiKit.hbox(10)
	var back := UiKit.button(tr("UI_BACK"), "chat_back", func() -> void: closed.emit())
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	_portrait = Portrait.of(d) if d else Portrait.new("", true)
	_portrait.custom_minimum_size = Vector2(88, 88)
	header.add_child(_portrait)
	var names := UiKit.vbox(2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := UiKit.label(_name(), UiKit.FONT_SIZE + 4, UiKit.JADE)
	title.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	names.add_child(title)
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
		if is_instance_valid(_typing_dots):
			var marks := PackedStringArray()
			for i in 3:
				marks.append("●" if i == _dots % 3 else "○")
			_typing_dots.text = " ".join(marks)


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
	_status.visible = waiting and not Motion.enabled()
	_energy.text = _energy_text()
	if waiting and not is_instance_valid(_typing):
		_typing = _typing_bubble()
		_list.add_child(_typing)
		Motion.pop(_typing)
		_scroll_to_end.call_deferred()
	elif not waiting and is_instance_valid(_typing):
		_typing.queue_free()
		_typing = null
	if lines.size() == _shown:
		return
	var first_look := _shown < 0
	_shown = lines.size()
	for child in _list.get_children():
		if child != _typing:
			_list.remove_child(child)
			child.queue_free()
	var distress := false
	var last: Control
	for line: Dictionary in lines:
		last = _bubble(line)
		_list.add_child(last)
		if line.get("safety") == "distress":
			distress = true
	if is_instance_valid(_typing):
		_list.move_child(_typing, -1)
	if last and not first_look:
		Motion.pop(last)
	for i in range(lines.size() - 1, -1, -1):
		if lines[i]["from"] == "character":
			var expression := String(lines[i].get("expression", "thinking"))
			_portrait.expression = expression
			if not first_look and expression != _expression:
				Motion.bounce(_portrait)
			_expression = expression
			var mood := int(lines[i].get("mood", 0))
			if not first_look and i == lines.size() - 1 and mood != 0:
				_float_mood.call_deferred(mood)
			break
	_support.visible = distress
	_scroll_to_end.call_deferred()


func _float_mood(mood: int) -> void:
	if is_instance_valid(_portrait):
		Motion.float_text(tr("UI_MOOD_CHANGE").format({"mood": "%+d" % mood}), _portrait.get_global_rect().get_center(), UiKit.JADE if mood > 0 else UiKit.WARN)


## The character's "typing" bubble, shown while they think.
func _typing_bubble() -> Control:
	var row := UiKit.hbox(6)
	row.add_child(_face(32.0))
	var bubble := _bubble_panel(UiKit.CARD, UiKit.LINE)
	_typing_dots = UiKit.label("● ○ ○", UiKit.FONT_SIZE, UiKit.JADE_LIGHT)
	_typing_dots.autowrap_mode = TextServer.AUTOWRAP_OFF
	bubble.add_child(_typing_dots)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(bubble)
	return row


func _face(size: float) -> Portrait:
	var d := _disciple()
	var face := Portrait.of(d) if d else Portrait.new("", true)
	face.custom_minimum_size = Vector2(size, size)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return face


func _bubble_panel(fill: Color, border: Color) -> PanelContainer:
	var bubble := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = UiKit.SHADOW
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 1)
	bubble.add_theme_stylebox_override("panel", box)
	return bubble


## One line of the conversation as a speech bubble: the player's on the
## right in jade, the character's on the left with their face (the Elder's
## in plum), with "written" and Mood changes as chips underneath.
func _bubble(line: Dictionary) -> Control:
	var row := UiKit.hbox(6)
	var text := String(line["text"])
	var short := text.length() < 26
	if line["from"] == "player":
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.size_flags_stretch_ratio = 0.35
		row.add_child(spacer)
		var mine := _bubble_panel(UiKit.JADE, Color.TRANSPARENT)
		var label := UiKit.label(text, UiKit.FONT_SIZE, Color.WHITE)
		mine.add_child(label)
		_fit(mine, label, short, true)
		row.add_child(mine)
		return row
	row.add_child(_face(32.0))
	var column := UiKit.vbox(3)
	var elder := target == GameState.ELDER
	var theirs := _bubble_panel(UiKit.PLUM.lerp(UiKit.CARD, 0.82) if elder else UiKit.CARD, UiKit.PLUM.lerp(UiKit.LINE, 0.4) if elder else UiKit.LINE)
	# The game's own written lines already start with the speaker's name.
	var prefix := _name() + ": "
	if text.begins_with(prefix):
		text = text.substr(prefix.length())
	var label := UiKit.label(text)
	theirs.add_child(label)
	column.add_child(theirs)
	var chips := UiKit.hbox(4)
	if line.get("source") != "ai":
		chips.add_child(UiKit.chip(tr("UI_WRITTEN"), UiKit.LINE))
	if int(line.get("mood", 0)) != 0:
		var mood := int(line["mood"])
		chips.add_child(UiKit.chip(tr("UI_MOOD_CHANGE").format({"mood": "%+d" % mood}), UiKit.GOLD if mood > 0 else UiKit.WARN, Icons.mood_kind(mood * 3)))
	if chips.get_child_count() > 0:
		column.add_child(chips)
	_fit(theirs, label, short, false)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	row.add_child(column)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.25
	row.add_child(spacer)
	return row


## Short lines get a snug bubble; long ones wrap across most of the row.
func _fit(bubble: PanelContainer, label: Label, short: bool, right: bool) -> void:
	if short:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	else:
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL if right else Control.SIZE_FILL


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
