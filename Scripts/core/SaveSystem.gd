# File: res://Scripts/core/SaveSystem.gd
# Save / load to user://save_slot_N.json (readable JSON). Works on the state
# held by the Global autoload. Saved: player position, every character's
# level/xp/points/equipment, which characters are unlocked / in the party,
# the inventory and story flags.
class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 1
const SLOT_COUNT := 3

static func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

## Small summary for the menu, or {} if the slot is empty / unreadable.
static func get_slot_info(slot: int) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	var lan: Dictionary = data.get("progress", {}).get("player", {})
	return {"saved_at": str(data.get("saved_at", "?")), "level": int(lan.get("level", 1))}

static func save_game(slot: int) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"progress": {},
		"inventory": Global.inventory.duplicate(),
		"flags": Global.flags.duplicate(true),
		"roster": {},
	}
	for id in Global.progress:
		data["progress"][id] = Global.progress[id].to_dict()
	if is_instance_valid(Global.player):
		data["player_position"] = [Global.player.global_position.x, Global.player.global_position.y]
	if Global.roster:
		for e in Global.roster.entries:
			if e:
				data["roster"][e.member_id] = {"unlocked": e.unlocked, "in_party": e.in_party}

	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: can't write %s (error %d)" % [slot_path(slot), FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

static func load_game(slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false

	Global.progress.clear()
	for id in data.get("progress", {}):
		Global.progress[str(id)] = CharacterProgress.from_dict(data["progress"][id])
	Global.inventory = []
	for id in data.get("inventory", []):
		Global.inventory.append(str(id))
	Global.flags = data.get("flags", {})

	if Global.roster:
		var saved_roster: Dictionary = data.get("roster", {})
		for e in Global.roster.entries:
			if e and saved_roster.has(e.member_id):
				e.unlocked = bool(saved_roster[e.member_id].get("unlocked", false))
				e.in_party = bool(saved_roster[e.member_id].get("in_party", false))
		Global.roster.roster_changed.emit()

	var pos = data.get("player_position")
	if pos is Array and pos.size() == 2 and is_instance_valid(Global.player):
		Global.player.global_position = Vector2(float(pos[0]), float(pos[1]))

	Global.refresh_live_units(true)
	Global.progression_changed.emit()
	return true

static func _read(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
