class_name MorningCards
extends RefCounted
## The morning's cards: the surprise event with its choices (and, once
## chosen, what happened), and a hopeful waiting at the gate. Built from the
## sect every time the screen is rebuilt.


static func t(key: String) -> String:
	return ReportText.t(key)


## Today's event, when there is one: pending (choice buttons, probes
## "event_<choice>") or resolved (the choice and its results). [param writing]
## is true while Claude is still writing its words. With [param reveal]
## (the choice was just made), the results appear one by one and the pair
## cheer or wobble.
static func event_card(sect: Sect, locale: String, writing: bool, reveal: bool = false) -> Control:
	var event := sect.event
	var pending := EventRules.pending(sect)
	var card := UiKit.card(UiKit.PLUM)
	var box := UiKit.vbox(6)
	card.add_child(box)
	var title := UiKit.icon_label("event", ReportText.event_title(sect, event, locale), UiKit.FONT_SIZE + 2, UiKit.JADE, 26.0)
	(title.get_child(1) as Label).add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	box.add_child(title)
	box.add_child(UiKit.label(t("UI_EVENT_AT").format({"place": ReportText.place_name(String(event["place"]))}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))

	var face := "nervous"
	if not pending:
		face = "sad" if event.get("result") == "lose" else "happy"
	var faces := UiKit.hbox(12)
	var portraits: Array[Control] = []
	for id: Variant in event["disciples"]:
		var d := sect.disciple(String(id))
		if d:
			var who := _face(d, locale, face)
			portraits.append(who.get_child(0))
			faces.add_child(who)
	box.add_child(faces)

	if pending and writing and not event.get("words", {}).has("story"):
		box.add_child(UiKit.label(t("UI_EVENT_WRITING"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	else:
		box.add_child(UiKit.label(ReportText.event_story(sect, event, locale)))

	if pending:
		for choice: Dictionary in EventRules.choices(sect):
			var id := String(choice["id"])
			var text := ReportText.event_choice(sect, event, id, locale)
			var price: Dictionary = EventCatalog.choice(event["problem"], id).get("cost", {})
			if not price.is_empty():
				text = t("UI_CHOICE_COST").format({"choice": text, "cost": ReportText.cost(price)})
			var b := UiKit.button(text, "event_" + id, func() -> void: GameState.choose_event(id), true)
			b.disabled = not choice["ok"]
			box.add_child(b)
	else:
		var chosen := ReportText.event_choice(sect, event, String(event["choice"]), locale)
		box.add_child(UiKit.label(t("UI_EVENT_CHOSE").format({"choice": chosen}), UiKit.SMALL_SIZE, UiKit.JADE))
		var results: Array[Control] = []
		for line in ReportText.event_result(sect, event, locale):
			var result := UiKit.label(line, UiKit.SMALL_SIZE)
			results.append(result)
			box.add_child(result)
		if reveal:
			_reveal.call_deferred(results, portraits, event.get("result") != "lose")
	return card


## The results appear one by one; the faces cheer (with sparkles) or wobble.
static func _reveal(results: Array[Control], portraits: Array[Control], good: bool) -> void:
	for i in results.size():
		Motion.pop(results[i], 0.12 * i)
	for portrait in portraits:
		if not is_instance_valid(portrait):
			continue
		if good:
			Motion.bounce(portrait)
			Motion.sparkle(portrait.get_global_rect().get_center())
		else:
			Motion.wobble(portrait)


## The hopeful at the gate, with "recruit_accept" and "recruit_decline".
static func candidate_card(sect: Sect, locale: String) -> Control:
	var hopeful := Recruiting.candidate(sect)
	var card := UiKit.card(UiKit.GOLD)
	var box := UiKit.vbox(6)
	card.add_child(box)
	box.add_child(UiKit.icon_label("gate", t("UI_CANDIDATE"), UiKit.SMALL_SIZE, UiKit.SOFT_INK, 20.0))
	var row := UiKit.hbox()
	var portrait := Portrait.of(hopeful)
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expression = "happy"
	row.add_child(portrait)
	var info := UiKit.vbox(2)
	info.add_child(UiKit.label(hopeful.display_name(locale), UiKit.FONT_SIZE + 2, UiKit.JADE))
	info.add_child(UiKit.label("%s · %s" % [t("ROOT_" + hopeful.spirit_root.to_upper()), ReportText.realm_name(hopeful.realm)], UiKit.SMALL_SIZE))
	row.add_child(info)
	box.add_child(row)
	box.add_child(UiKit.label(ReportText.stats_line(hopeful), UiKit.SMALL_SIZE))
	box.add_child(UiKit.label(ReportText.quirks_line(hopeful), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	box.add_child(UiKit.label(t("UI_CANDIDATE_COST").format({
		"name": hopeful.display_name(locale),
		"cost": Recruiting.cost(sect),
		"day": int(sect.candidate["until"]),
	}), UiKit.SMALL_SIZE))

	var check := Recruiting.can_accept(sect)
	match String(check["reason"]):
		"full":
			box.add_child(UiKit.label(t("UI_RECRUIT_FULL"), UiKit.SMALL_SIZE, UiKit.WARN))
		"not_enough_stones":
			box.add_child(UiKit.label(t("UI_RECRUIT_POOR"), UiKit.SMALL_SIZE, UiKit.WARN))
	var buttons := UiKit.hbox()
	var accept := UiKit.primary(t("UI_RECRUIT_ACCEPT"), "recruit_accept", func() -> void: GameState.recruit(true), "disciples")
	accept.disabled = not check["ok"]
	buttons.add_child(accept)
	buttons.add_child(UiKit.button(t("UI_RECRUIT_DECLINE"), "recruit_decline", func() -> void: GameState.recruit(false), true))
	box.add_child(buttons)
	return card


static func _face(d: Disciple, locale: String, expression: String) -> Control:
	var who := UiKit.vbox(2)
	var portrait := Portrait.of(d)
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expression = expression
	who.add_child(portrait)
	var name := UiKit.label(d.display_name(locale), UiKit.SMALL_SIZE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(name)
	return who


# The world (M6) -------------------------------------------------------------------

## Toggle buttons for picking champions or defenders ([param kind]
## "tournament" or "battle"), probes "champion_<id>" or "defender_<id>".
static func _picker(sect: Sect, kind: String, locale: String) -> HFlowContainer:
	var row := UiKit.flow(6)
	var picked := GameState.picks_for(kind)
	var prefix := "champion_" if kind == "tournament" else "defender_"
	for d in Tournament.eligible(sect):
		var id := d.id
		row.add_child(UiKit.choice(d.display_name(locale), prefix + id, id in picked, func() -> void: GameState.toggle_pick(kind, id), "train"))
	return row


static func _place_word(place: int) -> String:
	return t("PLACE_WORD_%d" % place)


## The season's tournament: pick champions and enter ("tournament_enter") or
## sit it out ("tournament_skip"); once played, the place and the matches.
static func tournament_card(sect: Sect, locale: String, reveal: bool = false) -> Control:
	var tournament := sect.tournament
	var card := UiKit.card(UiKit.GOLD)
	var box := UiKit.vbox(6)
	card.add_child(box)
	var title := UiKit.icon_label("medal", t("UI_TOURNAMENT"), UiKit.FONT_SIZE + 2, UiKit.JADE, 26.0)
	(title.get_child(1) as Label).add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	box.add_child(title)
	var emblems := UiKit.hbox(10)
	for rival in RivalCatalog.ids():
		var emblem := Icons.rect(rival, 32.0)
		emblem.tooltip_text = ReportText.rival_name(rival)
		emblems.add_child(emblem)
	box.add_child(emblems)
	if Tournament.pending(sect):
		box.add_child(UiKit.label(t("UI_TOURNAMENT_PICK"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		if Tournament.eligible(sect).is_empty():
			box.add_child(UiKit.label(t("UI_NO_CHAMPIONS"), UiKit.SMALL_SIZE, UiKit.WARN))
		else:
			box.add_child(_picker(sect, "tournament", locale))
		var picked := GameState.picks_for("tournament")
		if not picked.is_empty():
			box.add_child(UiKit.chip(t("UI_LIKELY_PLACE").format({"place": _place_word(Tournament.likely_place(sect, picked))}), UiKit.JADE_LIGHT, "medal"))
		var buttons := UiKit.flow(8)
		var enter := UiKit.primary(t("UI_ENTER_TOURNAMENT"), "tournament_enter", func() -> void: GameState.enter_tournament(), "medal")
		enter.disabled = picked.is_empty()
		buttons.add_child(enter)
		buttons.add_child(UiKit.button(t("UI_SIT_OUT"), "tournament_skip", func() -> void: GameState.skip_tournament()))
		box.add_child(buttons)
		return card
	if tournament.get("skipped", false):
		box.add_child(UiKit.label(t("UI_SAT_OUT"), UiKit.FONT_SIZE, UiKit.SOFT_INK))
		return card
	var place := int(tournament["place"])
	var results: Array[Control] = []
	var heading := UiKit.heading(t("UI_PLACE_RESULT").format({"place": _place_word(place)}))
	results.append(heading)
	box.add_child(heading)
	for m: Dictionary in tournament["matches"]:
		var line := UiKit.icon_label(String(m["rival"]), _first_upper(t("MATCH_WON" if m["won"] else "MATCH_LOST").format({"rival": ReportText.rival_name(m["rival"])})), UiKit.SMALL_SIZE, UiKit.INK, 22.0)
		results.append(line)
		box.add_child(line)
	var won := ReportText.amounts(tournament["rewards"])
	if won != "":
		var prize := UiKit.label(t("FACT_REWARDS").format({"rewards": won}), UiKit.SMALL_SIZE, UiKit.JADE)
		results.append(prize)
		box.add_child(prize)
	if reveal:
		var medal: Array[Control] = [title.get_child(0)]
		_reveal.call_deferred(results, medal, place <= 3)
	return card


## Today's battle: pick defenders and defend ("battle_defend"), or pay for
## peace ("battle_peace"); once fought, the result.
static func battle_card(sect: Sect, locale: String, reveal: bool = false) -> Control:
	var war := sect.war
	var rival := String(war["rival"])
	var card := UiKit.card(UiKit.WARN)
	var box := UiKit.vbox(6)
	card.add_child(box)
	var title := UiKit.icon_label(rival, t("UI_BATTLE").format({"rival": ReportText.rival_name(rival)}), UiKit.FONT_SIZE + 2, UiKit.JADE, 30.0)
	(title.get_child(1) as Label).add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	box.add_child(title)
	if Wars.pending(sect):
		box.add_child(UiKit.label(t("UI_BATTLE_PICK"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		box.add_child(_picker(sect, "battle", locale))
		var picked := GameState.picks_for("battle")
		box.add_child(UiKit.chip(t("UI_WIN_CHANCE").format({"percent": roundi(100 * Wars.win_chance(sect, picked))}), UiKit.JADE_LIGHT, "banner"))
		var buttons := UiKit.flow(8)
		buttons.add_child(UiKit.primary(t("UI_DEFEND"), "battle_defend", func() -> void: GameState.defend(), "banner"))
		var peace := UiKit.button(t("UI_MAKE_PEACE").format({"cost": Wars.peace_cost(sect)}), "battle_peace", func() -> void: GameState.make_peace())
		peace.disabled = not Wars.can_make_peace(sect)
		buttons.add_child(peace)
		box.add_child(buttons)
		return card
	var won := bool(war["won"])
	var result := UiKit.heading(t("UI_BATTLE_WON" if won else "UI_BATTLE_LOST").format({"land": sect.land}))
	box.add_child(result)
	if reveal:
		var lines: Array[Control] = [result]
		var emblem: Array[Control] = [title.get_child(0)]
		_reveal.call_deferred(lines, emblem, won)
	return card


## A war on its way (before the battle day), with "war_peace".
static func war_banner(sect: Sect) -> Control:
	var rival := String(sect.war["rival"])
	var card := UiKit.card(UiKit.WARN)
	var box := UiKit.vbox(6)
	card.add_child(box)
	box.add_child(UiKit.icon_label("banner", t("UI_WAR_BANNER").format({"rival": ReportText.rival_name(rival), "day": int(sect.war["battle_day"])}), UiKit.FONT_SIZE, UiKit.WARN, 26.0))
	box.add_child(UiKit.label(t("UI_WAR_HINT"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var peace := UiKit.button(t("UI_MAKE_PEACE").format({"cost": Wars.peace_cost(sect)}), "war_peace", func() -> void: GameState.make_peace())
	peace.disabled = not Wars.can_make_peace(sect)
	box.add_child(peace)
	return card


## A disciple asks to travel: "travel_go" or "travel_stay".
static func travel_card(sect: Sect, locale: String) -> Control:
	var request := sect.travel_request
	var d := sect.disciple(String(request["disciple"]))
	var card := UiKit.card(Portrait.ROOT_COLORS.get(d.spirit_root, UiKit.LINE) if d else UiKit.LINE)
	var box := UiKit.vbox(6)
	card.add_child(box)
	var row := UiKit.hbox(10)
	if d:
		var portrait := Portrait.of(d)
		portrait.custom_minimum_size = Vector2(56, 56)
		portrait.expression = "happy"
		row.add_child(portrait)
	var words := UiKit.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UiKit.label(t("UI_TRAVEL_ASK").format({
		"name": sect.name_of(String(request["disciple"]), locale),
		"place": ReportText.travel_place_name(String(request["place"])),
		"days": int(request["days"]),
	})))
	words.add_child(UiKit.label(t("UI_TRAVEL_NOTE"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	row.add_child(words)
	box.add_child(row)
	var buttons := UiKit.flow(8)
	buttons.add_child(UiKit.primary(t("UI_TRAVEL_GO"), "travel_go", func() -> void: GameState.answer_travel(true), "mountain"))
	buttons.add_child(UiKit.button(t("UI_TRAVEL_STAY"), "travel_stay", func() -> void: GameState.answer_travel(false)))
	box.add_child(buttons)
	return card


## This morning's letter, on paper. [param writing] while Claude is still
## writing it.
static func letter_card(sect: Sect, locale: String, writing: bool) -> Control:
	var letter := sect.letter
	var card := UiKit.card(UiKit.LINE)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.98, 0.95, 0.86)
	paper.border_color = UiKit.LINE
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(4)
	paper.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", paper)
	var box := UiKit.vbox(8)
	card.add_child(box)
	var who := sect.name_of(String(letter["disciple"]), locale)
	box.add_child(UiKit.icon_label("letter", t("UI_LETTER").format({"name": who}), UiKit.FONT_SIZE, UiKit.JADE, 24.0))
	if writing and String(letter.get("words", "")) == "":
		box.add_child(UiKit.label(t("UI_LETTER_WRITING"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	else:
		box.add_child(UiKit.label(ReportText.letter_text(sect, letter, locale)))
	var gift := ReportText.gift_text(letter.get("gift", {}), String(letter.get("item", "none")))
	if gift != "":
		box.add_child(UiKit.label(t("UI_LETTER_GIFT").format({"gift": gift}), UiKit.SMALL_SIZE, UiKit.JADE))
	return card


static func _first_upper(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
