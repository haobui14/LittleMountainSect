class_name FakeTransport
extends RefCounted
## Stands in for HttpTransport: records every request and answers from a
## handler, so Backend and GameState can be tested with no network.

var requests: Array[Dictionary] = []
## func(request: Dictionary) -> {"code": int, "body": String or JSON value,
## "error": String}. request has method, url, path, headers, body (parsed).
var handler: Callable = func(_request: Dictionary) -> Dictionary: return {"code": 0, "error": "network"}


func send(method: int, url: String, headers: PackedStringArray, body: String, timeout: float) -> Dictionary:
	var request := {
		"method": method,
		"url": url,
		"path": url.substr(url.find("/", 8)),
		"headers": headers,
		"body": JSON.parse_string(body) if body != "" else null,
		"timeout": timeout,
	}
	requests.append(request)
	var response: Dictionary = handler.call(request)
	var payload: Variant = response.get("body", "")
	return {
		"code": int(response.get("code", 200)),
		"body": payload if payload is String else JSON.stringify(payload),
		"error": String(response.get("error", "")),
	}


func paths() -> Array:
	return requests.map(func(r: Dictionary) -> String: return r["path"])


func header(request: Dictionary, name: String) -> String:
	for line: String in request["headers"]:
		if line.begins_with(name + ": "):
			return line.substr(name.length() + 2)
	return ""


## A server that signs anyone up and answers the gateway, saves and status.
static func happy_server(overrides: Dictionary = {}) -> Callable:
	var state := {"signups": 0, "save": null}
	return func(r: Dictionary) -> Dictionary:
		var path: String = r["path"]
		for prefix: String in overrides:
			if path.begins_with(prefix):
				return overrides[prefix].call(r)
		if path.begins_with("/auth/v1/signup") or path.begins_with("/auth/v1/token"):
			state["signups"] += 1
			return {"code": 200, "body": {
				"access_token": "token-%d" % state["signups"],
				"refresh_token": "refresh-%d" % state["signups"],
				"expires_in": 3600,
				"user": {"id": "player-1"},
			}}
		if path.begins_with("/functions/v1/ai-gateway"):
			if r["body"]["kind"] == "evening":
				return {"code": 200, "body": {
					"source": "ai", "stored": false, "spirit_energy_left": 46,
					"story": "A good day.", "morning_report": "Tomorrow, chickens.",
					"decisions": [], "memories": [], "relationship_changes": [],
				}}
			return {"code": 200, "body": {
				"source": "ai", "safety": "ok", "reply": "Master!", "expression": "happy",
				"mood_change": 1, "memory": null, "wants_action": "rest", "spirit_energy_left": 49,
			}}
		if path.begins_with("/rest/v1/rpc/spirit_energy_status"):
			return {"code": 200, "body": {"left": 50, "per_day": 50, "enabled": true, "costs": {"chat": 1, "elder": 1, "event": 2, "evening": 3}}}
		if path.begins_with("/rest/v1/saves"):
			if r["method"] == HTTPClient.METHOD_GET:
				return {"code": 200, "body": [] if state["save"] == null else [state["save"]]}
			state["save"] = r["body"]
			return {"code": 200 if r["method"] == HTTPClient.METHOD_PATCH else 201, "body": [r["body"]]}
		return {"code": 200, "body": []}
