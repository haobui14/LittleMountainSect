class_name Portrait
extends Control
## A disciple's portrait, drawn in code from layers, the way the real art
## will be put together (see docs/art/style-brief.md): a backdrop in the
## spirit root's colour, the robe, hair behind the head, the head, hair in
## front, then the face with one of the 6 expressions the AI can pick (happy,
## sad, angry, nervous, proud, thinking). The hair style and colour come from
## the disciple's id, so a disciple always looks the same; side effects show
## (green hair, glowing at night). The Elder has white hair and a beard.

const EXPRESSIONS: Array[String] = ["happy", "sad", "angry", "nervous", "proud", "thinking"]
const ROOT_COLORS := {
	"metal": Color(0.72, 0.66, 0.45),
	"wood": Color(0.42, 0.62, 0.4),
	"water": Color(0.38, 0.55, 0.75),
	"fire": Color(0.85, 0.45, 0.3),
	"earth": Color(0.6, 0.48, 0.34),
}
const HAIR_STYLES: Array[String] = ["bun", "twin_buns", "bangs", "long"]
const HAIR_COLORS: Array[Color] = [
	Color(0.16, 0.13, 0.12),
	Color(0.29, 0.19, 0.13),
	Color(0.47, 0.3, 0.19),
	Color(0.17, 0.18, 0.27),
]
const GREEN_HAIR := Color(0.36, 0.76, 0.34)
const ELDER_HAIR := Color(0.95, 0.95, 0.93)
## The Elder's robe and backdrop, so the white beard shows.
const ELDER_ROBE := Color(0.55, 0.45, 0.62)
const SKIN := Color(0.99, 0.9, 0.8)
const CHEEK := Color(0.96, 0.6, 0.55, 0.35)
const COLLAR := Color(0.99, 0.96, 0.88)
const GLOW := Color(1.0, 0.93, 0.55, 0.55)
const INK := Color(0.24, 0.2, 0.17)

var expression: String = "thinking":
	set(value):
		expression = value if value in EXPRESSIONS else "thinking"
		queue_redraw()
var ring := Color(0.6, 0.6, 0.6)
var elder := false
var hair_style := "bun"
var hair_color: Color = HAIR_COLORS[0]
var glowing := false


func _init(root: String = "", is_elder: bool = false) -> void:
	ring = ROOT_COLORS.get(root, Color(0.75, 0.75, 0.75))
	elder = is_elder
	if elder:
		ring = ELDER_ROBE
		hair_color = ELDER_HAIR
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The portrait of [param d]: root colour, their own hair and any side
## effect that shows.
static func of(d: Disciple) -> Portrait:
	var p := Portrait.new(d.spirit_root)
	var h := absi((d.id + ":" + d.name_en).hash())
	p.hair_style = HAIR_STYLES[h % HAIR_STYLES.size()]
	p.hair_color = HAIR_COLORS[(h / HAIR_STYLES.size()) % HAIR_COLORS.size()]
	if d.has_effect("green_hair"):
		p.hair_color = GREEN_HAIR
	p.glowing = d.has_effect("glowing")
	return p


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.45
	var w := maxf(1.5, r * 0.05)
	var head := c + Vector2(0, -r * 0.12)
	var hr := r * 0.5
	if glowing:
		draw_circle(c, r * 1.1, GLOW)
	draw_circle(c, r, ring.lerp(Color.WHITE, 0.6))
	_robe(c, r, w)
	if hair_style == "long" and not elder:
		draw_circle(head, hr * 1.12, hair_color)
		draw_rect(Rect2(head + Vector2(-hr * 1.12, 0), Vector2(hr * 2.24, hr * 1.05)), hair_color)
	draw_circle(head, hr, SKIN)
	draw_circle(head + Vector2(-hr * 0.55, hr * 0.32), hr * 0.16, CHEEK)
	draw_circle(head + Vector2(hr * 0.55, hr * 0.32), hr * 0.16, CHEEK)
	_hair(head, hr)
	_face(head, hr, maxf(1.5, hr * 0.09))
	draw_arc(c, r, 0, TAU, 48, ring, w)


## Shoulders in a robe of the root's colour, with a crossed collar.
func _robe(c: Vector2, r: float, w: float) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(c + Vector2(cos(a) * r * 0.78, r * 0.62 + sin(a) * r * 0.24))
	for i in 13:
		var a := asin(0.62) + (PI - 2.0 * asin(0.62)) * i / 12.0
		points.append(c + Vector2(cos(a), sin(a)) * r * 0.99)
	draw_colored_polygon(points, ring.darkened(0.08))
	var neck := PackedVector2Array([c + Vector2(-r * 0.14, r * 0.36), c + Vector2(r * 0.14, r * 0.36), c + Vector2(0, r * 0.62)])
	draw_colored_polygon(neck, SKIN)
	draw_line(neck[0], neck[2], COLLAR, w * 1.4)
	draw_line(neck[1], neck[2], COLLAR, w * 1.4)


