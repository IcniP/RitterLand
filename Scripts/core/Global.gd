# File: res://Scripts/core/Global.gd
# Autoload this as "Global" in Project Settings > Autoload.
extends Node

enum GameState { EXPLORATION, COMBAT }

const MAX_PARTY_SIZE := 3

var game_state: GameState = GameState.EXPLORATION

## Active party members (max MAX_PARTY_SIZE). Populated by PartyNPC.recruit().
var party: Array = []

## Enemies currently alive in the active CombatZone.
var active_enemies: Array = []

## The CombatZone currently controlling combat (null while exploring).
var current_combat_zone: Node = null

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
