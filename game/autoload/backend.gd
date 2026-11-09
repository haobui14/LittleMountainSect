class_name BackendService
extends Node
## Talks to the server (Supabase): anonymous sign-in, the AI gateway, saves,
## memories and stored evening stories. Runs as the autoload "Backend".
##
## Every call can fail, and the game must keep playing when it does (CLAUDE.md
## rule 3): calls return {"ok": false, ...} instead of raising, and after a
## failure the service stays "offline" for a short while so the game doesn't
## wait on a server that is down.
##
## Only public values are used here: the project URL and the publishable key
## from config/backend.json. The Claude API key never reaches the game.

signal status_changed(status: String)
signal energy_changed(energy: Dictionary)

const CONFIG_PATH := "res://config/backend.json"
const SESSION_PATH := "user://session.cfg"
const OFFLINE_SECONDS := 30.0
const TIMEOUT := {"rest": 10.0, "chat": 20.0, "evening": 60.0, "event": 45.0}

## "offline", "signing_in" or "online".
var status := "offline"
## The last Spirit Energy status: {left, per_day, costs, enabled}, or {}.
var energy := {}
## Swappable for tests: anything with send(method, url, headers, body, timeout).
var transport: Object
## Tests point this somewhere else.
var session_path := SESSION_PATH
## The save row's revision on the server: -1 when unknown, -2 when there is none.
var server_revision := -1

var _url := ""
var _key := ""
var _region := ""
var _session := {}
var _offline_until := 0.0
var _signing_in := false

signal _signed_in(ok: bool)


func _ready() -> void:
	if transport == null:
		var http := HttpTransport.new()
		add_child(http)
		transport = http
	if _url == "":
		_load_config()
	_load_session()


## Points the service at a server. Tests call this with fake values.
func configure(url: String, key: String, region: String = "") -> void:
	_url = url.trim_suffix("/")
	_key = key
	_region = region


func is_configured() -> bool:
	return _url != "" and _key != ""


func user_id() -> String:
	return String(_session.get("user_id", ""))


# Public calls ---------------------------------------------------------------

## A chat line with a disciple or the Elder (body from ChatRules.request).
func chat(body: Dictionary) -> Dictionary:
	var result := await _call(HTTPClient.METHOD_POST, "/functions/v1/ai-gateway", body, TIMEOUT["chat"], true)
	_note_energy(result)
	return result


## The evening story (body from EveningRules.request).
func evening(body: Dictionary) -> Dictionary:
	var result := await _call(HTTPClient.METHOD_POST, "/functions/v1/ai-gateway", body, TIMEOUT["evening"], true)
	_note_energy(result)
	return result


## The evening story the server already stored for a day, or {"ok": false}.
func stored_evening(game_day: int) -> Dictionary:
	var result := await _call(HTTPClient.METHOD_GET, "/rest/v1/evening_stories?select=reply&game_day=eq.%d" % game_day, null, TIMEOUT["rest"])
	if result["ok"] and result["data"] is Array and not result["data"].is_empty():
		return {"ok": true, "data": result["data"][0]["reply"]}
	return {"ok": false, "error": result.get("error", "none")}


## The words of a surprise event (body from EventRules.request).
func event(body: Dictionary) -> Dictionary:
	var result := await _call(HTTPClient.METHOD_POST, "/functions/v1/ai-gateway", body, TIMEOUT["event"], true)
	_note_energy(result)
	return result


## The event words the server already stored for a day, or {"ok": false}.
func stored_event(game_day: int) -> Dictionary:
	var result := await _call(HTTPClient.METHOD_GET, "/rest/v1/event_stories?select=reply&game_day=eq.%d" % game_day, null, TIMEOUT["rest"])
	if result["ok"] and result["data"] is Array and not result["data"].is_empty():
		return {"ok": true, "data": result["data"][0]["reply"]}
	return {"ok": false, "error": result.get("error", "none")}


