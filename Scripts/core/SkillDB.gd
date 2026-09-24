# File: res://Scripts/core/SkillDB.gd
# All skills + which character can learn which. Add skills in _build(), and
# list them per character in CHARACTER_SKILLS (key = character id: "player" for
# Lan, the PartyMemberEntry.member_id for the others).
# Higher min_level = stronger skill.
class_name SkillDB
extends RefCounted

const MAX_LOADOUT := 4

const CHARACTER_SKILLS := {
	# Lan: longsword (precise), zweihander (heavy/wide), wind shir (magic)
	"player": ["zornhau", "half_sword", "krumphau", "zwerchhau",          # longsword
		"cross_slash", "montante_crash", "zweihander_sweep", "storm_zweihander",   # montante
		"wind_blade", "vortex", "tailwind", "gale_cleave", "cyclone_prison",       # wind shir (shared slots)
		"crimson_finale"],
	# Ilia: rapier (SPD-based), illusion shir (debuff/control)
	"ilia": ["fleche", "mirage_veil", "double_thrust", "phantom_step", "illusion_snare",
		"dancing_blades", "hundred_faces", "meteor_rain"],
}

# Basic attack per character. reach = tiles (2+ must be in a straight line),
# power = x ATK, spd = x SPD added, hits = split into this many strikes.
const BASIC := {
	"player:longsword": {"name": "Longsword Cut", "reach": 1, "power": 1.0, "spd": 0.0, "hits": 1, "shape": "single"},
	# montante: hits a 3x3 around an adjacent tile you pick
	"player:montante": {"name": "Montante Swing", "reach": 1, "power": 0.7, "spd": 0.0, "hits": 1, "shape": "area", "radius": 1, "splash": 1.0},
	"ilia": {"name": "Rapier Thrust", "reach": 2, "power": 0.6, "spd": 0.5, "hits": 1, "shape": "proj"},
}
const BASIC_DEFAULT := {"name": "Strike", "reach": 1, "power": 1.0, "spd": 0.0, "hits": 1, "shape": "single"}

const START_WEAPON := {"player": "longsword"}
const SWAP := {"longsword": "montante", "montante": "longsword"}

static func weapon_of(actor: Node) -> String:
	if actor.weapon == "":
		actor.weapon = START_WEAPON.get(actor.character_id, "")
	return actor.weapon

static func basic_for(actor: Node) -> Dictionary:
	var w := weapon_of(actor)
	return BASIC.get(actor.character_id + (":" + w if w != "" else ""), BASIC.get(actor.character_id, BASIC_DEFAULT))

static var _basic_cache: Dictionary = {}

## The basic attack as a SkillData (0 SP, 1 AP) so it reuses skill aiming + grid highlight (key Q).
static func basic_skill(actor: Node) -> SkillData:
	var w := weapon_of(actor)
	var key: String = actor.character_id + (":" + w if w != "" else "")
	if not _basic_cache.has(key):
		var b := basic_for(actor)
		var sk := SkillData.new()
		sk.id = "basic:" + key
		sk.display_name = b.name
		sk.category = SkillData.Category.PHYSICAL
		sk.shape = {"single": SkillData.Shape.SINGLE, "area": SkillData.Shape.AREA, "proj": SkillData.Shape.PROJECTILE}[b.get("shape", "single")]
		sk.sp_cost = 0
		sk.ap_cost = 1
		sk.power = b.power
		sk.spd_scale = b.spd
		sk.hits = b.hits
		sk.cast_range = b.reach
		sk.radius = b.get("radius", 0)
		sk.charge_gain = 0.0
		sk.description = "Basic attack."
		_basic_cache[key] = sk
	return _basic_cache[key]

static func basic_damage(actor: Node) -> int:
	var b := basic_for(actor)
	return int(actor.get_effective_stat(StatusEffect.StatType.ATK) * b.power \
		+ actor.get_effective_stat(StatusEffect.StatType.SPD) * b.spd)

static func basic_in_reach(actor: Node, from: Vector2i, to: Vector2i) -> bool:
	var d := absi(from.x - to.x) + absi(from.y - to.y)
	var reach: int = basic_for(actor).reach
	return d >= 1 and d <= reach and (d == 1 or from.x == to.x or from.y == to.y)
const DEFAULT_SKILLS := ["power_strike", "spark"]

static var _skills: Dictionary = {}

static func _ensure() -> void:
	if _skills.is_empty():
		_build()

static func _add(d: Dictionary) -> void:
	var s := SkillData.new()
	for k in d:
		s.set(k, d[k])
	_skills[s.id] = s

