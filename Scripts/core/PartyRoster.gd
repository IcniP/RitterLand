# File: res://Scripts/core/PartyRoster.gd
# Every party character the player owns. Put ONE of these in the game scene,
# fill "entries" in the Inspector. Characters are NOT placed in the Y-sort node:
# when a fight starts the roster spawns the unlocked + in_party ones next to the
# player, and removes them when the fight ends.
class_name PartyRoster
extends Node

@export var entries: Array[PartyMemberEntry] = []

signal roster_changed

var _spawned: Array = []
var _preview_cache: Dictionary = {}

func _ready() -> void:
	Global.roster = self

# ---------------- For the future party menu / story events ----------------

func get_entry(member_id: String) -> PartyMemberEntry:
	for e in entries:
		if e and e.member_id == member_id:
			return e
	return null

func unlock(member_id: String) -> void:
	var e := get_entry(member_id)
	if e:
		e.unlocked = true
		roster_changed.emit()

## Add/remove a character from the active party. Returns false if locked or full.
func set_in_party(member_id: String, value: bool) -> bool:
	var e := get_entry(member_id)
	if e == null or (value and not e.unlocked):
		return false
	if value and not e.in_party and get_active_entries().size() >= Global.MAX_PARTY_SIZE:
		return false
	e.in_party = value
	roster_changed.emit()
	return true

func get_active_entries() -> Array[PartyMemberEntry]:
	var list: Array[PartyMemberEntry] = []
	for e in entries:
		if e and e.unlocked and e.in_party and e.character_scene:
			list.append(e)
	return list

## Level-1 stats (straight from the character scene) + portrait, cached.
func get_base_stats(entry: PartyMemberEntry) -> Dictionary:
	if _preview_cache.has(entry.member_id):
		return _preview_cache[entry.member_id]
	var data := {"max_hp": 0, "max_sp": 0, "atk": 0, "def_stat": 0, "spd": 0, "portrait": null}
	if entry.character_scene:
		var inst = entry.character_scene.instantiate()  # never added to the tree
		if "max_hp" in inst:
			data = {"max_hp": inst.max_hp, "max_sp": inst.max_sp, "atk": inst.atk,
				"def_stat": inst.def_stat, "spd": inst.spd, "portrait": inst.portrait_icon}
		inst.free()
	_preview_cache[entry.member_id] = data
	return data

## Current stats (level + points + gear included) WITHOUT spawning the
## character - for menus. Also has "portrait".
func get_preview(entry: PartyMemberEntry) -> Dictionary:
	var base := get_base_stats(entry)
	var stats := Progression.compute_stats(base, Global.get_progress(entry.member_id))
	stats["portrait"] = base.get("portrait")
	return stats

# ---------------- Combat spawning ----------------

## Instantiate the active party next to the player. TurnManager then snaps them
## onto free tiles inside the combat area.
func spawn_party(player: Node2D) -> Array:
	despawn_party()
	var parent: Node = player.get_parent()
	for e in get_active_entries():
		if _spawned.size() >= Global.MAX_PARTY_SIZE:
			break
		var member = e.character_scene.instantiate()
		member.character_id = e.member_id   # must be set before _ready()
		parent.add_child(member)
		member.global_position = player.global_position
		Global.add_party_member(member)
		_spawned.append(member)
	return _spawned.duplicate()

func despawn_party() -> void:
	for member in _spawned:
		if is_instance_valid(member):
			Global.remove_party_member(member)
			member.queue_free()
	_spawned.clear()
