# File: res://Scripts/entities/PartyNPC.gd
# An owned party character. It does not exist in the open world: PartyRoster
# spawns it when a fight starts (if unlocked + in_party) and frees it afterwards.
class_name PartyNPC
extends EntityBase

@export var npc_id: String = "companion"

@onready var interactable: Area2D = get_node_or_null("Interactable")

func _ready() -> void:
	super._ready()
	movement_mode = MovementMode.OPEN_WORLD
	is_player_controlled = false
	# Leftover from the old "Recruit" NPC scene: nothing to interact with now.
	if interactable:
		interactable.set_deferred("monitorable", false)
