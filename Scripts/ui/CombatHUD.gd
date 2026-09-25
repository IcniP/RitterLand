# File: res://Scripts/ui/CombatHUD.gd
# Live combat stats. Shows only while a fight is running. Party on the left,
# enemies on the right: HP / SP / Charge bars, AP left, ATK/DEF/SPD with the
# buff/debuff already applied (green = buffed, red = debuffed), and a list of
# every active status effect with its remaining turns. Refreshes every frame,
# so any change shows up immediately. Built in code - add as a CanvasLayer
# that is a sibling of TurnManager and PlayerInputHandler.
class_name CombatHUD
extends CanvasLayer

## Icons for the Q / E slots. Empty for now: drag a texture in later.
@export var basic_icon: Texture2D
@export var special_icon: Texture2D

const BUFF_COLOR := "lime"
const DEBUFF_COLOR := "tomato"

var turn_manager: Node
var input_handler: Node
var _ally_box: VBoxContainer
var _enemy_box: VBoxContainer
var _cards: Dictionary = {}        # unit -> widget dictionary
var _signature: Array = []

# skill bar (bottom centre)
var _skill_panel: PanelContainer
var _skill_row: HBoxContainer
var _skill_hint: Label
var _skill_sig: Array = []
var _skill_buttons: Array = []     # [{button, skill}]

func _ready() -> void:
	layer = 10
	turn_manager = get_node_or_null("../TurnManager")
	input_handler = get_node_or_null("../PlayerInputHandler")
	_build_root()
	_build_skill_bar()
	visible = false

func _build_root() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var row := HBoxContainer.new()
	margin.add_child(row)
	_ally_box = VBoxContainer.new()
	_ally_box.add_theme_constant_override("separation", 6)
	row.add_child(_ally_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_enemy_box = VBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 6)
	row.add_child(_enemy_box)
	_set_ignore_mouse(margin)   # never eat clicks meant for the grid

func _set_ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_set_ignore_mouse(c)

# ---------------- Per frame ----------------

func _process(_delta: float) -> void:
	var in_combat: bool = turn_manager != null \
		and turn_manager.current_phase != turn_manager.BattlePhase.EXPLORATION
	visible = in_combat
	if not in_combat:
		if not _cards.is_empty():
			_clear_cards()
		return

	var live: Array = []
	for u in turn_manager.units:
		if is_instance_valid(u):
			live.append(u)
	var sig: Array = live.map(func(u): return u.get_instance_id())
	if sig != _signature:
		_signature = sig
		_rebuild(live)

	for unit in _cards.keys():
		if is_instance_valid(unit):
			_update_card(unit, _cards[unit])
	_update_skill_bar()

func _clear_cards() -> void:
	for box in [_ally_box, _enemy_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_cards.clear()
	_signature = []

func _rebuild(live: Array) -> void:
	_clear_cards()
	_signature = live.map(func(u): return u.get_instance_id())
	_add_header(_ally_box, "PARTY")
	_add_header(_enemy_box, "ENEMIES")
	for u in live:
		var is_enemy: bool = u is EnemyNPC
		var w := _make_card(u, is_enemy)
		(_enemy_box if is_enemy else _ally_box).add_child(w["card"])
		_cards[u] = w
	_set_ignore_mouse(_ally_box)
	_set_ignore_mouse(_enemy_box)

func _add_header(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(1, 1, 1, 0.7)
	box.add_child(l)

# ---------------- Card ----------------

func _make_card(unit: Node, is_enemy: bool) -> Dictionary:
	var w := {}
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 0)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)

	w["card"] = card
	w["name"] = Label.new()
	w["name"].add_theme_font_size_override("font_size", 17)
	v.add_child(w["name"])

	w["hp_bar"] = _bar(v, Color(0.85, 0.2, 0.2))
	w["hp_text"] = _bar_label(v)
	w["sp_bar"] = _bar(v, Color(0.25, 0.5, 0.95))
	w["sp_text"] = _bar_label(v)
	if not is_enemy:
		w["ch_bar"] = _bar(v, Color(0.95, 0.75, 0.2))
		w["ch_text"] = _bar_label(v)

	w["stats"] = _rich(v)
	w["effects"] = _rich(v)
	return w