static func _effect(id: String, name: String, stat: StatusEffect.StatType, amount: int, turns: int) -> StatusEffect:
	var e := StatusEffect.new()
	e.id = id
	e.display_name = name
	e.stat_affected = stat
	e.amount = amount
	e.duration_turns = turns
	return e

static func _build() -> void:
	var P := SkillData.Category.PHYSICAL
	var M := SkillData.Category.MAGIC
	var SINGLE := SkillData.Shape.SINGLE
	var AREA := SkillData.Shape.AREA
	var PROJ := SkillData.Shape.PROJECTILE
	var ALLY := SkillData.TargetSide.ALLIES

	# ---- Lan: longsword (single target) ----
	_add({"id": "zornhau", "display_name": "Zornhau", "category": P, "shape": SINGLE, "weapon": "longsword",
		"min_level": 1, "sp_cost": 2, "ap_cost": 1, "power": 1.6, "cast_range": 1,
		"description": "Wrath cut, a strong diagonal strike on an adjacent enemy."})
	_add({"id": "half_sword", "display_name": "Half-Sword Thrust", "category": P, "shape": SINGLE, "weapon": "longsword",
		"min_level": 3, "sp_cost": 3, "ap_cost": 1, "power": 1.5, "cast_range": 2, "def_pierce": 0.4,
		"description": "Halbschwert thrust that reaches two tiles."})
	_add({"id": "krumphau", "display_name": "Krumphau", "category": P, "shape": SINGLE, "weapon": "longsword",
		"min_level": 6, "sp_cost": 4, "ap_cost": 1, "power": 1.4, "cast_range": 1, "def_pierce": 0.7,
		"description": "Crooked cut that slips past armor."})
	_add({"id": "zwerchhau", "display_name": "Zwerchhau", "category": P, "shape": SINGLE, "weapon": "longsword",
		"min_level": 9, "sp_cost": 8, "ap_cost": 2, "power": 2.8, "cast_range": 1, "def_pierce": 0.5,
		"description": "Cross cut that ends a duel."})
	# ---- Lan: montante (area) ----
	_add({"id": "montante_crash", "display_name": "Montante Crash", "category": P, "shape": AREA, "weapon": "montante",
		"min_level": 3, "sp_cost": 4, "ap_cost": 2, "power": 1.4, "cast_range": 2, "radius": 1,
		"description": "Bring the great blade down on a tile up to 2 away."})
	_add({"id": "cross_slash", "display_name": "Montante Cross", "category": P, "shape": AREA, "weapon": "montante",
		"min_level": 1, "sp_cost": 5, "ap_cost": 2, "power": 1.3, "cast_range": 0, "radius": 1,
		"description": "Slash everything around you with the great blade."})
	_add({"id": "zweihander_sweep", "display_name": "Montante Sweep", "category": P, "shape": AREA, "weapon": "montante",
		"min_level": 6, "sp_cost": 8, "ap_cost": 2, "power": 1.7, "cast_range": 0, "radius": 2,
		"description": "A huge horizontal sweep."})
	_add({"id": "storm_zweihander", "display_name": "Montante Storm", "category": P, "shape": AREA, "weapon": "montante",
		"min_level": 9, "sp_cost": 10, "ap_cost": 2, "power": 2.4, "cast_range": 3, "radius": 1,
		"description": "The whole weight of the blade crashes down on a tile you pick."})
	# ---- Lan: wind shir (crowd control, any weapon) ----
	_add({"id": "wind_blade", "display_name": "Wind Blade", "category": M, "shape": PROJ,
		"min_level": 2, "sp_cost": 3, "ap_cost": 1, "power": 1.0, "cast_range": 5, "def_pierce": 0.5,
		"description": "A cutting wind flies in a straight line."})
	_add({"id": "vortex", "display_name": "Vortex", "category": M, "shape": AREA,
		"min_level": 3, "sp_cost": 10, "ap_cost": 2, "power": 0.4, "cast_range": 4, "radius": 2, "pull": 2, "def_pierce": 0.5,
		"description": "Drags enemies toward the centre, setting up an area skill."})
	_add({"id": "tailwind", "display_name": "Tailwind", "category": M, "shape": AREA, "target_side": ALLY,
		"min_level": 5, "sp_cost": 4, "ap_cost": 1, "power": 0.0, "cast_range": 0, "radius": 0,
		"effect": _effect("tailwind", "Tailwind", StatusEffect.StatType.SPD, 2, 3),
		"description": "Wind at your back (SPD +2 for 3 turns, self)."})
	_add({"id": "gale_cleave", "display_name": "Gale Cleave", "category": M, "shape": AREA,
		"min_level": 9, "sp_cost": 8, "ap_cost": 2, "power": 1.8, "cast_range": 4, "radius": 1, "def_pierce": 0.5,
		"description": "A whirlwind lands on a tile you pick."})
	_add({"id": "cyclone_prison", "display_name": "Cyclone Prison", "category": M, "shape": AREA,
		"min_level": 11, "sp_cost": 14, "ap_cost": 2, "power": 0.8, "cast_range": 5, "radius": 2, "pull": 3, "def_pierce": 0.7,
		"effect": _effect("cyclone_prison", "Caught", StatusEffect.StatType.SPD, -2, 2),
		"description": "Advanced shir: hauls everyone into a knot and slows them."})

	# ---- Ilia: rapier (SPD-based) ----
	_add({"id": "fleche", "display_name": "Fleche", "category": P, "shape": PROJ,
		"min_level": 1, "sp_cost": 2, "ap_cost": 1, "power": 0.5, "spd_scale": 0.8, "cast_range": 3,
		"description": "A lunging rapier dash down a line. Damage scales with SPD."})
	_add({"id": "double_thrust", "display_name": "Double Thrust", "category": P, "shape": SINGLE,
		"min_level": 3, "sp_cost": 4, "ap_cost": 1, "power": 0.5, "spd_scale": 1.0, "hits": 2, "cast_range": 2,
		"description": "Two quick thrusts. Scales with SPD."})
	_add({"id": "dancing_blades", "display_name": "Dancing Blades", "category": P, "shape": AREA,
		"min_level": 7, "sp_cost": 8, "ap_cost": 2, "power": 0.6, "spd_scale": 1.2, "hits": 3, "cast_range": 0, "radius": 1,
		"description": "A whirl of thrusts around you. Scales with SPD."})
	# ---- Ilia: illusion shir (magic control) ----
	_add({"id": "mirage_veil", "display_name": "Mirage Veil", "category": M, "shape": SINGLE,
		"min_level": 2, "sp_cost": 3, "ap_cost": 1, "power": 0.3, "cast_range": 4, "def_pierce": 1.0,
		"effect": _effect("mirage_veil", "Blinded", StatusEffect.StatType.ATK, -3, 3),
		"description": "An illusion clouds the target's aim (ATK -3 for 3 turns)."})
	_add({"id": "phantom_step", "display_name": "Phantom Step", "category": M, "shape": AREA, "target_side": ALLY,
		"min_level": 4, "sp_cost": 4, "ap_cost": 1, "power": 0.0, "cast_range": 0, "radius": 0,
		"effect": _effect("phantom_step", "Phantom", StatusEffect.StatType.SPD, 3, 3),
		"description": "Blur into afterimages (SPD +3 for 3 turns, self)."})
	_add({"id": "illusion_snare", "display_name": "Illusion Snare", "category": M, "shape": AREA,
		"min_level": 6, "sp_cost": 6, "ap_cost": 1, "power": 0.4, "cast_range": 4, "radius": 1, "def_pierce": 1.0,
		"effect": _effect("illusion_snare", "Slowed", StatusEffect.StatType.SPD, -2, 3),
		"description": "A false floor drags enemies down (SPD -2 for 3 turns)."})
	_add({"id": "hundred_faces", "display_name": "Hundred Faces", "category": M, "shape": AREA,
		"min_level": 10, "sp_cost": 10, "ap_cost": 2, "power": 0.5, "spd_scale": 1.5, "hits": 4, "cast_range": 4, "radius": 1, "def_pierce": 0.7,
		"effect": _effect("hundred_faces", "Confused", StatusEffect.StatType.ATK, -2, 2),
		"description": "Illusory copies strike from every side. Scales with SPD."})

	# ---- Ultimates (cost a full charge bar) ----
	_add({"id": "crimson_finale", "display_name": "Crimson Finale", "category": P, "shape": AREA,
		"min_level": 3, "sp_cost": 0, "ap_cost": 2, "power": 4.0, "cast_range": 4, "radius": 2,
		"charge_gain": 0.0, "is_ultimate": true, "description": "Lan's ultimate."})
	_add({"id": "meteor_rain", "display_name": "Meteor Rain", "category": M, "shape": AREA,
		"min_level": 3, "sp_cost": 0, "ap_cost": 2, "power": 4.5, "cast_range": 5, "radius": 2, "def_pierce": 0.5,
		"charge_gain": 0.0, "is_ultimate": true, "description": "Ilia's ultimate."})

