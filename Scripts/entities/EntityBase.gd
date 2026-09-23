# File: res://Scripts/entities/EntityBase.gd
# Shared base for anything that has combat stats and can act: the player,
# PartyNPCs, and EnemyNPCs. StaticNPCs also extend this for a uniform
# interaction API, even though they never enter combat.
#
# This supersedes Scripts/entities/Unit.gd — migrate existing scenes
# (lan.tscn, Ilia.tscn) to this script when convenient; the movement API
# (move_to_grid_target, _physics_process handling) is intentionally kept
# compatible with Unit.gd so the swap is mostly a script re-point.
class_name EntityBase
extends CharacterBody2D

enum MovementMode { OPEN_WORLD, GRID_COMBAT }
var movement_mode: MovementMode = MovementMode.OPEN_WORLD

@export_group("Core Stats")
@export var max_hp: int = 100
@export var def_stat: int = 5
@export var max_sp: int = 50
@export var spd: int = 3
@export var atk: int = 15

var hp: int
var sp: int
var charge_bar: float = 0.0
const CHARGE_MAX := 100.0

@export_group("Movement")
@export var move_speed: float = 55.0
@export var is_player_controlled: bool = false

@export_group("Visuals (placeholder)")
@export var animated_sprite: AnimatedSprite2D
@export var portrait_icon: Texture2D  # PLACEHOLDER: UI portrait / turn-order icon

var facing_direction: Vector2i = Vector2i.DOWN

## Each entry: {"effect": StatusEffect, "turns_left": int}
var active_effects: Array[Dictionary] = []

signal died(entity)
signal hp_changed(new_hp, max_hp)
signal sp_changed(new_sp, max_sp)
signal charge_changed(new_charge)

func _ready() -> void:
	hp = max_hp
	sp = max_sp

func _physics_process(_delta: float) -> void:
	if movement_mode == MovementMode.OPEN_WORLD and is_player_controlled:
		_handle_open_world_movement()

# ---------------- Movement ----------------

func _handle_open_world_movement() -> void:
	var dir := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("bottom") - Input.get_action_strength("top")
	)
	if dir.length() > 0:
		dir = dir.normalized()
	velocity = dir * move_speed
	move_and_slide()
	_update_animation(dir)

## Used by CombatManager/PlayerInputHandler to animate a queued grid step.
func move_to_grid_target(target_world_pos: Vector2) -> void:
	var dir: Vector2 = (target_world_pos - global_position).normalized()
	_update_animation(dir)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_world_pos, 0.4)
	await tween.finished
	_update_animation(Vector2.ZERO)

func _update_animation(direction: Vector2) -> void:
	# PLACEHOLDER: replace with real AnimatedSprite2D / AnimationTree logic.
	if animated_sprite == null:
		return
	if direction == Vector2.ZERO:
		animated_sprite.play("Idle" + _direction_suffix())
		return
	if abs(direction.x) > abs(direction.y):
		facing_direction = Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
	else:
		facing_direction = Vector2i.DOWN if direction.y > 0 else Vector2i.UP
	animated_sprite.play("Walk" + _direction_suffix())

func _direction_suffix() -> String:
	match facing_direction:
		Vector2i.RIGHT: return "Right"
		Vector2i.LEFT: return "Left"
		Vector2i.UP: return "Up"
		_: return "Down"

# ---------------- Buffs / Debuffs ----------------

func apply_status_effect(effect: StatusEffect) -> void:
	active_effects.append({"effect": effect, "turns_left": effect.duration_turns})

## Call once per combat turn (CombatManager._end_turn) to age out effects.
func tick_status_effects() -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		active_effects[i]["turns_left"] -= 1
		if active_effects[i]["turns_left"] <= 0:
			active_effects.remove_at(i)

## Base stat + any active buffs/debuffs affecting it.
func get_effective_stat(stat: StatusEffect.StatType) -> int:
	var base_value := 0
	match stat:
		StatusEffect.StatType.ATK: base_value = atk
		StatusEffect.StatType.DEF: base_value = def_stat
		StatusEffect.StatType.SPD: base_value = spd
		StatusEffect.StatType.SP: base_value = max_sp
		StatusEffect.StatType.HP: base_value = max_hp
	var modifier := 0
	for entry in active_effects:
		var effect: StatusEffect = entry["effect"]
		if effect.stat_affected == stat:
			modifier += effect.amount
	return max(base_value + modifier, 0)

# ---------------- Combat resource management ----------------

func take_damage(amount: int, _attacker = null) -> void:
	var effective_def := get_effective_stat(StatusEffect.StatType.DEF)
	var final_damage: int = max(amount - effective_def, 1)
	hp = max(0, hp - final_damage)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		die()

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

func spend_sp(amount: int) -> bool:
	if sp < amount:
		return false
	sp -= amount
	sp_changed.emit(sp, max_sp)
	return true

func gain_charge(amount: float) -> void:
	charge_bar = min(CHARGE_MAX, charge_bar + amount)
	charge_changed.emit(charge_bar)

func can_ultimate() -> bool:
	return charge_bar >= CHARGE_MAX

func consume_charge() -> void:
	charge_bar = 0.0
	charge_changed.emit(charge_bar)

func die() -> void:
	died.emit(self)
	# PLACEHOLDER: play death animation, disable collision, drop loot, etc.

func is_alive() -> bool:
	return hp > 0

## Generic hook for Global.modify_stat — permanent changes (leveling, gear).
func modify_stat(stat_name: String, amount: int) -> void:
	match stat_name:
		"max_hp":
			max_hp += amount
			hp = min(hp, max_hp)
		"def_stat": def_stat += amount
		"max_sp":
			max_sp += amount
			sp = min(sp, max_sp)
		"spd": spd += amount
		"atk": atk += amount
		_: push_warning("EntityBase: unknown stat '%s'" % stat_name)