## Refreshes the Spirit Energy status (and emits energy_changed).
func refresh_energy() -> Dictionary:
	var result := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/spirit_energy_status", {}, TIMEOUT["rest"])
	if result["ok"] and result["data"] is Dictionary:
		energy = result["data"]
		energy_changed.emit(energy)
	return result


## The newest key memories for a disciple, newest first.
func memories(disciple_id: String) -> Dictionary:
	var path := "/rest/v1/memories?select=content&kind=eq.key&subject=eq.%s&order=id.desc&limit=10" % disciple_id.uri_encode()
	var result := await _call(HTTPClient.METHOD_GET, path, null, TIMEOUT["rest"])
	if not result["ok"]:
		return result
	var texts: Array[String] = []
	for row: Dictionary in result["data"]:
		texts.append(String(row["content"]))
	return {"ok": true, "data": texts}


## The server's save: {"ok": true, "data": {revision, schema_version, data}}
## or {"ok": true, "data": null} when there is none.
func load_save() -> Dictionary:
	var result := await _call(HTTPClient.METHOD_GET, "/rest/v1/saves?select=revision,schema_version,data", null, TIMEOUT["rest"])
	if not result["ok"]:
		return result
	if result["data"].is_empty():
		server_revision = -2
		return {"ok": true, "data": null}
	var row: Dictionary = result["data"][0]
	server_revision = int(row["revision"])
	return {"ok": true, "data": row}


## Writes the save. Only replaces the server's copy when it still has the
## revision this game last saw, so two tabs can't overwrite each other:
## {"ok": false, "error": "conflict"} means another copy was saved first.
func write_save(save: Dictionary, revision: int) -> Dictionary:
	if server_revision == -1:
		var loaded := await load_save()
		if not loaded["ok"]:
			return loaded
	var row := {"schema_version": int(save.get("version", 1)), "revision": revision, "data": save}
	var result: Dictionary
	if server_revision == -2:
		row["player_id"] = user_id()
		result = await _call(HTTPClient.METHOD_POST, "/rest/v1/saves", row, TIMEOUT["rest"], false, ["Prefer: return=representation"])
	else:
		var path := "/rest/v1/saves?player_id=eq.%s&revision=eq.%d" % [user_id(), server_revision]
		result = await _call(HTTPClient.METHOD_PATCH, path, row, TIMEOUT["rest"], false, ["Prefer: return=representation"])
	if not result["ok"]:
		if int(result.get("code", 0)) == 409:
			server_revision = -1
			return {"ok": false, "error": "conflict"}
		return result
	if result["data"] is Array and result["data"].is_empty():
		server_revision = -1
		return {"ok": false, "error": "conflict"}
	server_revision = revision
	return {"ok": true}


## Updates the player's row (language, age_confirmed_at, last_seen_at only).
func update_player(fields: Dictionary) -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "error": "offline"}
	return await _call(HTTPClient.METHOD_PATCH, "/rest/v1/players?id=eq.%s" % user_id(), fields, TIMEOUT["rest"])


# Sessions ---------------------------------------------------------------------

