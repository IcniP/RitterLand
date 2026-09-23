# File: res://Scripts/entities/EnemyNPC.gd
# Hostile entity, only active inside a CombatZone. Registers/unregisters
# itself with Global so UI and the CombatManager can always query who's alive.
class_name EnemyNPC
extends EntityBase

@export var enemy_id: String = "enemy"
@export var loot_table: Array[String] = []   # PLACEHOLDER: item ids
@export var ai_aggression: float = 1.0        # 0..1, feed into smarter AI later

func _ready() -> void:
	super._ready()
	movement_mode = MovementMode.GRID_COMBAT
	is_player_controlled = false
	Global.register_enemy(self)
	died.connect(_on_died)

func _on_died(_entity) -> void:
	Global.unregister_enemy(self)
	# PLACEHOLDER: death animation / loot drop, then remove.
	set_physics_process(false)
	call_deferred("queue_free")

## Minimal stub AI — always basic-attacks a random living party member.
## Swap this out for a real decision system (behavior tree, utility AI, etc).
func choose_action(possible_targets: Array) -> CombatAction:
	var action := CombatAction.new()
	action.actor = self
	action.action_type = CombatAction.ActionType.PHYSICAL
	if possible_targets.size() > 0:
		action.target = possible_targets[randi() % possible_targets.size()]
	action.compute_priority()
	return action
