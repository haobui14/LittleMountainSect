class_name GameScreen
extends Control
## The game in play: a resource bar, tabs (Today, Mountain, Disciples) and the
## current view. On a narrow screen the tabs sit at the bottom, within reach
## of a thumb; on a wide one they sit at the top. Everything is rebuilt from
## GameState whenever it changes, which keeps these placeholder screens simple.

signal navigate(target: String)

const TABS: Array[String] = ["today", "mountain", "disciples"]

var _tab := "today"
var _rebuild_queued := false
## Kept across rebuilds, so a tap doesn't jump the list back to the top.
var _scroll: ScrollContainer
var _scroll_value := 0
## The open chat ("" when none): a disciple id or GameState.ELDER. The chat
## view is kept while open so the text box keeps what the player types.
var _chat_target := ""
var _chat_view: ChatView
## Disciple id -> their newest memories from the server (fetched on the
## Disciples tab, once per day).
var _memories := {}
var _memories_day := -1
var _loaded_newer := false
## What the screen showed last time, so entrance animations play only when
## the step or tab changes, and so resource changes can float up.
var _shown_view := ""
var _shown_sect_id := 0
var _shown_resources := {}
var _resource_labels := {}
## The building picked on the Mountain, and one that was just upgraded.
var _selected_building := ""
var _shown_building := ""
var _celebrate := ""
## Whether the morning's event still waited for a choice at the last look.
var _event_was_pending := false
## The evening's breakthrough lines (shown as banners, not again as lines),
## and the day whose banners already sparkled.
var _banner_texts: Array[String] = []
var _celebrated_day := -1


func _ready() -> void:
	Events.state_changed.connect(_queue_rebuild)
	get_viewport().size_changed.connect(_queue_rebuild)
	GameState.loaded_newer_save.connect(func() -> void:
		_loaded_newer = true
		_chat_target = ""
		_queue_rebuild())
	var backend := _backend()
	if backend:
		backend.status_changed.connect(func(_s: String) -> void: _queue_rebuild())
		backend.energy_changed.connect(func(_e: Dictionary) -> void: _queue_rebuild())
		backend.refresh_energy()
	_rebuild()


func _backend() -> BackendService:
	return get_node_or_null("/root/Backend")


func open_chat(target: String) -> void:
	_chat_target = target
	_rebuild()


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _locale() -> String:
	return Settings.locale


func _rebuild() -> void:
	_rebuild_queued = false
	if not GameState.has_game():
		navigate.emit("title")
		return
	# An open chat refreshes itself; rebuilding would wipe what is being typed.
	if _chat_target != "" and is_instance_valid(_chat_view):
		return
	if is_instance_valid(_scroll):
		_scroll_value = _scroll.scroll_vertical
	UiKit.clear(self)
	var narrow := UiKit.is_narrow(self)
	var root := UiKit.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	if _chat_target != "":
		root.add_child(_hud(narrow))
		var margin := MarginContainer.new()
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12)
		_chat_view = ChatView.new(_chat_target)
		_chat_view.closed.connect(func() -> void:
			_chat_target = ""
			_chat_view = null
			_queue_rebuild())
		margin.add_child(_chat_view)
		root.add_child(margin)
		return

	var tabs := _tabs(narrow)
	root.add_child(_hud(narrow))
	if not narrow:
		# Wide: the step's action sits at the end of the tabs row.
		tabs.add_child(_action_button())
		root.add_child(tabs)
	var scroll: Array = UiKit.scroll_column()
	root.add_child(scroll[0])
	_scroll = scroll[0]
	var body: VBoxContainer = scroll[1]
	match _tab:
		"mountain":
			_mountain(body, narrow)
		"disciples":
			_disciples(body, narrow)
		_:
			_today(body)
	if narrow:
		root.add_child(_action_bar())
		root.add_child(tabs)
	else:
		for note in _action_notes():
			body.add_child(note)

	# Cards pop in when the step or tab changes, not on every tap.
	var view := "%s/%s/%d" % [GameState.step, _tab, GameState.sect.day]
	if view != _shown_view:
		_shown_view = view
		_scroll_value = 0
		Motion.stagger.call_deferred(body.get_children())
	_restore_scroll.call_deferred(_scroll, _scroll_value)
	_show_gains.call_deferred()


func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


# Resource bar and tabs ------------------------------------------------------

