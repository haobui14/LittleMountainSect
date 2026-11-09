class_name UiKit
extends RefCounted
## Builders for the placeholder screens: one warm theme, a few widgets, and
## the narrow/wide layout rule. Screens are built in code so they can reflow
## for a phone held upright or a desktop window.
##
## The base viewport is 480x480 with stretch "expand": the shorter side of the
## screen is always 480 units, so an upright phone gets a tall narrow canvas
## and a desktop gets a wide one.

## Below this width (in canvas units) screens use a single column.
const NARROW_WIDTH := 720.0
const FONT_SIZE := 18
const SMALL_SIZE := 15
const HEADING_SIZE := 24
const BUTTON_HEIGHT := 44.0

const PAPER := Color(0.957, 0.925, 0.847)
const CARD := Color(0.992, 0.976, 0.937)
const INK := Color(0.239, 0.2, 0.165)
const SOFT_INK := Color(0.42, 0.36, 0.3)
const JADE := Color(0.267, 0.373, 0.337)
const JADE_LIGHT := Color(0.435, 0.604, 0.553)
const WARN := Color(0.62, 0.27, 0.2)
const LINE := Color(0.82, 0.77, 0.67)
const GOLD := Color(0.91, 0.76, 0.35)
const PLUM := Color(0.55, 0.45, 0.62)
const SHADOW := Color(0.36, 0.27, 0.15, 0.13)
## Icons on buttons, in canvas units.
const ICON_SIZE := 22
## The likely result of a mission, from great to disaster.
const TIER_COLORS := {
	"great": Color(0.42, 0.62, 0.4),
	"success": Color(0.435, 0.604, 0.553),
	"partial": Color(0.85, 0.68, 0.3),
	"failure": Color(0.85, 0.45, 0.3),
	"disaster": Color(0.62, 0.27, 0.2),
}

static var _theme: Theme


static func is_narrow(node: CanvasItem) -> bool:
	return node.get_viewport_rect().size.x < NARROW_WIDTH


