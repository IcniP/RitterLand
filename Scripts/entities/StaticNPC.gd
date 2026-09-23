# File: res://Scripts/entities/StaticNPC.gd
# Stationary NPC that opens a Dialogic timeline on interact. Expects a child
# node named "Interactable" (instance of res://Interaction/interactable.tscn),
# same pattern already used by Ilia.tscn / lan.tscn.
class_name StaticNPC
extends EntityBase

@export var dialogue_timeline: String = ""  # e.g. "res://Dialog/timeline.dtl"
@export var interact_prompt: String = "Talk"

@onready var interactable: Area2D = $Interactable

func _ready() -> void:
	super._ready()
	movement_mode = MovementMode.OPEN_WORLD
	is_player_controlled = false
	if interactable:
		interactable.interact_name = interact_prompt
		interactable.interact = _on_interact

func _on_interact() -> void:
	if dialogue_timeline != "":
		Dialogic.start(dialogue_timeline)
	else:
		push_warning("StaticNPC '%s' has no dialogue_timeline assigned." % name)
