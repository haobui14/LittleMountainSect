class_name MountainView
extends Control
## The illustrated mountain (art from MountainArt). Each of the 8 plots is a
## flat button (probe "plot_<building>") with a name badge; pressing one
## selects it (plot_pressed), and the screen shows that building's card.
## Mist drifts, birds cross, the Kitchen smokes, the Alchemy Room glows
## while it has brews left, and leaky roofs drip. With "Less motion" on, the
## picture stands still. The title screen uses it as scenery, without plots.

signal plot_pressed(building: String)

## Redraws a second while anything moves.
const FPS := 30.0

## Building -> level shown.
var levels := {}
var selected := ""
var show_plots := true
## Alchemy brews left today (the glow shows while there are some).
var brews_left := 0

var _backdrop: Texture2D
var _buildings := {}
var _time := 0.0
var _since_draw := 0.0
var _celebrate := ""
var _celebrate_time := -1.0


## [param picture_width] is in canvas units; the height follows (4:3).
func _init(building_levels: Dictionary, picture_width: float, with_plots: bool = true) -> void:
	levels = building_levels
	show_plots = with_plots
	custom_minimum_size = Vector2(picture_width, picture_width * MountainArt.VIEW.y / MountainArt.VIEW.x)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Mist drifts in from beyond the edges; keep it inside the picture.
	clip_contents = true
	_time = randf() * 20.0


func _ready() -> void:
	_draw_art()
	if show_plots:
		_add_plots()
	resized.connect(func() -> void:
		_draw_art()
		_place_plots())


## Plays a little pop and sparkle on [param building] (after an upgrade).
func celebrate(building: String) -> void:
	_celebrate = building
	_celebrate_time = 0.0
	if not Motion.enabled():
		return
	await get_tree().process_frame
	if is_instance_valid(self):
		Motion.sparkle(get_global_rect().position + base_of(building) - Vector2(0, 26 * _scale()))


## Picture units to canvas units.
func _scale() -> float:
	return size.x / MountainArt.VIEW.x


## Where [param building] stands, in this control's coordinates.
func base_of(building: String) -> Vector2:
	var fraction: Vector2 = MountainArt.PLOTS[building]
	return Vector2(fraction.x * size.x, fraction.y * size.y)


## The clickable area of a plot, in this control's coordinates. Plots never
## overlap (test_mountain.gd checks).
func plot_rect(building: String) -> Rect2:
	var k := _scale() * MountainArt.PLOT_SCALE
	var base := base_of(building)
	return Rect2(base + Vector2(-44, -58) * k, Vector2(88, 62) * k)


func _draw_art() -> void:
	var pixels := int(size.x * Art.density(self))
	_backdrop = Art.texture(MountainArt.backdrop(), pixels)
	_buildings = {}
	var box_pixels := int(MountainArt.BOX.x * MountainArt.BUILDING_SCALE * _scale() * Art.density(self))
	for building: String in MountainArt.PLOTS:
		if show_plots or int(levels.get(building, 0)) > 0:
			_buildings[building] = Art.texture(MountainArt.building(building, int(levels.get(building, 0))), box_pixels)
	queue_redraw()


func _add_plots() -> void:
	for building: String in MountainArt.PLOTS:
		var plot := Button.new()
		plot.flat = true
		plot.focus_mode = Control.FOCUS_NONE
		plot.tooltip_text = tr("BUILDING_" + building.to_upper())
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			plot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		plot.pressed.connect(func() -> void: plot_pressed.emit(building))
		UiKit.probe(plot, "plot_" + building)
		plot.set_meta("building", building)
		add_child(plot)
		var level := int(levels.get(building, 0))
		var text := tr("BUILDING_" + building.to_upper())
		if level > 0:
			text += " · %d" % level
		var color := UiKit.GOLD if building == selected else (UiKit.JADE_LIGHT if level > 0 else UiKit.LINE)
		var badge := UiKit.chip(text, color)
		badge.set_meta("badge", building)
		(badge.get_child(0).get_child(0) as Label).add_theme_font_size_override("font_size", UiKit.SMALL_SIZE - 2)
		add_child(badge)
	_place_plots.call_deferred()


func _place_plots() -> void:
	for child in get_children():
		if child.has_meta("building"):
			var rect := plot_rect(String(child.get_meta("building")))
			(child as Control).position = rect.position
			(child as Control).size = rect.size
		elif child.has_meta("badge"):
			var badge := child as Control
			badge.reset_size()
			var base := base_of(String(child.get_meta("badge")))
			badge.position = base - Vector2(badge.size.x / 2.0, badge.size.y * 0.55)


