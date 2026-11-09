class_name MountainArt
extends RefCounted
## The mountain, drawn in code as SVG (see Art): the backdrop, and each of the
## 8 buildings at 4 stages (an empty plot with a sign, then levels 1–3).
## Level 1 leaks (a patch and drips), level 2 is mended, level 3 has gold
## trim and banners. docs/art/style-brief.md gives an artist the same plot
## positions and silhouettes.
##
## The backdrop is a 400×300 picture; each building is a 100×80 box that
## stands on its base point (BASE) at its plot.

const VIEW := Vector2(400, 300)
const BOX := Vector2(100, 80)
const BASE := Vector2(50, 74)
## Buildings are drawn at this size relative to the backdrop; their tap
## areas use PLOT_SCALE, so neighbouring plots never overlap.
const BUILDING_SCALE := 1.15
const PLOT_SCALE := 0.9
## Where each building stands (its base), as a fraction of the picture.
const PLOTS := {
	"main_hall": Vector2(0.5, 0.3),
	"library": Vector2(0.3, 0.51),
	"alchemy_room": Vector2(0.7, 0.51),
	"disciple_huts": Vector2(0.17, 0.72),
	"training_yard": Vector2(0.5, 0.72),
	"kitchen": Vector2(0.83, 0.72),
	"spirit_field": Vector2(0.29, 0.93),
	"mission_hall": Vector2(0.71, 0.93),
}

const INK := "#3D332A"
const ROOF := "#5E7F73"
const ROOF_DARK := "#445F56"
const STRAW := "#C9A15B"
const WALL := "#F3E3C3"
const PLANK := "#E2C79A"
const WOOD := "#8B5A3C"
const RED := "#B3473A"
const STONE := "#C9C1B0"
const GOLD := "#E8C35A"
const LEAF := "#7DB26B"
const WATER := "#7FB3D9"


static func _n(v: float) -> String:
	return "%.1f" % v


static func _rect(x: float, y: float, w: float, h: float, fill: String, rx: float = 1.5) -> String:
	return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % [_n(x), _n(y), _n(w), _n(h), _n(rx), fill, INK]


static func _circle(cx: float, cy: float, r: float, fill: String, outline: bool = true) -> String:
	if not outline:
		return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [_n(cx), _n(cy), _n(r), fill]
	return '<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % [_n(cx), _n(cy), _n(r), fill, INK]


static func _line(x1: float, y1: float, x2: float, y2: float, color: String, width: float) -> String:
	return '<path d="M%s %sL%s %s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % [_n(x1), _n(y1), _n(x2), _n(y2), color, _n(width)]


static func _shadow(rx: float) -> String:
	return '<ellipse cx="50" cy="75" rx="%s" ry="4.5" fill="%s" fill-opacity="0.16"/>' % [_n(rx), INK]


## A roof with upturned eaves: ridge at [param y], eave tips lower down.
static func _roof(cx: float, y: float, w: float, h: float, fill: String, trim: bool = false) -> String:
	var l := cx - w / 2.0
	var r := cx + w / 2.0
	var d := "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Q%s %s %s %sZ" % [
		_n(l), _n(y + h * 0.6), _n(cx - w * 0.36), _n(y + h * 0.5), _n(cx - w * 0.28), _n(y),
		_n(cx + w * 0.28), _n(y), _n(cx + w * 0.36), _n(y + h * 0.5), _n(r), _n(y + h * 0.6),
		_n(cx), _n(y + h * 1.3), _n(l), _n(y + h * 0.6)]
	return '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % [d, fill, GOLD if trim else INK, "2" if trim else "1.2"]


## A pitched straw roof.
static func _thatch(cx: float, y: float, w: float, h: float, fill: String = STRAW) -> String:
	return '<path d="M%s %s L%s %s L%s %sZ" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % [
		_n(cx - w / 2.0), _n(y + h), _n(cx), _n(y), _n(cx + w / 2.0), _n(y + h), fill, INK]


## A mended spot on a leaky roof.
static func _patch(x: float, y: float) -> String:
	return _rect(x, y, 7, 5, "#B08355", 0.5) + _line(x + 1, y + 1, x + 6, y + 4, INK, 0.6) + _line(x + 6, y + 1, x + 1, y + 4, INK, 0.6)


