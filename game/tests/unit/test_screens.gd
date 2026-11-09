extends GutTest
## The game screen with everything M5 adds (Showcase.sect()): the controls
## are there, enabled only when they can be used, and do what they say. The
## Backend autoload gets a transport with no network, so nothing leaves the
## machine.

const PATH := "user://test_screens_save.json"

var _saved_path: String
var _saved_backend: BackendService
var _saved_transport: Variant
var _saved_locale: String


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_backend = GameState.backend
	_saved_transport = Backend.transport
	_saved_locale = TranslationServer.get_locale()
	GameState.save_path = PATH
	GameState.backend = null
	Backend.transport = FakeTransport.new()
	TranslationServer.set_locale("en")
	GameState.sect = Showcase.sect()
	GameState.step = "morning"
	GameState.plan = null


func after_each() -> void:
	GameState.save_path = _saved_path
	GameState.backend = _saved_backend
	Backend.transport = _saved_transport
	TranslationServer.set_locale(_saved_locale)
	SaveStore.delete(PATH)


func _screen() -> GameScreen:
	var screen := GameScreen.new()
	screen.size = Vector2(480, 900)
	add_child_autofree(screen)
	await wait_process_frames(2)
	return screen


## Every probed control on screen, by probe id.
func _probes(node: Node, found: Dictionary = {}) -> Dictionary:
	if node.has_meta("probe"):
		found[String(node.get_meta("probe"))] = node
	for child in node.get_children():
		_probes(child, found)
	return found


func _texts(node: Node, found: Array[String] = []) -> Array[String]:
	if node is Label:
		found.append((node as Label).text)
	elif node is Button:
		found.append((node as Button).text)
	for child in node.get_children():
		_texts(child, found)
	return found


func _has_text(screen: Node, part: String) -> bool:
	return _texts(screen).any(func(text: String) -> bool: return text.contains(part))


func _press(screen: GameScreen, id: String) -> void:
	var button: Button = _probes(screen).get(id)
	assert_not_null(button, id)
	if button:
		assert_false(button.disabled, id + " is enabled")
		button.pressed.emit()
	await wait_process_frames(2)


func test_the_morning_event_comes_before_the_plan() -> void:
	var sect := GameState.sect
	sect.resources["stones"] = 10
	var screen := await _screen()
	var probes := _probes(screen)
	assert_true(probes["plan_day"].disabled, "the day waits for the event")
	assert_true(_has_text(screen, "The Wandering Master"))
	assert_true(probes["event_pay_lesson"].disabled, "20 Spirit Stones is too much today")
	assert_true(probes["event_take_lesson"].text.contains("5 Food"), "a paid choice shows its price")
	await _press(screen, "event_take_lesson")
	assert_false(EventRules.pending(sect))
	probes = _probes(screen)
	assert_false(probes.has("event_decline"), "no more choices")
	assert_false(probes["plan_day"].disabled)
	assert_true(_has_text(screen, "You chose: Trade a meal for a lesson"))
	assert_true(_has_text(screen, "cultivation progress"), "the result shows on the card")


func test_a_hopeful_can_be_welcomed_or_sent_home() -> void:
	var sect := GameState.sect
	var count := sect.disciples.size()
	var cost := Recruiting.cost(sect)
	var screen := await _screen()
	assert_true(_has_text(screen, "A hopeful at the gate"))
	await _press(screen, "recruit_accept")
	assert_eq(sect.disciples.size(), count + 1)
	assert_eq(int(sect.resources["stones"]), 140 - cost)
	assert_false(_probes(screen).has("recruit_accept"), "the card is gone")

	GameState.sect = Showcase.sect()
	GameState.sect.resources["stones"] = 0
	screen = await _screen()
	assert_true(_probes(screen)["recruit_accept"].disabled)
	assert_true(_has_text(screen, "Not enough Spirit Stones yet."))
	await _press(screen, "recruit_decline")
	assert_true(GameState.sect.candidate.is_empty())


func test_the_plan_offers_breakthroughs_study_and_healing() -> void:
	var sect := GameState.sect
	EventRules.choose(sect, "decline")
	assert_true(GameState.start_planning())
	var screen := await _screen()
	var ready := sect.disciples[0]
	var green := sect.disciples[1]
	var hurt := sect.disciples[2]
	var gone := sect.disciples[3]
	var fresh := sect.disciples[4]
	var probes := _probes(screen)
	var percent := roundi(100 * CultivationRules.chance(sect, ready, "foundation_pill"))
	assert_eq(probes["choose_%s_breakthrough" % ready.id].text, "Break through (%d%%, uses a Foundation Pill)" % percent)
	assert_false(probes.has("choose_%s_breakthrough" % green.id), "only ready disciples")
	assert_eq(probes["choose_%s_study" % fresh.id].text, "Study (0/100)")
	assert_false(probes.has("choose_%s_study" % green.id), "the Library has taught them all it can")
	assert_true(probes.has("choose_%s_explore_secret_realm" % fresh.id), "the Mission Hall unlocked it")
	assert_false(probes.has("choose_%s_train" % gone.id), "away disciples can't be planned")
	assert_true(_has_text(screen, "Has left the sect for now."))
	assert_true(_has_text(screen, "Green hair, 4 more days. Only funny."))
	assert_false(probes.has("choose_%s_train" % hurt.id), "the injured rest")
	await _press(screen, "heal_" + hurt.id)
	assert_false(hurt.is_injured())
	assert_true(_probes(screen).has("choose_%s_train" % hurt.id), "healed, they can be planned again")
	assert_false(_probes(screen).has("heal_" + green.id), "that was the last Healing Pill")


