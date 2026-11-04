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
	save["version"] = version
	return {"ok": true, "data": save}


## Version 2 (M4) adds relationships, the disciples' own decisions, chat
## counters and the save revision.
static func _v1_to_v2(save: Dictionary) -> Dictionary:
	save["relationships"] = {}
	save["decisions"] = {}
	save["revision"] = 0
	for d: Dictionary in save["disciples"]:
		d["chat_mood_today"] = 0
		d["wants"] = ""
		d["wants_day"] = 0
	return save
