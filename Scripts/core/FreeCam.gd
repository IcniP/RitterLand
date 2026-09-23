# File: res://scripts/core/FreeCam.gd
extends Camera2D

@export var target_unit: Node2D          # Target yang diikuti (Lan)
@export var turn_manager: Node           # Referensi ke TurnManager
@export var camera_speed: float = 300.0  # Kecepatan gerak Free Cam (WASD)

@export_group("Combat Camera")
## Zoom used while in combat (smaller = see more of the arena).
@export var combat_zoom: Vector2 = Vector2(3, 3)
## How long the switch between exploration and combat camera takes.
@export var transition_time: float = 0.6

var _exploration_zoom: Vector2
var _transition: Tween = null
var _transitioning: bool = false

func _ready() -> void:
	_exploration_zoom = zoom

func _process(delta: float) -> void:
	if turn_manager == null or _transitioning:
		return

	# 1. EXPLORATION: kamera selalu mengunci & ikuti Lan
	if turn_manager.current_phase == turn_manager.BattlePhase.EXPLORATION:
		if is_instance_valid(target_unit):
			global_position = target_unit.global_position

	# 2. COMBAT (Planning Phase): kamera bisa digerakkan bebas dengan WASD
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

# ---------------- Combat camera ----------------

## Called by TurnManager.enter_combat_mode(): glide to the fight and zoom out.
func enter_combat_camera(focus: Vector2) -> void:
	_start_transition(focus, combat_zoom)

## Called by TurnManager.exit_combat_mode(): glide back to Lan and restore zoom.
func exit_combat_camera() -> void:
	var dest := global_position
	if is_instance_valid(target_unit):
		dest = target_unit.global_position
	_start_transition(dest, _exploration_zoom)

# Kept for old callers.
func reset_to_target() -> void:
	exit_combat_camera()

func _start_transition(dest: Vector2, dest_zoom: Vector2) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_transitioning = true
	_transition = create_tween().set_parallel(true)
	_transition.tween_property(self, "global_position", dest, transition_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self, "zoom", dest_zoom, transition_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.finished.connect(func(): _transitioning = false)
