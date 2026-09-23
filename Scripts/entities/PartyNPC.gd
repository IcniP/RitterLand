# File: res://Scripts/entities/PartyNPC.gd
# Ally that follows the player in the open world once recruited, and joins
# the active roster (max 3, enforced by Global.add_party_member).
class_name PartyNPC
extends EntityBase

@export var npc_id: String = "companion"
@export var follow_distance: float = 24.0
@export var is_recruited: bool = false

var follow_target: Node2D = null

func _ready() -> void:
	super._ready()
	movement_mode = MovementMode.OPEN_WORLD
	is_player_controlled = false

func _physics_process(delta: float) -> void:
	if movement_mode != MovementMode.OPEN_WORLD:
		return
	if is_recruited and is_instance_valid(follow_target):
		_follow_leader()
	elif is_player_controlled:
		_handle_open_world_movement()

func _follow_leader() -> void:
	var to_target: Vector2 = follow_target.global_position - global_position
	if to_target.length() > follow_distance:
		var dir := to_target.normalized()
		velocity = dir * move_speed
		move_and_slide()
		_update_animation(dir)
	else:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)

## Call from an interactable's `interact` Callable to add this NPC to the party.
func recruit(leader: Node2D) -> void:
	if Global.add_party_member(self):
		is_recruited = true
		follow_target = leader
