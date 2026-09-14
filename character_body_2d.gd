extends CharacterBody2D

# Tentukan kecepatan karakter
@export var speed: float = 55.0

# Ambil referensi ke node animasi (sesuaikan namanya jika berbeda di scene kamu)
@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(_delta):
	# 1. Ambil input dari arrow keys / WASD
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("bottom") - Input.get_action_strength("top")
	)
	
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
	
	velocity = input_direction * speed
	move_and_slide()
	
	# 2. Atur Animasi Berdasarkan Pergerakan
	update_animation(input_direction)

func update_animation(direction: Vector2):
	# Jika karakter tidak bergerak, putar animasi Idle
	if direction == Vector2.ZERO:
		animated_sprite.play("Idle")
		return

	# Jika karakter bergerak, tentukan arah dominan (X atau Y)
	if abs(direction.x) > abs(direction.y):
		# Gerakan horizontal lebih dominan
		if direction.x > 0:
			animated_sprite.play("Walkright")
		else:
			animated_sprite.play("WalkLeft")
	else:
		# Gerakan vertikal lebih dominan (atau sama kuat saat miring pas 45 derajat)
		if direction.y > 0:
			animated_sprite.play("WalkDown")
		else:
			animated_sprite.play("Walkup")
