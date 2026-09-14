# File: res://scripts/entities/Unit.gd
extends CharacterBody2D

enum ControlMode { EXPLORATION, COMBAT }
var current_mode: ControlMode = ControlMode.EXPLORATION

# HANYA Karakter Utama (Lan) yang bernilai TRUE di Inspector
@export var is_player_controlled: bool = false

# Stat Karakter sesuai Ritterland GDD
@export var spd: int = 3 # Stat SPD menentukan AP per turn
@export var hp: int = 100
@export var atk: int = 15
@export var def_stat: int = 5
@export var speed: float = 55.0

var facing_direction: Vector2i = Vector2i.DOWN
var is_stunned: bool = false

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	# WASD HANYA aktif jika dalam EXPLORATION Mode DAN karakter ini adalah player utama (Lan)
	if current_mode == ControlMode.EXPLORATION and is_player_controlled:
		handle_exploration_movement()

func handle_exploration_movement() -> void:
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("bottom") - Input.get_action_strength("top")
	)
	
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
	
	velocity = input_direction * speed
	move_and_slide()
	update_animation(input_direction)

# Animasi pergerakan grid otomatis saat eksekusi turn (Execution Phase)
func move_to_grid_target(target_world_pos: Vector2) -> void:
	var move_dir = (target_world_pos - global_position).normalized()
	update_animation(move_dir)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_world_pos, 0.4)
	await tween.finished
	
	update_animation(Vector2.ZERO)

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)

func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		animated_sprite.play("Idle")
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("Walkright")
			facing_direction = Vector2i.RIGHT
		else:
			animated_sprite.play("WalkLeft")
			facing_direction = Vector2i.LEFT
	else:
		if direction.y > 0:
			animated_sprite.play("WalkDown")
			facing_direction = Vector2i.DOWN
		else:
			animated_sprite.play("Walkup")
			facing_direction = Vector2i.UP
