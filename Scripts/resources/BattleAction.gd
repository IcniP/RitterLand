# File: res://scripts/resources/BattleAction.gd
class_name BattleAction
extends Resource

enum Type { MOVE, ATTACK_MELEE, ATTACK_PROJECTILE, USE_ITEM, STUNNED }

@export var action_type: Type = Type.MOVE
var actor: Node2D
@export var target_grid: Vector2i
var target_unit: Node2D = null
@export var execution_cost_ap: int = 1
