class_name TypingReport
extends RefCounted
## Describes typed text for the Vietnamese typing test (M2): every Unicode
## code point, and whether the keyboard sent separate combining marks
## (decomposed text) instead of single precomposed letters.

const MAX_CODE_POINTS := 60


## "U+0043 C, U+01B0 ư, …" for the first MAX_CODE_POINTS characters.
static func code_points(text: String) -> String:
	var parts := PackedStringArray()
	for i in mini(text.length(), MAX_CODE_POINTS):
		var code := text.unicode_at(i)
		var shown := char(code) if code >= 0x20 else "?"
		parts.append("U+%04X %s" % [code, shown])
	if text.length() > MAX_CODE_POINTS:
		parts.append("…")
	return ", ".join(parts)


## True when the text holds combining diacritical marks (U+0300 to U+036F),
## meaning the keyboard sent a letter and its tone mark separately.
static func has_combining_marks(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x0300 and code <= 0x036F:
			return true
	return false


## The report a tester copies and sends back.
static func build(text: String, box: String, browser: String, locale: String) -> String:
	return "\n".join(PackedStringArray([
		"Little Mountain Sect typing test",
		"Box: %s" % box,
		"Language: %s" % locale,
		"Browser: %s" % browser,
		"Text: %s" % text,
		"Characters: %d" % text.length(),
		"Combining marks: %s" % ("yes" if has_combining_marks(text) else "no"),
		"Code points: %s" % code_points(text),
	]))