func _hud(narrow: bool) -> Control:
	var panel := PanelContainer.new()
	var box := UiKit.vbox(6)
	panel.add_child(box)
	var top := UiKit.hbox()
	# The evening belongs to the day that just ended.
	var day := GameState.report.day if GameState.step == "results" and GameState.report else GameState.sect.day
	var title := UiKit.label(tr("UI_DAY").format({"day": day}), UiKit.FONT_SIZE + 2, UiKit.JADE)
	title.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(title)
	var resources := UiKit.flow(12)
	if narrow:
		box.add_child(top)
		box.add_child(resources)
	else:
		resources.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(resources)
		box.add_child(top)
	top.add_child(UiKit.button(tr("UI_MENU"), "menu", func() -> void: navigate.emit("title")))

	_resource_labels = {}
	for resource in Balance.RESOURCES:
		var amount := int(GameState.sect.resources[resource])
		var text := ("%s %d" % [ReportText.resource_name(resource), amount]) if not narrow else str(amount)
		var item := UiKit.icon_label(resource, text, UiKit.FONT_SIZE, UiKit.INK, 20.0)
		item.tooltip_text = ReportText.resource_name(resource)
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var label: Label = item.get_child(1)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_resource_labels[resource] = label
		resources.add_child(item)
	var backend := _backend()
	var offline := backend == null or backend.status == "offline"
	var energy := UiKit.chip(tr("UI_OFFLINE_SHORT") if offline else _energy_text(), Color(0.55, 0.62, 0.85), "energy")
	energy.tooltip_text = _energy_text()
	energy.mouse_filter = Control.MOUSE_FILTER_PASS
	resources.add_child(energy)
	for pill in Balance.PILLS:
		if GameState.sect.item(pill) > 0:
			var chip := UiKit.chip("×%d" % GameState.sect.item(pill), UiKit.GOLD, pill)
			chip.tooltip_text = ReportText.pill_name(pill)
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			resources.add_child(chip)
	box.add_child(DayTracker.new(GameState.step))
	if not GameState.saving_works:
		box.add_child(UiKit.label(tr("UI_NOT_SAVING"), UiKit.SMALL_SIZE, UiKit.WARN))
	if _loaded_newer:
		box.add_child(UiKit.label(tr("UI_LOADED_NEWER"), UiKit.SMALL_SIZE, UiKit.WARN))
	return panel


## After a rebuild: resources that changed count to their new value, and the
## change floats up from them. Not on the first look at a sect.
func _show_gains() -> void:
	var sect := GameState.sect
	if sect == null:
		return
	var known := sect.get_instance_id() == _shown_sect_id
	var before := _shown_resources
	_shown_sect_id = sect.get_instance_id()
	_shown_resources = sect.resources.duplicate()
	if not known:
		return
	var narrow := UiKit.is_narrow(self)
	var floats := {}
	for resource in Balance.RESOURCES:
		var label: Label = _resource_labels.get(resource)
		var change := int(sect.resources[resource]) - int(before.get(resource, sect.resources[resource]))
		if change == 0 or not is_instance_valid(label):
			continue
		var amount := int(sect.resources[resource])
		var format := "%d" if narrow else ReportText.resource_name(resource) + " %d"
		Motion.count(label, amount - change, amount, format)
		floats[label] = change
	if floats.is_empty():
		return
	# Wait for the layout, so the numbers float up from the right place.
	await get_tree().process_frame
	for label: Label in floats:
		if is_instance_valid(label):
			var change: int = floats[label]
			Motion.float_text("%+d" % change, label.get_global_rect().get_center(), UiKit.JADE if change > 0 else UiKit.WARN)


func _energy_text() -> String:
	var backend := _backend()
	if backend == null or backend.status == "offline":
		return tr("UI_OFFLINE")
	var left: Variant = backend.energy.get("left")
	return tr("UI_ENERGY").format({"left": str(left) if left != null else "…"})


func _tabs(narrow: bool) -> HBoxContainer:
	var row := UiKit.hbox(4)
	for tab in TABS:
		var b := UiKit.choice(tr("UI_TAB_" + tab.to_upper()), "tab_" + tab, _tab == tab, func() -> void:
			_tab = tab
			_scroll_value = 0
			_queue_rebuild(), tab)
		if narrow:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			b.custom_minimum_size.x = 130
		row.add_child(b)
	return row


# Today: the day's steps ----------------------------------------------------

## The step's main action (the same probe id on every layout).
func _action_button() -> Button:
	var action: Button
	match GameState.step:
		"morning":
			action = UiKit.primary(tr("UI_PLAN_DAY"), "plan_day", GameState.start_planning, "today")
			action.disabled = EventRules.pending(GameState.sect)
		"plan":
			action = UiKit.primary(tr("UI_DONE_PLANNING"), "done_planning", GameState.finish_planning)
			action.disabled = not GameState.plan_errors().is_empty()
		"free_time":
			action = UiKit.primary(tr("UI_END_DAY"), "end_day", _end_day, "rest")
		_:
			action = UiKit.primary(tr("UI_NEXT_MORNING"), "next_morning", GameState.next_morning, "today")
	return action


