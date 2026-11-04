class_name Portrait
extends Control
## A placeholder face drawn in code, with the 6 expressions the AI can pick:
## happy, sad, angry, nervous, proud and thinking. The ring takes the
## disciple's spirit root colour; the Elder gets a beard. Real art comes in M7.

const EXPRESSIONS: Array[String] = ["happy", "sad", "angry", "nervous", "proud", "thinking"]
const ROOT_COLORS := {
	"metal": Color(0.72, 0.66, 0.45),
	"wood": Color(0.42, 0.62, 0.4),
	"water": Color(0.38, 0.55, 0.75),
	"fire": Color(0.85, 0.45, 0.3),
	"earth": Color(0.6, 0.48, 0.34),
}
const SKIN := Color(0.99, 0.9, 0.8)
const INK := Color(0.24, 0.2, 0.17)

var expression: String = "thinking":
	set(value):
		expression = value if value in EXPRESSIONS else "thinking"
		queue_redraw()
var ring := Color(0.6, 0.6, 0.6)
var elder := false


func _init(root: String = "", is_elder: bool = false) -> void:
	ring = ROOT_COLORS.get(root, Color(0.75, 0.75, 0.75))
	elder = is_elder
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.45
	draw_circle(c, r, ring)
	draw_circle(c, r * 0.88, SKIN)
	var eye_l := c + Vector2(-r * 0.32, -r * 0.12)
	var eye_r := c + Vector2(r * 0.32, -r * 0.12)
	var mouth := c + Vector2(0, r * 0.3)
	var w := maxf(2.0, r * 0.07)
	match expression:
		"happy":
			_eyes(eye_l, eye_r, r)
			draw_arc(mouth - Vector2(0, r * 0.12), r * 0.3, 0.25, PI - 0.25, 16, INK, w)
		"sad":
			_eyes(eye_l, eye_r, r)
			draw_arc(mouth + Vector2(0, r * 0.18), r * 0.25, PI + 0.4, TAU - 0.4, 16, INK, w)
		"angry":
			_eyes(eye_l, eye_r, r)
			draw_line(eye_l + Vector2(-r * 0.15, -r * 0.2), eye_l + Vector2(r * 0.12, -r * 0.1), INK, w)
			draw_line(eye_r + Vector2(r * 0.15, -r * 0.2), eye_r + Vector2(-r * 0.12, -r * 0.1), INK, w)
			draw_line(mouth + Vector2(-r * 0.2, 0), mouth + Vector2(r * 0.2, 0), INK, w)
		"nervous":
			_eyes(eye_l, eye_r, r)
			var points := PackedVector2Array()
			for i in 7:
				points.append(mouth + Vector2(-r * 0.25 + i * r * 0.083, (r * 0.05) * (1 if i % 2 == 0 else -1)))
			draw_polyline(points, INK, w)
			draw_circle(c + Vector2(r * 0.62, -r * 0.35), r * 0.09, Color(0.45, 0.7, 0.95))
		"proud":
			draw_arc(eye_l + Vector2(0, r * 0.05), r * 0.1, PI, TAU, 8, INK, w)
			draw_arc(eye_r + Vector2(0, r * 0.05), r * 0.1, PI, TAU, 8, INK, w)
			draw_arc(mouth - Vector2(0, r * 0.15), r * 0.33, 0.15, PI - 0.15, 16, INK, w)
		_:
			draw_circle(eye_l - Vector2(0, r * 0.05), r * 0.07, INK)
			draw_circle(eye_r - Vector2(0, r * 0.05), r * 0.07, INK)
			draw_arc(mouth, r * 0.08, 0, TAU, 12, INK, w)
	if elder:
		var beard := PackedVector2Array([
			c + Vector2(-r * 0.45, r * 0.45),
			c + Vector2(r * 0.45, r * 0.45),
			c + Vector2(0, r * 1.15),
		])
		draw_colored_polygon(beard, Color(0.92, 0.92, 0.9))


func _eyes(left: Vector2, right: Vector2, r: float) -> void:
	draw_circle(left, r * 0.07, INK)
	draw_circle(right, r * 0.07, INK)