## How many cards of about [param card_width] fit across the screen.
static func columns(node: CanvasItem, card_width: float, most: int) -> int:
	return clampi(int((node.get_viewport_rect().size.x - 24.0) / card_width), 1, most)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/nunito_ui.tres")
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", INK)
	for type in ["Button", "CheckButton"]:
		t.set_color("font_color", type, INK)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(INK, 0.4))
	t.set_stylebox("normal", "Button", _box(CARD, LINE))
	t.set_stylebox("hover", "Button", _box(Color(0.97, 0.94, 0.86), JADE_LIGHT))
	t.set_stylebox("pressed", "Button", _box(JADE, JADE))
	t.set_stylebox("hover_pressed", "Button", _box(JADE_LIGHT, JADE))
	t.set_stylebox("disabled", "Button", _box(Color(CARD, 0.6), Color(LINE, 0.6)))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, JADE_LIGHT))
	t.set_constant("icon_max_width", "Button", ICON_SIZE)
	t.set_constant("h_separation", "Button", 6)
	# The main action of each step: jade with white text.
	t.set_type_variation("PrimaryButton", "Button")
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "PrimaryButton", Color.WHITE)
	t.set_color("font_disabled_color", "PrimaryButton", Color(Color.WHITE, 0.7))
	t.set_stylebox("normal", "PrimaryButton", _box(JADE, JADE, 10))
	t.set_stylebox("hover", "PrimaryButton", _box(JADE_LIGHT, JADE, 10))
	t.set_stylebox("pressed", "PrimaryButton", _box(JADE.darkened(0.15), JADE, 10))
	t.set_stylebox("disabled", "PrimaryButton", _box(Color(JADE, 0.35), Color.TRANSPARENT, 10))
	t.set_stylebox("focus", "PrimaryButton", _box(Color.TRANSPARENT, JADE_LIGHT, 10))
	# A breakthrough choice stands out in gold.
	t.set_type_variation("GoldButton", "Button")
	t.set_stylebox("normal", "GoldButton", _box(GOLD.lerp(CARD, 0.7), GOLD))
	t.set_stylebox("hover", "GoldButton", _box(GOLD.lerp(CARD, 0.5), GOLD))
	t.set_stylebox("pressed", "GoldButton", _box(GOLD.darkened(0.15), GOLD.darkened(0.3)))
	t.set_stylebox("hover_pressed", "GoldButton", _box(GOLD.darkened(0.05), GOLD.darkened(0.3)))
	var panel := _box(CARD, LINE, 10, 12)
	panel.shadow_color = SHADOW
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(0, 2)
	t.set_stylebox("panel", "PanelContainer", panel)
	var bar_bg := _box(Color(0.89, 0.85, 0.76), Color.TRANSPARENT, 4, 0)
	var bar_fill := _box(JADE_LIGHT, Color.TRANSPARENT, 4, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	_theme = t
	return t


static func _box(fill: Color, border: Color, radius: int = 8, padding: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding + 4
	box.content_margin_right = padding + 4
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


## A control's rectangle in window pixels. Canvas transforms work in the
## 480-unit canvas, so this applies the stretch to the real window size.
static func window_rect(control: Control) -> Rect2:
	var scale := stretch_scale(control)
	var rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	return Rect2(rect.position * scale, rect.size * scale)


## Window pixels per canvas unit.
static func stretch_scale(node: CanvasItem) -> Vector2:
	var view_size := node.get_viewport().get_visible_rect().size
	if view_size.x <= 0 or view_size.y <= 0:
		return Vector2.ONE
	return Vector2(node.get_window().size) / view_size


## Tags a control so browser checks (window.lmsUi) can find and click it.
static func probe(control: Control, id: String) -> Control:
	control.set_meta("probe", id)
	return control


static func label(text: String, size: int = FONT_SIZE, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


static func heading(text: String) -> Label:
	var l := label(text, HEADING_SIZE, JADE)
	l.add_theme_font_override("font", load("res://assets/fonts/nunito_title.tres"))
	return l


## A button with an optional icon (see Icons). It bounces when pressed.
static func button(text: String, probe_id: String, on_press: Callable, wide: bool = false, icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if icon != "":
		b.icon = Icons.texture(icon, ICON_SIZE * 3)
	if wide:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Long labels wrap instead of pushing the screen wider than a phone.
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.button_down.connect(func() -> void: Motion.bounce(b))
	b.pressed.connect(on_press)
	probe(b, probe_id)
	return b


## The step's main action: a wide jade button.
static func primary(text: String, probe_id: String, on_press: Callable, icon: String = "") -> Button:
	var b := button(text, probe_id, on_press, true, icon)
	b.theme_type_variation = "PrimaryButton"
	return b


## A toggle that shows as pressed when [param on] is true.
static func choice(text: String, probe_id: String, on: bool, on_press: Callable, icon: String = "") -> Button:
	var b := button(text, probe_id, on_press, false, icon)
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	return b


## A card; with [param accent], a coloured edge on the left.
static func card(accent: Color = Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if accent.a > 0.0:
		var box := _box(CARD, accent.lerp(LINE, 0.35), 10, 12)
		box.border_width_left = 6
		box.shadow_color = SHADOW
		box.shadow_size = 5
		box.shadow_offset = Vector2(0, 2)
		p.add_theme_stylebox_override("panel", box)
	return p


## A small rounded tag, tinted [param color], with an optional icon.
static func chip(text: String, color: Color = JADE_LIGHT, icon: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color.lerp(CARD, 0.78)
	box.border_color = color.lerp(LINE, 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", box)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		row.add_child(Icons.rect(icon, 16.0))
	var l := label(text, SMALL_SIZE, color.darkened(0.45))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(l)
	p.add_child(row)
	return p


## An icon followed by text on one line.
static func icon_label(icon: String, text: String, size: int = FONT_SIZE, color: Color = INK, icon_size: float = 20.0) -> HBoxContainer:
	var row := hbox(6)
	var i := Icons.rect(icon, icon_size)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(i)
	var l := label(text, size, color)
	row.add_child(l)
	return row


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## A row that wraps onto more lines when the screen is narrow.
static func flow(separation: int = 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", separation)
	f.add_theme_constant_override("v_separation", separation)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func bar(value: float, max_value: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## A scrolling column that fills its parent, for long lists.
static func scroll_column() -> Array:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var column := vbox(10)
	margin.add_child(column)
	s.add_child(margin)
	return [s, column]


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