## Signs in (anonymously the first time) or refreshes the session. Returns
## false, quickly, while the server is unreachable.
func _ensure_session() -> bool:
	if not is_configured():
		return false
	if _now() < _offline_until:
		return false
	if _session_valid():
		return true
	if _signing_in:
		return await _signed_in
	_signing_in = true
	_set_status("signing_in")
	var ok := false
	if _session.has("refresh_token"):
		ok = await _auth("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _session["refresh_token"]})
	if not ok:
		ok = await _auth("/auth/v1/signup", {})
	_signing_in = false
	if ok:
		_set_status("online")
	else:
		_go_offline()
	_signed_in.emit(ok)
	return ok


func _auth(path: String, body: Dictionary) -> bool:
	var headers := PackedStringArray(["apikey: " + _key, "Content-Type: application/json"])
	var response: Dictionary = await transport.send(HTTPClient.METHOD_POST, _url + path, headers, JSON.stringify(body), TIMEOUT["rest"])
	if int(response["code"]) != 200:
		return false
	var data: Variant = _parse(response["body"])
	if not data is Dictionary or not data.has("access_token"):
		return false
	_session = {
		"access_token": String(data["access_token"]),
		"refresh_token": String(data.get("refresh_token", "")),
		"expires_at": _now() + float(data.get("expires_in", 3600)),
		"user_id": String(data.get("user", {}).get("id", _session.get("user_id", ""))),
	}
	_save_session()
	return true


func _session_valid() -> bool:
	return _session.has("access_token") and float(_session.get("expires_at", 0)) > _now() + 60.0


# Requests ---------------------------------------------------------------------

## One call with the session's token. Retries once on a network error or a
## 502/503/504, and once after refreshing the session on a 401.
## Returns {"ok", "code", "data", "error"}.
func _call(method: int, path: String, body: Variant, timeout: float, gateway: bool = false, extra: Array = []) -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "code": 0, "data": null, "error": "offline"}
	var text := "" if body == null else JSON.stringify(body)
	var refreshed := false
	var retried := false
	while true:
		var headers := PackedStringArray([
			"apikey: " + _key,
			"Authorization: Bearer " + String(_session["access_token"]),
			"Content-Type: application/json",
		])
		if gateway and _region != "":
			headers.append("x-region: " + _region)
		for header: String in extra:
			headers.append(header)
		var response: Dictionary = await transport.send(method, _url + path, headers, text, timeout)
		var code := int(response["code"])
		if code == 401 and not refreshed:
			refreshed = true
			_session.erase("access_token")
			if not await _ensure_session():
				return {"ok": false, "code": 401, "data": null, "error": "offline"}
			continue
		if (code == 0 or code in [502, 503, 504]) and not retried:
			retried = true
			continue
		if code == 0:
			# No answer at all means the server is unreachable; a timeout only
			# means it was slow, so later calls (like fetching a stored story)
			# still try.
			if String(response["error"]) != "timeout":
				_go_offline()
			return {"ok": false, "code": 0, "data": null, "error": String(response["error"])}
		var data: Variant = _parse(response["body"])
		# The gateway answers 503 with a written line when something broke on
		# its side; that's still a usable reply.
		var ok := (code >= 200 and code < 300) or (gateway and code == 503 and data is Dictionary)
		return {"ok": ok, "code": code, "data": data, "error": "" if ok else "http_%d" % code}
	return {}


func _note_energy(result: Dictionary) -> void:
	if result["ok"] and result["data"] is Dictionary:
		var left: Variant = result["data"].get("spirit_energy_left")
		if left is float or left is int:
			energy["left"] = int(left)
			energy_changed.emit(energy)


func _go_offline() -> void:
	_offline_until = _now() + OFFLINE_SECONDS
	_set_status("offline")


func _set_status(value: String) -> void:
	if status != value:
		status = value
		status_changed.emit(status)


func _parse(text: String) -> Variant:
	if text == "":
		return null
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


func _now() -> float:
	return Time.get_unix_time_from_system()


# Files ------------------------------------------------------------------------

func _load_config() -> void:
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var data: Variant = _parse(text)
	if data is Dictionary:
		configure(String(data.get("supabase_url", "")), String(data.get("publishable_key", "")), String(data.get("functions_region", "")))


func _load_session() -> void:
	var config := ConfigFile.new()
	if config.load(session_path) != OK:
		return
	for key in ["access_token", "refresh_token", "expires_at", "user_id"]:
		if config.has_section_key("session", key):
			_session[key] = config.get_value("session", key)


func _save_session() -> void:
	var config := ConfigFile.new()
	for key: String in _session:
		config.set_value("session", key, _session[key])
	config.save(session_path)


## Forgets the session (tests, and a future "sign out").
func forget_session() -> void:
	_session = {}
	server_revision = -1
	_offline_until = 0.0
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
