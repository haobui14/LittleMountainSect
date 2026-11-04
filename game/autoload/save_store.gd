class_name SaveStore
extends RefCounted
## Saves the sect as JSON on this device (user://). On the web, user:// is the
## browser's storage, which can fail in private windows or embedded pages, so
## every call reports failure instead of crashing; the game keeps playing.
## M4 moves saves to the server's `saves` table.

const DEFAULT_PATH := "user://save.json"


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


## Writes the save. Returns false when the device won't store it.
static func write(sect: Sect, path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(sect.to_dict()))
	file.close()
	return file.get_error() == OK


## Reads, upgrades and loads the save:
## {"ok": true, "sect": Sect} or {"ok": false, "error": "no_save" | "unreadable"
## | "not_a_save" | "newer_version"}.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no_save"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "unreadable"}
	var migrated := SaveMigration.migrate(json.data)
	if not migrated["ok"]:
		return migrated
	return {"ok": true, "sect": Sect.from_dict(migrated["data"])}


static func delete(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
