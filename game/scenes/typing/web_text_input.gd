class_name WebTextInput
extends Node
## A browser-native <input> laid over a Control, for keyboards that Godot's
## own text box may not handle on the web (some Vietnamese input methods,
## some phone keyboards). Web builds only; it does nothing elsewhere.

signal text_changed(text: String)

const ELEMENT_ID := "lms-text-input"

var _target: Control
var _font_px := 22
var _element: JavaScriptObject
## Kept as a member: if the callback is freed, the browser stops calling it.
var _on_input: JavaScriptObject
## Where the input was last placed, in screen pixels.
var _placed_rect := Rect2()


static func available() -> bool:
	return OS.has_feature("web")


## Shows the input over `target` and focuses it.
func attach(target: Control, placeholder: String, font_px: int) -> void:
	if not available():
		return
	_target = target
	_font_px = font_px
	JavaScriptBridge.eval("""
		(function () {
			let el = document.getElementById('%s');
			if (!el) {
				el = document.createElement('input');
				el.id = '%s';
				document.body.appendChild(el);
			}
			el.type = 'text';
			el.autocomplete = 'off';
			el.spellcheck = false;
			Object.assign(el.style, {
				position: 'fixed', zIndex: '10', boxSizing: 'border-box', margin: '0',
				border: '2px solid #6f9a8d', borderRadius: '6px', outline: 'none',
				background: '#fffdf7', color: '#3d332a', padding: '0 10px',
				fontFamily: 'Nunito, system-ui, sans-serif',
			});
		})();
	""" % [ELEMENT_ID, ELEMENT_ID])
	_element = JavaScriptBridge.get_interface("document").getElementById(ELEMENT_ID)
	_element.placeholder = placeholder
	_on_input = JavaScriptBridge.create_callback(_handle_input)
	_element.addEventListener("input", _on_input)
	_placed_rect = Rect2()
	_process(0.0)
	_element.focus()


## Removes the input from the page.
func detach() -> void:
	if _element == null:
		return
	JavaScriptBridge.eval("document.getElementById('%s')?.remove();" % ELEMENT_ID)
	_element = null
	_on_input = null


func _exit_tree() -> void:
	detach()


## Follows the target on screen: window resizes and layout shifts both move
## it. JavaScript runs only when the rectangle actually changes.
func _process(_delta: float) -> void:
	if _element == null or _target == null:
		return
	var rect := UiKit.window_rect(_target)
	if rect != _placed_rect:
		_placed_rect = rect
		_place(rect)


## Matches the input to an on-screen rectangle, converting the canvas's
## pixels to the page's CSS pixels.
func _place(rect: Rect2) -> void:
	JavaScriptBridge.eval("""
		(function () {
			const el = document.getElementById('%s');
			const canvas = document.getElementById('canvas');
			if (!el || !canvas) return;
			const box = canvas.getBoundingClientRect();
			const sx = box.width / canvas.width;
			const sy = box.height / canvas.height;
			el.style.left = (box.left + %f * sx) + 'px';
			el.style.top = (box.top + %f * sy) + 'px';
			el.style.width = (%f * sx) + 'px';
			el.style.height = (%f * sy) + 'px';
			el.style.fontSize = Math.max(16, Math.round(%d * sy)) + 'px';
		})();
	""" % [ELEMENT_ID, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			roundi(_font_px * UiKit.stretch_scale(_target).y)])


func _handle_input(_args: Array) -> void:
	text_changed.emit(String(_element.value))
