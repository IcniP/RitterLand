# File: res://Scripts/core/SkillDB.gd
# All skills live as .tres SkillData resources under res://Resources/Skills/
# (one file per skill, edited in the Godot Inspector) and are loaded here.
# To add a skill: duplicate a .tres in that folder, set its fields (id must
# be unique), then list the id per character in CHARACTER_SKILLS (key =
# character id: "player" for Lan, the PartyMemberEntry.member_id for others).
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

## Every skill is now a .tres SkillData resource under this folder (one file
## per skill), edited in the Godot Inspector -- no code/preload needed to add
## art: open the .tres, drag a texture into `icon` or `effect_sprite`.
const SKILLS_DIR := "res://Resources/Skills/"

static func _ensure() -> void:
	if _skills.is_empty():
		_load_all()

static func _load_all() -> void:
	var dir := DirAccess.open(SKILLS_DIR)
	if dir == null:
		push_warning("SkillDB: folder not found -- " + SKILLS_DIR)
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			var s: SkillData = load(SKILLS_DIR + f)
			if s and s.id != "":
				_skills[s.id] = s
			else:
				push_warning("SkillDB: %s has no id set" % f)
		f = dir.get_next()
	dir.list_dir_end()

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
	if prog.loadout_customized:
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