func test_the_mountain_brews_pills_and_shows_every_building() -> void:
	var sect := GameState.sect
	var screen := await _screen()
	await _press(screen, "tab_mountain")
	var probes := _probes(screen)
	for building in Balance.BUILDINGS:
		assert_true(probes.has("plot_" + building), building)
		assert_true(_has_text(screen, ReportText.t("BUILDING_" + building.to_upper())), building)
	assert_true(probes.has("upgrade_disciple_huts"), "starts on the cheapest upgrade it can afford (the first of three at 100)")
	await _press(screen, "plot_mission_hall")
	assert_true(_has_text(screen, "Unlocks: Escort a Merchant, Explore a Secret Realm."))
	await _press(screen, "plot_main_hall")
	assert_true(_has_text(screen, "The next level needs 50 Reputation (the sect has 22)."))
	assert_true(_probes(screen)["upgrade_main_hall"].disabled, "not famous enough yet")
	assert_false(_probes(screen).has("upgrade_mission_hall"), "one building's card at a time")
	await _press(screen, "plot_alchemy_room")
	await _press(screen, "brew_golden_pill")
	assert_eq(sect.item("golden_pill"), 1)
	assert_eq(int(sect.resources["herbs"]), 15)
	await _press(screen, "brew_foundation_pill")
	assert_eq(sect.item("foundation_pill"), 2)
	assert_eq(int(sect.resources["herbs"]), 5)
	assert_true(_probes(screen)["brew_foundation_pill"].disabled, "out of Herbs")
	assert_true(_probes(screen)["brew_healing_pill"].disabled)
	assert_true(_has_text(screen, "Brews 3 pills a day (1 left today)."))
	assert_true(_probes(screen).has("brew_golden_pill"), "the Alchemy Room stays picked after a brew")


func test_an_upgrade_from_the_mountain_raises_the_level() -> void:
	var sect := GameState.sect
	var screen := await _screen()
	await _press(screen, "tab_mountain")
	await _press(screen, "plot_kitchen")
	await _press(screen, "upgrade_kitchen")
	assert_eq(sect.level("kitchen"), 2)
	assert_eq(int(sect.resources["stones"]), 40)
	assert_true(_has_text(screen, "Kitchen · 2"), "the badge shows the new level")


func test_the_disciples_tab_shows_techniques_study_and_effects() -> void:
	var screen := await _screen()
	await _press(screen, "tab_disciples")
	var green := GameState.sect.disciples[1]
	var technique := ReportText.technique_name(CultivationRules.technique_of(green))
	assert_true(_has_text(screen, "Technique: %s, level 1" % technique))
	assert_true(_has_text(screen, "Study: 40/100"))
	assert_true(_has_text(screen, "Green hair, 4 more days."))
	assert_true(_has_text(screen, "Has left the sect for now."))


func test_the_hud_floats_gains_and_the_action_bar_follows_the_step() -> void:
	var overlay := Control.new()
	overlay.add_to_group(Motion.OVERLAY_GROUP)
	add_child_autofree(overlay)
	var saved_motion := Settings.reduce_motion
	Settings.reduce_motion = false
	var screen := await _screen()
	assert_true(_probes(screen)["plan_day"].disabled)
	assert_true(_has_text(screen, "Decide what to do about this before you plan the day."))
	GameState.sect.add_resource("stones", 12)
	await _press(screen, "event_decline")
	await wait_process_frames(3)
	var floats := overlay.get_children().filter(func(n: Node) -> bool: return n is Label)
	assert_eq(floats.map(func(l: Label) -> String: return l.text), ["+12"])
	assert_false(_probes(screen)["plan_day"].disabled)
	GameState.start_planning()
	await wait_process_frames(2)
	assert_true(_probes(screen).has("done_planning"))
	assert_false(_probes(screen).has("plan_day"))
	await _press(screen, "tab_mountain")
	assert_true(_probes(screen).has("done_planning"), "the day goes on from any tab")
	Settings.reduce_motion = saved_motion