static func _drip(x: float, y: float) -> String:
	return '<path d="M%s %s q-2 3 0 4 q2 -1 0 -4z" fill="%s"/>' % [_n(x), _n(y), WATER]


static func _banner(x: float, y: float, color: String = RED) -> String:
	return _line(x, y, x, y + 34, WOOD, 1.8) + '<path d="M%s %s h9 v14 l-4.5 -3 l-4.5 3z" fill="%s" stroke="%s" stroke-width="1"/>' % [_n(x), _n(y + 2), color, GOLD]


static func _lantern(x: float, y: float) -> String:
	return _line(x, y - 4, x, y - 1, INK, 0.8) + '<ellipse cx="%s" cy="%s" rx="3" ry="3.6" fill="%s" stroke="%s" stroke-width="0.8"/>' % [_n(x), _n(y + 2), RED, GOLD]


static func _door(x: float, y: float, w: float, h: float, fill: String = WOOD) -> String:
	return '<path d="M%s %s v-%s a%s %s 0 0 1 %s 0 v%sz" fill="%s" stroke="%s" stroke-width="1"/>' % [
		_n(x), _n(y + h), _n(h - w / 2.0), _n(w / 2.0), _n(w / 2.0), _n(w), _n(h - w / 2.0), fill, INK]


## The whole picture behind the buildings.
static func backdrop() -> String:
	var body := '<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
	body += '<stop offset="0" stop-color="#CFE3EA"/><stop offset="0.5" stop-color="#EAF0E4"/><stop offset="1" stop-color="#F4ECD8"/></linearGradient></defs>'
	body += '<rect width="400" height="300" fill="url(#sky)"/>'
	body += '<circle cx="334" cy="46" r="19" fill="#F7E3A6" fill-opacity="0.85"/>'
	body += '<path d="M0 150 L38 96 L66 122 L108 66 L146 112 L186 84 L226 118 L268 72 L318 116 L358 88 L400 124 V300 H0Z" fill="#C6D6D3"/>'
	body += '<path d="M108 66 L98 80 L108 76 L116 82Z M268 72 L258 86 L268 81 L277 88Z" fill="#F4F6F2"/>'
	body += '<path d="M0 176 C50 146 90 158 136 138 C176 122 220 140 262 128 C306 116 350 140 400 150 V300 H0Z" fill="#AFC7B8"/>'
	# The sect's mountain, with four terraces.
	body += '<path d="M-10 300 V214 C30 188 66 170 96 134 C126 96 160 60 200 50 C240 60 274 96 304 134 C334 170 370 188 410 214 V300Z" fill="#8DB38A" stroke="#6F9A80" stroke-width="2"/>'
	for terrace in [[200, 92, 66, 12], [200, 155, 132, 14], [200, 218, 186, 16], [200, 281, 214, 18]]:
		body += '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="#77A173"/>' % [terrace[0], terrace[1] + 4, terrace[2], terrace[3]]
		body += '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="#B9D6A3"/>' % terrace
	# The stone path up the middle.
	var path := "M200 304 C182 286 226 262 206 240 C186 220 218 196 200 176 C184 158 214 132 200 98"
	body += '<path d="%s" fill="none" stroke="#CDBB93" stroke-width="13" stroke-linecap="round"/>' % path
	body += '<path d="%s" fill="none" stroke="#E9DCBA" stroke-width="9" stroke-linecap="round" stroke-dasharray="6 3"/>' % path
	# Trees along the sides.
	for tree in [[22, 206, 1.0], [42, 196, 0.8], [378, 208, 1.0], [356, 198, 0.75], [110, 128, 0.7], [290, 128, 0.7], [8, 268, 1.1], [392, 270, 1.1]]:
		var x: float = tree[0]
		var y: float = tree[1]
		var s: float = tree[2]
		body += _line(x, y, x, y + 12 * s, WOOD, 2.2 * s)
		body += '<path d="M%s %s L%s %s L%s %sZ M%s %s L%s %s L%s %sZ" fill="#5E8F5A" stroke="#4A7547" stroke-width="1"/>' % [
			_n(x - 9 * s), _n(y + 4 * s), _n(x), _n(y - 12 * s), _n(x + 9 * s), _n(y + 4 * s),
			_n(x - 7 * s), _n(y - 4 * s), _n(x), _n(y - 20 * s), _n(x + 7 * s), _n(y - 4 * s)]
	# A few soft clouds.
	for cloud in [[70, 40, 26], [190, 26, 18], [250, 50, 22]]:
		body += '<ellipse cx="%d" cy="%d" rx="%d" ry="7" fill="#FFFFFF" fill-opacity="0.7"/>' % cloud
	return Art.svg(VIEW.x, VIEW.y, body)


