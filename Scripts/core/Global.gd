# File: res://Scripts/core/Global.gd
# Autoload this as "Global" in Project Settings > Autoload.
extends Node

enum GameState { EXPLORATION, COMBAT }

const MAX_PARTY_SIZE := 3
var player: EntityBase = null
var game_state: GameState = GameState.EXPLORATION

## Active party members (max MAX_PARTY_SIZE). Filled by PartyRoster when a fight spawns them.
var party: Array = []

## The PartyRoster node in the game scene (sets itself in _ready).
var roster: Node = null

## Enemies currently alive in the active CombatZone.
var active_enemies: Array = []

## The CombatZone currently controlling combat (null while exploring).
var current_combat_zone: Node = null

## Per-character progress (level, xp, points, equipment), keyed by
## character id: "player" for Lan, the PartyMemberEntry.member_id for others.
var progress: Dictionary = {}
## Equipment item ids you own (duplicates allowed).
var inventory: Array = []
## Free-form story flags for later (saved in the save file).
var flags: Dictionary = {}

signal progression_changed
## Emitted after a fight: {"xp": int, "results": [{id, name, level, levels_gained, points}]}
signal xp_awarded(summary)
signal game_state_changed(new_state)
signal party_changed
signal enemy_registry_changed

# ---------------- Party management ----------------

func add_party_member(member) -> bool:
	if party.size() >= MAX_PARTY_SIZE:
		push_warning("Global: Party is full (max %d)." % MAX_PARTY_SIZE)
		return false
	if member in party:
		return false
	party.append(member)
	party_changed.emit()
	return true

func remove_party_member(member) -> void:
	if member in party:
		party.erase(member)
		party_changed.emit()

func get_party_alive() -> Array:
	return party.filter(func(m): return is_instance_valid(m) and m.is_alive())

# ---------------- Enemy registry ----------------

func register_enemy(enemy) -> void:
	if enemy not in active_enemies:
		active_enemies.append(enemy)
		enemy_registry_changed.emit()

func unregister_enemy(enemy) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)
		enemy_registry_changed.emit()

func clear_enemy_registry() -> void:
	active_enemies.clear()
	enemy_registry_changed.emit()

func get_enemies_alive() -> Array:
	return active_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive())

# ---------------- Game state ----------------

func set_game_state(new_state: GameState) -> void:
	if game_state == new_state:
		return
	game_state = new_state
	game_state_changed.emit(new_state)

# ---------------- Generic stat helper ----------------
# Lets UI / quest / item systems modify any character or enemy's permanent
# stats without needing to know EntityBase internals.
func modify_stat(entity, stat_name: String, amount: int) -> void:
	if entity == null or not entity.has_method("modify_stat"):
		push_warning("Global.modify_stat: target has no modify_stat() method.")
		return
	entity.modify_stat(stat_name, amount)

# ---------------- Progression / equipment ----------------

func _ready() -> void:
	# New game: start with the test equipment. (A loaded save replaces this.)
	if inventory.is_empty():
		inventory = ItemDB.starter_inventory()

func get_progress(character_id: String) -> CharacterProgress:
	if not progress.has(character_id):
		progress[character_id] = CharacterProgress.new()
	return progress[character_id]

func character_name(character_id: String) -> String:
	if character_id == "player":
		return String(player.name) if is_instance_valid(player) else "Player"
	if roster:
		var e = roster.get_entry(character_id)
		if e:
			return e.display_name
	return character_id

## {"name", "base" (level-1 stats from the scene), "stats" (final), "portrait"}
func get_character_info(character_id: String) -> Dictionary:
	var base := {}
	var portrait = null
	if character_id == "player":
		if is_instance_valid(player):
			base = player.get_base_stats()
			portrait = player.portrait_icon
	elif roster:
		var e = roster.get_entry(character_id)
		if e:
			var b: Dictionary = roster.get_base_stats(e)
			portrait = b.get("portrait")
			base = b
	return {"name": character_name(character_id), "base": base, "portrait": portrait,
		"stats": Progression.compute_stats(base, get_progress(character_id))}

## Re-apply level / points / gear to the live player and spawned party.
func refresh_live_units(heal_to_full: bool = false) -> void:
	if is_instance_valid(player):
		player.refresh_stats(heal_to_full)
	for m in party:
		if is_instance_valid(m):
			m.refresh_stats(heal_to_full)

