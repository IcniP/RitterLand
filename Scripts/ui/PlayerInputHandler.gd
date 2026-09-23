# File: res://scripts/ui/PlayerInputHandler.gd
extends Node2D

@onready var tile_map_layer: TileMapLayer = $"../Map/TileMapLayer"
@onready var highlight_layer: TileMapLayer = $"../Map/HighlightLayer"
@onready var turn_manager: Node = $"../TurnManager"

@export var highlight_source_id: int = 0
@export var green_tile_coords: Vector2i = Vector2i(3, 3)
@export var red_tile_coords: Vector2i = Vector2i(4, 3)

var selected_unit: CharacterBody2D = null
## The skill being aimed (null = normal move / melee mode). Set from the
## skill bar (CombatHUD) or the 1-4 keys (5 = ultimate).
var active_skill: SkillData = null

var _highlighted: Array[Vector2i] = []
var _highlight_sig: String = ""


func _ready() -> void:
	# HighlightLayer has no offset in the scene, but the TileMapLayer does,
	# so line them up or the highlight draws a tile away from the cursor.
	if highlight_layer and tile_map_layer:
		highlight_layer.global_position = tile_map_layer.global_position
	# Lan registers herself as Global.player in her own _ready (runs before ours).
	if Global.player:
		selected_unit = Global.player

func _process(_delta: float) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		# Drop skill mode if it became unusable (unit died, out of AP...).
		if active_skill != null and (selected_unit == null or not can_use_skill(selected_unit, active_skill)):
			active_skill = null
		if active_skill != null:
			update_skill_highlight()
		else:
			update_grid_highlight_set_cell()
	else:
		active_skill = null
		clear_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if turn_manager and turn_manager.current_phase == turn_manager.BattlePhase.PLANNING:
		# Hotkeys: 1-4 = the unit's skills, 5 = ultimate.
		if event is InputEventKey and event.pressed and not event.echo:
			var idx := -1
			match event.keycode:
				KEY_1: idx = 0
				KEY_2: idx = 1
				KEY_3: idx = 2
				KEY_4: idx = 3
				KEY_5: idx = 4
			if idx != -1:
				_hotkey_skill(idx)
			return

		if event is InputEventMouseButton and event.pressed:
			var mouse_world_pos: Vector2 = get_global_mouse_position()
			var clicked_cell: Vector2i = turn_manager.world_to_cell(mouse_world_pos)

			# Aiming a skill: left = cast, right = cancel aiming.
			if active_skill != null:
				if event.button_index == MOUSE_BUTTON_LEFT:
					queue_skill_at(clicked_cell)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					cancel_skill()
				return

			# KLIK KIRI: Pilih Unit / Antre Pergerakan
			if event.button_index == MOUSE_BUTTON_LEFT:
				# 1. Cek Klik pada Unit Kawan (Lan / Ilia) untuk Switch Unit
				for unit in turn_manager.units:
					if not is_instance_valid(unit) or not unit.is_alive():
						continue
					var unit_cell: Vector2i = turn_manager.world_to_cell(unit.global_position)
					if unit_cell != clicked_cell:
						continue
					# Enemies are never controllable: clicking one = attack it (if adjacent).
					if unit is EnemyNPC:
						if selected_unit != null:
							queue_melee_attack(unit)
						return
					selected_unit = unit
					print("Unit dipilih: ", selected_unit.name)
					update_grid_highlight_set_cell(true)
					return
				
				# 2. Antrekan Pergerakan Multi-Tile (1 atau 2 Tile Sekaligus)
				if selected_unit != null:
					queue_multi_tile_move(clicked_cell)
					
			# KLIK KANAN: Cancel Pre-move Terakhir
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if selected_unit != null:
					var success: bool = turn_manager.cancel_last_action(selected_unit)
					if success:
						update_grid_highlight_set_cell(true)

# Menghitung sisa AP (SPD) yang masih bisa digunakan oleh selected_unit
func get_remaining_ap(unit: CharacterBody2D) -> int:
	var used_ap: int = 0
	if turn_manager and turn_manager.global_action_queue:
		for act in turn_manager.global_action_queue:
			if act.actor == unit:
				used_ap += act.execution_cost_ap
	return unit.spd - used_ap