# ---------------- Lookups ----------------

static func get_skill(id: String) -> SkillData:
	_ensure()
	return _skills.get(id)

## Every skill this character can ever learn (incl. ultimate), lowest level first.
static func skills_for_character(character_id: String) -> Array:
	_ensure()
	var list: Array = []
	for id in CHARACTER_SKILLS.get(character_id, DEFAULT_SKILLS):
		var s: SkillData = _skills.get(id)
		if s:
			list.append(s)
	list.sort_custom(func(a, b): return a.min_level < b.min_level)
	return list

## Learned normal skills (no ultimate) at this level.
static func unlocked_skills(character_id: String, level: int) -> Array:
	return skills_for_character(character_id).filter(func(s): return not s.is_ultimate and s.min_level <= level)

static func get_ultimate(character_id: String, level: int) -> SkillData:
	for s in skills_for_character(character_id):
		if s.is_ultimate and s.min_level <= level:
			return s
	return null

static func _fits(s: SkillData, weapon: String) -> bool:
	return s.weapon == "" or s.weapon == weapon   # magic (weapon "") fits every weapon

## Default bar for a weapon: its own skills first, then magic, 4 max.
static func _default_bar(character_id: String, weapon: String, level: int) -> Array:
	var un := unlocked_skills(character_id, level)
	var own := un.filter(func(s): return s.weapon == weapon)
	var magic := un.filter(func(s): return s.weapon == "")
	return (own + magic).slice(0, MAX_LOADOUT)

