# File: res://scripts/resources/BattleAction.gd
class_name BattleAction
extends Resource

enum Type { MOVE, ATTACK_MELEE, ATTACK_PROJECTILE, USE_ITEM, STUNNED, SKILL }

@export var action_type: Type = Type.MOVE
var actor: Node2D
@export var target_grid: Vector2i
var target_unit: Node2D = null
@export var execution_cost_ap: int = 1

# --- SKILL actions ---
var skill: SkillData = null
## SINGLE/AREA: the tile that was targeted (the caster's tile for self-centred areas).
var skill_target_cell: Vector2i = Vector2i.ZERO
## PROJECTILE: which way it flies (Vector2i.LEFT / RIGHT / UP / DOWN).
var skill_direction: Vector2i = Vector2i.ZERO
