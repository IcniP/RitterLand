# File: res://scripts/ui/PlayerInputHandler.gd
extends Node2D

@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"
@onready var highlight_layer: TileMapLayer = $"../Map/HighlightLayer"
@onready var turn_manager: Node = $"../TurnManager"
@onready var player_unit: CharacterBody2D = $"../Y-sort/Ilia"

# Pengaturan ID Tile di TileSet milik highlight_layer
@export var highlight_source_id: int = 0
@export var green_tile_coords: Vector2i = Vector2i(3, 3) # Coords tile hijau di atlas
@export var red_tile_coords: Vector2i = Vector2i(4, 3)   # Coords tile merah di atlas

var last_hovered_cell: Vector2i = Vector2i(-999, -999)

func _process(_delta: float) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		update_grid_highlight_set_cell()
	else:
		clear_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world_pos: Vector2 = get_global_mouse_position()
			var clicked_cell: Vector2i = tile_map_layer.local_to_map(mouse_world_pos)
			
			# Cek apakah petak valid (1 tile di sebelah & kosong)
			if is_valid_move_cell(clicked_cell):
				var new_action = BattleAction.new()
				new_action.action_type = BattleAction.Type.MOVE
				new_action.actor = player_unit
				new_action.target_grid = clicked_cell
				new_action.execution_cost_ap = 1
				
				var success: bool = turn_manager.queue_action(player_unit, new_action)
				if success:
					print("Pre-move Lan ditambahkan ke cell: ", clicked_cell)
					# Update ulang highlight setelah pergerakan berhasil diantrekan
					update_grid_highlight_set_cell(true)
				else:
					print("AP (SPD) Lan sudah penuh!")

# Menggambar highlight menggunakan set_cell() pada HighlightLayer
func update_grid_highlight_set_cell(force_update: bool = false) -> void:
	if highlight_layer == null or tile_map_layer == null or player_unit == null:
		return
		
	var mouse_world_pos: Vector2 = get_global_mouse_position()
	var current_hover_cell: Vector2i = tile_map_layer.local_to_map(mouse_world_pos)
	
	# Hanya render ulang jika kursor berpindah sel (menghemat kinerja)
	if current_hover_cell != last_hovered_cell or force_update:
		# Hapus tile highlight lama pada posisi sebelumnya
		if last_hovered_cell != Vector2i(-999, -999):
			highlight_layer.set_cell(last_hovered_cell, -1)
			
		last_hovered_cell = current_hover_cell
		
		# Tentukan apakah petak valid untuk dijangkau
		var is_valid: bool = is_valid_move_cell(current_hover_cell)
		var target_coords: Vector2i = green_tile_coords if is_valid else red_tile_coords
		
		# Panggil set_cell() untuk menampilkan tile hijau atau merah di grid target
		highlight_layer.set_cell(current_hover_cell, highlight_source_id, target_coords)

# Bersihkan seluruh tile highlight pada layer
func clear_highlight() -> void:
	if highlight_layer and last_hovered_cell != Vector2i(-999, -999):
		highlight_layer.set_cell(last_hovered_cell, -1)
		last_hovered_cell = Vector2i(-999, -999)

# Menghitung titik akhir pergerakan Lan dari antrean pre-move yang sudah dimasukkan
func get_current_unit_end_cell() -> Vector2i:
	var current_cell: Vector2i = tile_map_layer.local_to_map(player_unit.global_position)
	if turn_manager.action_queues.has(player_unit):
		var queues: Array = turn_manager.action_queues[player_unit]
		if not queues.is_empty():
			var last_action: BattleAction = queues.back()
			current_cell = last_action.target_grid
	return current_cell

# Logika validasi 1 tile (Harus tepat 1 langkah di sebelah Atas/Bawah/Kiri/Kanan)
func is_valid_move_cell(target_cell: Vector2i) -> bool:
	var current_cell: Vector2i = get_current_unit_end_cell()
	
	# 1. Cek jarak Manhattan (x + y harus persis 1 tile)
	var diff: Vector2i = (target_cell - current_cell).abs()
	var is_adjacent: bool = (diff.x + diff.y == 1)
	if not is_adjacent:
		return false
		
	# 2. Cek jika petak sedang ditempati unit lain
	if turn_manager.has_method("is_cell_occupied") and turn_manager.is_cell_occupied(target_cell, player_unit):
		return false
		
	return true
