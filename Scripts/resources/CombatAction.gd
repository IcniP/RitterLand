# File: res://Scripts/resources/CombatAction.gd
# Queued during the Planning phase, resolved during the Execution phase.
# This is the simultaneous-combat counterpart to the project's existing
# Scripts/resources/BattleAction.gd (which is movement-only/FIFO).
class_name CombatAction
extends Resource

enum ActionType { MOVE, PHYSICAL, PHYSICAL_SKILL, MAGIC, ULTIMATE }

@export var action_type: ActionType = ActionType.PHYSICAL
@export var skill_id: String = ""          # PLACEHOLDER: lookup key into a future SkillDatabase
@export var target_grid: Vector2i
@export var sp_cost: int = 0
@export var power_multiplier: float = 1.0

var actor            # EntityBase — the character/enemy performing the action
var target            # EntityBase — single target (extend to Array for AoE later)

## Snapshot of the actor's SPD at the moment the turn begins.
## Higher priority resolves first (see CombatManager._resolve_actions).
var priority: int = 0

func compute_priority() -> void:
	priority = actor.spd if is_instance_valid(actor) else 0
