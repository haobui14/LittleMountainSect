extends GutTest
## Every fact the rules can produce reads as a finished sentence in both
## languages: no raw keys and no unfilled {placeholders}.

const FACT_TYPES: Array[String] = [
	"trained", "worked", "rested", "healed", "mission_departed", "mission_returned",
	"injured", "lost_cultivation", "ate", "hungry",
]

var _locale: String


func before_all() -> void:
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


func _bad(line: String) -> bool:
	return line == "" or "{" in line or "}" in line or line.contains("FACT_") \
		or line.contains("EVENING_") or line.contains("MORNING_") or line.contains("TALK_")


## Plays a few busy seeds so every fact type shows up at least once.
func _reports() -> Array:
	var played: Array = []
	for seed_value in 12:
		var sect := NewGame.create(seed_value)
		sect.resources["food"] = 2
		var policy := SimRng.new(seed_value)
		for day in 25:
			var plan := SimPlayers.random(sect, policy)
			var report := DayResolver.resolve(sect, plan)
			played.append({"sect": sect, "report": report, "morning": ReportText.morning(sect, "en")})
	return played


func test_every_fact_type_turns_into_sentences_in_both_languages() -> void:
	var played := _reports()
	var seen := {}
	var bad: Array[String] = []
	for locale in ["en", "vi"]:
		TranslationServer.set_locale(locale)
		for entry: Dictionary in played:
			var report: DayReport = entry["report"]
			for fact in report.facts:
				seen[fact["type"]] = true
			for line in ReportText.evening(report, entry["sect"], locale):
				if _bad(line):
					bad.append("%s: %s" % [locale, line])
			for line in ReportText.morning(entry["sect"], locale):
				if _bad(line):
					bad.append("%s: %s" % [locale, line])
	for type in FACT_TYPES:
		assert_true(seen.has(type), "the test games produced a %s fact" % type)
	assert_eq(bad, [] as Array[String])


func test_names_join_naturally_in_each_language() -> void:
	var sect := SimFixtures.sect()
	TranslationServer.set_locale("en")
	assert_eq(ReportText.names(sect, ["a", "b", "c"], "en"), "Test a, Test b and Test c")
	TranslationServer.set_locale("vi")
	assert_eq(ReportText.names(sect, ["a", "b"], "vi"), "Thử a và Thử b")


func test_mission_rewards_are_listed_and_empty_rewards_are_left_out() -> void:
	TranslationServer.set_locale("en")
	assert_eq(ReportText.amounts({"stones": 30, "reputation": 2, "food": 0}), "+30 Spirit Stones, +2 Reputation")
	var sect := SimFixtures.sect()
	var fact := {"type": "mission_returned", "mission": "hunt_monster", "tier": "failure", "team": ["a"], "rewards": {"stones": 0}}
	assert_eq(ReportText.describe(fact, sect, "en"), "Test a came back from Hunt a Monster: it didn't go well.")


func test_the_first_five_mornings_carry_an_elder_tip() -> void:
	TranslationServer.set_locale("en")
	var sect := NewGame.create(1)
	for day in range(1, 7):
		sect.day = day
		var has_tip := ReportText.morning(sect, "en").any(func(l: String) -> bool: return l.begins_with("Elder Mo Wen"))
		assert_eq(has_tip, day <= 5, "day %d" % day)


func test_every_quirk_has_a_talk_line_and_an_evening_line() -> void:
	for locale in ["en", "vi"]:
		TranslationServer.set_locale(locale)
		for quirk in Quirks.ids():
			var d := SimFixtures.disciple("a")
			d.quirks.assign([quirk, quirk])
			assert_false(_bad(ReportText.talk_line(d, 1, locale)), "%s %s" % [locale, quirk])
			assert_false(_bad(ReportText.t(Quirks.text_key(quirk))) or ReportText.t(Quirks.text_key(quirk)).begins_with("QUIRK_"), quirk)
