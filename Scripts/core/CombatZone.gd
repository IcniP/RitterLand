# File: res://Scripts/core/CombatZone.gd
# The training ground. An Area2D over the arena on your tilemap.
#
# Combat does NOT start when you walk in. It starts when a Dialogic timeline
# emits the signal "start_training" (the "Training" choice when talking to
# IliaNpc): as soon as that timeline ends, the player is moved into the arena,
# the enemies spawn, the party appears, everyone snaps onto the grid and the
# camera switches to combat mode. When the fight is over the player is moved
# back to where they were standing, and to train again they talk to Ilia again.
class_name CombatZone
extends Area2D

@export var enemy_scenes: Array[PackedScene] = []      # PLACEHOLDER enemy roster for this zone
@export var enemy_spawn_points: Array[NodePath] = []    # optional Marker2D per enemy_scenes entry
@export var combat_manager_path: NodePath
## Optional. Leave empty to auto-find a sibling node named "TurnManager".
@export var turn_manager_path: NodePath

@export_group("Training trigger")
## Dialogic `[signal arg="..."]` value that starts the fight.
@export var training_signal: String = "start_training"
## Optional Marker2D where the player is placed when training starts.
## Empty = lower middle of the arena.
@export var player_spawn_point: NodePath
## Restore the player's HP/SP after the fight (training shouldn't leave scars).
@export var heal_after_combat: bool = true

@export_group("Rewards")
## Bonus XP for clearing this area, on top of each killed enemy's xp_reward.
@export var battle_xp: int = 0

@export_group("Walk-in trigger (old behaviour)")
## If true, walking into the zone also starts combat (no dialogue needed).
@export var auto_trigger: bool = false
## Only for auto_trigger: can the zone trigger again after it resolves?
@export var repeatable: bool = false

var _combat_manager: Node = null
var _spawned_enemies: Array = []
var _active: bool = false
var _used: bool = false
var _training_requested: bool = false
var _kill_xp: int = 0
var _teleported: bool = false
var _return_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if combat_manager_path != NodePath():
		_combat_manager = get_node(combat_manager_path)
	# Dialogic is an autoload; connect if it's there.
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic:
		dialogic.signal_event.connect(_on_dialogic_signal)
		dialogic.timeline_ended.connect(_on_timeline_ended)
	else:
		push_warning("CombatZone: Dialogic autoload not found - training can only start via start_training().")

func _get_turn_manager() -> Node:
	if turn_manager_path != NodePath():
		return get_node_or_null(turn_manager_path)
	return get_parent().get_node_or_null("TurnManager")

# ---------------- Triggers ----------------

func _on_dialogic_signal(argument) -> void:
	if str(argument) == training_signal:
		_training_requested = true   # wait until the dialogue box has closed

func _on_timeline_ended() -> void:
	if _training_requested:
		_training_requested = false
		call_deferred("start_training")

## Start a training fight. Called after the Dialogic "Training" choice, but you
## can also call it from anywhere else.
func start_training() -> void:
	if _active or Global.game_state == Global.GameState.COMBAT:
		return
	if not is_instance_valid(Global.player):
		push_warning("CombatZone: no player found.")
		return
	_start_combat(Global.player)

func _on_body_entered(body: Node) -> void:
	if not auto_trigger or _active or _used:
		return
	if body is EntityBase and body.is_player_controlled:
		call_deferred("_start_combat", body)

# ---------------- Combat lifecycle ----------------

func _start_combat(player: EntityBase) -> void:
	_active = true
	_kill_xp = 0
	Global.current_combat_zone = self
	Global.set_game_state(Global.GameState.COMBAT)

	# Bring the player into the arena (remember where they were).
	var arena := get_arena_rect()
	_teleported = false
	if arena.size != Vector2.ZERO and not arena.has_point(player.global_position):
		_return_position = player.global_position
		_teleported = true
		player.global_position = _get_player_start(arena)

	_spawn_enemies(player)

	# Owned characters (unlocked + in_party) are spawned next to the player now.
	var party: Array = [player]
	if Global.roster:
		party.append_array(Global.roster.spawn_party(player))

	# TurnManager snaps everyone to the grid, flips them to GRID_COMBAT,
	# starts the Planning phase and switches the camera.
	var turn_manager := _get_turn_manager()
	if turn_manager and turn_manager.has_method("enter_combat_mode"):
		turn_manager.enter_combat_mode(party + _spawned_enemies, arena)
	else:
		push_warning("CombatZone: no TurnManager found - combat has no grid/camera.")
		for member in party + _spawned_enemies:
			member.movement_mode = EntityBase.MovementMode.GRID_COMBAT

	if _combat_manager and _combat_manager.has_method("start_combat"):
		_combat_manager.start_combat(party, _spawned_enemies)
	else:
		push_warning("CombatZone: no CombatManager assigned at combat_manager_path.")

func _get_player_start(arena: Rect2) -> Vector2:
	if player_spawn_point != NodePath():
		var marker := get_node_or_null(player_spawn_point)
		if marker:
			return marker.global_position
	return arena.position + Vector2(arena.size.x * 0.5, arena.size.y * 0.8)

## World-space rectangle of this zone's CollisionShape2D. Combat units are
## snapped inside it and can't leave it while fighting.
func get_arena_rect() -> Rect2:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size * child.global_scale.abs()
			return Rect2(child.global_position - size / 2.0, size)
	return Rect2()

func _spawn_enemies(player: EntityBase) -> void:
	# Spawn into the same Y-sort node as the player so depth sorting and the
	# grid's occupancy checks see the enemies. Enemies only exist during the fight.
	var parent: Node = player.get_parent()
	for i in range(enemy_scenes.size()):
		var scene := enemy_scenes[i]
		if scene == null:
			continue
		var enemy = scene.instantiate()
		parent.add_child(enemy)
		if i < enemy_spawn_points.size():
			var spawn_node := get_node_or_null(enemy_spawn_points[i])
			if spawn_node:
				enemy.global_position = spawn_node.global_position
		_spawned_enemies.append(enemy)
		if enemy.has_signal("died"):
			# Count each kill's XP as it happens (dead enemies get freed).
			enemy.died.connect(func(e): _kill_xp += int(e.xp_reward) if "xp_reward" in e else 0)

func resolve_victory() -> void:
	# Everyone who fought (player + party) gets the full XP.
	var ids: Array = []
	if is_instance_valid(Global.player):
		ids.append(Global.player.character_id)
	for m in Global.party:
		if is_instance_valid(m):
			ids.append(m.character_id)
	Global.award_xp(ids, battle_xp + _kill_xp)
	_finish()

func resolve_defeat() -> void:
	# PLACEHOLDER: game-over flow, respawn at last checkpoint, etc.
	_finish()

func _finish() -> void:
	var turn_manager := _get_turn_manager()
	if turn_manager and turn_manager.has_method("exit_combat_mode"):
		turn_manager.exit_combat_mode()  # calls _end_combat() back on us
	else:
		_end_combat()

func _end_combat() -> void:
	if Global.current_combat_zone != self:
		return  # already cleaned up
	Global.current_combat_zone = null
	if Global.roster:
		Global.roster.despawn_party()
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	Global.clear_enemy_registry()
	_spawned_enemies.clear()

	var player = Global.player
	if is_instance_valid(player):
		if _teleported:
			player.global_position = _return_position   # back to Ilia
		if heal_after_combat:
			player.heal(player.max_hp)
			player.sp = player.max_sp
			player.sp_changed.emit(player.sp, player.max_sp)
	_teleported = false

	Global.set_game_state(Global.GameState.EXPLORATION)
	_active = false
	_used = not repeatable
