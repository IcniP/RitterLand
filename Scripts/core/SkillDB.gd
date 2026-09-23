# File: res://Scripts/core/SkillDB.gd
# All skills + which character can learn which. Add skills in _build(), and
# list them per character in CHARACTER_SKILLS (key = character id: "player" for
# Lan, the PartyMemberEntry.member_id for the others).
# Higher min_level = stronger skill.
class_name SkillDB
extends RefCounted

const MAX_LOADOUT := 4

const CHARACTER_SKILLS := {
	"player": ["power_strike", "spark", "fireball", "battle_cry", "crimson_finale",
		"cross_slash", "shockwave", "whirlwind", "blade_storm"],
	"ilia": ["spark", "fireball", "weaken", "battle_cry", "meteor_rain",
		"flame_burst", "inferno", "power_strike"],
}
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

	# ---- Physical ----
	_add({"id": "power_strike", "display_name": "Power Strike", "category": P, "shape": SINGLE,
		"min_level": 1, "sp_cost": 2, "ap_cost": 1, "power": 1.6, "cast_range": 1,
		"description": "A heavy blow to an adjacent enemy."})
	_add({"id": "cross_slash", "display_name": "Cross Slash", "category": P, "shape": AREA,
		"min_level": 3, "sp_cost": 4, "ap_cost": 2, "power": 1.3, "cast_range": 0, "radius": 1,
		"description": "Slash everything around you."})
	_add({"id": "shockwave", "display_name": "Shockwave", "category": P, "shape": PROJ,
		"min_level": 5, "sp_cost": 5, "ap_cost": 1, "power": 1.5, "cast_range": 4,
		"description": "A wave of force that flies in a straight line."})
	_add({"id": "whirlwind", "display_name": "Whirlwind", "category": P, "shape": AREA,
		"min_level": 8, "sp_cost": 8, "ap_cost": 2, "power": 1.6, "cast_range": 0, "radius": 2,
		"description": "A wide spinning attack."})
	_add({"id": "blade_storm", "display_name": "Blade Storm", "category": P, "shape": SINGLE,
		"min_level": 12, "sp_cost": 10, "ap_cost": 2, "power": 3.0, "cast_range": 2,
		"description": "A devastating flurry on one target."})

	# ---- Magic ----
	_add({"id": "spark", "display_name": "Spark", "category": M, "shape": SINGLE,
		"min_level": 1, "sp_cost": 3, "ap_cost": 1, "power": 1.4, "cast_range": 3, "def_pierce": 0.5,
		"description": "A small bolt that partly ignores armor."})
	_add({"id": "fireball", "display_name": "Fireball", "category": M, "shape": PROJ,
		"min_level": 2, "sp_cost": 4, "ap_cost": 1, "power": 1.8, "cast_range": 5, "def_pierce": 0.5,
		"description": "Flies straight in one direction and burns the first enemy it meets."})
	_add({"id": "weaken", "display_name": "Weaken", "category": M, "shape": SINGLE,
		"min_level": 4, "sp_cost": 4, "ap_cost": 1, "power": 0.5, "cast_range": 3, "def_pierce": 0.5,
		"effect": _effect("weaken", "Weaken", StatusEffect.StatType.ATK, -3, 3),
		"description": "Saps the target's strength (ATK -3 for 3 turns)."})
	_add({"id": "flame_burst", "display_name": "Flame Burst", "category": M, "shape": AREA,
		"min_level": 6, "sp_cost": 7, "ap_cost": 2, "power": 1.7, "cast_range": 4, "radius": 1, "def_pierce": 0.5,
		"description": "An explosion on a tile you pick."})
	_add({"id": "inferno", "display_name": "Inferno", "category": M, "shape": AREA,
		"min_level": 10, "sp_cost": 12, "ap_cost": 2, "power": 2.2, "cast_range": 4, "radius": 2, "def_pierce": 0.5,
		"description": "A huge blaze."})

	# ---- Support ----
	_add({"id": "battle_cry", "display_name": "Battle Cry", "category": P, "shape": AREA, "target_side": ALLY,
		"min_level": 3, "sp_cost": 5, "ap_cost": 1, "power": 0.0, "cast_range": 0, "radius": 2,
		"effect": _effect("battle_cry", "Battle Cry", StatusEffect.StatType.ATK, 3, 3),
		"description": "Rally nearby allies (ATK +3 for 3 turns)."})

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

## The (max 4) skills equipped for battle. Until the player customises them,
## it's simply the 4 strongest (highest level) skills learned.
static func get_loadout(character_id: String) -> Array:
	if character_id == "":
		return []
	var prog: CharacterProgress = Global.get_progress(character_id)
	var unlocked := unlocked_skills(character_id, prog.level)
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
	if prog.loadout_customized:
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
				var slot: int = prog.skill_loadout.find("")
				if slot != -1:
					prog.skill_loadout[slot] = s.id
	return learned
