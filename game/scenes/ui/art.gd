class_name Art
extends RefCounted
## Turns SVG written in code into textures, once per size. The game's
## placeholder art (icons, the mountain and its buildings) is SVG in
## GDScript strings, drawn by Godot's SVG module, so it stays crisp at any
## screen size and adds almost nothing to the download. Real art from
## docs/art/style-brief.md can replace these strings later.

const INK := "#3D332A"

static var _cache := {}


## The texture of [param svg] drawn [param width] pixels wide (its height
## follows the SVG's viewBox). Cached by content and size.
static func texture(svg: String, width: int) -> Texture2D:
	width = clampi(width, 4, 2048)
	var key := "%d:%d" % [svg.hash(), width]
	if _cache.has(key):
		return _cache[key]
	var image := Image.new()
	var view_width := _view_width(svg)
	if image.load_svg_from_string(svg, float(width) / view_width) != OK:
		push_error("Art: this SVG could not be drawn")
		image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var made := ImageTexture.create_from_image(image)
	_cache[key] = made
	return made


## Pixels per canvas unit for crisp art: the window's stretch, at least 1,
## times 2 so it stays sharp on high-density screens.
static func density(node: CanvasItem) -> float:
	if node == null or not node.is_inside_tree():
		return 2.0
	return maxf(1.0, UiKit.stretch_scale(node).x) * 2.0


## Wraps SVG body content in an <svg> element with this viewBox.
static func svg(view_width: float, view_height: float, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s">%s</svg>' % [view_width, view_height, body]


static func _view_width(svg_text: String) -> float:
	var at := svg_text.find('viewBox="')
	if at < 0:
		return 24.0
	var parts := svg_text.substr(at + 9, svg_text.find('"', at + 9) - at - 9).split(" ", false)
	return float(parts[2]) if parts.size() == 4 and float(parts[2]) > 0.0 else 24.0
