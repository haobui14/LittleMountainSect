class_name Motion
extends RefCounted
## Short animations for the screens: fades, pops, a bounce on press, numbers
## that count, and gains that float up. With the "Less motion" setting on,
## every helper does nothing and things simply appear in place.
##
## Inside containers only modulate and scale move: a container resets its
## children's position (and, when it sorts, their scale), so each tween sets
## its start value with from(). Floating text lives on the overlay (a layer
## above every screen, see app.gd), which screen rebuilds never clear.

const FAST := 0.15
const NORMAL := 0.25
const SLOW := 0.35
const FLOAT_TIME := 1.1
const OVERLAY_GROUP := "overlay"


## False when the player chose "Less motion". Reads the Settings autoload by
## path, so tools that run before the autoloads exist can still load this.
static func enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var settings := tree.root.get_node_or_null("Settings")
	return settings == null or not bool(settings.get("reduce_motion"))


static func _ready_to_move(node: Node) -> bool:
	return enabled() and is_instance_valid(node) and node.is_inside_tree()


## Fades [param node] in after [param delay] seconds.
static func fade_in(node: CanvasItem, delay: float = 0.0) -> void:
	if not _ready_to_move(node):
		return
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, NORMAL).from(0.0).set_delay(delay)


## Grows [param node] from a little smaller while it fades in, with a small
## overshoot.
static func pop(node: Control, delay: float = 0.0, from_scale: float = 0.88) -> void:
	if not _ready_to_move(node):
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void: node.pivot_offset = node.size / 2.0)
	tween.tween_property(node, "scale", Vector2.ONE, NORMAL).from(Vector2.ONE * from_scale) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate:a", 1.0, FAST).from(0.0)


## Pops each node in turn, a little after the one before.
static func stagger(nodes: Array, step: float = 0.04, most: float = 0.4) -> void:
	for i in nodes.size():
		var node: Variant = nodes[i]
		if node is Control:
			pop(node, minf(i * step, most))


## A quick squash and spring back, for a pressed button.
static func bounce(node: Control) -> void:
	if not _ready_to_move(node):
		return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * 0.94, 0.06).from(Vector2.ONE)
	tween.tween_property(node, "scale", Vector2.ONE, FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A little shake, for something that went wrong.
static func wobble(node: Control) -> void:
	if not _ready_to_move(node):
		return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	for angle in [0.08, -0.07, 0.04, 0.0]:
		tween.tween_property(node, "rotation", angle, 0.07)


## Counts [param label] from one number to another, using [param format]
## ("%d" by default).
static func count(label: Label, from_value: int, to_value: int, format: String = "%d") -> void:
	label.text = format % to_value
	if not _ready_to_move(label) or from_value == to_value:
		return
	var tween := label.create_tween()
	tween.tween_method(func(v: float) -> void: label.text = format % roundi(v), float(from_value), float(to_value), SLOW)


## The layer above every screen, or null (in tests and tools without one).
static func overlay() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(OVERLAY_GROUP) as Control


## Text that rises from [param at] (canvas units) and fades away.
static func float_text(text: String, at: Vector2, color: Color = UiKit.JADE) -> Label:
	var layer := overlay()
	if layer == null or not enabled():
		return null
	var label := UiKit.label(text, UiKit.FONT_SIZE, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_outline_color", UiKit.CARD)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	label.reset_size()
	label.position = at - Vector2(label.size.x / 2.0, label.size.y)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 34.0, FLOAT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_TIME * 0.5).set_delay(FLOAT_TIME * 0.5)
	tween.tween_callback(label.queue_free)
	return label


## A few sparkles that burst from [param at] (canvas units), for a level-up
## or a breakthrough.
static func sparkle(at: Vector2, color: Color = Color(0.91, 0.76, 0.35)) -> void:
	var layer := overlay()
	if layer == null or not enabled():
		return
	for i in 8:
		var star := Icons.rect("sparkle", 14.0)
		star.modulate = color
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(star)
		star.position = at - Vector2(7, 7)
		var direction := Vector2.from_angle(TAU * i / 8.0 + 0.3)
		var tween := star.create_tween()
		tween.tween_property(star, "position", star.position + direction * 46.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(star, "modulate:a", 0.0, 0.3).set_delay(0.3)
		tween.tween_callback(star.queue_free)
