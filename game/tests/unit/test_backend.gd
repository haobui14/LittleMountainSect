extends GutTest
## The Backend service with a fake server: sign-in and sessions, retries,
## going offline quickly, and saves that two tabs can't overwrite.

const SESSION := "user://test_session.cfg"

var fake: FakeTransport
var backend: BackendService


func before_each() -> void:
	if FileAccess.file_exists(SESSION):
		DirAccess.remove_absolute(SESSION)
	fake = FakeTransport.new()
	fake.handler = FakeTransport.happy_server()
	backend = _new_backend()


func after_all() -> void:
	if FileAccess.file_exists(SESSION):
		DirAccess.remove_absolute(SESSION)


func _new_backend() -> BackendService:
	var b := BackendService.new()
	b.transport = fake
	b.session_path = SESSION
	b.configure("https://example.test", "pk_test", "us-west-1")
	add_child_autofree(b)
	return b


func test_the_first_call_signs_up_anonymously_and_keeps_the_session() -> void:
	var result: Dictionary = await backend.chat({"kind": "elder", "locale": "en", "recent": [], "message": "Hi"})
	assert_true(result["ok"])
	assert_eq(result["data"]["reply"], "Master!")
	assert_eq(fake.paths(), ["/auth/v1/signup", "/functions/v1/ai-gateway"])
	var gateway: Dictionary = fake.requests[1]
	assert_eq(fake.header(gateway, "Authorization"), "Bearer token-1")
	assert_eq(fake.header(gateway, "apikey"), "pk_test")
	assert_eq(fake.header(gateway, "x-region"), "us-west-1")
	assert_eq(backend.status, "online")
	assert_eq(int(backend.energy["left"]), 49, "Spirit Energy comes back with each reply")

	# A new game session reuses the saved session instead of signing up again.
	var again := _new_backend()
	await again.refresh_energy()
	assert_eq(fake.paths().count("/auth/v1/signup"), 1)
	assert_eq(int(again.energy["left"]), 50)


func test_an_expired_session_is_refreshed_not_replaced() -> void:
	await backend.refresh_energy()
	backend._session["expires_at"] = 0.0
	await backend.refresh_energy()
	assert_eq(fake.paths().filter(func(p: String) -> bool: return p.begins_with("/auth/")), [
		"/auth/v1/signup",
		"/auth/v1/token?grant_type=refresh_token",
	])


func test_a_401_refreshes_the_session_and_tries_again() -> void:
	var rejected := [false]
	fake.handler = FakeTransport.happy_server({
		"/rest/v1/rpc/spirit_energy_status": func(_r: Dictionary) -> Dictionary:
			if not rejected[0]:
				rejected[0] = true
				return {"code": 401, "body": {"message": "JWT expired"}}
			return {"code": 200, "body": {"left": 7}},
	})
	var result: Dictionary = await backend.refresh_energy()
	assert_true(result["ok"])
	assert_eq(int(backend.energy["left"]), 7)


func test_one_retry_after_a_network_error_or_a_502() -> void:
	var failures := [1]
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary:
			if failures[0] > 0:
				failures[0] -= 1
				return {"code": 502}
			return {"code": 200, "body": {"source": "ai", "reply": "Back!"}},
	})
	var result: Dictionary = await backend.chat({"kind": "elder"})
	assert_true(result["ok"])
	assert_eq(fake.paths().count("/functions/v1/ai-gateway"), 2)


func test_a_dead_server_means_offline_quickly_and_without_waiting_again() -> void:
	fake.handler = func(_r: Dictionary) -> Dictionary: return {"code": 0, "error": "network"}
	var result: Dictionary = await backend.chat({"kind": "elder"})
	assert_false(result["ok"])
	assert_eq(result["error"], "offline")
	assert_eq(backend.status, "offline")
	var tried := fake.requests.size()
	result = await backend.chat({"kind": "elder"})
	assert_false(result["ok"])
	assert_eq(fake.requests.size(), tried, "no new requests while offline")


func test_the_gateways_written_line_on_a_503_is_still_used() -> void:
	fake.handler = FakeTransport.happy_server({
		"/functions/v1/ai-gateway": func(_r: Dictionary) -> Dictionary:
			return {"code": 503, "body": {"source": "fallback", "reason": "error", "reply": "My mind wandered."}},
	})
	var result: Dictionary = await backend.chat({"kind": "elder"})
	assert_true(result["ok"])
	assert_eq(result["data"]["source"], "fallback")


func test_saves_insert_then_update_only_the_revision_they_saw() -> void:
	var first: Dictionary = await backend.write_save({"version": 2, "day": 1}, 1)
	assert_true(first["ok"])
	var second: Dictionary = await backend.write_save({"version": 2, "day": 2}, 2)
	assert_true(second["ok"])
	var writes := fake.requests.filter(func(r: Dictionary) -> bool: return r["path"].begins_with("/rest/v1/saves") and r["method"] != HTTPClient.METHOD_GET)
	assert_eq(writes[0]["method"], HTTPClient.METHOD_POST)
	assert_eq(writes[0]["body"]["player_id"], "player-1")
	assert_eq(writes[1]["method"], HTTPClient.METHOD_PATCH)
	assert_string_contains(writes[1]["path"], "revision=eq.1")
	assert_eq(backend.server_revision, 2)


func test_a_save_from_another_tab_is_a_conflict() -> void:
	fake.handler = FakeTransport.happy_server({
		"/rest/v1/saves?player_id": func(_r: Dictionary) -> Dictionary: return {"code": 200, "body": []},
		"/rest/v1/saves?select": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"revision": 5, "schema_version": 2, "data": {"day": 9}}]},
	})
	var loaded: Dictionary = await backend.load_save()
	assert_eq(int(loaded["data"]["revision"]), 5)
	var result: Dictionary = await backend.write_save({"version": 2}, 6)
	assert_eq(result, {"ok": false, "error": "conflict"})
	assert_eq(backend.server_revision, -1, "the next write reloads first")


func test_memories_and_stored_stories_are_read_from_the_server() -> void:
	fake.handler = FakeTransport.happy_server({
		"/rest/v1/memories": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"content": "newest"}, {"content": "older"}]},
		"/rest/v1/evening_stories": func(_r: Dictionary) -> Dictionary:
			return {"code": 200, "body": [{"reply": {"story": "Stored."}}]},
	})
	assert_eq((await backend.memories("d1"))["data"], ["newest", "older"])
	assert_eq((await backend.stored_evening(4))["data"], {"story": "Stored."})
	assert_string_contains(fake.paths()[-1], "game_day=eq.4")
