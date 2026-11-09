extends GutTest
## The layered portrait: each disciple always looks the same, disciples look
## different from each other, and side effects show.


func test_a_disciple_always_gets_the_same_hair() -> void:
	var sect := NewGame.create(3)
	var d := sect.disciples[0]
	var first := Portrait.of(d)
	var again := Portrait.of(Disciple.from_dict(d.to_dict()))
	assert_eq([first.hair_style, first.hair_color], [again.hair_style, again.hair_color])
	assert_eq(first.ring, Portrait.ROOT_COLORS[d.spirit_root])
	first.free()
	again.free()


func test_disciples_get_a_mix_of_styles_and_colours() -> void:
	var sect := NewGame.create(9)
	for i in 27:
		sect.disciples.append(DiscipleGenerator.generate(sect))
	var styles := {}
	var colours := {}
	for d in sect.disciples:
		var p := Portrait.of(d)
		styles[p.hair_style] = true
		colours[p.hair_color] = true
		p.free()
	assert_eq(styles.size(), Portrait.HAIR_STYLES.size(), "every style turns up")
	assert_eq(colours.size(), Portrait.HAIR_COLORS.size(), "every colour turns up")


func test_side_effects_show_and_the_elder_looks_like_the_elder() -> void:
	var d := SimFixtures.disciple("a")
	d.add_effect("green_hair", 3)
	d.add_effect("glowing", 3)
	var p := Portrait.of(d)
	assert_eq(p.hair_color, Portrait.GREEN_HAIR)
	assert_true(p.glowing)
	p.expression = "sleepy"
	assert_eq(p.expression, "thinking", "unknown faces fall back to thinking")
	p.free()
	var elder := Portrait.new("", true)
	assert_eq([elder.hair_color, elder.ring], [Portrait.ELDER_HAIR, Portrait.ELDER_ROBE])
	elder.free()