func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _bar_label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	parent.add_child(l)
	return l

func _rich(parent: Control) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(230, 0)
	r.add_theme_font_size_override("normal_font_size", 13)
	parent.add_child(r)
	return r

func _update_card(unit: Node, w: Dictionary) -> void:
	var dead: bool = not unit.is_alive()
	var selected: bool = input_handler != null and input_handler.get("selected_unit") == unit

	# Name row: selection marker, KO tag, remaining AP for allies.
	var title: String = String(unit.name)
	if unit is EnemyNPC:
		title = unit.enemy_id if unit.enemy_id != "" else title
	if not (unit is EnemyNPC) and unit.level > 0:
		title += "  Lv%d" % unit.level
	if selected:
		title = "> " + title
	if dead:
		title += "  (KO)"
	elif not (unit is EnemyNPC) and turn_manager.unit_ap_used.has(unit):
		title += "   AP %d/%d" % [maxi(unit.spd - turn_manager.unit_ap_used[unit], 0), unit.spd]
	w["name"].text = title
	w["name"].modulate = Color(1, 0.9, 0.3) if selected else (Color(0.6, 0.6, 0.6) if dead else Color.WHITE)

	_set_bar(w["hp_bar"], w["hp_text"], "HP", unit.hp, unit.max_hp)
	_set_bar(w["sp_bar"], w["sp_text"], "SP", unit.sp, unit.max_sp)
	if w.has("ch_bar"):
		_set_bar(w["ch_bar"], w["ch_text"], "CHARGE", int(unit.charge_bar), int(EntityBase.CHARGE_MAX))

	_set_rich(w, "stats", _stats_bbcode(unit))
	_set_rich(w, "effects", _effects_bbcode(unit))

func _set_bar(bar: ProgressBar, label: Label, tag: String, value: int, max_value: int) -> void:
	bar.max_value = maxi(max_value, 1)
	bar.value = value
	label.text = "%s %d / %d" % [tag, value, max_value]

func _set_rich(w: Dictionary, key: String, text: String) -> void:
	# Only touch the label when the text changed (avoids re-parsing BBCode every frame).
	var cache_key := key + "_cache"
	if w.get(cache_key, "") != text:
		w[cache_key] = text
		w[key].text = text

func _stat_bbcode(tag: String, base: int, effective: int) -> String:
	if effective > base:
		return "%s [color=%s]%d (+%d)[/color]" % [tag, BUFF_COLOR, effective, effective - base]
	if effective < base:
		return "%s [color=%s]%d (%d)[/color]" % [tag, DEBUFF_COLOR, effective, effective - base]
	return "%s %d" % [tag, effective]

func _stats_bbcode(unit: Node) -> String:
	return "   ".join([
		_stat_bbcode("ATK", unit.atk, unit.get_effective_stat(StatusEffect.StatType.ATK)),
		_stat_bbcode("DEF", unit.def_stat, unit.get_effective_stat(StatusEffect.StatType.DEF)),
		_stat_bbcode("SPD", unit.spd, unit.get_effective_stat(StatusEffect.StatType.SPD)),
	])

func _effects_bbcode(unit: Node) -> String:
	if unit.active_effects.is_empty():
		return "[color=gray]No effects[/color]"
	var lines: PackedStringArray = []
	for entry in unit.active_effects:
		var e: StatusEffect = entry["effect"]
		var turns: int = entry["turns_left"]
		var stat_name: String = StatusEffect.StatType.keys()[e.stat_affected]
		var color := DEBUFF_COLOR if e.is_debuff() else BUFF_COLOR
		var arrow := "v" if e.is_debuff() else "^"
		lines.append("[color=%s]%s %s  %s %+d  (%d turn%s)[/color]" % [
			color, arrow, e.display_name, stat_name, e.amount, turns, "" if turns == 1 else "s"])
	return "\n".join(lines)

# ---------------- Skill bar ----------------
# Shows the selected ally's (max 4) skills + ultimate during the planning phase.
# Click a button or press 1-4 / 5, then click the target on the grid. The tiles
# that will be hit are highlighted by PlayerInputHandler.

