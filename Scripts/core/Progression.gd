# File: res://Scripts/core/Progression.gd
# All the level / stat-point / equipment RULES in one place - tweak the numbers
# here to rebalance the game.
class_name Progression
extends RefCounted

const MAX_LEVEL := 50
## Unspent stat points gained per level-up.
const POINTS_PER_LEVEL := 3

const STATS: Array[String] = ["max_hp", "max_sp", "atk", "def_stat", "spd"]
const STAT_LABELS := {"max_hp": "HP", "max_sp": "SP", "atk": "ATK", "def_stat": "DEF", "spd": "SPD"}

## Automatic growth every level (on top of the points you allocate).
const LEVEL_GROWTH := {"max_hp": 10, "max_sp": 3, "atk": 1, "def_stat": 1, "spd": 0}
## How much ONE allocated point adds, and how many points it costs.
const POINT_VALUE := {"max_hp": 10, "max_sp": 5, "atk": 2, "def_stat": 1, "spd": 1}
const POINT_COST := {"max_hp": 1, "max_sp": 1, "atk": 1, "def_stat": 1, "spd": 3}

const SLOTS: Array[String] = ["weapon", "artifact", "armor", "accessory_1", "accessory_2", "accessory_3"]
const SLOT_LABELS := {
	"weapon": "Weapon", "artifact": "Artifact", "armor": "Armor",
	"accessory_1": "Accessory 1", "accessory_2": "Accessory 2", "accessory_3": "Accessory 3",
}

static func slot_type(slot: String) -> int:
	match slot:
		"weapon": return EquipmentItem.SlotType.WEAPON
		"artifact": return EquipmentItem.SlotType.ARTIFACT
		"armor": return EquipmentItem.SlotType.ARMOR
		_: return EquipmentItem.SlotType.ACCESSORY

## XP needed to go from `level` to `level + 1`.
static func xp_to_next(level: int) -> int:
	return 50 * level + 10 * (level - 1) * (level - 1)

static func equipment_bonus(prog: CharacterProgress) -> Dictionary:
	var total := {}
	for slot in prog.equipment:
		var item := ItemDB.get_item(prog.equipment[slot])
		if item == null:
			continue
		for stat in item.bonuses:
			total[stat] = int(total.get(stat, 0)) + int(item.bonuses[stat])
	return total

## Final stats = base (from the character scene) + level growth
## + allocated points + equipment.
static func compute_stats(base: Dictionary, prog: CharacterProgress) -> Dictionary:
	var gear := equipment_bonus(prog)
	var out := {}
	for s in STATS:
		var v: int = int(base.get(s, 0))
		v += int(LEVEL_GROWTH[s]) * (prog.level - 1)
		v += int(prog.allocated.get(s, 0)) * int(POINT_VALUE[s])
		v += int(gear.get(s, 0))
		out[s] = maxi(v, 1) if (s == "max_hp" or s == "spd") else maxi(v, 0)
	return out
