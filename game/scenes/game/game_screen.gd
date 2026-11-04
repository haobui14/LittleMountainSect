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
## Disciple id -> the line they said in free time today.
var _talk_lines := {}


func _ready() -> void:
	Events.state_changed.connect(_queue_rebuild)
	get_viewport().size_changed.connect(_queue_rebuild)
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
	if is_instance_valid(_scroll):
		_scroll_value = _scroll.scroll_vertical
	UiKit.clear(self)
	var narrow := UiKit.is_narrow(self)
	var root := UiKit.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var tabs := _tabs()
	if not narrow:
		root.add_child(_hud(narrow))
		root.add_child(tabs)
	else:
		root.add_child(_hud(narrow))
	var scroll: Array = UiKit.scroll_column()
	root.add_child(scroll[0])
	_scroll = scroll[0]
	_restore_scroll.call_deferred(_scroll, _scroll_value)
	var body: VBoxContainer = scroll[1]
	match _tab:
		"mountain":
			_mountain(body, narrow)
		"disciples":
			_disciples(body, narrow)
		_:
			_today(body)
	if narrow:
		root.add_child(tabs)


func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


# Resource bar and tabs ------------------------------------------------------

func _hud(narrow: bool) -> Control:
	var panel := PanelContainer.new()
	var box := UiKit.vbox(4)
	panel.add_child(box)
	var top := UiKit.hbox()
	# The evening belongs to the day that just ended.
	var day := GameState.report.day if GameState.step == "results" and GameState.report else GameState.sect.day
	var title := UiKit.label("%s · %s" % [tr("UI_DAY").format({"day": day}), tr("UI_STEP_" + GameState.step.to_upper())], UiKit.FONT_SIZE, UiKit.JADE)
	top.add_child(title)
	top.add_child(UiKit.button(tr("UI_MENU"), "menu", func() -> void: navigate.emit("title")))
	box.add_child(top)
	var resources := UiKit.flow(14)
	for resource in Balance.RESOURCES:
		resources.add_child(UiKit.label("%s %d" % [ReportText.resource_name(resource), int(GameState.sect.resources[resource])], UiKit.SMALL_SIZE))
	for child in resources.get_children():
		(child as Label).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(resources)
	if not GameState.saving_works:
		box.add_child(UiKit.label(tr("UI_NOT_SAVING"), UiKit.SMALL_SIZE, UiKit.WARN))
	if not narrow:
		box.add_theme_constant_override("separation", 2)
	return panel


func _tabs() -> Control:
	var row := UiKit.hbox(4)
	for tab in TABS:
		var b := UiKit.choice(tr("UI_TAB_" + tab.to_upper()), "tab_" + tab, _tab == tab, func() -> void:
			_tab = tab
			_scroll_value = 0
			_queue_rebuild())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


# Today: the day's steps ----------------------------------------------------

func _today(body: VBoxContainer) -> void:
	body.add_child(UiKit.heading(tr("UI_STEP_" + GameState.step.to_upper())))
	match GameState.step:
		"morning":
			for line in ReportText.morning(GameState.sect, _locale()):
				body.add_child(UiKit.label(line))
			body.add_child(UiKit.button(tr("UI_PLAN_DAY"), "plan_day", GameState.start_planning, true))
		"plan":
			_plan(body)
		"free_time":
			_free_time(body)
		"results":
			_results(body)