func allocate_point(character_id: String, stat: String) -> bool:
	if not get_progress(character_id).spend_point(stat):
		return false
	refresh_live_units()
	progression_changed.emit()
	return true

func owned_count(item_id: String) -> int:
	return inventory.count(item_id)

## How many copies of an item are equipped, optionally ignoring one slot.
func equipped_count(item_id: String, except_char: String = "", except_slot: String = "") -> int:
	var n := 0
	for cid in progress:
		var eq: Dictionary = progress[cid].equipment
		for slot in eq:
			if cid == except_char and slot == except_slot:
				continue
			if eq[slot] == item_id:
				n += 1
	return n

func available_count(item_id: String, except_char: String = "", except_slot: String = "") -> int:
	return owned_count(item_id) - equipped_count(item_id, except_char, except_slot)

## item_id "" = unequip. Returns false if the item doesn't fit the slot or none is free.
func equip(character_id: String, slot: String, item_id: String) -> bool:
	var p := get_progress(character_id)
	if item_id == "":
		p.equipment.erase(slot)
	else:
		var item := ItemDB.get_item(item_id)
		if item == null or int(item.slot_type) != Progression.slot_type(slot):
			return false
		if available_count(item_id, character_id, slot) < 1:
			return false
		p.equipment[slot] = item_id
	refresh_live_units()
	progression_changed.emit()
	return true

## Give XP to these characters (everyone who fought gets the full amount).
func award_xp(character_ids: Array, amount: int) -> Dictionary:
	var summary := {"xp": amount, "results": []}
	if amount <= 0:
		return summary
	var seen := {}
	for id in character_ids:
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		var p := get_progress(id)
		var old_level := p.level
		var gained := p.add_xp(amount)
		var learned: Array = SkillDB.on_level_up(id, old_level, p.level) if gained > 0 else []
		summary["results"].append({"id": id, "name": character_name(id), "level": p.level,
			"levels_gained": gained, "points": gained * Progression.POINTS_PER_LEVEL,
			"new_skills": learned})
	refresh_live_units()
	progression_changed.emit()
	xp_awarded.emit(summary)
	return summary

## Put a learned skill into one of the 4 loadout slots ("" = empty the slot).
## If the skill is already in another slot the two slots swap.
## Weapon users (Lan) have one bar per `weapon`; a magic skill (weapon "") takes the
## SAME slot in every weapon bar, and removing/replacing it there clears it from all bars.
func set_skill_slot(character_id: String, slot_index: int, skill_id: String, weapon: String = "") -> bool:
	if slot_index < 0 or slot_index >= SkillDB.MAX_LOADOUT:
		return false
	var p := get_progress(character_id)
	var s: SkillData = null
	if skill_id != "":
		s = SkillDB.get_skill(skill_id)
		if s == null or s.is_ultimate or not SkillDB.unlocked_skills(character_id, p.level).has(s):
			return false
	SkillDB.ensure_customized(character_id)
	if SkillDB.START_WEAPON.has(character_id):
		if weapon == "":
			weapon = SkillDB.START_WEAPON[character_id]
		if not SkillDB.SWAP.has(weapon) or (s != null and not SkillDB._fits(s, weapon)):
			return false
		var old_s: SkillData = SkillDB.get_skill(str(p.weapon_loadout[weapon][slot_index]))
		if old_s != null and old_s.weapon == "":   # the slot held a shared magic skill: free it everywhere
			for w in SkillDB.SWAP:
				if p.weapon_loadout[w][slot_index] == old_s.id:
					p.weapon_loadout[w][slot_index] = ""
		var targets: Array = SkillDB.SWAP.keys() if (s != null and s.weapon == "") else [weapon]
		for w in targets:
			var bar: Array = p.weapon_loadout[w]
			var other: int = bar.find(skill_id) if skill_id != "" else -1
			if other != -1 and other != slot_index:
				bar[other] = ""
			bar[slot_index] = skill_id
		progression_changed.emit()
		return true
	if skill_id != "":
		var other: int = p.skill_loadout.find(skill_id)
		if other != -1 and other != slot_index:
			p.skill_loadout[other] = p.skill_loadout[slot_index]
	p.skill_loadout[slot_index] = skill_id
	progression_changed.emit()
	return true