# PERBAIKAN PADA FUNGSI INI (BARIS 53):
# Menemukan titik akhir posisi grid unit berdasarkan antrean global di turn_manager
func get_current_unit_end_cell() -> Vector2i:
	if selected_unit == null:
		return Vector2i.ZERO
		
	var current_cell: Vector2i = turn_manager.world_to_cell(selected_unit.global_position)
	
	# PERBAIKAN: Gunakan global_action_queue (bukan action_queues)
	if turn_manager and turn_manager.global_action_queue:
		# Cari dari urutan paling belakang (aksi paling baru) yang dimiliki oleh selected_unit
		for i in range(turn_manager.global_action_queue.size() - 1, -1, -1):
			var act: BattleAction = turn_manager.global_action_queue[i]
			if act.actor == selected_unit:
				current_cell = act.target_grid
				break
			
	return current_cell

# Menghitung jalur langkah per-tile (Manhattan Path)
func get_step_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var curr: Vector2i = start_cell
	
	while curr != target_cell:
		var diff: Vector2i = target_cell - curr
		if abs(diff.x) >= abs(diff.y):
			curr.x += 1 if diff.x > 0 else -1
		else:
			curr.y += 1 if diff.y > 0 else -1
		path.append(curr)
	return path

# Memvalidasi pergerakan multi-tile
func is_valid_move_cell(target_cell: Vector2i) -> bool:
	if selected_unit == null:
		return false
		
	var start_cell: Vector2i = get_current_unit_end_cell()
	var path: Array[Vector2i] = get_step_path(start_cell, target_cell)
	var distance: int = path.size()
	
	# Jarak tile harus > 0 dan <= sisa AP yang dimiliki
	var rem_ap: int = get_remaining_ap(selected_unit)
	if distance == 0 or distance > rem_ap:
		return false
		
	# Pastikan seluruh jalur yang dilalui tidak menabrak obstacle / unit lain
	for cell in path:
		if not turn_manager.is_cell_in_arena(cell):
			return false
		if turn_manager.has_method("is_cell_occupied") and turn_manager.is_cell_occupied(cell, selected_unit):
			return false
			
	return true

# Memasukkan aksi gerakan per-tile ke antrean TurnManager
func queue_multi_tile_move(target_cell: Vector2i) -> void:
	if not is_valid_move_cell(target_cell):
		print("Target tile tidak valid atau AP tidak cukup!")
		return
		
	var start_cell: Vector2i = get_current_unit_end_cell()
	var path: Array[Vector2i] = get_step_path(start_cell, target_cell)
	
	for step_cell in path:
		var new_action = BattleAction.new()
		new_action.action_type = BattleAction.Type.MOVE
		new_action.actor = selected_unit
		new_action.target_grid = step_cell
		new_action.execution_cost_ap = 1
		
		turn_manager.queue_action(selected_unit, new_action)
		
	print("Berhasil mengantre ", path.size(), " langkah sekaligus ke cell: ", target_cell)
	update_grid_highlight_set_cell(true)

# Queue a 1-AP melee attack on an adjacent enemy (from where the unit will
# be standing after its already-queued moves).
func queue_melee_attack(target: Node2D) -> void:
	if selected_unit == null or get_remaining_ap(selected_unit) < 1:
		print("AP tidak cukup untuk menyerang!")
		return
	var from_cell: Vector2i = get_current_unit_end_cell()
	var to_cell: Vector2i = turn_manager.world_to_cell(target.global_position)
	var dist: int = absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)
	if dist != 1:
		print("Musuh terlalu jauh! Dekati dulu (harus bersebelahan).")
		return
	var act := BattleAction.new()
	act.action_type = BattleAction.Type.ATTACK_MELEE
	act.actor = selected_unit
	act.target_unit = target
	act.target_grid = from_cell  # keeps get_current_unit_end_cell() correct
	act.execution_cost_ap = 1
	if turn_manager.queue_action(selected_unit, act):
		print(selected_unit.name, " akan menyerang ", target.name)
		update_grid_highlight_set_cell(true)

func update_grid_highlight_set_cell(force_update: bool = false) -> void:
	if highlight_layer == null or tile_map_layer == null or selected_unit == null:
		return
	var hover: Vector2i = turn_manager.world_to_cell(get_global_mouse_position())
	if force_update:
		_highlight_sig = ""
	var cells: Array[Vector2i] = [hover]
	_apply_highlight(cells, is_valid_move_cell(hover))

func clear_highlight() -> void:
	_clear_highlighted()
	_highlight_sig = ""

# Paint a list of cells green (valid) or red (invalid) on the highlight layer.
func _apply_highlight(cells: Array[Vector2i], valid: bool) -> void:
	if highlight_layer == null:
		return
	var sig := "%s|%s" % [str(cells), valid]
	if sig == _highlight_sig:
		return
	_clear_highlighted()
	var coords: Vector2i = green_tile_coords if valid else red_tile_coords
	for c in cells:
		highlight_layer.set_cell(c, highlight_source_id, coords)
	_highlighted = cells.duplicate()
	_highlight_sig = sig

