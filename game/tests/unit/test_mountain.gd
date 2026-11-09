extends GutTest
## The illustrated mountain: every building has art at every level, plots
## sit inside the picture without overlapping at phone and desktop sizes,
## and pressing a plot says which.


func test_every_building_has_art_at_every_level() -> void:
	assert_eq(MountainArt.PLOTS.keys().size(), Balance.BUILDINGS.size())
	for building in Balance.BUILDINGS:
		assert_true(MountainArt.PLOTS.has(building), building)
		for level in range(0, Balance.MAX_LEVEL + 1):
			var texture := Art.texture(MountainArt.building(building, level), 100)
			assert_eq(texture.get_size(), Vector2(100, 80), "%s %d" % [building, level])
	assert_eq(Art.texture(MountainArt.backdrop(), 400).get_size(), Vector2(400, 300))
	assert_ne(MountainArt.building("kitchen", 1), MountainArt.building("kitchen", 2), "levels look different")


func _view(width: float) -> MountainView:
	var levels := {}
	for building in Balance.BUILDINGS:
		levels[building] = 1
	var view := MountainView.new(levels, width)
	add_child_autofree(view)
	return view


func test_plots_fit_the_picture_and_never_overlap() -> void:
	# A phone's canvas is about 456 wide; a desktop's mountain about 350.
	for width in [456.0, 350.0, 300.0]:
		var view := _view(width)
		await wait_process_frames(2)
		var picture := Rect2(Vector2.ZERO, view.size)
		assert_almost_eq(view.size.y, width * 0.75, 0.5, "4:3")
		var rects := {}
		for building: String in MountainArt.PLOTS:
			var rect := view.plot_rect(building)
			assert_true(picture.encloses(rect), "%s inside at %d" % [building, width])
			for other: String in rects:
				assert_false(rect.intersects(rects[other]), "%s and %s overlap at %d" % [building, other, width])
			rects[building] = rect


func test_pressing_a_plot_names_its_building() -> void:
	var view := _view(456.0)
	await wait_process_frames(2)
	watch_signals(view)
	for child in view.get_children():
		if child is Button and child.get_meta("probe", "") == "plot_library":
			(child as Button).pressed.emit()
	assert_signal_emitted_with_parameters(view, "plot_pressed", ["library"])


func test_scenery_has_no_plots() -> void:
	var view := MountainView.new({"main_hall": 1}, 400.0, false)
	add_child_autofree(view)
	await wait_process_frames(1)
	assert_true(view.get_children().filter(func(c: Node) -> bool: return c is Button).is_empty())
