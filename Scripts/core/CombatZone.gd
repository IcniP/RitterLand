# File: res://Scripts/core/CombatZone.gd
# Attach to an Area2D placed over a battle arena on your tilemap. When the
# player (an EntityBase with is_player_controlled = true) enters, the zone
# switches the game into GridCombat mode, spawns its enemies, and hands
# control to a CombatManager.
class_name CombatZone
extends Area2D

@export var enemy_scenes: Array[PackedScene] = []      # PLACEHOLDER enemy roster for this zone
@export var enemy_spawn_points: Array[NodePath] = []    # optional Marker2D per enemy_scenes entry
@export var combat_manager_path: NodePath
## If true, the zone can trigger combat again after it resolves (rematch spots).
@export var repeatable: bool = false

var _combat_manager: Node = null
var _spawned_enemies: Array = []
var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if combat_manager_path != NodePath():
		_combat_manager = get_node(combat_manager_path)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is EntityBase and body.is_player_controlled:
		_triggered = true
		_start_combat(body)

func _start_combat(player: EntityBase) -> void:
	Global.current_combat_zone = self
	Global.set_game_state(Global.GameState.COMBAT)

	player.movement_mode = EntityBase.MovementMode.GRID_COMBAT
	for member in Global.get_party_alive():
		member.movement_mode = EntityBase.MovementMode.GRID_COMBAT

	_spawn_enemies()

	if _combat_manager and _combat_manager.has_method("start_combat"):
		var party: Array = [player] + Global.get_party_alive()
		_combat_manager.start_combat(party, _spawned_enemies)
	else:
		push_warning("CombatZone: no CombatManager assigned at combat_manager_path.")

func _spawn_enemies() -> void:
	for i in range(enemy_scenes.size()):
		var scene := enemy_scenes[i]
		if scene == null:
			continue
		var enemy = scene.instantiate()
		if i < enemy_spawn_points.size():
			var spawn_node := get_node_or_null(enemy_spawn_points[i])
			if spawn_node:
				enemy.global_position = spawn_node.global_position
		get_tree().current_scene.add_child(enemy)
		_spawned_enemies.append(enemy)

func resolve_victory() -> void:
	_end_combat()

func resolve_defeat() -> void:
	# PLACEHOLDER: game-over flow, respawn at last checkpoint, etc.
	_end_combat()

func _end_combat() -> void:
	if is_instance_valid(Global.current_combat_zone):
		for member in Global.get_party_alive():
			member.movement_mode = EntityBase.MovementMode.OPEN_WORLD
	Global.clear_enemy_registry()
	Global.set_game_state(Global.GameState.EXPLORATION)
	Global.current_combat_zone = null
	_spawned_enemies.clear()
	_triggered = not repeatable
