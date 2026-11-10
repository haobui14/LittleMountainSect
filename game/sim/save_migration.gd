class_name SaveMigration
extends RefCounted
## Upgrades older saves to Sect.SAVE_VERSION, one version at a time. When the
## save format changes, bump Sect.SAVE_VERSION and add a step here that turns
## version N into N + 1, with a test.

## Returns {"ok": true, "data": <current-version save>} or
## {"ok": false, "error": <reason>} for saves the game cannot read.
static func migrate(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or not data.has("version"):
		return {"ok": false, "error": "not_a_save"}
	var save: Dictionary = data.duplicate(true)
	var version := int(save["version"])
	if version > Sect.SAVE_VERSION:
		return {"ok": false, "error": "newer_version"}
	if version < 1:
		return {"ok": false, "error": "not_a_save"}
	if version == 1:
		save = _v1_to_v2(save)
		version = 2
	if version == 2:
		save = _v2_to_v3(save)
		version = 3
	if version == 3:
		save = _v3_to_v4(save)
		version = 4
	save["version"] = version
	return {"ok": true, "data": save}


## Version 2 (M4) adds relationships, the disciples' own decisions, chat
## counters, the save revision and the last evening story.
static func _v1_to_v2(save: Dictionary) -> Dictionary:
	save["relationships"] = {}
	save["decisions"] = {}
	save["revision"] = 0
	save["evening"] = {}
	for d: Dictionary in save["disciples"]:
		d["chat_mood_today"] = 0
		d["wants"] = ""
		d["wants_day"] = 0
	return save


## Version 3 (M5) adds pills, surprise events, the gate candidate, morning
## facts and the Sect Chronicle, and each disciple's status, technique and
## study.
static func _v2_to_v3(save: Dictionary) -> Dictionary:
	var items := {}
	for pill in Balance.PILLS:
		items[pill] = 0
	save["items"] = items
	save["brews_today"] = 0
	save["event"] = {}
	save["next_event_day"] = 0
	save["recent_problems"] = []
	save["candidate"] = {}
	save["next_candidate_day"] = 0
	save["pending_facts"] = []
	save["chronicle"] = []
	for d: Dictionary in save["disciples"]:
		d["status"] = "home"
		d["return_day"] = 0
		d["technique"] = 0
		d["study"] = 0
	return save


## Version 4 (M6) adds the rival sects, land, wars, tournaments, travel,
## letters and the alumni, and each disciple's role, joining day and travel.
## Disciples already in the sect count as having joined on day 1.
static func _v3_to_v4(save: Dictionary) -> Dictionary:
	var fresh := Sect.new()
	save["rivals"] = fresh.rivals.duplicate(true)
	save["land"] = Balance.LAND_START
	save["war"] = {}
	save["last_war_day"] = fresh.last_war_day
	save["tournament"] = {}
	save["travel_request"] = {}
	save["next_travel_day"] = 0
	save["letter"] = {}
	save["alumni"] = []
	for d: Dictionary in save["disciples"]:
		d["role"] = "disciple"
		d["joined_day"] = 1
		d["travel"] = {}
	var candidate: Dictionary = save.get("candidate", {})
	if candidate.has("disciple"):
		candidate["disciple"]["role"] = "disciple"
		candidate["disciple"]["joined_day"] = 1
		candidate["disciple"]["travel"] = {}
	return save
