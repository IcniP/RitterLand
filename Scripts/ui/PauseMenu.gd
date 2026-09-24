# File: res://Scripts/ui/PauseMenu.gd
# Esc opens/closes the pause menu:
#   Party       - see everyone you own and pick up to 3 for the party
#   Characters  - level / XP, spend stat points, change equipment
#   Save / Load - 3 slots
# Also shows a toast after a fight with the XP earned and any level-ups.
# Built entirely in code - just add this as a CanvasLayer.
class_name PauseMenu
extends CanvasLayer

var _root: Control
var _views: Dictionary = {}          # name -> Control
var _current_view: String = "main"

# main
var _resume_button: Button
var _characters_button: Button
# party
var _party_list: VBoxContainer
var _party_count: Label
var _party_note: Label
# characters
var _char_select: OptionButton
var _char_ids: Array = []
var _sel_char: String = "player"
var _char_note: Label
var _char_body: VBoxContainer
# save / load
var _save_list: VBoxContainer
var _save_status: Label
# toast
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the tree is paused
	layer = 20
	_build_ui()
	_build_toast()
	_root.visible = false
	Global.progression_changed.connect(_on_progression_changed)
	Global.xp_awarded.connect(_on_xp_awarded)

# ---------------- Open / close ----------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		if _current_view != "main":
			_show_view("main")
		else:
			_close()
	else:
		if _dialogue_running():
			return
		_open()
	get_viewport().set_input_as_handled()

func _dialogue_running() -> bool:
	var d := get_node_or_null("/root/Dialogic")
	return d != null and "current_timeline" in d and d.current_timeline != null

func _in_combat() -> bool:
	return Global.game_state == Global.GameState.COMBAT

func _open() -> void:
	if Global.roster and not Global.roster.roster_changed.is_connected(_on_progression_changed):
		Global.roster.roster_changed.connect(_on_progression_changed)
	get_tree().paused = true
	_root.visible = true
	_show_view("main")

func _close() -> void:
	_root.visible = false
	get_tree().paused = false

func _show_view(view: String) -> void:
	_current_view = view
	for v in _views:
		_views[v].visible = (v == view)
	match view:
		"main":
			var points := _any_unspent_points()
			_characters_button.text = "Characters  (stat points available!)" if points else "Characters"
			_resume_button.grab_focus()
		"party": _refresh_party()
		"characters":
			_populate_char_select()
			_refresh_char()
		"saves":
			_save_status.text = ""
			_refresh_saves()

func _on_progression_changed() -> void:
	if not _root.visible:
		return
	match _current_view:
		"party": _refresh_party()
		"characters": _refresh_char()
		"saves": _refresh_saves()

func _any_unspent_points() -> bool:
	for id in _all_character_ids():
		if Global.get_progress(id).stat_points > 0:
			return true
	return false

func _all_character_ids() -> Array:
	var ids: Array = ["player"]
	if Global.roster:
		for e in Global.roster.entries:
			if e and e.unlocked:
				ids.append(e.member_id)
	return ids

# ---------------- Building blocks ----------------

func _margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(on_press)
	return b

func _label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	return l

func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _make_scroll(min_height: int) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, min_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll

func _build_ui() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	center.add_child(panel)
	var margin := _margin(18)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)

	_build_main_view(stack)
	_build_party_view(stack)
	_build_char_view(stack)
	_build_save_view(stack)