func _process(delta: float) -> void:
	if not Motion.enabled() or not is_visible_in_tree():
		return
	_time += delta
	if _celebrate_time >= 0.0:
		_celebrate_time += delta
		if _celebrate_time > 0.6:
			_celebrate_time = -1.0
	_since_draw += delta
	if _since_draw >= 1.0 / FPS:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	if _backdrop:
		draw_texture_rect(_backdrop, Rect2(Vector2.ZERO, size), false)
	var moving := Motion.enabled()
	var k := _scale()
	if moving:
		_draw_mist(0.42, 9.0, 0.0)
	for building: String in MountainArt.PLOTS:
		if not _buildings.has(building):
			continue
		var base := base_of(building)
		var box := MountainArt.BOX * MountainArt.BUILDING_SCALE * k
		var origin := base - MountainArt.BASE * MountainArt.BUILDING_SCALE * k
		if building == selected and show_plots:
			draw_set_transform(base, 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, 46.0 * k, Color(UiKit.GOLD, 0.35), true, -1.0, true)
			draw_circle(Vector2.ZERO, 46.0 * k, UiKit.GOLD, false, 2.5, true)
			draw_set_transform(Vector2.ZERO)
		var grow := 1.0
		if building == _celebrate and _celebrate_time >= 0.0:
			grow = 1.0 + 0.12 * sin(_celebrate_time / 0.6 * PI)
		draw_set_transform(base, 0.0, Vector2(grow, grow))
		draw_texture_rect(_buildings[building], Rect2(origin - base, box), false)
		draw_set_transform(Vector2.ZERO)
		if moving:
			_draw_life(building, origin, k * MountainArt.BUILDING_SCALE)
	if moving:
		_draw_mist(0.8, 6.0, 7.0)
		_draw_birds()


## A drifting band of mist at [param height] (a fraction of the picture).
func _draw_mist(height: float, speed: float, offset: float) -> void:
	var k := _scale()
	var span := size.x + 160.0 * k
	for i in 3:
		var x := fposmod(_time * speed * k + offset * 40.0 * k + i * span / 3.0, span) - 80.0 * k
		var y := size.y * height + sin(_time * 0.3 + i) * 4.0 * k
		draw_set_transform(Vector2(x, y), 0.0, Vector2(3.2, 1.0))
		draw_circle(Vector2.ZERO, 16.0 * k, Color(1, 1, 1, 0.32), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)


## Three birds cross the sky every 20 seconds or so.
func _draw_birds() -> void:
	var k := _scale()
	var cycle := fposmod(_time, 20.0)
	if cycle > 9.0:
		return
	var x0 := -20.0 * k + cycle / 9.0 * (size.x + 40.0 * k)
	for i in 3:
		var p := Vector2(x0 - i * 14.0 * k, size.y * (0.12 + 0.03 * i) + sin(_time * 2.0 + i) * 3.0 * k)
		var flap := sin(_time * 12.0 + i * 1.7) * 3.0 * k
		var wing := 5.0 * k
		draw_polyline(PackedVector2Array([p + Vector2(-wing, -flap), p, p + Vector2(wing, -flap)]), Color(UiKit.INK, 0.7), maxf(1.0, 1.4 * k), true)


## Smoke, glow and drips for one building.
func _draw_life(building: String, origin: Vector2, k: float) -> void:
	var level := int(levels.get(building, 0))
	if level == 0:
		return
	if building == "kitchen":
		var top := origin + MountainArt.chimney(level) * k
		for i in 3:
			var p := fposmod(_time * 0.45 + i / 3.0, 1.0)
			var at := top + Vector2(sin(_time * 1.5 + i) * 3.0 * k, -p * 34.0 * k)
			draw_circle(at, (2.5 + 5.0 * p) * k, Color(0.96, 0.96, 0.94, 0.55 * (1.0 - p)), true, -1.0, true)
	elif building == "alchemy_room" and brews_left > 0:
		var at := origin + MountainArt.cauldron(level) * k
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(at, (8.0 + 3.0 * pulse) * k, Color(0.6, 0.92, 0.78, 0.22 + 0.18 * pulse), true, -1.0, true)
	for drip in MountainArt.drips(building, level):
		var fall := fposmod(_time * 0.8 + drip.x * 0.13, 1.0)
		if fall < 0.7:
			draw_circle(origin + (drip + Vector2(0, 4.0 + fall * 14.0)) * k, 1.4 * k, Color(0.5, 0.7, 0.85, 0.8), true, -1.0, true)
