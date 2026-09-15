# File: res://scripts/core/FreeCam.gd
extends Camera2D

@export var target_unit: Node2D          # Target yang diikuti (Lan)
@export var turn_manager: Node           # Referensi ke TurnManager
@export var camera_speed: float = 300.0  # Kecepatan gerak Free Cam (WASD)

func _process(delta: float) -> void:
	if turn_manager == null:
		return

	# 1. Saat EXPLORATION MODE (Di luar battle): Kamera selalu mengunci & ikuti Lan
	if turn_manager.current_phase == turn_manager.BattlePhase.EXPLORATION:
		if is_instance_valid(target_unit):
			global_position = target_unit.global_position

	# 2. Saat COMBAT MODE (Planning Phase): Kamera bisa digerakkan bebas dengan WASD
	elif turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		handle_free_cam_movement(delta)

func handle_free_cam_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
		
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		global_position += input_dir * camera_speed * delta

# Dipanggil saat keluar dari Combat Mode agar kamera smooth bergeser kembali ke Lan
func reset_to_target() -> void:
	if is_instance_valid(target_unit):
		var tween = create_tween()
		tween.tween_property(self, "global_position", target_unit.global_position, 0.3).set_trans(Tween.TRANS_SINE)
