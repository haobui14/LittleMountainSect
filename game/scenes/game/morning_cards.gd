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
