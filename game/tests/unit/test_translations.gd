extends GutTest
## Every translation key needs English and Vietnamese text, and the game
## must actually load both, so no player ever sees a raw key.

const CSV_PATH := "res://i18n/strings.csv"
const LOCALES: Array[String] = ["en", "vi"]


func _read_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		fail_test("Cannot open %s" % CSV_PATH)
		return rows
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1 or row[0] != "":
			rows.append(row)
	return rows


func test_header_is_keys_english_vietnamese() -> void:
	assert_eq(Array(_read_rows()[0]), ["keys", "en", "vi"])


func test_every_key_has_english_and_vietnamese_text() -> void:
	var incomplete: Array[String] = []
	for row in _read_rows().slice(1):
		if row.size() < 3 or row[1].strip_edges() == "" or row[2].strip_edges() == "":
			incomplete.append(row[0])
	assert_true(incomplete.is_empty(), "Keys missing text: %s" % [incomplete])


func test_keys_are_unique() -> void:
	var seen := {}
	var duplicates: Array[String] = []
	for row in _read_rows().slice(1):
		if seen.has(row[0]):
			duplicates.append(row[0])
		seen[row[0]] = true
	assert_true(duplicates.is_empty(), "Duplicate keys: %s" % [duplicates])


func test_game_loads_the_text_for_each_language() -> void:
	var previous_locale := TranslationServer.get_locale()
	var wrong: Array[String] = []
	for row in _read_rows().slice(1):
		for column in LOCALES.size():
			TranslationServer.set_locale(LOCALES[column])
			if tr(row[0]) != row[column + 1]:
				wrong.append("%s (%s)" % [row[0], LOCALES[column]])
	TranslationServer.set_locale(previous_locale)
	assert_true(wrong.is_empty(), "Not loaded by the game: %s" % [wrong])