func _build_skill_bar() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_panel = PanelContainer.new()
	_skill_panel.visible = false
	holder.add_child(_skill_panel)
	_skill_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skill_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skill_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skill_panel.offset_bottom = -12
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	_skill_panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	_skill_hint = Label.new()
	_skill_hint.add_theme_font_size_override("font_size", 13)
	_skill_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_skill_hint)
	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 6)
	v.add_child(_skill_row)

func _update_skill_bar() -> void:
	var unit = input_handler.get("selected_unit") if input_handler else null
	var show: bool = turn_manager.current_phase == turn_manager.BattlePhase.PLANNING \
		and is_instance_valid(unit) and not (unit is EnemyNPC) and unit.is_alive()
	_skill_panel.visible = show
	if not show:
		return

	var skills: Array = unit.get_battle_skills()
	var ult: SkillData = unit.get_ultimate_skill()
	var sig: Array = [unit.get_instance_id()]
	for s in skills:
		sig.append(s.id)
	sig.append(ult.id if ult else "")
	sig.append(SkillDB.weapon_of(unit))
	sig.append(SkillDB.basic_skill(unit).id)
	if sig != _skill_sig:
		_skill_sig = sig
		_rebuild_skill_buttons(unit, skills, ult)

	for entry in _skill_buttons:
		var s: SkillData = entry["skill"]
		if s == null:
			continue   # the E special button has no skill
		var b: Button = entry["button"]
		b.disabled = not input_handler.can_use_skill(unit, s)
		b.set_pressed_no_signal(input_handler.active_skill == s)

	var active: SkillData = input_handler.active_skill
	if active:
		_skill_hint.text = "%s  -  left-click a target to cast, right-click to cancel" % active.display_name
	elif _skill_buttons.is_empty():
		_skill_hint.text = "No skills learned yet."
	else:
		_skill_hint.text = "Skills: 1-4  |  Q = basic attack  |  E = special (Lan: swap weapon, free)  |  5 = ultimate"

func _rebuild_skill_buttons(unit: Node, skills: Array, ult: SkillData) -> void:
	for c in _skill_row.get_children():
		_skill_row.remove_child(c)
		c.queue_free()
	_skill_buttons.clear()
	var basic := SkillDB.basic_skill(unit)
	_add_skill_button(basic, "[Q] %s\n%d AP" % [basic.display_name, basic.ap_cost], basic_icon)
	var w := SkillDB.weapon_of(unit)
	if w != "":
		var sp := Button.new()
		sp.text = "[E] Swap Weapon\nnow: %s  (free)" % w
		sp.icon = special_icon
		sp.focus_mode = Control.FOCUS_NONE
		sp.custom_minimum_size = Vector2(140, 50)
		sp.pressed.connect(func(): input_handler.do_special())
		_skill_row.add_child(sp)
		_skill_buttons.append({"button": sp, "skill": null})
	for i in range(skills.size()):
		var sk: SkillData = skills[i]
		var label: String = sk.display_name if sk.icon == null else ""   # icon set -> no name text, saves space
		_add_skill_button(sk, "[%d] %s\n%d SP   %d AP" % [i + 1, label, sk.sp_cost, sk.ap_cost], sk.icon)
	if ult:
		_add_skill_button(ult, "[5] %s\nULTIMATE   %d AP" % ["" if ult.icon else ult.display_name, ult.ap_cost], ult.icon)

func _add_skill_button(skill: SkillData, text: String, icon: Texture2D = null) -> void:
	var b := Button.new()
	b.text = text
	b.icon = icon
	if icon:
		b.expand_icon = true   # icon fills the button instead of a tiny corner glyph
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE       # so SPACE (execute turn) never presses a button
	b.custom_minimum_size = Vector2(140, 50)
	b.tooltip_text = skill.summary() + "\n" + skill.description
	b.pressed.connect(func(): input_handler.toggle_skill(skill))
	_skill_row.add_child(b)
	_skill_buttons.append({"button": b, "skill": skill})
