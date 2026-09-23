# File: res://Scripts/core/CombatManager.gd
# Drives the Planning -> Execution loop for a single battle. Where the
# project's existing TurnManager.gd resolves queued moves strictly FIFO,
# this resolves ALL queued actions (party + enemies) by SPD priority each
# turn, giving the "simultaneous" clash-resolution feel: higher SPD acts
# first, and an actor who dies before their turn has their action cancelled.
class_name CombatManager
extends Node

enum CombatPhase { PLANNING, EXECUTION, RESOLVED }
var phase: CombatPhase = CombatPhase.PLANNING

var party: Array = []
var enemies: Array = []
var queued_actions: Array[CombatAction] = []

signal combat_started
signal planning_started
signal execution_started
signal action_resolved(action)
signal combat_ended(victory)

func start_combat(p_party: Array, p_enemies: Array) -> void:
	party = p_party
	enemies = p_enemies
	queued_actions.clear()
	phase = CombatPhase.PLANNING
	combat_started.emit()
	planning_started.emit()

## Called by PlayerInputHandler / a combat UI once per queued action.
## Handles SP/Charge cost up front so an invalid action never gets queued.
func queue_player_action(action: CombatAction) -> bool:
	if phase != CombatPhase.PLANNING:
		return false

	match action.action_type:
		CombatAction.ActionType.PHYSICAL_SKILL, CombatAction.ActionType.MAGIC:
			if not action.actor.spend_sp(action.sp_cost):
				return false
		CombatAction.ActionType.ULTIMATE:
			if not action.actor.can_ultimate():
				return false
			action.actor.consume_charge()

	queued_actions.append(action)
	return true

## Call once the player has finished queueing actions for the party this turn.
func confirm_planning() -> void:
	if phase != CombatPhase.PLANNING:
		return
	_queue_enemy_actions()
	_begin_execution()

func _queue_enemy_actions() -> void:
	var living_party: Array = party.filter(func(m): return m.is_alive())
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		if enemy.has_method("choose_action"):
			queued_actions.append(enemy.choose_action(living_party))

func _begin_execution() -> void:
	phase = CombatPhase.EXECUTION
	execution_started.emit()
	_resolve_actions()

func _resolve_actions() -> void:
	# Freeze each action's priority at the SPD each actor has right now —
	# a mid-turn buff/debuff shouldn't retroactively reorder this turn.
	for action in queued_actions:
		action.compute_priority()

	# Higher SPD resolves first. Equal SPD is a coin-flip clash.
	queued_actions.sort_custom(func(a, b):
		if a.priority == b.priority:
			return randf() < 0.5
		return a.priority > b.priority
	)

	for action in queued_actions:
		if not is_instance_valid(action.actor) or not action.actor.is_alive():
			continue  # actor was killed earlier this turn — action cancelled
		await _resolve_single_action(action)
		action_resolved.emit(action)

	queued_actions.clear()
	_end_turn()

func _resolve_single_action(action: CombatAction) -> void:
	match action.action_type:
		CombatAction.ActionType.MOVE:
			# TODO: convert action.target_grid via your TileMapLayer.map_to_local()
			pass
		CombatAction.ActionType.PHYSICAL, CombatAction.ActionType.PHYSICAL_SKILL, \
		CombatAction.ActionType.MAGIC, CombatAction.ActionType.ULTIMATE:
			_resolve_offensive_action(action)

	await get_tree().create_timer(0.15).timeout  # PLACEHOLDER pacing between resolutions

func _resolve_offensive_action(action: CombatAction) -> void:
	if not is_instance_valid(action.target) or not action.target.is_alive():
		return  # target already died to a higher-priority action this turn
	var attacker = action.actor
	var base_power: int = attacker.get_effective_stat(StatusEffect.StatType.ATK)
	var damage: int = int(base_power * action.power_multiplier)
	action.target.take_damage(damage, attacker)
	attacker.gain_charge(10.0)  # PLACEHOLDER charge-on-action rule

func _end_turn() -> void:
	for combatant in party + enemies:
		if is_instance_valid(combatant):
			combatant.tick_status_effects()

	var enemies_alive: bool = not enemies.filter(func(e): return e.is_alive()).is_empty()
	var party_alive: bool = not party.filter(func(m): return m.is_alive()).is_empty()

	if not enemies_alive:
		_finish_combat(true)
	elif not party_alive:
		_finish_combat(false)
	else:
		phase = CombatPhase.PLANNING
		planning_started.emit()

func _finish_combat(victory: bool) -> void:
	phase = CombatPhase.RESOLVED
	combat_ended.emit(victory)
	var zone = Global.current_combat_zone
	if zone:
		if victory and zone.has_method("resolve_victory"):
			zone.resolve_victory()
		elif not victory and zone.has_method("resolve_defeat"):
			zone.resolve_defeat()