## Why the action can't be taken yet, if it can't.
func _action_notes() -> Array[Label]:
	var notes: Array[Label] = []
	match GameState.step:
		"morning":
			if EventRules.pending(GameState.sect):
				notes.append(UiKit.label(tr("UI_EVENT_FIRST"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		"plan":
			for error in GameState.plan_errors():
				var key := "ERR_TEAM_SIZE" if error.begins_with("team_size") else "ERR_PLAN"
				notes.append(UiKit.label(tr(key), UiKit.SMALL_SIZE, UiKit.WARN))
	return notes


## Phones: the step's action, always in reach above the tabs. Shown on every
## tab, so the day can go on from the Mountain.
func _action_bar() -> Control:
	var bar := MarginContainer.new()
	for side in ["left", "right"]:
		bar.add_theme_constant_override("margin_" + side, 12)
	bar.add_theme_constant_override("margin_top", 6)
	bar.add_theme_constant_override("margin_bottom", 8)
	var box := UiKit.vbox(4)
	bar.add_child(box)
	for note in _action_notes():
		box.add_child(note)
	box.add_child(_action_button())
	return bar


func _today(body: VBoxContainer) -> void:
	body.add_child(UiKit.heading(tr("UI_STEP_" + GameState.step.to_upper())))
	match GameState.step:
		"morning":
			_morning(body)
		"plan":
			_plan(body)
		"free_time":
			_free_time(body)
		"results":
			_results(body)


## The morning report, then today's surprise event and any hopeful at the
## gate. The day can't be planned until the event's choice is made.
func _morning(body: VBoxContainer) -> void:
	var sect := GameState.sect
	for line in ReportText.morning(sect, _locale()):
		body.add_child(UiKit.label(line))
	if not sect.event.is_empty() and int(sect.event["day"]) == sect.day:
		# Reveal the result when the choice was made since the last look.
		var pending := EventRules.pending(sect)
		var reveal := _event_was_pending and not pending
		_event_was_pending = pending
		body.add_child(MorningCards.event_card(sect, _locale(), GameState.event_waiting, reveal))
	if not sect.candidate.is_empty():
		body.add_child(MorningCards.candidate_card(sect, _locale()))


## Where a disciple is when they can't be planned (a mission, lost or left)
## or why they must rest (an injury), or null.
func _status_label(d: Disciple) -> Label:
	var sect := GameState.sect
	var away := sect.mission_of(d.id)
	if away:
		return UiKit.label(tr("UI_AWAY").format({"mission": ReportText.mission_name(away.mission), "day": away.return_day}), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	match d.status:
		"lost":
			if d.return_day > 0:
				return UiKit.label(tr("UI_COMING_HOME").format({"day": d.return_day}), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
			return UiKit.label(tr("UI_LOST"), UiKit.SMALL_SIZE, UiKit.WARN)
		"left":
			return UiKit.label(tr("UI_LEFT"), UiKit.SMALL_SIZE, UiKit.WARN)
	if d.is_injured():
		return UiKit.label(tr("UI_INJURED").format({"days": d.injury_days()}), UiKit.SMALL_SIZE, UiKit.WARN)
	return null


## "Green hair, 3 more days. Only funny." for each side effect.
func _side_effect_labels(box: VBoxContainer, d: Disciple) -> void:
	for effect in d.side_effects():
		box.add_child(UiKit.label(tr("UI_SIDE_EFFECT").format({
			"effect": _first_upper(ReportText.side_effect_name(effect.kind)),
			"days": effect.days_left,
			"rule": tr("SIDE_%s_RULE" % effect.kind.to_upper()),
		}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))


func _first_upper(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## The pill a breakthrough by [param d] would use today: the best one left
## after the disciples before them (who try first) have taken theirs.
func _pill_for(d: Disciple) -> String:
	var sect := GameState.sect
	var stock := {}
	for pill: String in Balance.PILL_BREAKTHROUGH:
		stock[pill] = sect.item(pill)
	for other in sect.disciples:
		if other == d:
			break
		if GameState.plan.task_of(other.id) == "breakthrough":
			for pill: String in stock:
				if stock[pill] > 0:
					stock[pill] -= 1
					break
	for pill: String in stock:
		if stock[pill] > 0:
			return pill
	return "none"


func _choice_text(d: Disciple, choice: String) -> String:
	match choice:
		"breakthrough":
			var pill := _pill_for(d)
			var percent := roundi(100 * CultivationRules.chance(GameState.sect, d, pill))
			if pill == "none":
				return tr("TASK_BREAKTHROUGH_CHANCE").format({"percent": percent})
			return tr("TASK_BREAKTHROUGH_PILL").format({"percent": percent, "pill": ReportText.pill_name(pill)})
		"study":
			return tr("TASK_STUDY_PROGRESS").format({"study": d.study, "max": Balance.STUDY_MAX})
	if choice in Balance.HOME_TASKS:
		return tr("TASK_" + choice.to_upper())
	return ReportText.mission_name(choice)


func _plan(body: VBoxContainer) -> void:
	var sect := GameState.sect
	body.add_child(UiKit.label(tr("UI_PLAN_HINT"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var cards := _card_grid()
	body.add_child(cards)
	for d in sect.disciples:
		var card := UiKit.card(Portrait.ROOT_COLORS.get(d.spirit_root, UiKit.LINE))
		var box := UiKit.vbox(6)
		card.add_child(box)
		box.add_child(_name_row(d, 44.0))
		var status := _status_label(d)
		if status:
			box.add_child(status)
		if not sect.is_away(d.id):
			_side_effect_labels(box, d)
			if Alchemy.can_heal(sect, d):
				box.add_child(UiKit.button(tr("UI_HEAL").format({"count": sect.item("healing_pill")}), "heal_" + d.id, GameState.heal.bind(d.id), false, "heal"))
		if not sect.is_away(d.id) and not d.is_injured():
			var decision := Decisions.for_today(sect, d.id)
			if not decision.is_empty():
				var note := tr("UI_DECIDED").format({"action": tr("ACTION_" + String(decision["action"]).to_upper())})
				if decision["overruled"]:
					note += " " + tr("UI_OVERRULED")
				box.add_child(UiKit.label(note, UiKit.SMALL_SIZE, UiKit.WARN if decision["overruled"] else UiKit.SOFT_INK))
			elif ChatRules.wished_task(sect, d) != "":
				box.add_child(UiKit.label(tr("UI_WANTS").format({"action": tr("ACTION_" + d.wants.to_upper())}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
			var current := GameState.choice_of(d.id)
			var home := UiKit.flow()
			var missions := UiKit.flow()
			for choice in GameState.choices_for(d.id):
				var b := UiKit.choice(_choice_text(d, choice), "choose_%s_%s" % [d.id, choice], current == choice, GameState.choose.bind(d.id, choice), Icons.task_kind(choice))
				if choice == "breakthrough":
					b.theme_type_variation = "GoldButton"
				(home if choice in Balance.HOME_TASKS else missions).add_child(b)
			box.add_child(UiKit.label(tr("UI_AT_HOME"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
			box.add_child(home)
			if missions.get_child_count() > 0:
				box.add_child(UiKit.label(tr("UI_MISSIONS"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
				box.add_child(missions)
		cards.add_child(card)

	for entry in GameState.plan.missions:
		body.add_child(_team_card(entry))


## A disciple's face, name and Mood, for the top of a card.
func _name_row(d: Disciple, face: float) -> HBoxContainer:
	var row := UiKit.hbox(8)
	var portrait := Portrait.of(d)
	portrait.custom_minimum_size = Vector2(face, face)
	portrait.expression = "happy" if d.mood >= 3 else ("sad" if d.mood <= -3 else "thinking")
	row.add_child(portrait)
	var name := UiKit.label(d.display_name(_locale()), UiKit.FONT_SIZE, UiKit.JADE)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var mood := UiKit.chip("%+d" % d.mood, UiKit.GOLD if d.mood >= 0 else UiKit.WARN, Icons.mood_kind(d.mood))
	mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mood.tooltip_text = tr("UI_MOOD")
	row.add_child(mood)
	return row


## A mission's team: the mission, the faces going, and the likely result.
func _team_card(entry: Dictionary) -> Control:
	var sect := GameState.sect
	var mission := String(entry["mission"])
	var team: Array = entry["team"]
	var likely := MissionResolver.expected_tier(sect, mission, team)
	var card := UiKit.card(UiKit.TIER_COLORS.get(likely, UiKit.LINE))
	var box := UiKit.vbox(6)
	card.add_child(box)
	var top := UiKit.hbox(8)
	top.add_child(UiKit.icon_label(Icons.task_kind(mission), ReportText.mission_name(mission), UiKit.FONT_SIZE, UiKit.JADE, 24.0))
	top.add_child(UiKit.chip(tr("UI_LIKELY").format({"tier": tr("TIER_" + likely.to_upper())}), UiKit.TIER_COLORS.get(likely, UiKit.LINE)))
	box.add_child(top)
	var faces := UiKit.hbox(4)
	for id: String in team:
		var d := sect.disciple(id)
		if d:
			var portrait := Portrait.of(d)
			portrait.custom_minimum_size = Vector2(36, 36)
			portrait.expression = "proud"
			faces.add_child(portrait)
	var names := UiKit.label(ReportText.names(sect, team, _locale()), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	faces.add_child(names)
	box.add_child(faces)
	return card


func _free_time(body: VBoxContainer) -> void:
	var sect := GameState.sect
	body.add_child(UiKit.label(tr("UI_FREE_TIME_HINT"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	body.add_child(UiKit.button(tr("UI_ASK_ELDER"), "chat_elder", open_chat.bind(GameState.ELDER), true, "elder"))
	var cards := _card_grid()
	body.add_child(cards)
	for d in sect.disciples:
		if not sect.is_away(d.id):
			cards.add_child(_talk_card(d))
	body.add_child(UiKit.label(tr("UI_CHAT_COST"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))


## A disciple to talk to: the whole card opens the chat (probe chat_<id>).
func _talk_card(d: Disciple) -> Control:
	var card := UiKit.card(Portrait.ROOT_COLORS.get(d.spirit_root, UiKit.LINE))
	var box := UiKit.vbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var row := UiKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := Portrait.of(d)
	portrait.custom_minimum_size = Vector2(64, 64)
	var lines: Array = GameState.chats.get(d.id, [])
	portrait.expression = String(lines[-1].get("expression", "thinking")) if not lines.is_empty() else ("happy" if d.mood >= 3 else "thinking")
	row.add_child(portrait)
	var who := UiKit.vbox(4)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(UiKit.label(d.display_name(_locale()), UiKit.FONT_SIZE + 1, UiKit.JADE))
	var mood := UiKit.chip("%s %+d" % [tr("UI_MOOD"), d.mood], UiKit.GOLD if d.mood >= 0 else UiKit.WARN, Icons.mood_kind(d.mood))
	who.add_child(mood)
	row.add_child(who)
	var talk := UiKit.icon_label("chat", tr("UI_CHAT"), UiKit.SMALL_SIZE, UiKit.JADE, 26.0)
	talk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(talk.get_child(1) as Label).size_flags_horizontal = Control.SIZE_SHRINK_END
	(talk.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	talk.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(talk)
	box.add_child(row)
	if not lines.is_empty():
		var said := PanelContainer.new()
		var bubble := StyleBoxFlat.new()
		bubble.bg_color = UiKit.PAPER
		bubble.set_corner_radius_all(12)
		bubble.content_margin_left = 10
		bubble.content_margin_right = 10
		bubble.content_margin_top = 6
		bubble.content_margin_bottom = 6
		said.add_theme_stylebox_override("panel", bubble)
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		said.add_child(UiKit.label(String(lines[-1]["text"]), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		box.add_child(said)
	# The whole card is the button.
	var open := Button.new()
	open.flat = true
	open.focus_mode = Control.FOCUS_NONE
	open.tooltip_text = tr("UI_CHAT")
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiKit.JADE, 0.07)
	hover.set_corner_radius_all(10)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(UiKit.JADE, 0.14)
	open.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	open.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	open.add_theme_stylebox_override("hover", hover)
	open.add_theme_stylebox_override("pressed", pressed)
	open.button_down.connect(func() -> void: Motion.bounce(card))
	open.pressed.connect(open_chat.bind(d.id))
	UiKit.probe(open, "chat_" + d.id)
	card.add_child(open)
	return card


## Disciple cards side by side when the screen is wide enough.
func _card_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = UiKit.columns(self, 380.0, 3)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


func _end_day() -> void:
	_scroll_value = 0
	GameState.end_day()


func _results(body: VBoxContainer) -> void:
	var report := GameState.report
	var sect := GameState.sect
	if report:
		var evening := sect.evening
		var story_ready: bool = evening.get("source") == "ai" and int(evening.get("day", 0)) == report.day
		if GameState.evening_state == "waiting":
			body.add_child(UiKit.label(tr("UI_EVENING_WRITING"), UiKit.FONT_SIZE, UiKit.SOFT_INK))
		elif story_ready:
			var story := UiKit.card()
			story.add_child(UiKit.label(String(evening["story"])))
			body.add_child(story)
			for decision: Dictionary in evening.get("decisions", []):
				body.add_child(UiKit.label(ReportText.decision_line(sect, decision, _locale()), UiKit.SMALL_SIZE, UiKit.JADE))
			for change: Dictionary in evening.get("relationships", []):
				body.add_child(UiKit.label(ReportText.relationship_line(sect, change, _locale()), UiKit.SMALL_SIZE, UiKit.JADE))
			body.add_child(UiKit.label(tr("UI_WHAT_HAPPENED"), UiKit.FONT_SIZE, UiKit.JADE))
		var banners := _breakthrough_banners(report)
		for banner in banners:
			body.add_child(banner)
		for item in ReportText.evening_items(report, sect, _locale()):
			if String(item["text"]) in _banner_texts:
				continue
			var line := UiKit.icon_label(String(item["icon"]), String(item["text"]), UiKit.SMALL_SIZE if story_ready else UiKit.FONT_SIZE, UiKit.INK, 22.0)
			(line.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			body.add_child(line)
		if not banners.is_empty() and _celebrated_day != report.day:
			_celebrated_day = report.day
			_celebrate_banners.call_deferred(banners)
		var changes := ReportText.amounts(report.resource_changes)
		body.add_child(UiKit.label(tr("UI_CHANGES").format({"changes": changes}) if changes != "" else tr("UI_NO_CHANGES"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))


## A banner for each breakthrough tonight: a glowing face on success; on a
## failure, the face shows its new side effect.
func _breakthrough_banners(report: DayReport) -> Array[Control]:
	var sect := GameState.sect
	var banners: Array[Control] = []
	_banner_texts = []
	for fact in report.facts:
		var type := String(fact["type"])
		if not type.begins_with("breakthrough"):
			continue
		var d := sect.disciple(String(fact["disciple"]))
		if d == null:
			continue
		var won := type == "breakthrough"
		var card := UiKit.card(UiKit.GOLD if won else UiKit.LINE)
		var row := UiKit.hbox(12)
		card.add_child(row)
		var portrait := Portrait.of(d)
		portrait.custom_minimum_size = Vector2(72, 72)
		portrait.glowing = won or portrait.glowing
		portrait.expression = "proud" if won else "nervous"
		row.add_child(portrait)
		var words := UiKit.vbox(4)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_child(UiKit.heading(tr("UI_BREAKTHROUGH_WON" if won else "UI_BREAKTHROUGH_LOST")))
		var text := ReportText.describe(fact, sect, _locale())
		_banner_texts.append(text)
		words.add_child(UiKit.label(text, UiKit.SMALL_SIZE))
		row.add_child(words)
		card.set_meta("won", won)
		banners.append(card)
	return banners


func _celebrate_banners(banners: Array[Control]) -> void:
	await get_tree().process_frame
	for banner in banners:
		if not is_instance_valid(banner):
			continue
		var face: Control = banner.get_child(0).get_child(0)
		if banner.get_meta("won", false):
			Motion.sparkle(face.get_global_rect().get_center())
			Motion.bounce(face)
		else:
			Motion.wobble(face)


# Mountain: the 8 building slots --------------------------------------------

func _mountain(body: VBoxContainer, narrow: bool) -> void:
	var sect := GameState.sect
	var rank := UiKit.heading(tr("RANK_" + sect.rank().to_upper()))
	var hint := UiKit.label(tr("UI_TAP_BUILDING"), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
	if _selected_building == "":
		_selected_building = _suggested_building()
	var levels := {}
	for building in Balance.BUILDINGS:
		levels[building] = sect.level(building)
	var screen := get_viewport_rect().size
	var width := screen.x - 36.0
	if not narrow:
		width = clampf(minf((screen.x - 36.0) * 0.55, (screen.y - 215.0) * 4.0 / 3.0), 300.0, 640.0)
	var view := MountainView.new(levels, width)
	view.selected = _selected_building
	view.brews_left = maxi(0, sect.level("alchemy_room") - sect.brews_today)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.plot_pressed.connect(func(building: String) -> void:
		_selected_building = building
		_queue_rebuild())
	var detail := _slot(_selected_building)
	if narrow:
		body.add_child(rank)
		body.add_child(hint)
		body.add_child(view)
		body.add_child(detail)
	else:
		# Wide: the picture starts at the top, so it fits without scrolling.
		var row := UiKit.hbox(12)
		row.add_child(view)
		var column := UiKit.vbox(8)
		column.add_child(rank)
		column.add_child(hint)
		column.add_child(detail)
		row.add_child(column)
		body.add_child(row)
	if _shown_building != _selected_building:
		if _shown_building != "":
			Motion.pop.call_deferred(detail)
		_shown_building = _selected_building
	if _celebrate != "":
		view.celebrate.call_deferred(_celebrate)
		_celebrate = ""


## The building to show first: the cheapest upgrade the sect can afford, or
## else the cheapest one left.
func _suggested_building() -> String:
	var sect := GameState.sect
	var best := ""
	var best_cost := 1 << 30
	for affordable_only in [true, false]:
		for building in Balance.BUILDINGS:
			var check := BuildingRules.can_upgrade(sect, building)
			if check["reason"] == "max_level" or (affordable_only and not check["ok"]):
				continue
			if int(check["cost"]) < best_cost:
				best = building
				best_cost = int(check["cost"])
		if best != "":
			return best
	return "main_hall"


func _upgrade(building: String) -> void:
	if GameState.upgrade(building):
		_celebrate = building


func _slot(building: String) -> Control:
	var sect := GameState.sect
	var card := UiKit.card()
	card.size_flags_vertical = Control.SIZE_FILL
	var box := UiKit.vbox(4)
	card.add_child(box)
	var header := UiKit.hbox(10)
	var picture := TextureRect.new()
	picture.texture = Art.texture(MountainArt.building(building, sect.level(building)), 160)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(70, 56)
	header.add_child(picture)
	var name := UiKit.label(tr("BUILDING_" + building.to_upper()), UiKit.FONT_SIZE + 2, UiKit.JADE)
	name.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name)
	box.add_child(header)
	if not BuildingRules.in_play(building):
		box.add_child(UiKit.label(tr("BUILDING_%s_DESC" % building.to_upper()), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		box.add_child(UiKit.label(tr("UI_LOCKED"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		return card
	var level := sect.level(building)
	box.add_child(UiKit.label(tr("UI_LEVEL").format({"level": level}) if level > 0 else tr("UI_NOT_BUILT"), UiKit.SMALL_SIZE))
	box.add_child(UiKit.label(_effect(building), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	if building == "alchemy_room" and level > 0:
		_pills(box)
	var check := BuildingRules.can_upgrade(sect, building)
	var reputation := int(check["reputation"])
	if reputation > 0:
		var have := int(sect.resources["reputation"])
		box.add_child(UiKit.label(tr("UI_NEEDS_REPUTATION").format({"reputation": reputation, "have": have}), UiKit.SMALL_SIZE, UiKit.WARN if have < reputation else UiKit.SOFT_INK))
	if check["reason"] == "max_level":
		box.add_child(UiKit.label(tr("UI_MAX_LEVEL"), UiKit.SMALL_SIZE))
	else:
		var key := "UI_UPGRADE" if level > 0 else "UI_BUILD"
		var b := UiKit.primary(tr(key).format({"cost": check["cost"]}), "upgrade_" + building, _upgrade.bind(building), "stones")
		b.disabled = not check["ok"]
		box.add_child(b)
	return card


func _effect(building: String) -> String:
	var sect := GameState.sect
	var level := sect.level(building)
	match building:
		"main_hall":
			return tr("EFFECT_MAIN_HALL").format({"limit": sect.disciple_limit()})
		"disciple_huts":
			var text := tr("EFFECT_HUTS").format({"mood": BuildingRules.rest_mood(sect)})
			if BuildingRules.heal_per_day(sect) > 1:
				text += " " + tr("EFFECT_HUTS_HEAL")
			return text
		"training_yard":
			if level == 0:
				return tr("EFFECT_TRAINING_YARD_NONE").format({"percent": roundi(100 * Balance.TRAIN_YARD_BONUS)})
			return tr("EFFECT_TRAINING_YARD").format({"percent": roundi(100 * Balance.TRAIN_YARD_BONUS * level)})
		"spirit_field":
			if level == 0:
				return tr("EFFECT_FIELD_NONE").format({"food": BuildingRules.work_food(sect)})
			return tr("EFFECT_FIELD").format({"food": BuildingRules.work_food(sect), "herbs": BuildingRules.work_herbs(sect)})
		"kitchen":
			if level == 0:
				return tr("BUILDING_KITCHEN_DESC")
			return tr("EFFECT_KITCHEN").format({"mood": BuildingRules.kitchen_mood(sect), "per": Balance.KITCHEN_FOOD_PER[level]})
		"alchemy_room":
			if level == 0:
				return tr("BUILDING_ALCHEMY_ROOM_DESC")
			return tr("EFFECT_ALCHEMY").format({"brews": level, "left": maxi(0, level - sect.brews_today)})
		"library":
			if level == 0:
				return tr("BUILDING_LIBRARY_DESC")
			return tr("EFFECT_LIBRARY").format({"level": mini(level, Balance.TECHNIQUE_MAX)})
		"mission_hall":
			if level == 0:
				return tr("BUILDING_MISSION_HALL_DESC")
			var open: Array[String] = []
			for mission: String in Balance.MISSION_HALL_NEEDED:
				if level >= int(Balance.MISSION_HALL_NEEDED[mission]):
					open.append(ReportText.mission_name(mission))
			var text := tr("EFFECT_MISSION_HALL").format({"missions": ", ".join(open)})
			if level >= Balance.MISSION_HALL_REWARD_LEVEL:
				text += " " + tr("EFFECT_MISSION_HALL_BONUS").format({"percent": roundi(100 * Balance.MISSION_HALL_REWARD_BONUS)})
			return text
	return ""


## The Alchemy Room's pills: the stock of each and a "brew_<pill>" button,
## or the level that unlocks it.
func _pills(box: VBoxContainer) -> void:
	var sect := GameState.sect
	for pill in Balance.PILLS:
		var recipe: Dictionary = Balance.RECIPES[pill]
		if sect.level("alchemy_room") < int(recipe["level"]):
			box.add_child(UiKit.label(tr("UI_PILL_LOCKED").format({"pill": ReportText.pill_name(pill), "level": recipe["level"]}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
			continue
		box.add_child(UiKit.label(tr("UI_PILL_STOCK").format({"pill": ReportText.pill_name(pill), "count": sect.item(pill)}), UiKit.SMALL_SIZE))
		var b := UiKit.button(tr("UI_BREW").format({"cost": ReportText.cost(recipe["cost"])}), "brew_" + pill, GameState.brew.bind(pill), true)
		b.disabled = not Alchemy.can_brew(sect, pill)["ok"]
		box.add_child(b)


# Disciples ------------------------------------------------------------------

func _disciples(body: VBoxContainer, _narrow: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = UiKit.columns(self, 340.0, 3)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in GameState.sect.disciples:
		grid.add_child(_disciple_card(d))
	body.add_child(grid)
	if _memories_day != GameState.sect.day:
		_memories_day = GameState.sect.day
		_fetch_memories()


## Reads each disciple's newest memories from the server, then redraws.
func _fetch_memories() -> void:
	var backend := _backend()
	if backend == null:
		return
	for d in GameState.sect.disciples:
		var result: Dictionary = await backend.memories(d.id)
		if not result.get("ok", false):
			return
		_memories[d.id] = result["data"]
	if _tab == "disciples":
		_queue_rebuild()


## How two disciples get along, in words.
func _relationship_words(score: int) -> String:
	if score <= -10:
		return tr("REL_RIVALS")
	if score <= -4:
		return tr("REL_COOL")
	if score < 4:
		return tr("REL_ORDINARY")
	if score < 10:
		return tr("REL_FRIENDLY")
	return tr("REL_CLOSE")


## Talent, Body, Spirit and Wit as small bars out of Balance.STAT_MAX.
func _stat_bars(d: Disciple) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for stat in Balance.STATS:
		var name := UiKit.label(tr("STAT_" + stat.to_upper()), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
		name.size_flags_horizontal = Control.SIZE_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(name)
		var bar := UiKit.bar(d.stat(stat), Balance.STAT_MAX)
		bar.custom_minimum_size = Vector2(60, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var value := UiKit.label(str(d.stat(stat)), UiKit.SMALL_SIZE)
		value.size_flags_horizontal = Control.SIZE_SHRINK_END
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(value)
	return grid


func _disciple_card(d: Disciple) -> Control:
	var sect := GameState.sect
	var root_color: Color = Portrait.ROOT_COLORS.get(d.spirit_root, UiKit.LINE)
	var card := UiKit.card(root_color)
	var box := UiKit.vbox(6)
	card.add_child(box)
	var header := UiKit.hbox(10)
	var portrait := Portrait.of(d)
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expression = "happy" if d.mood >= 3 else ("sad" if d.mood <= -3 else "thinking")
	header.add_child(portrait)
	var who := UiKit.vbox(4)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := UiKit.label(d.display_name(_locale()), UiKit.FONT_SIZE + 3, UiKit.JADE)
	name.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	who.add_child(name)
	var tags := UiKit.flow(4)
	tags.add_child(UiKit.chip(tr("ROOT_" + d.spirit_root.to_upper()), root_color))
	tags.add_child(UiKit.chip(tr("REALM_" + d.realm.to_upper()), UiKit.JADE_LIGHT, "breakthrough" if CultivationRules.can_break_through(d) else ""))
	who.add_child(tags)
	header.add_child(who)
	box.add_child(header)
	box.add_child(UiKit.label("%s %d/%d" % [tr("UI_PROGRESS"), d.progress, Balance.PROGRESS_MAX], UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	box.add_child(UiKit.bar(d.progress, Balance.PROGRESS_MAX))
	var feelings := UiKit.hbox(14)
	feelings.add_child(UiKit.icon_label(Icons.mood_kind(d.mood), "%s %+d" % [tr("UI_MOOD"), d.mood], UiKit.SMALL_SIZE, UiKit.INK, 18.0))
	feelings.add_child(UiKit.icon_label("loyalty", "%s %d" % [tr("UI_LOYALTY"), d.loyalty], UiKit.SMALL_SIZE, UiKit.INK, 18.0))
	for child in feelings.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		((child as HBoxContainer).get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(feelings)
	box.add_child(_stat_bars(d))
	box.add_child(UiKit.label(ReportText.quirks_line(d), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	if d.technique > 0:
		box.add_child(UiKit.label(tr("UI_TECHNIQUE").format({"technique": ReportText.technique_name(CultivationRules.technique_of(d)), "tier": d.technique}), UiKit.SMALL_SIZE))
	if sect.level("library") >= 1 or d.study > 0:
		box.add_child(UiKit.label(tr("UI_STUDY").format({"study": d.study, "max": Balance.STUDY_MAX}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var status := _status_label(d)
	if status:
		box.add_child(status)
	_side_effect_labels(box, d)
	for other in sect.disciples:
		var score := Relationships.score(sect, d.id, other.id)
		if other != d and score != 0:
			var bond := UiKit.hbox(6)
			var face := Portrait.of(other)
			face.custom_minimum_size = Vector2(24, 24)
			face.expression = "happy" if score >= 4 else ("angry" if score <= -4 else "thinking")
			bond.add_child(face)
			var words := UiKit.label(tr("UI_RELATIONSHIP").format({
				"name": other.display_name(_locale()),
				"words": _relationship_words(score),
				"score": "%+d" % score,
			}), UiKit.SMALL_SIZE, UiKit.SOFT_INK)
			words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bond.add_child(words)
			box.add_child(bond)
	var remembered: Array = _memories.get(d.id, [])
	if not remembered.is_empty():
		box.add_child(UiKit.label(tr("UI_REMEMBERS").format({"memories": " / ".join(remembered.slice(0, 3))}), UiKit.SMALL_SIZE))
	return card