func _plan(body: VBoxContainer) -> void:
	var sect := GameState.sect
	body.add_child(UiKit.label(tr("UI_PLAN_HINT"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	for d in sect.disciples:
		var card := UiKit.card()
		var box := UiKit.vbox(6)
		card.add_child(box)
		box.add_child(UiKit.label(d.display_name(_locale()), UiKit.FONT_SIZE, UiKit.JADE))
		var away := sect.mission_of(d.id)
		if away:
			box.add_child(UiKit.label(tr("UI_AWAY").format({"mission": ReportText.mission_name(away.mission), "day": away.return_day}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		elif d.is_injured():
			box.add_child(UiKit.label(tr("UI_INJURED").format({"days": d.injury_days()}), UiKit.SMALL_SIZE, UiKit.WARN))
		else:
			var row := UiKit.flow()
			var current := GameState.choice_of(d.id)
			for choice in GameState.choices():
				var text := tr("TASK_" + choice.to_upper()) if choice in Balance.HOME_TASKS else ReportText.mission_name(choice)
				row.add_child(UiKit.choice(text, "choose_%s_%s" % [d.id, choice], current == choice, GameState.choose.bind(d.id, choice)))
			box.add_child(row)
		body.add_child(card)

	for entry in GameState.plan.missions:
		var team: Array = entry["team"]
		var likely := MissionResolver.expected_tier(sect, entry["mission"], team)
		body.add_child(UiKit.label(tr("UI_TEAM").format({
			"mission": ReportText.mission_name(entry["mission"]),
			"names": ReportText.names(sect, team, _locale()),
			"tier": tr("TIER_" + likely.to_upper()),
		})))
	var errors := GameState.plan_errors()
	for error in errors:
		var key := "ERR_TEAM_SIZE" if error.begins_with("team_size") else "ERR_PLAN"
		body.add_child(UiKit.label(tr(key), UiKit.SMALL_SIZE, UiKit.WARN))
	var done := UiKit.button(tr("UI_DONE_PLANNING"), "done_planning", GameState.finish_planning, true)
	done.disabled = not errors.is_empty()
	body.add_child(done)


func _free_time(body: VBoxContainer) -> void:
	var sect := GameState.sect
	body.add_child(UiKit.label(tr("UI_FREE_TIME_HINT"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	for d in sect.disciples:
		if sect.is_away(d.id):
			continue
		var card := UiKit.card()
		var box := UiKit.vbox(6)
		card.add_child(box)
		var row := UiKit.hbox()
		row.add_child(UiKit.label("%s · %s %+d" % [d.display_name(_locale()), tr("UI_MOOD"), d.mood], UiKit.FONT_SIZE, UiKit.JADE))
		var talk := UiKit.button(tr("UI_TALK") if FreeTime.can_talk(d) else tr("UI_TALKED"), "talk_" + d.id, _talk.bind(d))
		talk.disabled = not FreeTime.can_talk(d)
		row.add_child(talk)
		box.add_child(row)
		if _talk_lines.has(d.id):
			box.add_child(UiKit.label(_talk_lines[d.id], UiKit.SMALL_SIZE))
		body.add_child(card)
	body.add_child(UiKit.button(tr("UI_END_DAY"), "end_day", _end_day, true))


func _talk(d: Disciple) -> void:
	var gained := GameState.talk(d.id)
	_talk_lines[d.id] = "%s  (%s)" % [ReportText.talk_line(d, GameState.sect.day, _locale()), tr("UI_MOOD_UP").format({"mood": gained})]


func _end_day() -> void:
	_talk_lines.clear()
	_scroll_value = 0
	GameState.end_day()


func _results(body: VBoxContainer) -> void:
	var report := GameState.report
	if report:
		for line in ReportText.evening(report, GameState.sect, _locale()):
			body.add_child(UiKit.label(line))
		var changes := ReportText.amounts(report.resource_changes)
		body.add_child(UiKit.label(tr("UI_CHANGES").format({"changes": changes}) if changes != "" else tr("UI_NO_CHANGES"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	body.add_child(UiKit.button(tr("UI_NEXT_MORNING"), "next_morning", GameState.next_morning, true))


# Mountain: the 8 building slots --------------------------------------------

func _mountain(body: VBoxContainer, _narrow: bool) -> void:
	body.add_child(UiKit.heading(tr("RANK_" + GameState.sect.rank().to_upper())))
	var grid := GridContainer.new()
	grid.columns = UiKit.columns(self, 220.0, 4)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for building in Balance.BUILDINGS:
		grid.add_child(_slot(building))
	body.add_child(grid)


func _slot(building: String) -> Control:
	var sect := GameState.sect
	var card := UiKit.card()
	card.size_flags_vertical = Control.SIZE_FILL
	var box := UiKit.vbox(4)
	card.add_child(box)
	box.add_child(UiKit.label(tr("BUILDING_" + building.to_upper()), UiKit.FONT_SIZE, UiKit.JADE))
	if not BuildingRules.in_play(building):
		box.add_child(UiKit.label(tr("BUILDING_%s_DESC" % building.to_upper()), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		box.add_child(UiKit.label(tr("UI_LOCKED"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		return card
	var level := sect.level(building)
	box.add_child(UiKit.label(tr("UI_LEVEL").format({"level": level}) if level > 0 else tr("UI_NOT_BUILT"), UiKit.SMALL_SIZE))
	box.add_child(UiKit.label(_effect(building), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var check := BuildingRules.can_upgrade(sect, building)
	if check["reason"] == "max_level":
		box.add_child(UiKit.label(tr("UI_MAX_LEVEL"), UiKit.SMALL_SIZE))
	else:
		var key := "UI_UPGRADE" if level > 0 else "UI_BUILD"
		var b := UiKit.button(tr(key).format({"cost": check["cost"]}), "upgrade_" + building, func() -> void: GameState.upgrade(building), true)
		b.disabled = not check["ok"]
		box.add_child(b)
	return card


func _effect(building: String) -> String:
	var sect := GameState.sect
	match building:
		"main_hall":
			return tr("EFFECT_MAIN_HALL").format({"limit": sect.disciple_limit()})
		"disciple_huts":
			var text := tr("EFFECT_HUTS").format({"mood": BuildingRules.rest_mood(sect)})
			if BuildingRules.heal_per_day(sect) > 1:
				text += " " + tr("EFFECT_HUTS_HEAL")
			return text
		"training_yard":
			if sect.level(building) == 0:
				return tr("EFFECT_TRAINING_YARD_NONE").format({"percent": roundi(100 * Balance.TRAIN_YARD_BONUS)})
			return tr("EFFECT_TRAINING_YARD").format({"percent": roundi(100 * Balance.TRAIN_YARD_BONUS * sect.level(building))})
		"spirit_field":
			if sect.level(building) == 0:
				return tr("EFFECT_FIELD_NONE").format({"food": BuildingRules.work_food(sect)})
			return tr("EFFECT_FIELD").format({"food": BuildingRules.work_food(sect), "herbs": BuildingRules.work_herbs(sect)})
	return ""


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


func _disciple_card(d: Disciple) -> Control:
	var sect := GameState.sect
	var card := UiKit.card()
	var box := UiKit.vbox(4)
	card.add_child(box)
	box.add_child(UiKit.label(d.display_name(_locale()), UiKit.FONT_SIZE + 2, UiKit.JADE))
	box.add_child(UiKit.label("%s · %s" % [tr("ROOT_" + d.spirit_root.to_upper()), tr("REALM_" + d.realm.to_upper())], UiKit.SMALL_SIZE))
	box.add_child(UiKit.label("%s %d/%d" % [tr("UI_PROGRESS"), d.progress, Balance.PROGRESS_MAX], UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	box.add_child(UiKit.bar(d.progress, Balance.PROGRESS_MAX))
	var stats: Array[String] = []
	for stat in Balance.STATS:
		stats.append("%s %d" % [tr("STAT_" + stat.to_upper()), d.stat(stat)])
	box.add_child(UiKit.label(" · ".join(stats), UiKit.SMALL_SIZE))
	box.add_child(UiKit.label("%s %+d · %s %d" % [tr("UI_MOOD"), d.mood, tr("UI_LOYALTY"), d.loyalty], UiKit.SMALL_SIZE))
	var quirks: Array[String] = []
	for quirk in d.quirks:
		quirks.append(tr(Quirks.text_key(quirk)))
	box.add_child(UiKit.label(tr("UI_QUIRKS").format({"quirks": ", ".join(quirks)}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var away := sect.mission_of(d.id)
	if away:
		box.add_child(UiKit.label(tr("UI_AWAY").format({"mission": ReportText.mission_name(away.mission), "day": away.return_day}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	elif d.is_injured():
		box.add_child(UiKit.label(tr("UI_INJURED").format({"days": d.injury_days()}), UiKit.SMALL_SIZE, UiKit.WARN))
	return card
