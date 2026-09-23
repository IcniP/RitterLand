# File: res://Scripts/core/CharacterProgress.gd
# Everything about one character that persists between fights and in save
# files: level, xp, unspent stat points, allocated points, equipment.
class_name CharacterProgress
extends RefCounted

var level: int = 1
var xp: int = 0
var stat_points: int = 0
var allocated: Dictionary = {}   # stat -> number of points bought
var equipment: Dictionary = {}   # slot -> item id
## Up to 4 skill ids ("" = empty slot). Only used once loadout_customized is true;
## before that the game auto-picks the 4 strongest learned skills.
var skill_loadout: Array = []
var loadout_customized: bool = false

## Returns how many levels were gained.
func add_xp(amount: int) -> int:
	var gained := 0
	if amount <= 0:
		return 0
	xp += amount
	while level < Progression.MAX_LEVEL and xp >= Progression.xp_to_next(level):
		xp -= Progression.xp_to_next(level)
		level += 1
		stat_points += Progression.POINTS_PER_LEVEL
		gained += 1
	if level >= Progression.MAX_LEVEL:
		xp = 0
	return gained

func spend_point(stat: String) -> bool:
	if not Progression.STATS.has(stat):
		return false
	var cost: int = Progression.POINT_COST[stat]
	if stat_points < cost:
		return false
	stat_points -= cost
	allocated[stat] = int(allocated.get(stat, 0)) + 1
	return true

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "stat_points": stat_points,
		"allocated": allocated.duplicate(), "equipment": equipment.duplicate(),
		"skill_loadout": skill_loadout.duplicate(), "loadout_customized": loadout_customized}

static func from_dict(d: Dictionary) -> CharacterProgress:
	var p := CharacterProgress.new()
	p.level = clampi(int(d.get("level", 1)), 1, Progression.MAX_LEVEL)
	p.xp = int(d.get("xp", 0))
	p.stat_points = int(d.get("stat_points", 0))
	for k in d.get("allocated", {}):
		p.allocated[str(k)] = int(d["allocated"][k])
	for k in d.get("equipment", {}):
		p.equipment[str(k)] = str(d["equipment"][k])
	for id in d.get("skill_loadout", []):
		p.skill_loadout.append(str(id))
	p.loadout_customized = bool(d.get("loadout_customized", false))
	return p
