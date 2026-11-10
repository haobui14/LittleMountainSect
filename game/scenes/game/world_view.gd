class_name WorldView
extends RefCounted
## The World tab (M6): the season and the hills the sect holds, a war on
## its way, a card for each rival sect (Attitude, Trust, and the gift, trade
## and alliance buttons, each disabled with the reason), and the Sect
## Chronicle grouped by season, newest first. Built from the sect every time
## the screen is rebuilt.

## Chronicle entries shown at first, and added by "Show older".
const CHRONICLE_PAGE := 20


static func t(key: String) -> String:
	return ReportText.t(key)


## Adds the tab's cards to [param body]. [param shown] is how many Chronicle
## entries to show; [param more] is called by "Show older".
static func build(body: VBoxContainer, sect: Sect, locale: String, columns: int, shown: int, more: Callable) -> void:
	var day := sect.day
	var season := ReportText.season_name(Seasons.season(day))
	var days := Seasons.days_to_tournament(day)
	var header := UiKit.card(UiKit.JADE_LIGHT)
	var top := UiKit.vbox(6)
	header.add_child(top)
	var line := t("UI_SEASON_TODAY") if days == 0 else t("UI_SEASON_LINE")
	top.add_child(UiKit.icon_label("today", line.format({"season": season, "year": Seasons.year(day), "days": days}), UiKit.FONT_SIZE, UiKit.INK, 22.0))
	top.add_child(UiKit.icon_label("hill", t("UI_LAND").format({
		"land": sect.land, "food": Balance.LAND_FOOD * sect.land, "herbs": Balance.LAND_HERBS * sect.land,
	}), UiKit.SMALL_SIZE, UiKit.INK, 22.0))
	body.add_child(header)
	if Wars.active(sect) and not Wars.pending(sect):
		body.add_child(MorningCards.war_banner(sect))

	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for rival in RivalCatalog.ids():
		grid.add_child(rival_card(sect, rival))
	body.add_child(grid)
	body.add_child(chronicle(sect, locale, shown, more))


## The color of an Attitude, from brick red to jade.
static func attitude_color(attitude: int) -> Color:
	var share := clampf((attitude - Balance.ATTITUDE_MIN) / float(Balance.ATTITUDE_MAX - Balance.ATTITUDE_MIN), 0.0, 1.0)
	return UiKit.WARN.lerp(UiKit.JADE_LIGHT, share)


