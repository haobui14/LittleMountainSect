extends GutTest
## The typing report must show exactly what the keyboard sent, so testers can
## tell a working Vietnamese keyboard from a broken one.

const PRECOMPOSED := "Chưởng" # ở is one code point, U+1EDF
const DECOMPOSED := "Chửơng" # u + horn + hook, then o + horn


func test_code_points_name_each_character() -> void:
	assert_eq(TypingReport.code_points("Aư"), "U+0041 A, U+01B0 ư")


func test_precomposed_vietnamese_has_no_combining_marks() -> void:
	assert_false(TypingReport.has_combining_marks(PRECOMPOSED))
	assert_string_contains(TypingReport.code_points(PRECOMPOSED), "U+1EDF ở")


func test_decomposed_vietnamese_is_flagged() -> void:
	assert_true(TypingReport.has_combining_marks(DECOMPOSED))
	assert_string_contains(TypingReport.code_points(DECOMPOSED), "U+031B")


func test_long_text_is_cut_with_an_ellipsis() -> void:
	var listed := TypingReport.code_points("a".repeat(100)).split(", ")
	assert_eq(listed.size(), TypingReport.MAX_CODE_POINTS + 1)
	assert_eq(listed[-1], "…")


func test_report_has_everything_a_tester_sends_back() -> void:
	var report := TypingReport.build(DECOMPOSED, "browser", "Firefox 140", "vi")
	for line in ["Box: browser", "Language: vi", "Browser: Firefox 140", "Combining marks: yes"]:
		assert_string_contains(report, line)
