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

## Key into Global.progress. "" = no progression (enemies). Lan becomes
## "player" automatically; PartyRoster sets it for party members.
var character_id: String = ""
## Current weapon (only Lan swaps; "" = fixed weapon). Set lazily by SkillDB.weapon_of().
var weapon: String = ""
var level: int = 1
var _base_stats: Dictionary = {}

var facing_direction: Vector2i = Vector2i.DOWN

## Each entry: {"effect": StatusEffect, "turns_left": int}
var active_effects: Array[Dictionary] = []

signal died(entity)
signal hp_changed(new_hp, max_hp)
signal sp_changed(new_sp, max_sp)
signal charge_changed(new_charge)

func _ready() -> void:
	_base_stats = {"max_hp": max_hp, "max_sp": max_sp, "atk": atk, "def_stat": def_stat, "spd": spd}
	if is_player_controlled and character_id == "":
		character_id = "player"
	hp = max_hp
	sp = max_sp
	if character_id != "":
		refresh_stats(true)
	if is_player_controlled:
		Global.player = self

func _physics_process(_delta: float) -> void:
	if movement_mode == MovementMode.OPEN_WORLD and is_player_controlled:
		_handle_open_world_movement()

# ---------------- Skills ----------------

## The (max 4) skills equipped for battle.
func get_battle_skills() -> Array:
	return SkillDB.get_loadout(character_id, SkillDB.weapon_of(self))

func get_ultimate_skill() -> SkillData:
	if character_id == "":
		return null
	return SkillDB.get_ultimate(character_id, level)

# ---------------- Level / equipment stats ----------------

func get_base_stats() -> Dictionary:
	return _base_stats.duplicate()

## Recompute max_hp/max_sp/atk/def/spd from base + level + points + gear.
func refresh_stats(heal_to_full: bool = false) -> void:
	if character_id == "" or _base_stats.is_empty():
		return
	var prog: CharacterProgress = Global.get_progress(character_id)
	var s: Dictionary = Progression.compute_stats(_base_stats, prog)
	var hp_gain: int = s["max_hp"] - max_hp
	var sp_gain: int = s["max_sp"] - max_sp
	max_hp = s["max_hp"]
	max_sp = s["max_sp"]
	atk = s["atk"]
	def_stat = s["def_stat"]
	spd = s["spd"]
	level = prog.level
	if heal_to_full:
		hp = max_hp
		sp = max_sp
	else:
		hp = clampi(hp + maxi(hp_gain, 0), mini(hp, max_hp), max_hp)
		sp = clampi(sp + maxi(sp_gain, 0), mini(sp, max_sp), max_sp)
	hp_changed.emit(hp, max_hp)
	sp_changed.emit(sp, max_sp)

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

## Called when combat starts so nobody is frozen mid-walk-animation.
func stop_moving() -> void:
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)

## Used by CombatManager/PlayerInputHandler to animate a queued grid step.
func move_to_grid_target(target_world_pos: Vector2) -> void:
	var dir: Vector2 = (target_world_pos - global_position).normalized()
	_update_animation(dir)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_world_pos, 0.4)
	await tween.finished
	_update_animation(Vector2.ZERO)

## Bumped every time play_attack() runs, so an older/stale call can never
## overwrite the animation set by a newer one after it wakes up from its await.
var _attack_token: int = 0

## Plays "Attack<Dir>" once (if the sprite has it) and returns after it finishes.
## Falls back to just facing the target when no attack animation exists yet.
func play_attack(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing_direction = Vector2i.RIGHT if dir.x > 0 else Vector2i.LEFT
		else:
			facing_direction = Vector2i.DOWN if dir.y > 0 else Vector2i.UP
	if animated_sprite == null:
		return
	var suffix := _direction_suffix()   # captured now so it can't drift while we await below
	var anim := "Attack" + suffix
	var frames := animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		print("play_attack: NO '%s' animation on %s -- skipping" % [anim, name])
		return   # this character has no attack sprite yet -> just keep the current pose
	_attack_token += 1
	var my_token := _attack_token
	# Wait by duration instead of the animation_finished signal: Godot's AnimatedSprite2D
	# doesn't reliably re-fire/restart when play() is called with a name that was already
	# set (e.g. attacking the same direction twice in a row), which left this stuck on the
	# last frame. Forcing frame 0 + timing it out ourselves works no matter what.
	frames.set_animation_loop(anim, false)
	var fps: float = frames.get_animation_speed(anim)
	var duration: float = (frames.get_frame_count(anim) / fps) if fps > 0.0 else 0.3
	print("play_attack: playing '%s' for %.2fs on %s" % [anim, duration, name])
	animated_sprite.play(anim)
	animated_sprite.frame = 0
	await get_tree().create_timer(duration).timeout
	print("play_attack: timer done for '%s' on %s (still current token: %s)" % [anim, name, my_token == _attack_token])
	if is_instance_valid(animated_sprite) and my_token == _attack_token:
		var idle_anim := "Idle" + suffix
		if frames.has_animation(idle_anim):
			animated_sprite.play(idle_anim)   # same direction as the attack just played
			print("play_attack: switched to %s on %s (frame=%s, playing=%s, visible=%s)" \
				% [idle_anim, name, animated_sprite.frame, animated_sprite.is_playing(), animated_sprite.visible])
		else:
			push_warning("play_attack: no '%s' animation to switch back to on %s!" % [idle_anim, name])

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
	# Re-applying the same effect refreshes its duration instead of stacking.
	for entry in active_effects:
		if entry["effect"].id == effect.id:
			entry["turns_left"] = effect.duration_turns
			return
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

## pierce = fraction of DEF ignored (0..1), used by magic skills.
func take_damage(amount: int, _attacker = null, pierce: float = 0.0) -> void:
	var effective_def := int(get_effective_stat(StatusEffect.StatType.DEF) * (1.0 - pierce))
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
	# Characters with progression: change the base and recompute everything.
	if character_id != "" and _base_stats.has(stat_name):
		_base_stats[stat_name] += amount
		refresh_stats()
		return
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
