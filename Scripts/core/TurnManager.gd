# File: res://scripts/core/TurnManager.gd
extends Node

@onready var y_sort_node: Node2D = $"../Y-sort"
@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"

enum BattlePhase { EXPLORATION, PLANNING, EXECUTION }
var current_phase: BattlePhase = BattlePhase.EXPLORATION

var units: Array[Node2D] = []
var action_queues: Dictionary = {}

func _ready() -> void:
	if y_sort_node == null or tile_map_layer == null:
		push_error("TurnManager ERROR: y_sort_node atau tile_map_layer belum di-assign di Inspector!")
		return
	register_units()

func register_units() -> void:
	units.clear()
	for child in y_sort_node.get_children():
		if child is CharacterBody2D:
			units.append(child)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Tekan Tombol 'R' untuk Toggle Masuk/Keluar Combat Mode
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle_combat_mode()

	# 2. Tekan Spacebar saat PLANNING PHASE untuk memulai eksekusi
	elif current_phase == BattlePhase.PLANNING and event.is_action_pressed("ui_accept"):
		start_execution_phase()

func toggle_combat_mode() -> void:
	if current_phase == BattlePhase.EXPLORATION:
		enter_combat_mode()
	else:
		exit_combat_mode()

func enter_combat_mode() -> void:
	current_phase = BattlePhase.PLANNING
	print("--- COMBAT MODE STARTED (PLANNING PHASE) ---")
	print("Tekan Klik Kiri pada petak grid untuk Pre-Move, Spacebar untuk Eksekusi, atau R untuk Keluar.")
	
	register_units()
	# Ubah mode seluruh unit ke COMBAT & kunci posisinya persis di tengah (center) cell grid
	for unit in units:
		if "current_mode" in unit:
			unit.current_mode = unit.ControlMode.COMBAT
		var current_cell: Vector2i = tile_map_layer.local_to_map(unit.global_position)
		unit.global_position = tile_map_layer.map_to_local(current_cell)

func exit_combat_mode() -> void:
	current_phase = BattlePhase.EXPLORATION
	action_queues.clear()
	print("--- EXIT COMBAT MODE (EXPLORATION MODE / WASD ACTIVE) ---")
	
	# Kembalikan mode seluruh unit ke EXPLORATION (WASD Bebas)
	for unit in units:
		if "current_mode" in unit:
			unit.current_mode = unit.ControlMode.EXPLORATION

# --- Sisa Logika Antrean & Eksekusi ---

func is_cell_occupied(target_cell: Vector2i, checking_unit: Node2D) -> bool:
	for unit in units:
		if unit == checking_unit or not is_instance_valid(unit):
			continue
		var unit_cell: Vector2i = tile_map_layer.local_to_map(unit.global_position)
		if unit_cell == target_cell:
			return true
	return false

func queue_action(unit: Node2D, action: BattleAction) -> bool:
	if current_phase != BattlePhase.PLANNING:
		return false
	
	if not action_queues.has(unit):
		action_queues[unit] = []
	
	var max_ap: int = unit.spd
	var current_ap_used: int = 0
	for act in action_queues[unit]:
		current_ap_used += act.execution_cost_ap
		
	if current_ap_used + action.execution_cost_ap <= max_ap:
		action_queues[unit].append(action)
		return true
	return false

func start_execution_phase() -> void:
	current_phase = BattlePhase.EXECUTION
	print("--- EXECUTION PHASE ---")
	execute_simultaneous_turns()

func execute_simultaneous_turns() -> void:
	var step: int = 0
	var has_actions_left: bool = true
	
	while has_actions_left:
		has_actions_left = false
		var current_step_actions: Array[BattleAction] = []
		
		for unit in units:
			if action_queues.has(unit) and step < action_queues[unit].size():
				current_step_actions.append(action_queues[unit][step])
				has_actions_left = true
		
		if has_actions_left:
			await process_step_actions(current_step_actions)
			step += 1
	
	action_queues.clear()
	current_phase = BattlePhase.PLANNING
	print("--- PLANNING PHASE ACTIVE ---")

func process_step_actions(step_actions: Array[BattleAction]) -> void:
	for action in step_actions:
		if action.action_type == BattleAction.Type.MOVE:
			var target_world_pos: Vector2 = tile_map_layer.map_to_local(action.target_grid)
			await action.actor.move_to_grid_target(target_world_pos)
			
	await get_tree().create_timer(0.2).timeout