## The (max 4) skills equipped for battle. Weapon users (Lan) have one bar per weapon.
static func get_loadout(character_id: String, weapon: String = "") -> Array:
	if character_id == "":
		return []
	var prog: CharacterProgress = Global.get_progress(character_id)
	var unlocked := unlocked_skills(character_id, prog.level)
	if weapon != "":
		if not prog.loadout_customized:
			return _default_bar(character_id, weapon, prog.level)
		var wl: Array = []
		for id in prog.weapon_loadout.get(weapon, []):
			var s := get_skill(str(id))
			if s and unlocked.has(s) and _fits(s, weapon):
				wl.append(s)
		return wl
	if not prog.loadout_customized:
		var best := unlocked.duplicate()
		best.reverse()   # highest level first
		return best.slice(0, MAX_LOADOUT)
	var list: Array = []
	for id in prog.skill_loadout:
		var s := get_skill(str(id))
		if s and unlocked.has(s):
			list.append(s)
	return list

## Turn the automatic loadout into an editable 4-slot one.
static func ensure_customized(character_id: String) -> void:
	var prog: CharacterProgress = Global.get_progress(character_id)
	# weapon users also need their per-weapon bars (older saves were customised without them)
	if prog.loadout_customized and not (START_WEAPON.has(character_id) and prog.weapon_loadout.is_empty()):
		return
	if START_WEAPON.has(character_id):
		for w in SWAP:
			var ids: Array = _default_bar(character_id, w, prog.level).map(func(x): return x.id)
			while ids.size() < MAX_LOADOUT:
				ids.append("")
			prog.weapon_loadout[w] = ids
		prog.loadout_customized = true
		return
	prog.skill_loadout = []
	for s in get_loadout(character_id):
		prog.skill_loadout.append(s.id)
	while prog.skill_loadout.size() < MAX_LOADOUT:
		prog.skill_loadout.append("")
	prog.loadout_customized = true

## After a level-up: fill EMPTY slots of a customised loadout with new skills.
## Returns the names of the skills learned between the two levels.
static func on_level_up(character_id: String, old_level: int, new_level: int) -> Array:
	var learned: Array = []
	var prog: CharacterProgress = Global.get_progress(character_id)
	for s in skills_for_character(character_id):
		if s.min_level > old_level and s.min_level <= new_level:
			learned.append(s.display_name + (" (Ultimate)" if s.is_ultimate else ""))
			if prog.loadout_customized and not s.is_ultimate:
				if START_WEAPON.has(character_id):
					ensure_customized(character_id)
					_fill_weapon_slot(prog, s)
				else:
					var slot: int = prog.skill_loadout.find("")
					if slot != -1:
						prog.skill_loadout[slot] = s.id
	return learned

## New skill on a weapon user's customised bars: a weapon skill goes in that weapon's first
## empty slot; a magic skill needs a slot that is empty in EVERY weapon bar.
static func _fill_weapon_slot(prog: CharacterProgress, s: SkillData) -> void:
	var ws: Array = [s.weapon] if s.weapon != "" else SWAP.keys()
	for i in MAX_LOADOUT:
		if ws.all(func(w): return prog.weapon_loadout[w][i] == ""):
			for w in ws:
				prog.weapon_loadout[w][i] = s.id
			return
