# File: res://scripts/ui/PlayerInputHandler.gd
extends Node2D

@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"
@onready var highlight_layer: TileMapLayer = $"../Map/HighlightLayer"
@onready var turn_manager: Node = $"../TurnManager"

@export var highlight_source_id: int = 0
@export var green_tile_coords: Vector2i = Vector2i(3, 3)
@export var red_tile_coords: Vector2i = Vector2i(4, 3)

var selected_unit: CharacterBody2D = null
var last_hovered_cell: Vector2i = Vector2i(-999, -999)

func _ready() -> void:
	if turn_manager and turn_manager.y_sort_node:
		for child in turn_manager.y_sort_node.get_children():
			if child is CharacterBody2D and "is_player_controlled" in child and child.is_player_controlled:
				selected_unit = child
				break

func _process(_delta: float) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		update_grid_highlight_set_cell()
	else:
		clear_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		if event is InputEventMouseButton and event.pressed:
			var mouse_world_pos: Vector2 = get_global_mouse_position()
			var clicked_cell: Vector2i = tile_map_layer.local_to_map(mouse_world_pos)
			
			# KLIK KIRI: Pilih Unit / Antre Pergerakan
			if event.button_index == MOUSE_BUTTON_LEFT:
				# 1. Cek Klik pada Unit Kawan (Lan / Ilia) untuk Switch Unit
				for unit in turn_manager.units:
					var unit_cell: Vector2i = tile_map_layer.local_to_map(unit.global_position)
					if unit_cell == clicked_cell:
						selected_unit = unit
						print("Unit dipilih: ", selected_unit.name)
						update_grid_highlight_set_cell(true)
						return
				
				# 2. Antrekan Pergerakan Multi-Tile (1 atau 2 Tile Sekaligus)
				if selected_unit != null:
					queue_multi_tile_move(clicked_cell)
					
			# KLIK KANAN: Cancel Pre-move Terakhir
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if selected_unit != null:
					var success: bool = turn_manager.cancel_last_action(selected_unit)
					if success:
						update_grid_highlight_set_cell(true)

# Menghitung sisa AP (SPD) yang masih bisa digunakan oleh selected_unit
func get_remaining_ap(unit: CharacterBody2D) -> int:
	var used_ap: int = 0
	if turn_manager and turn_manager.global_action_queue:
		for act in turn_manager.global_action_queue:
			if act.actor == unit:
				used_ap += act.execution_cost_ap
	return unit.spd - used_ap

# PERBAIKAN PADA FUNGSI INI (BARIS 53):
# Menemukan titik akhir posisi grid unit berdasarkan antrean global di turn_manager
func get_current_unit_end_cell() -> Vector2i:
	if selected_unit == null:
		return Vector2i.ZERO
		
	var current_cell: Vector2i = tile_map_layer.local_to_map(selected_unit.global_position)
	
	# PERBAIKAN: Gunakan global_action_queue (bukan action_queues)
	if turn_manager and turn_manager.global_action_queue:
		# Cari dari urutan paling belakang (aksi paling baru) yang dimiliki oleh selected_unit
		for i in range(turn_manager.global_action_queue.size() - 1, -1, -1):
			var act: BattleAction = turn_manager.global_action_queue[i]
			if act.actor == selected_unit:
				current_cell = act.target_grid
				break
			
	return current_cell

# Menghitung jalur langkah per-tile (Manhattan Path)
func get_step_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var curr: Vector2i = start_cell
	
	while curr != target_cell:
		var diff: Vector2i = target_cell - curr
		if abs(diff.x) >= abs(diff.y):
			curr.x += 1 if diff.x > 0 else -1
		else:
			curr.y += 1 if diff.y > 0 else -1
		path.append(curr)
	return path

# Memvalidasi pergerakan multi-tile
func is_valid_move_cell(target_cell: Vector2i) -> bool:
	if selected_unit == null:
		return false
		
	var start_cell: Vector2i = get_current_unit_end_cell()
	var path: Array[Vector2i] = get_step_path(start_cell, target_cell)
	var distance: int = path.size()
	
	# Jarak tile harus > 0 dan <= sisa AP yang dimiliki
	var rem_ap: int = get_remaining_ap(selected_unit)
	if distance == 0 or distance > rem_ap:
		return false
		
	# Pastikan seluruh jalur yang dilalui tidak menabrak obstacle / unit lain
	for cell in path:
		if turn_manager.has_method("is_cell_occupied") and turn_manager.is_cell_occupied(cell, selected_unit):
			return false
			
	return true

# Memasukkan aksi gerakan per-tile ke antrean TurnManager
func queue_multi_tile_move(target_cell: Vector2i) -> void:
	if not is_valid_move_cell(target_cell):
		print("Target tile tidak valid atau AP tidak cukup!")
		return
		
	var start_cell: Vector2i = get_current_unit_end_cell()
	var path: Array[Vector2i] = get_step_path(start_cell, target_cell)
	
	for step_cell in path:
		var new_action = BattleAction.new()
		new_action.action_type = BattleAction.Type.MOVE
		new_action.actor = selected_unit
		new_action.target_grid = step_cell
		new_action.execution_cost_ap = 1
		
		turn_manager.queue_action(selected_unit, new_action)
		
	print("Berhasil mengantre ", path.size(), " langkah sekaligus ke cell: ", target_cell)
	update_grid_highlight_set_cell(true)

func update_grid_highlight_set_cell(force_update: bool = false) -> void:
	if highlight_layer == null or tile_map_layer == null or selected_unit == null:
		return
		
	var mouse_world_pos: Vector2 = get_global_mouse_position()
	var current_hover_cell: Vector2i = tile_map_layer.local_to_map(mouse_world_pos)
	
	if current_hover_cell != last_hovered_cell or force_update:
		if last_hovered_cell != Vector2i(-999, -999):
			highlight_layer.set_cell(last_hovered_cell, -1)
			
		last_hovered_cell = current_hover_cell
		var is_valid: bool = is_valid_move_cell(current_hover_cell)
		var target_coords: Vector2i = green_tile_coords if is_valid else red_tile_coords
		
		highlight_layer.set_cell(current_hover_cell, highlight_source_id, target_coords)

func clear_highlight() -> void:
	if highlight_layer and last_hovered_cell != Vector2i(-999, -999):
		highlight_layer.set_cell(last_hovered_cell, -1)
		last_hovered_cell = Vector2i(-999, -999)