func _clear_highlighted() -> void:
	if highlight_layer:
		for c in _highlighted:
			highlight_layer.set_cell(c, -1)
	_highlighted.clear()

# ---------------- Skills ----------------

# SP this unit still has after the skills already queued this turn.
func get_projected_sp(unit: Node2D) -> int:
	var sp: int = unit.sp
	for act in turn_manager.global_action_queue:
		if act.actor == unit and act.action_type == BattleAction.Type.SKILL and not act.skill.is_ultimate:
			sp -= act.skill.sp_cost
	return sp

func can_use_skill(unit: Node2D, skill: SkillData) -> bool:
	if turn_manager.current_phase != turn_manager.BattlePhase.PLANNING:
		return false
	if not is_instance_valid(unit) or unit is EnemyNPC or not unit.is_alive():
		return false
	if get_remaining_ap(unit) < skill.ap_cost:
		return false
	if skill.is_ultimate:
		if not unit.can_ultimate():
			return false
		for act in turn_manager.global_action_queue:   # only one ultimate per turn
			if act.actor == unit and act.action_type == BattleAction.Type.SKILL and act.skill.is_ultimate:
				return false
		return true
	return get_projected_sp(unit) >= skill.sp_cost

func toggle_skill(skill: SkillData) -> void:
	if active_skill == skill:
		cancel_skill()
	elif selected_unit != null and can_use_skill(selected_unit, skill):
		active_skill = skill
		_highlight_sig = ""
		print("Skill dipilih: ", skill.display_name, "  (klik kiri = pakai, klik kanan = batal)")
	else:
		print("Skill tidak bisa dipakai (AP / SP / charge tidak cukup).")

func cancel_skill() -> void:
	active_skill = null
	clear_highlight()

func _hotkey_skill(index: int) -> void:
	if selected_unit == null or selected_unit is EnemyNPC:
		return
	if index < SkillDB.MAX_LOADOUT:
		var skills: Array = selected_unit.get_battle_skills()
		if index < skills.size():
			toggle_skill(skills[index])
	else:
		var ult: SkillData = selected_unit.get_ultimate_skill()
		if ult:
			toggle_skill(ult)

# Projectiles fly along the axis the cursor is furthest away on.
func _skill_direction(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var d := to_cell - from_cell
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

# What the cursor would do right now: the target tile / flight direction.
func _aim() -> Dictionary:
	var caster_cell: Vector2i = get_current_unit_end_cell()
	var hover: Vector2i = turn_manager.world_to_cell(get_global_mouse_position())
	var target: Vector2i = hover
	if active_skill.shape == SkillData.Shape.AREA and active_skill.cast_range == 0:
		target = caster_cell
	return {"origin": caster_cell, "target": target, "dir": _skill_direction(caster_cell, hover), "hover": hover}

# Show which tiles the skill will hit: green = can cast, red = can't.
func update_skill_highlight() -> void:
	if highlight_layer == null or selected_unit == null or active_skill == null:
		return
	var a := _aim()
	var valid: bool = turn_manager.is_skill_target_valid(active_skill, selected_unit, a["origin"], a["target"], a["dir"])
	var cells: Array[Vector2i] = turn_manager.get_skill_cells(active_skill, selected_unit, a["origin"], a["target"], a["dir"])
	if cells.is_empty():
		valid = false          # nothing to hit (e.g. projectile blocked at once)
		cells.append(a["hover"])
	_apply_highlight(cells, valid)

func queue_skill_at(_clicked_cell: Vector2i) -> void:
	if selected_unit == null or active_skill == null:
		return
	var a := _aim()
	if not turn_manager.is_skill_target_valid(active_skill, selected_unit, a["origin"], a["target"], a["dir"]):
		print("Target skill tidak valid (di luar jangkauan / tidak ada target).")
		return
	if not can_use_skill(selected_unit, active_skill):
		return
	var act := BattleAction.new()
	act.action_type = BattleAction.Type.SKILL
	act.actor = selected_unit
	act.skill = active_skill
	act.skill_target_cell = a["target"]
	act.skill_direction = a["dir"]
	act.target_grid = a["origin"]   # keeps get_current_unit_end_cell() correct
	act.execution_cost_ap = active_skill.ap_cost
	if turn_manager.queue_action(selected_unit, act):
		print(selected_unit.name, " akan memakai ", active_skill.display_name)
		active_skill = null
		clear_highlight()
