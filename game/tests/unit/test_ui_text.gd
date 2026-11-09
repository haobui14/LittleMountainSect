extends GutTest
## Screens build some keys from ids ("BUILDING_" + id, "TIER_" + tier...).
## Every id the rules know needs its text, in both languages.


func _key_families() -> Array[String]:
	var keys: Array[String] = []
	for step in GameState.STEPS:
		keys.append("UI_STEP_" + step.to_upper())
	for tab in GameScreen.TABS:
		keys.append("UI_TAB_" + tab.to_upper())
	for task in Balance.HOME_TASKS:
		keys.append("TASK_" + task.to_upper())
	for tier in Balance.TIERS:
		keys.append("TIER_" + tier.to_upper())
		keys.append("FACT_MISSION_" + tier.to_upper())
	for mission: String in Balance.MISSIONS:
		keys.append("MISSION_" + mission.to_upper())
	for building in Balance.BUILDINGS:
		keys.append("BUILDING_" + building.to_upper())
		if not BuildingRules.in_play(building):
			keys.append("BUILDING_%s_DESC" % building.to_upper())
	for rank in Balance.RANKS:
		if rank != "":
			keys.append("RANK_" + rank.to_upper())
	for root in Balance.SPIRIT_ROOTS:
		keys.append("ROOT_" + root.to_upper())
	for realm in Balance.REALMS:
		keys.append("REALM_" + realm.to_upper())
	for stat in Balance.STATS:
		keys.append("STAT_" + stat.to_upper())
	for resource in Balance.RESOURCES:
		keys.append("RES_" + resource.to_upper())
	for quirk in Quirks.ids():
		for prefix in ["QUIRK_", "TALK_", "EVENING_"]:
			keys.append(prefix + quirk.to_upper())
	for day in range(1, 6):
		keys.append("ELDER_TIP_%d" % day)
	for expression in ReportText.CHAT_EXPRESSIONS:
		for n in [1, 2]:
			keys.append("CHAT_%s_%d" % [expression.to_upper(), n])
	for n in [1, 2, 3]:
		keys.append("ELDER_OFFLINE_%d" % n)
	for action in Balance.ACTIONS:
		keys.append("ACTION_" + action.to_upper())
	for pill in Balance.PILLS:
		keys.append("PILL_" + pill.to_upper())
	for effect in Balance.SIDE_EFFECTS:
		keys.append("SIDE_" + effect.to_upper())
		keys.append("SIDE_%s_RULE" % effect.to_upper())
	for technique in Balance.TECHNIQUES:
		keys.append("TECHNIQUE_" + technique.to_upper())
	for place: String in EventCatalog.PLACES:
		keys.append("PLACE_" + place.to_upper())
	for problem: String in EventCatalog.PROBLEMS:
		keys.append("EVENT_%s_TITLE" % problem.to_upper())
		keys.append("EVENT_%s_STORY" % problem.to_upper())
		for choice in EventCatalog.choice_ids(problem):
			keys.append("EVENT_%s_%s" % [problem.to_upper(), choice.to_upper()])
	return keys


func test_every_id_has_text_in_both_languages() -> void:
	var previous := TranslationServer.get_locale()
	var missing: Array[String] = []
	for locale in ["en", "vi"]:
		TranslationServer.set_locale(locale)
		for key in _key_families():
			if tr(key) == key:
				missing.append("%s (%s)" % [key, locale])
	TranslationServer.set_locale(previous)
	assert_eq(missing, [] as Array[String])
