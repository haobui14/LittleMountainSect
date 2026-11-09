class_name MorningCards
extends RefCounted
## The morning's cards: the surprise event with its choices (and, once
## chosen, what happened), and a hopeful waiting at the gate. Built from the
## sect every time the screen is rebuilt.


static func t(key: String) -> String:
	return ReportText.t(key)


## Today's event, when there is one: pending (choice buttons, probes
## "event_<choice>") or resolved (the choice and its results). [param writing]
## is true while Claude is still writing its words.
static func event_card(sect: Sect, locale: String, writing: bool) -> Control:
	var event := sect.event
	var pending := EventRules.pending(sect)
	var card := UiKit.card()
	var box := UiKit.vbox(6)
	card.add_child(box)
	box.add_child(UiKit.label(ReportText.event_title(sect, event, locale), UiKit.FONT_SIZE + 2, UiKit.JADE))
	box.add_child(UiKit.label(t("UI_EVENT_AT").format({"place": ReportText.place_name(String(event["place"]))}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))

	var face := "nervous"
	if not pending:
		face = "sad" if event.get("result") == "lose" else "happy"
	var faces := UiKit.hbox(12)
	for id: Variant in event["disciples"]:
		var d := sect.disciple(String(id))
		if d:
			faces.add_child(_face(d, locale, face))
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
		for line in ReportText.event_result(sect, event, locale):
			box.add_child(UiKit.label(line, UiKit.SMALL_SIZE))
	return card


## The hopeful at the gate, with "recruit_accept" and "recruit_decline".
static func candidate_card(sect: Sect, locale: String) -> Control:
	var hopeful := Recruiting.candidate(sect)
	var card := UiKit.card()
	var box := UiKit.vbox(6)
	card.add_child(box)
	box.add_child(UiKit.label(t("UI_CANDIDATE"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
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
	var accept := UiKit.button(t("UI_RECRUIT_ACCEPT"), "recruit_accept", func() -> void: GameState.recruit(true), true)
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
