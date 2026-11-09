extends GutTest
## The look-and-feel helpers: every icon draws, animations end where they
## should, "Less motion" turns them all off, and gains float on the overlay.

var _saved_motion: bool
var _overlay: Control


func before_each() -> void:
	_saved_motion = Settings.reduce_motion
	Settings.reduce_motion = false
	_overlay = Control.new()
	_overlay.add_to_group(Motion.OVERLAY_GROUP)
	add_child_autofree(_overlay)


func after_each() -> void:
	Settings.reduce_motion = _saved_motion


func test_every_icon_draws() -> void:
	for kind: String in Icons.BODIES:
		var texture := Icons.texture(kind, 32)
		assert_eq(texture.get_width(), 32, kind)
		assert_eq(texture.get_height(), 32, kind)
	assert_eq(Icons.texture("stones", 32), Icons.texture("stones", 32), "drawn once and kept")
	for task in Balance.HOME_TASKS:
		assert_true(Icons.has(Icons.task_kind(task)), task)
	for mission: String in Balance.MISSIONS:
		assert_true(Icons.has(Icons.task_kind(mission)), mission)
	for resource in Balance.RESOURCES:
		assert_true(Icons.has(resource), resource)
	for pill in Balance.PILLS:
		assert_true(Icons.has(pill), pill)


func test_a_pop_ends_full_size_and_fully_shown() -> void:
	var box := ColorRect.new()
	box.size = Vector2(40, 40)
	add_child_autofree(box)
	Motion.pop(box)
	assert_almost_eq(box.modulate.a, 0.0, 0.01, "starts hidden")
	await wait_seconds(Motion.NORMAL + 0.15)
	assert_almost_eq(box.modulate.a, 1.0, 0.01)
	assert_almost_eq(box.scale.x, 1.0, 0.01)


func test_less_motion_turns_every_animation_off() -> void:
	Settings.reduce_motion = true
	var box := ColorRect.new()
	add_child_autofree(box)
	Motion.pop(box)
	Motion.fade_in(box)
	Motion.bounce(box)
	Motion.wobble(box)
	assert_eq([box.modulate.a, box.scale, box.rotation], [1.0, Vector2.ONE, 0.0])
	var label := Label.new()
	add_child_autofree(label)
	Motion.count(label, 3, 9)
	assert_eq(label.text, "9", "numbers jump straight to their value")
	assert_null(Motion.float_text("+5", Vector2(10, 10)))
	Motion.sparkle(Vector2(10, 10))
	assert_eq(_overlay.get_child_count(), 0)


func test_gains_float_up_and_numbers_count() -> void:
	var label := Motion.float_text("+12", Vector2(100, 100))
	assert_not_null(label)
	assert_eq(label.get_parent(), _overlay)
	assert_eq(label.text, "+12")
	var counter := Label.new()
	add_child_autofree(counter)
	Motion.count(counter, 0, 50)
	await wait_seconds(Motion.SLOW + 0.15)
	assert_eq(counter.text, "50")
	await wait_seconds(Motion.FLOAT_TIME)
	assert_false(is_instance_valid(label), "the floating text cleans itself up")