## The hair over the top of the head, in this portrait's style.
func _hair(head: Vector2, hr: float) -> void:
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + 0.12 + (PI - 0.24) * i / 16.0
		cap.append(head + Vector2(cos(a), sin(a)) * hr * 1.06)
	var fringe := -hr * 0.3
	if hair_style == "bangs" and not elder:
		# A scalloped fringe, right to left.
		for i in 7:
			var x := hr * (0.98 - 1.96 * i / 6.0)
			cap.append(head + Vector2(x, fringe + (hr * 0.12 if i % 2 == 1 else -hr * 0.02)))
	else:
		cap.append(head + Vector2(hr * 0.7, fringe))
		cap.append(head + Vector2(0, fringe - hr * 0.1))
		cap.append(head + Vector2(-hr * 0.7, fringe))
	draw_colored_polygon(cap, hair_color)
	if elder:
		draw_circle(head + Vector2(0, -hr * 1.08), hr * 0.26, hair_color)
		return
	match hair_style:
		"bun":
			draw_circle(head + Vector2(0, -hr * 1.08), hr * 0.32, hair_color)
			draw_line(head + Vector2(-hr * 0.45, -hr * 1.18), head + Vector2(hr * 0.45, -hr * 0.98), ring.darkened(0.25), maxf(1.5, hr * 0.08))
		"twin_buns":
			draw_circle(head + Vector2(-hr * 0.78, -hr * 0.78), hr * 0.3, hair_color)
			draw_circle(head + Vector2(hr * 0.78, -hr * 0.78), hr * 0.3, hair_color)


func _face(head: Vector2, hr: float, w: float) -> void:
	var eye_l := head + Vector2(-hr * 0.38, hr * 0.06)
	var eye_r := head + Vector2(hr * 0.38, hr * 0.06)
	var mouth := head + Vector2(0, hr * 0.48)
	var eye := hr * 0.1
	match expression:
		"happy":
			_eyes(eye_l, eye_r, eye)
			draw_arc(mouth - Vector2(0, hr * 0.14), hr * 0.26, 0.3, PI - 0.3, 12, INK, w)
		"sad":
			_eyes(eye_l, eye_r, eye)
			draw_arc(mouth + Vector2(0, hr * 0.16), hr * 0.2, PI + 0.5, TAU - 0.5, 12, INK, w)
		"angry":
			_eyes(eye_l, eye_r, eye)
			draw_line(eye_l + Vector2(-hr * 0.18, -hr * 0.24), eye_l + Vector2(hr * 0.14, -hr * 0.12), INK, w)
			draw_line(eye_r + Vector2(hr * 0.18, -hr * 0.24), eye_r + Vector2(-hr * 0.14, -hr * 0.12), INK, w)
			draw_line(mouth + Vector2(-hr * 0.18, 0), mouth + Vector2(hr * 0.18, 0), INK, w)
		"nervous":
			_eyes(eye_l, eye_r, eye)
			var points := PackedVector2Array()
			for i in 7:
				points.append(mouth + Vector2(-hr * 0.24 + i * hr * 0.08, hr * 0.05 * (1 if i % 2 == 0 else -1)))
			draw_polyline(points, INK, w)
			draw_circle(head + Vector2(hr * 0.78, -hr * 0.12), hr * 0.12, Color(0.45, 0.7, 0.95))
		"proud":
			draw_arc(eye_l + Vector2(0, hr * 0.06), hr * 0.12, PI, TAU, 8, INK, w)
			draw_arc(eye_r + Vector2(0, hr * 0.06), hr * 0.12, PI, TAU, 8, INK, w)
			draw_arc(mouth - Vector2(0, hr * 0.16), hr * 0.3, 0.2, PI - 0.2, 12, INK, w)
		_:
			draw_circle(eye_l, eye * 0.85, INK)
			draw_circle(eye_r, eye * 0.85, INK)
			draw_arc(mouth, hr * 0.08, 0, TAU, 12, INK, w)
	if elder:
		var beard := PackedVector2Array([
			head + Vector2(-hr * 0.5, hr * 0.62),
			head + Vector2(hr * 0.5, hr * 0.62),
			head + Vector2(0, hr * 1.45),
		])
		draw_colored_polygon(beard, ELDER_HAIR)
		draw_line(eye_l + Vector2(-hr * 0.2, -hr * 0.2), eye_l + Vector2(hr * 0.15, -hr * 0.2), ELDER_HAIR.darkened(0.2), w * 1.3)
		draw_line(eye_r + Vector2(-hr * 0.15, -hr * 0.2), eye_r + Vector2(hr * 0.2, -hr * 0.2), ELDER_HAIR.darkened(0.2), w * 1.3)


func _eyes(left: Vector2, right: Vector2, radius: float) -> void:
	draw_circle(left, radius, INK)
	draw_circle(right, radius, INK)
	draw_circle(left + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.32, Color.WHITE)
	draw_circle(right + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.32, Color.WHITE)
