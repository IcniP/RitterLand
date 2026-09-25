# File: res://scripts/core/TurnManager.gd
extends Node

@onready var y_sort_node: Node2D = $"../Y-sort"
@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"
@onready var main_camera: Camera2D = $"../MainCamera"

enum BattlePhase { EXPLORATION, PLANNING, EXECUTION }
var current_phase: BattlePhase = BattlePhase.EXPLORATION

var units: Array[Node2D] = []

# Gunakan Array global tunggal untuk menampung seluruh urutan Pre-Move
var global_action_queue: Array[BattleAction] = []

# Penampung hitungan AP sementara per unit selama Planning Phase
var unit_ap_used: Dictionary = {}

# World-space rectangle of the active CombatZone. Units snap inside it and
# can't plan moves outside it. has_arena = false -> no restriction (R debug).
var arena_rect: Rect2 = Rect2()
var has_arena: bool = false

## Hook for skill animations / sound later: emitted when a skill resolves.
signal skill_used(actor, skill, cells, targets)

const SNAP_SEARCH_RADIUS := 8
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

func _ready() -> void:
	if y_sort_node == null or tile_map_layer == null:
		push_error("TurnManager ERROR: y_sort_node atau tile_map_layer belum terhubung!")
		return

# ---------------- Grid helpers ----------------
# The TileMapLayer is offset from the world origin, so plain local_to_map() /
# map_to_local() on GLOBAL positions lands units half a tile off. Always go
# through these two helpers.

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return tile_map_layer.local_to_map(tile_map_layer.to_local(world_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return tile_map_layer.to_global(tile_map_layer.map_to_local(cell))

func is_cell_in_arena(cell: Vector2i) -> bool:
	if not has_arena:
		return true
	return arena_rect.has_point(cell_to_world(cell))

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _is_live(u) -> bool:
	return is_instance_valid(u) and u.is_alive()

# ---------------- Input (R = debug toggle, SPACE = execute) ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle_combat_mode()
	elif current_phase == BattlePhase.PLANNING and event.is_action_pressed("ui_accept"): # Spacebar
		start_execution_phase()

func toggle_combat_mode() -> void:
	if current_phase == BattlePhase.EXPLORATION:
		enter_combat_mode()
	else:
		exit_combat_mode()

# ---------------- Enter / exit combat ----------------

## Called by CombatZone (party + spawned enemies + the zone's rectangle) or by
## the R debug key (no args -> gathers everyone itself, no arena limit).
func enter_combat_mode(combatants: Array = [], arena: Rect2 = Rect2()) -> void:
	if current_phase != BattlePhase.EXPLORATION:
		return
	if combatants.is_empty():
		combatants = _gather_combatants()

	has_arena = arena.size != Vector2.ZERO
	arena_rect = arena

	units.clear()
	global_action_queue.clear()
	unit_ap_used.clear()

	# Cells already taken by anyone who is NOT fighting (e.g. static NPCs).
	var taken: Dictionary = {}
	for child in y_sort_node.get_children():
		if child is CharacterBody2D and not combatants.has(child):
			taken[world_to_cell(child.global_position)] = true

	for c in combatants:
		if not is_instance_valid(c):
			continue
		units.append(c)
		unit_ap_used[c] = 0
		if "movement_mode" in c:
			c.movement_mode = EntityBase.MovementMode.GRID_COMBAT
		if c.has_method("stop_moving"):
			c.stop_moving()
		# Snap to the closest free tile INSIDE the arena.
		var cell: Vector2i = _find_free_cell(world_to_cell(c.global_position), taken)
		taken[cell] = true
		c.global_position = cell_to_world(cell)

	current_phase = BattlePhase.PLANNING
	print("--- ENTER COMBAT MODE: PLANNING PHASE ---")

	if main_camera and main_camera.has_method("enter_combat_camera"):
		main_camera.enter_combat_camera(_units_center())

func exit_combat_mode() -> void:
	if current_phase == BattlePhase.EXPLORATION:
		return
	current_phase = BattlePhase.EXPLORATION
	global_action_queue.clear()
	print("--- EXIT COMBAT MODE ---")

	for unit in units:
		if is_instance_valid(unit) and "movement_mode" in unit:
			unit.movement_mode = EntityBase.MovementMode.OPEN_WORLD
	units.clear()
	unit_ap_used.clear()
	has_arena = false

	# Owned party members only exist during a fight.
	if Global.roster:
		Global.roster.despawn_party()

	# The zone cleans up first (it moves the player back to where they started
	# talking), so the camera below glides to the player's final position.
	var zone = Global.current_combat_zone
	if zone and zone.has_method("_end_combat"):
		zone._end_combat()

	if main_camera and main_camera.has_method("exit_combat_camera"):
		main_camera.exit_combat_camera()

func _gather_combatants() -> Array:
	var list: Array = []
	if is_instance_valid(Global.player):
		list.append(Global.player)
	if Global.roster and is_instance_valid(Global.player):
		list.append_array(Global.roster.spawn_party(Global.player))
	list.append_array(Global.get_enemies_alive())
	return list

func _units_center() -> Vector2:
	if units.is_empty():
		return main_camera.global_position if main_camera else Vector2.ZERO
	var sum := Vector2.ZERO
	for u in units:
		sum += u.global_position
	return sum / units.size()

func _find_free_cell(start: Vector2i, taken: Dictionary) -> Vector2i:
	# Pass 1 respects the arena; pass 2 is a fallback if the arena has no free tile.
	for enforce_arena in [true, false]:
		for r in range(0, SNAP_SEARCH_RADIUS + 1):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var cell := start + Vector2i(dx, dy)
					if taken.has(cell):
						continue
					if tile_map_layer.get_cell_source_id(cell) == -1:
						continue  # no ground tile here
					if enforce_arena and not is_cell_in_arena(cell):
						continue
					return cell
	return start

# ---------------- Planning / execution ----------------

func is_cell_occupied(target_cell: Vector2i, checking_unit: Node2D) -> bool:
	for child in y_sort_node.get_children():
		if child == checking_unit or not (child is CharacterBody2D):
			continue
		if child.has_method("is_alive") and not child.is_alive():
			continue
		var unit_cell: Vector2i = world_to_cell(child.global_position)
		if unit_cell == target_cell:
			return true
	return false

# 1. Menambahkan Aksi ke Antrean Global (Urutan Klik)
func queue_action(unit: Node2D, action: BattleAction) -> bool:
	if current_phase != BattlePhase.PLANNING:
		return false

	if not unit_ap_used.has(unit):
		unit_ap_used[unit] = 0

	var max_ap: int = unit.spd
	var current_ap: int = unit_ap_used[unit]

	if current_ap + action.execution_cost_ap <= max_ap:
		unit_ap_used[unit] += action.execution_cost_ap
		global_action_queue.append(action) # Dimasukkan ke antrean paling belakang
		return true
	return false

# 2. Cancel Aksi Terakhir Milik Unit yang Dipilih
func cancel_last_action(unit: Node2D) -> bool:
	if current_phase != BattlePhase.PLANNING:
		return false

	for i in range(global_action_queue.size() - 1, -1, -1):
		if global_action_queue[i].actor == unit:
			var popped: BattleAction = global_action_queue[i]
			global_action_queue.remove_at(i)
			unit_ap_used[unit] -= popped.execution_cost_ap
			print("Pre-move terakhir ", unit.name, " dibatalkan!")
			return true
	return false

func start_execution_phase() -> void:
	current_phase = BattlePhase.EXECUTION
	_queue_enemy_actions()   # enemies decide AFTER the player has committed
	execute_global_sequence()

# ---------------- Enemy AI ----------------
# Each enemy spends its SPD as AP: walk toward the nearest party member (one
# tile at a time, staying inside the arena and off occupied tiles) and melee
# them as soon as they're adjacent.

func _queue_enemy_actions() -> void:
	# Where every living unit will stand once the player's queued moves ran.
	var reserved: Dictionary = {}
	for u in units:
		if _is_live(u):
			reserved[_planned_end_cell(u)] = true

	for enemy in units:
		if not (is_instance_valid(enemy) and enemy is EnemyNPC and enemy.is_alive()):
			continue
		var cell: Vector2i = world_to_cell(enemy.global_position)
		reserved.erase(cell)
		var ap: int = enemy.spd

		while ap > 0:
			var target = _nearest_opponent(cell)
			if target == null:
				break
			var target_cell: Vector2i = _planned_end_cell(target)

			if _manhattan(cell, target_cell) == 1:
				var atk := BattleAction.new()
				atk.action_type = BattleAction.Type.ATTACK_MELEE
				atk.actor = enemy
				atk.target_unit = target
				atk.target_grid = cell
				atk.execution_cost_ap = 1
				global_action_queue.append(atk)
			else:
				var step: Vector2i = _best_step(cell, target_cell, reserved)
				if step == cell:
					break  # boxed in / can't get closer
				var mv := BattleAction.new()
				mv.action_type = BattleAction.Type.MOVE
				mv.actor = enemy
				mv.target_grid = step
				mv.execution_cost_ap = 1
				global_action_queue.append(mv)
				cell = step
			ap -= 1

		reserved[cell] = true

func _planned_end_cell(unit: Node2D) -> Vector2i:
	var cell: Vector2i = world_to_cell(unit.global_position)
	for act in global_action_queue:
		if act.actor == unit and act.action_type == BattleAction.Type.MOVE:
			cell = act.target_grid
	return cell

func _nearest_opponent(from_cell: Vector2i):
	var best = null
	var best_dist := 999999
	for u in units:
		if not _is_live(u) or u is EnemyNPC:
			continue
		var d := _manhattan(from_cell, _planned_end_cell(u))
		if d < best_dist:
			best_dist = d
			best = u
	return best

func _best_step(from_cell: Vector2i, goal: Vector2i, reserved: Dictionary) -> Vector2i:
	var best := from_cell
	var best_dist := _manhattan(from_cell, goal)
	for dir in CARDINALS:
		var n: Vector2i = from_cell + dir
		if reserved.has(n) or not is_cell_in_arena(n):
			continue
		if tile_map_layer.get_cell_source_id(n) == -1:
			continue
		var d := _manhattan(n, goal)
		if d < best_dist:
			best_dist = d
			best = n
	return best

# 3. Eksekusi Berurutan Sesuai Urutan Pre-Move (FIFO)
func execute_global_sequence() -> void:
	while not global_action_queue.is_empty() and current_phase == BattlePhase.EXECUTION:
		var current_action: BattleAction = global_action_queue.pop_front()
		await process_single_action(current_action)

	# Combat may have ended (victory/defeat/manual exit) while we animated.
	if current_phase != BattlePhase.EXECUTION:
		return

	global_action_queue.clear()
	unit_ap_used.clear()
	for unit in units:
		unit_ap_used[unit] = 0
		if _is_live(unit):
			unit.tick_status_effects()   # buffs / debuffs lose a turn

	current_phase = BattlePhase.PLANNING
	print("--- PLANNING PHASE ACTIVE ---")

func process_single_action(action: BattleAction) -> void:
	var actor = action.actor
	if not _is_live(actor):
		return  # died earlier this turn -> action cancelled

	if action.action_type == BattleAction.Type.MOVE:
		var target_cell: Vector2i = action.target_grid

		if is_cell_occupied(target_cell, actor):
			print("TABRAKAN! Cell ", target_cell, " terisi. Gerakan ", actor.name, " dibatalkan!")
			clear_remaining_actions_for_unit(actor)
			return

		await actor.move_to_grid_target(cell_to_world(target_cell))

	elif action.action_type == BattleAction.Type.ATTACK_MELEE:
		var target = action.target_unit
		if not _is_live(target):
			return
		if not SkillDB.basic_in_reach(actor, world_to_cell(actor.global_position), world_to_cell(target.global_position)):
			return  # target moved/died - attack fizzles
		await _play_attack_lunge(actor, target)
		var n: int = SkillDB.basic_for(actor).hits
		for _i in n:
			if _is_live(target):
				target.take_damage(SkillDB.basic_damage(actor) / n, actor)
		var splash: float = SkillDB.basic_for(actor).get("splash", 0.0)
		if splash > 0.0:
			var tc := world_to_cell(target.global_position)
			for u in units:
				if u != target and _is_live(u) and is_opponent(actor, u) and _manhattan(world_to_cell(u.global_position), tc) == 1:
					u.take_damage(int(SkillDB.basic_damage(actor) * splash), actor)
		_check_combat_end()

	elif action.action_type == BattleAction.Type.SKILL:
		await _execute_skill(actor, action)

	await get_tree().create_timer(0.1).timeout

func _play_attack_lunge(actor: Node2D, target: Node2D) -> void:
	var start: Vector2 = actor.global_position
	var dir: Vector2 = (target.global_position - start).normalized()
	if actor.has_method("play_attack") and actor.animated_sprite and actor.animated_sprite.sprite_frames \
			and actor.animated_sprite.sprite_frames.has_animation("Attack" + _dir_suffix(dir)):
		await actor.play_attack(dir)   # has a real Attack<Dir> animation: no lunge tween needed
		return
	if actor.has_method("_update_animation"):
		actor._update_animation(dir)
		actor._update_animation(Vector2.ZERO)  # face the target, then idle
	var tw := create_tween()
	tw.tween_property(actor, "global_position", start + dir * 6.0, 0.08)
	tw.tween_property(actor, "global_position", start, 0.08)
	await tw.finished

## "Down"/"Up"/"Left"/"Right" for a direction vector (same rule as EntityBase._direction_suffix).
func _dir_suffix(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "Down"
	if absf(dir.x) > absf(dir.y):
		return "Right" if dir.x > 0 else "Left"
	return "Down" if dir.y > 0 else "Up"

## Slices `sprite` into cols x rows equal frames and returns a one-animation
## ("play") SpriteFrames, played once at `fps`. Shared by effects and projectiles.
func _slice_frames(sprite: Texture2D, cols: int, rows: int, fps: float) -> SpriteFrames:
	cols = maxi(cols, 1)
	rows = maxi(rows, 1)
	var fw: int = sprite.get_width() / cols
	var fh: int = sprite.get_height() / rows
	var frames := SpriteFrames.new()
	frames.add_animation("play")
	frames.set_animation_loop("play", false)
	frames.set_animation_speed("play", fps)
	for row in rows:
		for col in cols:
			var tex := AtlasTexture.new()
			tex.atlas = sprite
			tex.region = Rect2(col * fw, row * fh, fw, fh)
			frames.add_frame("play", tex)
	return frames

## Spawns a one-shot effect sprite (skill.effect_sprite, sliced effect_hframes x effect_vframes)
## at a target's position, plays it once, then frees itself. No-op if the skill has no sprite set.
func _spawn_skill_effect(skill: SkillData, target: Node2D) -> void:
	if skill.effect_sprite == null or not is_instance_valid(target):
		return
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _slice_frames(skill.effect_sprite, skill.effect_hframes, skill.effect_vframes, skill.effect_fps)
	spr.animation = "play"
	spr.global_position = target.global_position
	spr.z_index = 100
	get_tree().current_scene.add_child(spr)
	spr.play("play")
	await spr.animation_finished
	spr.queue_free()

## PROJECTILE skills only: flies skill.projectile_sprite from `from_pos` to `to_pos`
## (rotated to face the direction of travel -- draw the sprite facing RIGHT), then
## frees itself. No-op if the skill has no projectile sprite set (silent, instant).
func _play_projectile(skill: SkillData, from_pos: Vector2, to_pos: Vector2) -> void:
	if skill.projectile_sprite == null:
		return
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _slice_frames(skill.projectile_sprite, skill.projectile_hframes, skill.projectile_vframes, skill.projectile_fps)
	spr.animation = "play"
	spr.sprite_frames.set_animation_loop("play", true)   # keep animating for the whole flight
	spr.global_position = from_pos
	spr.rotation = (to_pos - from_pos).angle()
	spr.z_index = 100
	get_tree().current_scene.add_child(spr)
	spr.play("play")
	var dist: float = from_pos.distance_to(to_pos)
	var dur: float = clampf(dist / maxf(skill.projectile_speed, 1.0), 0.05, 1.5)
	var tw := create_tween()
	tw.tween_property(spr, "global_position", to_pos, dur)
	await tw.finished
	spr.queue_free()

# ---------------- Skills ----------------

func unit_at_cell(cell: Vector2i, ignore: Node2D = null) -> Node2D:
	for u in units:
		if u == ignore or not _is_live(u):
			continue
		if world_to_cell(u.global_position) == cell:
			return u
	return null

func is_opponent(a: Node, b: Node) -> bool:
	return (a is EnemyNPC) != (b is EnemyNPC)

func _matches_side(actor: Node, u: Node, skill: SkillData) -> bool:
	if skill.target_side == SkillData.TargetSide.ENEMIES:
		return is_opponent(actor, u)
	return not is_opponent(actor, u)

func _cell_open(cell: Vector2i) -> bool:
	return tile_map_layer.get_cell_source_id(cell) != -1 and is_cell_in_arena(cell)

## Every tile the skill would hit. `target_cell` is the chosen tile
## (SINGLE / AREA), `dir` the flight direction (PROJECTILE).
func get_skill_cells(skill: SkillData, actor: Node2D, origin: Vector2i, target_cell: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match skill.shape:
		SkillData.Shape.SINGLE:
			cells.append(target_cell)
		SkillData.Shape.AREA:
			var center: Vector2i = target_cell if skill.cast_range > 0 else origin
			for dx in range(-skill.radius, skill.radius + 1):
				for dy in range(-skill.radius, skill.radius + 1):
					var c := center + Vector2i(dx, dy)
					if _cell_open(c):
						cells.append(c)
		SkillData.Shape.PROJECTILE:
			if dir == Vector2i.ZERO:
				return cells
			for i in range(1, skill.cast_range + 1):
				var c := origin + dir * i
				if not _cell_open(c):
					break
				cells.append(c)
				var u := unit_at_cell(c, actor)
				if u != null and _matches_side(actor, u, skill):
					break   # the projectile stops at the first valid target
	return cells

func is_skill_target_valid(skill: SkillData, actor: Node2D, origin: Vector2i, target_cell: Vector2i, dir: Vector2i) -> bool:
	match skill.shape:
		SkillData.Shape.SINGLE:
			if _manhattan(origin, target_cell) > skill.cast_range or not is_cell_in_arena(target_cell):
				return false
			var u := unit_at_cell(target_cell)
			return u != null and _matches_side(actor, u, skill)
		SkillData.Shape.AREA:
			if skill.cast_range == 0:
				return true
			return _manhattan(origin, target_cell) <= skill.cast_range and is_cell_in_arena(target_cell)
		SkillData.Shape.PROJECTILE:
			return dir != Vector2i.ZERO
	return false

func _execute_skill(actor: Node2D, action: BattleAction) -> void:
	var skill: SkillData = action.skill
	if skill == null:
		return
	# Pay the cost now (planning only checked it). Not enough -> the skill fizzles.
	if skill.is_ultimate:
		if not actor.can_ultimate():
			return
		actor.consume_charge()
	elif not actor.spend_sp(skill.sp_cost):
		return

	var origin: Vector2i = world_to_cell(actor.global_position)
	var cells: Array[Vector2i] = get_skill_cells(skill, actor, origin, action.skill_target_cell, action.skill_direction)
	var hit: Array = []
	for u in units:
		if _is_live(u) and cells.has(world_to_cell(u.global_position)) and _matches_side(actor, u, skill):
			hit.append(u)
	print(actor.name, " uses ", skill.display_name, " on ", hit.size(), " target(s)")

	if skill.category == SkillData.Category.PHYSICAL:
		var aim: Vector2 = (cell_to_world(action.skill_target_cell) - actor.global_position)
		if actor.has_method("play_attack"):
			await actor.play_attack(aim)
	if skill.shape == SkillData.Shape.PROJECTILE and not cells.is_empty():
		await _play_projectile(skill, actor.global_position, cell_to_world(cells.back()))
	await _play_skill_placeholder(skill, hit)
	skill_used.emit(actor, skill, cells, hit)

	for t in hit:
		if not _is_live(t):
			continue
		_spawn_skill_effect(skill, t)   # visual only; fire-and-forget
		if skill.power > 0.0:
			var total: float = actor.get_effective_stat(StatusEffect.StatType.ATK) * skill.power \
				+ actor.get_effective_stat(StatusEffect.StatType.SPD) * skill.spd_scale
			for _i in skill.hits:
				if _is_live(t):
					t.take_damage(int(total / skill.hits), actor, skill.def_pierce)
		if skill.effect and _is_live(t):
			t.apply_status_effect(skill.effect)

	# PROJECTILE explosion: everyone else within splash_radius of the impact point
	# takes splash_power x the normal hit (the primary target(s) above already got the full hit).
	if skill.shape == SkillData.Shape.PROJECTILE and skill.splash_radius > 0 and not cells.is_empty():
		var impact: Vector2i = cells.back()
		var total: float = actor.get_effective_stat(StatusEffect.StatType.ATK) * skill.power \
			+ actor.get_effective_stat(StatusEffect.StatType.SPD) * skill.spd_scale
		for u in units:
			if _is_live(u) and not hit.has(u) and _matches_side(actor, u, skill) \
					and _manhattan(world_to_cell(u.global_position), impact) <= skill.splash_radius:
				_spawn_skill_effect(skill, u)
				u.take_damage(int(total * skill.splash_power), actor, skill.def_pierce)

	if skill.pull > 0:
		var center: Vector2i = action.skill_target_cell if skill.cast_range > 0 else origin
		hit.sort_custom(func(a, b): return _manhattan(world_to_cell(a.global_position), center) < _manhattan(world_to_cell(b.global_position), center))
		for t in hit:
			if _is_live(t) and not t.get("is_boss"):   # bosses can't be pulled
				var before := world_to_cell(t.global_position)
				await _pull_toward(t, center, skill.pull)
				if t is EnemyNPC and world_to_cell(t.global_position) != before:
					clear_remaining_actions_for_unit(t)   # its planned route is stale: it loses the turn

	# Using a skill charges the ultimate bar.
	if not skill.is_ultimate:
		actor.gain_charge(skill.charge_gain)
	_check_combat_end()

# Slide a unit up to `steps` tiles toward `center`. Only enters free tiles, so
# nobody stacks: it tries the longer axis first, then the other, else stops.
func _pull_toward(t: Node2D, center: Vector2i, steps: int) -> void:
	for _i in steps:
		var c := world_to_cell(t.global_position)
		var d := center - c
		if d == Vector2i.ZERO:
			return
		var sx := Vector2i(signi(d.x), 0)
		var sy := Vector2i(0, signi(d.y))
		var opts: Array[Vector2i] = []
		opts.assign([sx, sy] if absi(d.x) >= absi(d.y) else [sy, sx])
		var moved := false
		for o in opts:
			if o == Vector2i.ZERO:
				continue
			var n := c + o
			if _cell_open(n) and unit_at_cell(n, t) == null:
				await t.move_to_grid_target(cell_to_world(n))
				moved = true
				break
		if not moved:
			return

# PLACEHOLDER (no animations yet): a short pause and a colour flash on the targets.
func _play_skill_placeholder(skill: SkillData, hit: Array) -> void:
	var flash := Color(0.6, 1.0, 0.6) if skill.target_side == SkillData.TargetSide.ALLIES else Color(1.0, 0.5, 0.5)
	for t in hit:
		if is_instance_valid(t):
			var tw := create_tween()
			tw.tween_property(t, "modulate", flash, 0.08)
			tw.tween_property(t, "modulate", Color.WHITE, 0.12)
	await get_tree().create_timer(0.3).timeout

# ---------------- Victory / defeat ----------------

func _prune_units() -> void:
	for i in range(units.size() - 1, -1, -1):
		if not is_instance_valid(units[i]):
			units.remove_at(i)

func _check_combat_end() -> bool:
	if current_phase == BattlePhase.EXPLORATION:
		return true
	_prune_units()
	var enemies_alive := false
	var party_alive := false
	for u in units:
		if not _is_live(u):
			continue
		if u is EnemyNPC:
			enemies_alive = true
		else:
			party_alive = true
	if enemies_alive and party_alive:
		return false

	global_action_queue.clear()
	print("--- COMBAT OVER: ", "VICTORY" if party_alive else "DEFEAT", " ---")
	var zone = Global.current_combat_zone
	if zone:
		if party_alive:
			zone.resolve_victory()
		else:
			zone.resolve_defeat()
	else:
		exit_combat_mode()
	return true

# Menghapus sisa antrean unit jika menabrak di tengah jalan
func clear_remaining_actions_for_unit(unit: Node2D) -> void:
	var i: int = global_action_queue.size() - 1
	while i >= 0:
		if global_action_queue[i].actor == unit:
			global_action_queue.remove_at(i)
		i -= 1