func _build_main_view(stack: VBoxContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	stack.add_child(v)
	_views["main"] = v
	var title := _label("PAUSED", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_resume_button = _button("Resume", _close)
	v.add_child(_resume_button)
	v.add_child(_button("Party", func(): _show_view("party")))
	_characters_button = _button("Characters", func(): _show_view("characters"))
	v.add_child(_characters_button)
	v.add_child(_button("Save / Load", func(): _show_view("saves")))
	v.add_child(_button("Quit Game", func(): get_tree().quit()))

func _build_party_view(stack: VBoxContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	stack.add_child(v)
	_views["party"] = v
	var header := HBoxContainer.new()
	v.add_child(header)
	var t := _label("PARTY", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	_party_count = _label("", 20)
	header.add_child(_party_count)
	_party_note = _label("", 16, Color(1, 0.8, 0.4))
	v.add_child(_party_note)
	var scroll := _make_scroll(400)
	v.add_child(scroll)
	_party_list = VBoxContainer.new()
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_party_list)
	v.add_child(_button("Back", func(): _show_view("main")))

func _build_char_view(stack: VBoxContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	stack.add_child(v)
	_views["characters"] = v
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	v.add_child(header)
	header.add_child(_label("CHARACTERS", 24))
	_char_select = OptionButton.new()
	_char_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_select.item_selected.connect(func(idx: int):
		_sel_char = _char_ids[idx]
		_refresh_char())
	header.add_child(_char_select)
	_char_note = _label("", 16, Color(1, 0.8, 0.4))
	v.add_child(_char_note)
	var scroll := _make_scroll(430)
	v.add_child(scroll)
	_char_body = VBoxContainer.new()
	_char_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_char_body)
	v.add_child(_button("Back", func(): _show_view("main")))

func _build_save_view(stack: VBoxContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	stack.add_child(v)
	_views["saves"] = v
	v.add_child(_label("SAVE / LOAD", 24))
	_save_status = _label("", 16, Color(0.6, 1, 0.6))
	v.add_child(_save_status)
	_save_list = VBoxContainer.new()
	_save_list.add_theme_constant_override("separation", 8)
	v.add_child(_save_list)
	v.add_child(_button("Back", func(): _show_view("main")))

# ---------------- Party view ----------------

func _refresh_party() -> void:
	_clear(_party_list)
	var in_combat := _in_combat()
	var roster = Global.roster
	var active_count := 0
	if roster:
		active_count = roster.get_active_entries().size()
	_party_count.text = "%d / %d" % [active_count, Global.MAX_PARTY_SIZE]
	_party_note.text = "The party can't be changed during combat." if in_combat else ""

	var p = Global.player
	if is_instance_valid(p):
		_party_list.add_child(_make_card(String(p.name),
			"Lv %d  -  Leader, always in the party" % p.level,
			{"hp": p.hp, "max_hp": p.max_hp, "sp": p.sp, "max_sp": p.max_sp,
			 "atk": p.atk, "def_stat": p.def_stat, "spd": p.spd},
			p.portrait_icon, null, false))

	if roster == null:
		_party_note.text = "No PartyRoster node found in the scene."
		return

	for entry in roster.entries:
		if entry == null:
			continue
		if not entry.unlocked:
			_party_list.add_child(_make_card("???", "Locked", {}, null, null, true))
			continue
		var stats: Dictionary = roster.get_preview(entry)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 36)
		if entry.in_party:
			btn.text = "Remove from party"
		else:
			btn.text = "Add to party"
			btn.disabled = active_count >= Global.MAX_PARTY_SIZE
		if in_combat:
			btn.disabled = true
		var id: String = entry.member_id
		var now_in: bool = entry.in_party
		btn.pressed.connect(func(): roster.set_in_party(id, not now_in))
		var lvl: int = Global.get_progress(id).level
		var sub := "Lv %d  -  %s" % [lvl, "In party" if entry.in_party else "Not in party"]
		_party_list.add_child(_make_card(entry.display_name, sub, stats, stats.get("portrait"), btn, false))

func _make_card(title: String, subtitle: String, s: Dictionary, portrait: Texture2D, action: Button, dim: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dim:
		card.modulate = Color(1, 1, 1, 0.45)
	var margin := _margin(10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	if portrait:
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.custom_minimum_size = Vector2(64, 64)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(title, 20))
	info.add_child(_label(subtitle, 16, Color(0.75, 0.75, 0.75)))
	if not s.is_empty():
		info.add_child(_label("HP %d/%d    SP %d/%d\nATK %d    DEF %d    SPD %d" % [
			s.get("hp", s.get("max_hp", 0)), s.get("max_hp", 0),
			s.get("sp", s.get("max_sp", 0)), s.get("max_sp", 0),
			s.get("atk", 0), s.get("def_stat", 0), s.get("spd", 0)]))
	if action:
		row.add_child(action)
	return card

# ---------------- Characters view (level / points / equipment) ----------------

func _populate_char_select() -> void:
	_char_ids = _all_character_ids()
	if not _char_ids.has(_sel_char):
		_sel_char = "player"
	_char_select.clear()
	for id in _char_ids:
		_char_select.add_item(Global.character_name(id))
	_char_select.select(_char_ids.find(_sel_char))

func _refresh_char() -> void:
	_clear(_char_body)
	var in_combat := _in_combat()
	_char_note.text = "Stats and equipment can't be changed during combat." if in_combat else ""

	var id := _sel_char
	var info := Global.get_character_info(id)
	var prog := Global.get_progress(id)
	var stats: Dictionary = info["stats"]
	var base: Dictionary = info["base"]
	var gear := Progression.equipment_bonus(prog)

	# --- Level / XP ---
	_char_body.add_child(_label("%s    Lv %d" % [info["name"], prog.level], 22))
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 10)
	_char_body.add_child(xp_row)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if prog.level >= Progression.MAX_LEVEL:
		bar.max_value = 1
		bar.value = 1
		xp_row.add_child(bar)
		xp_row.add_child(_label("MAX LEVEL", 14))
	else:
		bar.max_value = Progression.xp_to_next(prog.level)
		bar.value = prog.xp
		xp_row.add_child(bar)
		xp_row.add_child(_label("XP %d / %d" % [prog.xp, Progression.xp_to_next(prog.level)], 14))
	var pts_color := Color(1, 0.9, 0.3) if prog.stat_points > 0 else Color(0.75, 0.75, 0.75)
	_char_body.add_child(_label("Stat points: %d" % prog.stat_points, 18, pts_color))

	# --- Stats + allocation ---
	_char_body.add_child(HSeparator.new())
	for s in Progression.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_char_body.add_child(row)
		var name_l := _label(Progression.STAT_LABELS[s], 18)
		name_l.custom_minimum_size = Vector2(50, 0)
		row.add_child(name_l)
		var val_l := _label(str(stats.get(s, 0)), 18, Color(1, 0.95, 0.6))
		val_l.custom_minimum_size = Vector2(50, 0)
		row.add_child(val_l)
		var parts: PackedStringArray = ["base %d" % int(base.get(s, 0))]
		var lvl_bonus: int = int(Progression.LEVEL_GROWTH[s]) * (prog.level - 1)
		var pt_bonus: int = int(prog.allocated.get(s, 0)) * int(Progression.POINT_VALUE[s])
		if lvl_bonus != 0:
			parts.append("level +%d" % lvl_bonus)
		if pt_bonus != 0:
			parts.append("points +%d" % pt_bonus)
		if int(gear.get(s, 0)) != 0:
			parts.append("gear %+d" % int(gear[s]))
		var brk := _label("(" + ", ".join(parts) + ")", 13, Color(0.7, 0.7, 0.7))
		brk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(brk)
		var cost: int = Progression.POINT_COST[s]
		var btn := Button.new()
		btn.text = "+%d  (%d pt)" % [Progression.POINT_VALUE[s], cost]
		btn.custom_minimum_size = Vector2(110, 30)
		btn.disabled = in_combat or prog.stat_points < cost
		var stat_name: String = s
		btn.pressed.connect(func(): Global.allocate_point(id, stat_name))
		row.add_child(btn)

	# --- Equipment ---
	_char_body.add_child(HSeparator.new())
	_char_body.add_child(_label("Equipment", 20))
	for slot in Progression.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_char_body.add_child(row)
		var sl := _label(Progression.SLOT_LABELS[slot], 16)
		sl.custom_minimum_size = Vector2(110, 0)
		row.add_child(sl)

		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.disabled = in_combat
		var ids: Array = [""]
		opt.add_item("(empty)")
		var equipped: String = prog.equipment.get(slot, "")
		for item_id in ItemDB.ids_for_slot_type(Progression.slot_type(slot)):
			# Show items that are free, plus the one already in this slot.
			if item_id != equipped and Global.available_count(item_id, id, slot) < 1:
				continue
			var item := ItemDB.get_item(item_id)
			opt.add_item("%s   (%s)" % [item.display_name, ItemDB.bonus_text(item)])
			ids.append(item_id)
		opt.select(maxi(ids.find(equipped), 0))
		opt.item_selected.connect(func(idx: int): Global.equip(id, slot, ids[idx]))
		row.add_child(opt)

	# --- Skills (max 4 equipped; weapon users like Lan get one bar per weapon) ---
	_char_body.add_child(HSeparator.new())
	_char_body.add_child(_label("Skills   (equip up to %d per bar - using skills charges the ultimate)" % SkillDB.MAX_LOADOUT, 20))
	var unlocked: Array = SkillDB.unlocked_skills(id, prog.level)
	var bars: Array = SkillDB.SWAP.keys() if SkillDB.START_WEAPON.has(id) else [""]
	for w in bars:
		var fits: Array = unlocked.filter(func(sk): return SkillDB._fits(sk, w)) if w != "" else unlocked
		var cur_bar: Array = SkillDB.get_loadout(id, w).map(func(x): return x.id)
		if w != "":
			_char_body.add_child(_label("%s bar   (magic skills use the same slot in both bars)" % w.capitalize(), 16, Color(0.9, 0.8, 0.5)))
		for i in range(SkillDB.MAX_LOADOUT):
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 10)
			_char_body.add_child(srow)
			var sl2 := _label("Skill %d" % (i + 1), 16)
			sl2.custom_minimum_size = Vector2(110, 0)
			srow.add_child(sl2)
			var sopt := OptionButton.new()
			sopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sopt.disabled = in_combat
			var sids: Array = [""]
			sopt.add_item("(empty)")
			for sk in fits:
				sopt.add_item("%s%s   (%s)" % [sk.display_name, "  [shared]" if w != "" and sk.weapon == "" else "", sk.summary()])
				sids.append(sk.id)
			var cur := ""
			if prog.loadout_customized and w != "":
				var wl: Array = prog.weapon_loadout.get(w, [])
				cur = str(wl[i]) if i < wl.size() else ""
			elif prog.loadout_customized:
				cur = str(prog.skill_loadout[i]) if i < prog.skill_loadout.size() else ""
			elif i < cur_bar.size():
				cur = cur_bar[i]
			sopt.select(maxi(sids.find(cur), 0))
			var slot_i: int = i
			var weapon_w: String = w
			sopt.item_selected.connect(func(idx: int): Global.set_skill_slot(id, slot_i, sids[idx], weapon_w))
			srow.add_child(sopt)

	_char_body.add_child(_label("All skills (higher level = stronger)", 16, Color(0.8, 0.8, 0.8)))
	for sk in SkillDB.skills_for_character(id):
		var learned: bool = sk.min_level <= prog.level
		var txt := "Lv %d   %s%s   -   %s" % [sk.min_level, sk.display_name,
			"   [ULTIMATE]" if sk.is_ultimate else "", sk.summary()]
		var sl3 := _label(txt, 13, Color.WHITE if learned else Color(0.5, 0.5, 0.5))
		sl3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl3.custom_minimum_size = Vector2(620, 0)
		_char_body.add_child(sl3)

# ---------------- Save / load ----------------

func _refresh_saves() -> void:
	_clear(_save_list)
	var in_combat := _in_combat()
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var info := SaveSystem.get_slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_save_list.add_child(row)
		var text := "Slot %d  -  Empty" % slot
		if not info.is_empty():
			text = "Slot %d  -  Lv %d  -  %s" % [slot, info["level"], info["saved_at"]]
		var l := _label(text, 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var save_btn := _button("Save", func(): _do_save(slot))
		save_btn.custom_minimum_size = Vector2(90, 40)
		save_btn.disabled = in_combat
		row.add_child(save_btn)
		var load_btn := _button("Load", func(): _do_load(slot))
		load_btn.custom_minimum_size = Vector2(90, 40)
		load_btn.disabled = in_combat or info.is_empty()
		row.add_child(load_btn)
	if in_combat:
		_save_status.text = "Saving and loading are disabled during combat."

func _do_save(slot: int) -> void:
	if SaveSystem.save_game(slot):
		_save_status.text = "Saved to slot %d." % slot
	else:
		_save_status.text = "Save failed! (see the Output panel)"
	_refresh_saves()

func _do_load(slot: int) -> void:
	if SaveSystem.load_game(slot):
		_close()
		_show_toast("Loaded slot %d." % slot)
	else:
		_save_status.text = "Load failed."
		_refresh_saves()

# ---------------- XP toast ----------------

func _build_toast() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	holder.add_child(_toast_panel)
	var m := _margin(12)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(m)
	_toast_label = _label("", 18)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func(): _toast_panel.visible = false)
	add_child(_toast_timer)

func _show_toast(text: String, seconds: float = 6.0) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.reset_size()
	# Bottom centre of the screen.
	var vp := get_viewport().get_visible_rect().size
	_toast_panel.position = Vector2((vp.x - _toast_panel.size.x) / 2.0, vp.y - _toast_panel.size.y - 40)
	_toast_timer.start(seconds)

func _on_xp_awarded(summary: Dictionary) -> void:
	var lines: PackedStringArray = ["Victory!   +%d XP" % summary["xp"]]
	var any_points := false
	for r in summary["results"]:
		if r["levels_gained"] > 0:
			lines.append("%s reached Lv %d   (+%d stat points)" % [r["name"], r["level"], r["points"]])
			any_points = true
		if r.get("new_skills", []).size() > 0:
			lines.append("%s learned: %s" % [r["name"], ", ".join(PackedStringArray(r["new_skills"]))])
	if any_points:
		lines.append("Press Esc > Characters to spend your stat points.")
	_show_toast("\n".join(lines), 8.0)