## One rival sect: its emblem, what it's like, Attitude and Trust, and what
## the Sect Master can do. Probes: gift_<rival>_<resource>, trade_<rival>,
## ally_<rival>, end_<rival>.
static func rival_card(sect: Sect, rival: String) -> Control:
	var attitude := Rivals.attitude(sect, rival)
	var card := UiKit.card(attitude_color(attitude))
	var box := UiKit.vbox(6)
	card.add_child(box)
	var head := UiKit.hbox(10)
	head.add_child(Icons.rect(rival, 44.0))
	var names := UiKit.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UiKit.label(ReportText.rival_name(rival), UiKit.FONT_SIZE + 2, UiKit.JADE)
	name.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	names.add_child(name)
	var chips := UiKit.flow(4)
	if Rivals.is_ally(sect, rival):
		chips.add_child(UiKit.chip(t("UI_ALLY_CHIP"), UiKit.JADE_LIGHT, "gate"))
	if Wars.at_war_with(sect, rival):
		chips.add_child(UiKit.chip(t("UI_AT_WAR_CHIP"), UiKit.WARN, "banner"))
	if chips.get_child_count() > 0:
		names.add_child(chips)
	else:
		chips.free()
	head.add_child(names)
	box.add_child(head)
	box.add_child(UiKit.label(t("RIVAL_%s_ABOUT" % rival.to_upper()), UiKit.SMALL_SIZE, UiKit.SOFT_INK))

	var word := t("ATT_" + Rivals.mood_word(sect, rival).to_upper())
	box.add_child(UiKit.label(t("UI_ATTITUDE").format({"word": word, "value": "%+d" % attitude}), UiKit.SMALL_SIZE))
	var meter := UiKit.bar(attitude - Balance.ATTITUDE_MIN, Balance.ATTITUDE_MAX - Balance.ATTITUDE_MIN)
	var fill := StyleBoxFlat.new()
	fill.bg_color = attitude_color(attitude)
	fill.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("fill", fill)
	box.add_child(meter)
	box.add_child(UiKit.label(t("UI_TRUST").format({"value": Rivals.trust(sect, rival)}), UiKit.SMALL_SIZE))
	box.add_child(UiKit.bar(Rivals.trust(sect, rival), Balance.TRUST_MAX))

	# Gifts: one button per resource; the favourite first.
	var favourite: String = RivalCatalog.RIVALS[rival]["favourite"]
	var resources: Array = [favourite]
	for resource: String in Balance.GIFT_COST:
		if resource != favourite:
			resources.append(resource)
	var gifts := UiKit.flow(6)
	var waiting := false
	for resource: String in resources:
		var check := Rivals.can_gift(sect, rival, resource)
		waiting = waiting or check["reason"] == "too_soon"
		var cost := ReportText.quantities({resource: Balance.GIFT_COST[resource]})
		var b := UiKit.button(t("UI_GIFT").format({"cost": cost}), "gift_%s_%s" % [rival, resource], func() -> void: GameState.gift(rival, resource), false, resource)
		b.disabled = not check["ok"]
		gifts.add_child(b)
	box.add_child(gifts)
	if waiting:
		box.add_child(UiKit.label(t("UI_GIFT_WAIT").format({"day": Rivals.next_gift_day(sect, rival)}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))

	var deal := Rivals.offer(sect, rival)
	var trade_check := Rivals.can_trade(sect, rival)
	var trade := UiKit.button(t("UI_TRADE").format({"give": ReportText.quantities(deal["give"]), "get": ReportText.quantities(deal["get"])}), "trade_" + rival, func() -> void: GameState.trade(rival), true, "stones")
	trade.disabled = not trade_check["ok"]
	box.add_child(trade)
	match String(trade_check["reason"]):
		"done":
			box.add_child(UiKit.label(t("UI_TRADE_DONE").format({"day": Rivals.next_trade_day(sect)}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
		"cold":
			box.add_child(UiKit.label(t("UI_TRADE_COLD"), UiKit.SMALL_SIZE, UiKit.WARN))
		"at_war":
			box.add_child(UiKit.label(t("UI_TRADE_WAR"), UiKit.SMALL_SIZE, UiKit.WARN))

	if Rivals.is_ally(sect, rival):
		box.add_child(UiKit.button(t("UI_END_ALLIANCE"), "end_" + rival, func() -> void: GameState.end_alliance(rival), true))
	else:
		var ally := UiKit.button(t("UI_ALLY"), "ally_" + rival, func() -> void: GameState.ally(rival), true, "gate")
		ally.disabled = not Rivals.can_ally(sect, rival)["ok"]
		box.add_child(ally)
		if ally.disabled:
			box.add_child(UiKit.label(t("UI_ALLY_NEEDS").format({"attitude": Balance.ALLIANCE_ATTITUDE, "trust": Balance.ALLIANCE_TRUST}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	return card


## The Sect Chronicle: the newest [param shown] entries, grouped by season,
## with "Show older" (probe "chronicle_more") when there are more.
static func chronicle(sect: Sect, locale: String, shown: int, more: Callable) -> Control:
	var card := UiKit.card(UiKit.PLUM)
	var box := UiKit.vbox(4)
	card.add_child(box)
	box.add_child(UiKit.icon_label("event", t("UI_CHRONICLE"), UiKit.FONT_SIZE + 2, UiKit.JADE, 24.0))
	var entries: Array[Dictionary] = []
	for i in range(sect.chronicle.size() - 1, -1, -1):
		if ReportText.chronicle_line(sect.chronicle[i], sect, locale) != "":
			entries.append(sect.chronicle[i])
	if entries.is_empty():
		box.add_child(UiKit.label(t("UI_CHRONICLE_EMPTY"), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	var group := -1
	for entry in entries.slice(0, shown):
		var day := int(entry["day"])
		if Seasons.number(day) != group:
			group = Seasons.number(day)
			box.add_child(UiKit.label(t("UI_CHRONICLE_SEASON").format({
				"season": ReportText.season_name(Seasons.season(day)), "year": Seasons.year(day),
			}), UiKit.SMALL_SIZE, UiKit.JADE))
		box.add_child(UiKit.label("%s · %s" % [t("UI_DAY").format({"day": day}), ReportText.chronicle_line(entry, sect, locale)], UiKit.SMALL_SIZE))
	if entries.size() > shown:
		box.add_child(UiKit.button(t("UI_SHOW_OLDER"), "chronicle_more", more))
	if not sect.alumni.is_empty():
		var names: Array[String] = []
		for alum in sect.alumni:
			names.append(sect.name_of(String(alum["id"]), locale))
		box.add_child(UiKit.label(t("UI_ALUMNI").format({"names": ", ".join(names)}), UiKit.SMALL_SIZE, UiKit.SOFT_INK))
	return card
