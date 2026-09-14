# File: res://scripts/scenes/BattleTest.gd
extends Node2D

@onready var turn_manager: Node = $TurnManager
@onready var tile_map_layer: TileMapLayer = $Map/TileMapLayer
@onready var y_sort_node: Node2D = $"Y-sort"

func _ready() -> void:
	# 1. Jalankan setup posisi awal unit ke grid TileMapLayer
	setup_battlefield()
	
	# 2. Trigger langsung pertarungan untuk keperluan testing!
	start_battle()

func setup_battlefield() -> void:
	# Menyelaraskan posisi visual setiap unit ke petak grid terdekat
	for unit in y_sort_node.get_children():
		if unit is CharacterBody2D:
			var current_grid_pos: Vector2i = tile_map_layer.local_to_map(unit.global_position)
			unit.global_position = tile_map_layer.map_to_local(current_grid_pos)

func start_battle() -> void:
	print("--- COMBAT STARTED ---")
	
	# Ubah mode seluruh unit ke COMBAT (menghentikan input WASD bebas)
	for unit in y_sort_node.get_children():
		if unit is CharacterBody2D:
			unit.current_mode = unit.ControlMode.COMBAT
	
	# Daftarkan seluruh unit dan mulai Planning Phase di TurnManager
	turn_manager.units.clear()
	for unit in y_sort_node.get_children():
		if unit is CharacterBody2D:
			turn_manager.units.append(unit)
			
	turn_manager.current_phase = turn_manager.BattlePhase.PLANNING
	print("Planning Phase Active: Klik petak grid untuk mengantre pergerakan, lalu tekan SPACEBAR untuk mengeksekusi!")