## The SVG for [param building] at [param level] (0 = an empty plot).
static func building(name: String, level: int) -> String:
	level = clampi(level, 0, Balance.MAX_LEVEL)
	if level == 0:
		return Art.svg(BOX.x, BOX.y, _empty_plot())
	var body := ""
	match name:
		"main_hall":
			body = _main_hall(level)
		"disciple_huts":
			body = _huts(level)
		"training_yard":
			body = _training_yard(level)
		"spirit_field":
			body = _spirit_field(level)
		"kitchen":
			body = _kitchen(level)
		"alchemy_room":
			body = _alchemy_room(level)
		"library":
			body = _library(level)
		_:
			body = _mission_hall(level)
	return Art.svg(BOX.x, BOX.y, body)


## Where smoke leaves the Kitchen's chimney, in box units.
static func chimney(level: int) -> Vector2:
	return Vector2(64, 30) if level <= 1 else Vector2(66, 25)


## Where the Alchemy Room glows, in box units.
static func cauldron(level: int) -> Vector2:
	return Vector2(50, 55) if level <= 1 else (Vector2(84, 59) if level == 2 else Vector2(50, 56))


## Where water drips from a leaky (level 1) roof, in box units.
static func drips(name: String, level: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if level != 1:
		return out
	match name:
		"main_hall":
			out.assign([Vector2(21, 42), Vector2(79, 42)])
		"disciple_huts":
			out.assign([Vector2(33, 57)])
		"kitchen", "library":
			out.assign([Vector2(27, 52)])
	return out


static func _empty_plot() -> String:
	var s := '<ellipse cx="50" cy="68" rx="30" ry="7" fill="#C9A982" fill-opacity="0.7" stroke="%s" stroke-width="1" stroke-dasharray="3 2"/>' % WOOD
	s += _rect(48, 48, 4, 22, WOOD, 1) + _rect(37, 42, 26, 12, PLANK, 2)
	s += _line(50, 45, 50, 51, "#445F56", 2) + _line(47, 48, 53, 48, "#445F56", 2)
	return s


static func _main_hall(level: int) -> String:
	var gold := level == 3
	if level == 1:
		var s := _shadow(34) + _rect(18, 64, 64, 9, STONE)
		s += _rect(26, 46, 48, 19, WALL) + _rect(29, 46, 4, 19, RED, 0.5) + _rect(67, 46, 4, 19, RED, 0.5)
		s += _door(45, 51, 10, 14)
		s += _roof(50, 30, 64, 16, ROOF) + _patch(55, 32) + _drip(21, 43) + _drip(79, 43)
		return s
	var s := _shadow(42) + _rect(10, 64, 80, 9, STONE) + _rect(18, 44, 64, 21, WALL)
	for x in [21, 33, 63, 75]:
		s += _rect(x, 44, 4, 21, RED, 0.5)
	s += _door(44, 50, 12, 15, GOLD if gold else WOOD)
	s += _roof(50, 27, 84, 17, ROOF_DARK if gold else ROOF, gold)
	s += _rect(33, 17, 34, 12, WALL) + _rect(36, 17, 3, 12, RED, 0.5) + _rect(61, 17, 3, 12, RED, 0.5)
	s += _roof(50, 5, 56, 13, ROOF_DARK if gold else ROOF, gold)
	if gold:
		s += _circle(50, 4, 2.6, GOLD) + _banner(5, 36) + _banner(86, 36) + _lantern(26, 42) + _lantern(74, 42)
	return s


static func _hut(cx: float, scale: float, roof: String, leaky: bool) -> String:
	var w := 24.0 * scale
	var h := 17.0 * scale
	var s := _rect(cx - w / 2.0, 74 - h, w, h, PLANK, 1)
	s += _door(cx - 3.5 * scale, 74 - 11 * scale, 7 * scale, 11 * scale)
	if roof == STRAW:
		s += _thatch(cx, 74 - h - 13 * scale, w + 9 * scale, 14 * scale)
	else:
		s += _roof(cx, 74 - h - 9 * scale, w + 12 * scale, 11 * scale, roof)
	if leaky:
		s += _patch(cx + 2, 74 - h - 8 * scale) + _drip(cx - w / 2.0 - 3, 74 - h - 1)
	return s


static func _huts(level: int) -> String:
	match level:
		1:
			return _shadow(24) + _hut(50, 1.25, STRAW, true)
		2:
			return _shadow(38) + _hut(31, 1.05, STRAW, false) + _hut(69, 1.05, STRAW, false)
	var s := _shadow(44) + _hut(20, 0.95, ROOF, false) + _hut(50, 1.05, ROOF, false) + _hut(80, 0.95, ROOF, false)
	s += '<path d="M24 44 Q35 50 46 43 Q57 50 76 44" fill="none" stroke="%s" stroke-width="0.8"/>' % INK
	return s + _lantern(35, 47) + _lantern(62, 47)


static func _dummy(x: float) -> String:
	return _rect(x - 2, 46, 4, 26, WOOD, 1) + _rect(x - 9, 51, 18, 3.5, PLANK, 1) + _circle(x, 43, 5, STRAW)


static func _training_yard(level: int) -> String:
	var s := '<ellipse cx="50" cy="67" rx="43" ry="10" fill="#E2D3B0" stroke="%s" stroke-width="1.2"/>' % INK
	match level:
		1:
			s += _dummy(50) + '<ellipse cx="72" cy="69" rx="7" ry="2.5" fill="%s"/>' % WATER
		2:
			s += _dummy(34) + _dummy(66)
			s += _rect(80, 50, 3, 20, WOOD, 0.5) + _line(78, 52, 86, 44, "#AEB7BD", 1.6) + _line(81, 52, 88, 46, "#AEB7BD", 1.6)
		_:
			s += _dummy(25) + _dummy(50) + _dummy(75) + _banner(88, 30) + _banner(4, 30)
	return s


static func _spirit_field(level: int) -> String:
	var s := '<ellipse cx="50" cy="64" rx="44" ry="12" fill="#A9825A" stroke="%s" stroke-width="1.2"/>' % INK
	var rows := level + 1
	for i in rows:
		var y := 56.0 + i * (16.0 / rows)
		s += '<path d="M%s %s Q50 %s %s %s" fill="none" stroke="#7A5C3E" stroke-width="1"/>' % [_n(14 + i * 2), _n(y + 1), _n(y + 4), _n(86 - i * 2), _n(y + 1)]
		var clumps := 4 + level * 2
		for j in clumps:
			var x := 18.0 + j * (64.0 / (clumps - 1))
			s += _circle(x, y - 1, 2.6 + level * 0.3, LEAF if (i + j) % 3 else "#A6CF94", false)
	match level:
		1:
			s += _line(84, 34, 84, 60, WOOD, 1.6) + _line(77, 42, 91, 42, WOOD, 1.6) + _circle(84, 33, 4, STRAW) + '<path d="M78 31 h12 l-3 -5 h-6z" fill="#8B5A3C"/>'
		3:
			for dot in [[26, 50], [48, 54], [70, 50], [38, 62], [60, 63]]:
				s += _circle(dot[0], dot[1], 1.7, "#F7F3B2", false)
			for x in [8, 92]:
				s += _rect(x - 1.5, 56, 3, 14, WOOD, 0.5)
	return s


static func _kitchen(level: int) -> String:
	if level == 1:
		var s := _shadow(26) + _rect(30, 52, 40, 21, PLANK, 1) + _door(44, 58, 9, 15)
		s += '<path d="M60 44 L62 28 L68 29 L66 45Z" fill="%s" stroke="%s" stroke-width="1"/>' % [STONE, INK]
		s += _thatch(50, 34, 52, 19) + _patch(36, 41) + _drip(27, 52)
		return s
	var gold := level == 3
	var s := _shadow(36) + _rect(23, 48, 54, 25, WALL, 1) + _door(44, 55, 11, 18)
	s += _rect(28, 54, 9, 8, "#9FC4D9", 1) + _rect(62, 25, 8, 16, STONE, 1)
	s += _roof(50, 34, 66, 15, ROOF_DARK if gold else ROOF, gold)
	s += _circle(86, 66, 6, "#4F4A46") + _line(80, 61, 92, 61, INK, 1.4)
	if gold:
		s += _lantern(30, 46) + _lantern(70, 46) + _banner(6, 36)
	return s


static func _alchemy_room(level: int) -> String:
	if level == 1:
		var s := _shadow(28) + _rect(26, 40, 3, 33, WOOD, 0.5) + _rect(71, 40, 3, 33, WOOD, 0.5)
		s += _thatch(50, 24, 60, 17)
		s += _circle(42, 70, 3.5, STONE) + _circle(58, 70, 3.5, STONE)
		s += '<path d="M40 56 h20 l-2 11 a8 6 0 0 1 -16 0z" fill="#5E6B73" stroke="%s" stroke-width="1.2"/>' % INK
		return s + _patch(55, 31)
	var gold := level == 3
	var s := _shadow(40) + _rect(22, 44, 54, 29, WALL, 1) + _door(32, 56, 10, 17)
	s += _circle(55, 56, 7, "#B9E0D2" if gold else "#9FC4D9")
	s += _roof(49, 28, 68, 16, ROOF_DARK if gold else ROOF, gold)
	s += '<path d="M77 60 h14 l-1.5 7 a6 4.5 0 0 1 -11 0z" fill="#5E6B73" stroke="%s" stroke-width="1"/>' % INK
	if gold:
		for p in [[28, 40], [70, 40], [49, 22]]:
			s += _circle(p[0], p[1], 1.8, GOLD, false)
		s += _banner(6, 34, "#8C739E")
	return s


static func _library(level: int) -> String:
	if level == 1:
		var s := _shadow(26) + _rect(30, 48, 40, 25, PLANK, 1) + _door(45, 58, 10, 15)
		s += _rect(33, 53, 9, 8, WALL, 0.5) + _line(34, 56, 41, 56, WOOD, 0.8) + _line(34, 59, 41, 59, WOOD, 0.8)
		s += _thatch(50, 31, 50, 18) + _patch(55, 37) + _drip(27, 52)
		return s
	var gold := level == 3
	var roof := ROOF_DARK if gold else ROOF
	var s := _shadow(32) + _rect(27, 50, 46, 23, WALL, 1) + _door(45, 57, 10, 16)
	s += _rect(31, 55, 9, 8, "#F7EBD0", 0.5) + _rect(60, 55, 9, 8, "#F7EBD0", 0.5)
	s += _roof(50, 37, 60, 14, roof, gold)
	s += _rect(35, 25, 30, 13, WALL, 1) + _rect(45, 28, 10, 7, "#F7EBD0", 0.5)
	s += _roof(50, 13, 46, 13, roof, gold)
	if gold:
		s += _circle(50, 11, 2.4, GOLD) + '<path d="M78 28 v26 h8 v-26z" fill="#F4ECD8" stroke="%s" stroke-width="1"/>' % GOLD
		s += _line(78, 28, 86, 28, WOOD, 2) + _line(78, 54, 86, 54, WOOD, 2)
	return s


static func _mission_hall(level: int) -> String:
	if level == 1:
		var s := _shadow(26) + _rect(31, 44, 3, 29, WOOD, 0.5) + _rect(66, 44, 3, 29, WOOD, 0.5)
		s += _rect(27, 46, 46, 19, WOOD, 1)
		for paper in [[30, 49, 10, 12], [43, 48, 12, 9], [58, 50, 11, 11]]:
			s += _rect(paper[0], paper[1], paper[2], paper[3], WALL, 0.5)
		return s + _thatch(50, 34, 54, 12)
	var gold := level == 3
	var s := _shadow(40) + _rect(22, 28, 5, 45, RED, 0.5) + _rect(73, 28, 5, 45, RED, 0.5)
	s += _rect(16, 25, 68, 6, RED, 1) + _rect(38, 32, 24, 9, GOLD if gold else WALL, 1)
	s += _roof(50, 12, 78, 14, ROOF_DARK if gold else ROOF, gold)
	s += _rect(33, 50, 34, 16, WOOD, 1) + _rect(36, 53, 9, 10, WALL, 0.5) + _rect(48, 52, 9, 8, WALL, 0.5)
	if gold:
		s += _banner(6, 34) + _banner(88, 34) + _lantern(30, 34) + _lantern(70, 34)
	return s
