extends Node
## Web builds only: publishes the screen and the clickable controls tagged
## with UiKit.probe() as window.lmsUi, so browser checks
## (tools/web-check/*.cjs) can click by name instead of by fixed coordinates.
## Rectangles are in CSS pixels, relative to the page.
##
##   window.lmsUi = {screen: "plan", day: 3, chat_lines: 4, waiting: 0,
##                   evening: "done", event: false, candidate: false,
##                   items: {"end_day": {x, y, w, h, disabled, pressed, on_screen}}}
##
## event is true while the morning's surprise event waits for a choice, and
## candidate while a hopeful waits at the gate.

const INTERVAL := 0.2

var _elapsed := 0.0


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < INTERVAL:
		return
	_elapsed = 0.0
	var items := {}
	_collect(get_tree().root, items)
	var in_game := GameState.has_game() and _has_game_screen(get_tree().root)
	var screen := GameState.step if in_game else "title"
	var day := GameState.sect.day if in_game else 0
	var lines := 0
	for target: String in GameState.chats:
		lines += GameState.chats[target].size()
	var data := JSON.stringify({
		"screen": screen,
		"day": day,
		"items": items,
		"chat_lines": lines,
		"waiting": GameState.waiting.size(),
		"evening": GameState.evening_state,
		"event": in_game and EventRules.pending(GameState.sect),
		"candidate": in_game and not GameState.sect.candidate.is_empty(),
	})
	JavaScriptBridge.eval("""
		(function () {
			const canvas = document.getElementById('canvas');
			if (!canvas) return;
			const box = canvas.getBoundingClientRect();
			const sx = box.width / canvas.width;
			const sy = box.height / canvas.height;
			const ui = %s;
			for (const item of Object.values(ui.items)) {
				item.x = box.left + item.x * sx; item.w *= sx;
				item.y = box.top + item.y * sy; item.h *= sy;
			}
			window.lmsUi = ui;
		})();
	""" % data)


func _has_game_screen(node: Node) -> bool:
	if node is GameScreen:
		return true
	for child in node.get_children():
		if _has_game_screen(child):
			return true
	return false


func _collect(node: Node, items: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Control and node.has_meta("probe"):
		var control := node as Control
		var rect := UiKit.window_rect(control)
		items[String(node.get_meta("probe"))] = {
			"on_screen": _visible_area(control).encloses(rect),
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y,
			"disabled": control is BaseButton and (control as BaseButton).disabled,
			"pressed": control is BaseButton and (control as BaseButton).button_pressed,
		}
	for child in node.get_children():
		_collect(child, items)


## The part of the window where [param control] can be seen: the window,
## cut down by every ancestor that clips its children (a scrolling list).
## A button scrolled under a fixed bar is not on screen.
func _visible_area(control: Control) -> Rect2:
	var area := Rect2(Vector2.ZERO, Vector2(get_window().size))
	var parent := control.get_parent()
	while parent:
		if parent is Control and (parent as Control).clip_contents:
			area = area.intersection(UiKit.window_rect(parent as Control))
		parent = parent.get_parent()
	return area
