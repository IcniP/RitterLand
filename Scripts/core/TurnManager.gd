# File: res://scripts/core/TurnManager.gd
extends Node

@onready var y_sort_node: Node2D = $"../Y-sort"
@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"
@onready var main_camera: Camera2D = $"../MainCamera"

enum BattlePhase { EXPLORATION, PLANNING, EXECUTION }
var current_phase: BattlePhase = BattlePhase.EXPLORATION

var units: Array[Node2D] = []

# UBAH: Gunakan Array global tunggal untuk menampung seluruh urutan Pre-Move
var global_action_queue: Array[BattleAction] = [] 

# Penampung hitungan AP sementara per unit selama Planning Phase
var unit_ap_used: Dictionary = {} 

func _ready() -> void:
	if y_sort_node == null or tile_map_layer == null:
		push_error("TurnManager ERROR: y_sort_node atau tile_map_layer belum terhubung!")
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle_combat_mode()
	elif current_phase == BattlePhase.PLANNING and event.is_action_pressed("ui_accept"): # Spacebar
		start_execution_phase()

func toggle_combat_mode() -> void:
	if current_phase == BattlePhase.EXPLORATION:
		enter_combat_mode()
	else:
		exit_combat_mode()

func enter_combat_mode() -> void:
	current_phase = BattlePhase.PLANNING
	units.clear()
	global_action_queue.clear()
	unit_ap_used.clear()
	
	for child in y_sort_node.get_children():
		if child is CharacterBody2D and "current_mode" in child:
			units.append(child)
			unit_ap_used[child] = 0
			child.current_mode = child.ControlMode.COMBAT
			var current_cell: Vector2i = tile_map_layer.local_to_map(child.global_position)
			child.global_position = tile_map_layer.map_to_local(current_cell)



func exit_combat_mode() -> void:
	current_phase = BattlePhase.EXPLORATION
	global_action_queue.clear()
	print("--- EXIT COMBAT MODE ---")
	
	for unit in units:
		if "current_mode" in unit:
			unit.current_mode = unit.ControlMode.EXPLORATION
	units.clear()
	
	# Panggil reset kamera kembali ke Lan!
	if main_camera and main_camera.has_method("reset_to_target"):
		main_camera.reset_to_target()

func is_cell_occupied(target_cell: Vector2i, checking_unit: Node2D) -> bool:
	for child in y_sort_node.get_children():
		if child == checking_unit or not (child is CharacterBody2D):
			continue
		var unit_cell: Vector2i = tile_map_layer.local_to_map(child.global_position)
		if unit_cell == target_cell:
			return true
	return false

# 1. Menambahkan Aksi ke Antrean Global (Urutan Klik)
func queue_action(unit: Node2D, action: BattleAction) -> bool:
	if current_phase != BattlePhase.PLANNING:
		return false
	
	if not unit_ap_used.has(unit):
		unit_ap_used[unit] = 0
	
	var max_ap: int = unit.spd
	var current_ap: int = unit_ap_used[unit]
		
	if current_ap + action.execution_cost_ap <= max_ap:
		unit_ap_used[unit] += action.execution_cost_ap
		global_action_queue.append(action) # Dimasukkan ke antrean paling belakang
		return true
	return false

# 2. Cancel Aksi Terakhir Milik Unit yang Dipilih
func cancel_last_action(unit: Node2D) -> bool:
	if current_phase != BattlePhase.PLANNING:
		return false
		
	# Cari dari urutan paling belakang (terbaru) aksi milik unit ini
	for i in range(global_action_queue.size() - 1, -1, -1):
		if global_action_queue[i].actor == unit:
			var popped: BattleAction = global_action_queue[i]
			global_action_queue.remove_at(i)
			unit_ap_used[unit] -= popped.execution_cost_ap
			print("Pre-move terakhir ", unit.name, " dibatalkan!")
			return true
	return false

func start_execution_phase() -> void:
	current_phase = BattlePhase.EXECUTION
	execute_global_sequence()

# 3. Eksekusi Berurutan Sesuai Urutan Pre-Move (FIFO)
func execute_global_sequence() -> void:
	while not global_action_queue.is_empty():
		# Ambil perintah paling depan (pertama kali diklik)
		var current_action: BattleAction = global_action_queue.pop_front()
		await process_single_action(current_action)
	
	# Selesai eksekusi, reset antrean dan kembalikan ke Planning Phase
	global_action_queue.clear()
	unit_ap_used.clear()
	for unit in units:
		unit_ap_used[unit] = 0
		
	current_phase = BattlePhase.PLANNING
	print("--- PLANNING PHASE ACTIVE ---")

func process_single_action(action: BattleAction) -> void:
	if action.action_type == BattleAction.Type.MOVE:
		var target_cell: Vector2i = action.target_grid
		
		# Cek jika petak target saat ini sudah terisi oleh unit lain
		if is_cell_occupied(target_cell, action.actor):
			print("TABRAKAN! Cell ", target_cell, " terisi. Gerakan ", action.actor.name, " dibatalkan!")
			# Hapus sisa antrean gerakan milik unit yang menabrak ini dari global queue
			clear_remaining_actions_for_unit(action.actor)
			return
		
		# Jalankan pergerakan ke tile
		var target_world_pos: Vector2 = tile_map_layer.map_to_local(target_cell)
		await action.actor.move_to_grid_target(target_world_pos)
		
	await get_tree().create_timer(0.1).timeout

# Menghapus sisa antrean unit jika menabrak di tengah jalan
func clear_remaining_actions_for_unit(unit: Node2D) -> void:
	var i: int = global_action_queue.size() - 1
	while i >= 0:
		if global_action_queue[i].actor == unit:
			global_action_queue.remove_at(i)
		i -= 1
