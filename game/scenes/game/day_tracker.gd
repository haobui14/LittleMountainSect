class_name DayTracker
extends HBoxContainer
## The day's four steps (Morning → Plan → Free time → Evening) as dots on a
## line, with the current one filled in and the finished ones ticked.


class Dot:
	extends Control
	## One step's dot, with the line running through it to its neighbours.

	var state := "next"
	var first := false
	var last := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 18)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y / 2.0)
		var line := UiKit.JADE_LIGHT if state != "next" else UiKit.LINE
		if not first:
			draw_line(Vector2(0, c.y), c, UiKit.JADE_LIGHT if state != "next" else UiKit.LINE, 2.0, true)
		if not last:
			draw_line(c, Vector2(size.x, c.y), UiKit.JADE_LIGHT if state == "done" else UiKit.LINE, 2.0, true)
		match state:
			"current":
				draw_circle(c, 7.5, UiKit.JADE, true, -1.0, true)
				draw_circle(c, 3.0, UiKit.CARD, true, -1.0, true)
			"done":
				draw_circle(c, 6.0, line, true, -1.0, true)
			_:
				draw_circle(c, 5.5, UiKit.CARD, true, -1.0, true)
				draw_circle(c, 5.5, UiKit.LINE, false, 2.0, true)


func _init(step: String) -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at := GameState.STEPS.find(step)
	for i in GameState.STEPS.size():
		var column := UiKit.vbox(0)
		var dot := Dot.new()
		dot.first = i == 0
		dot.last = i == GameState.STEPS.size() - 1
		dot.state = "done" if i < at else ("current" if i == at else "next")
		column.add_child(dot)
		var name := UiKit.label(tr("UI_STEP_" + GameState.STEPS[i].to_upper()), UiKit.SMALL_SIZE - 2, UiKit.JADE if i == at else UiKit.SOFT_INK)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name)
		add_child(column)
