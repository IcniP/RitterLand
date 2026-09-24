# File: res://Scripts/resources/SkillData.gd
# One skill or spell. The test skills are defined in code in core/SkillDB.gd.
class_name SkillData
extends Resource

enum Category { PHYSICAL, MAGIC }
## SINGLE     = one tile you pick (within cast_range).
## AREA       = a (2*radius+1) square around a tile you pick; cast_range 0 = centred on the caster.
## PROJECTILE = flies in a straight line (up / down / left / right) up to cast_range
##              tiles and hits the first valid target on the way (e.g. fireball).
enum Shape { SINGLE, AREA, PROJECTILE }
enum TargetSide { ENEMIES, ALLIES }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.PHYSICAL
@export var shape: Shape = Shape.SINGLE
@export var target_side: TargetSide = TargetSide.ENEMIES
## Character level needed to learn it.
@export var min_level: int = 1
@export var sp_cost: int = 2
## Action points used (a character has SPD points per turn).
@export var ap_cost: int = 1
## Damage multiplier on the caster's ATK. 0 = no damage (buff/debuff skills).
@export var power: float = 1.5
## SINGLE/AREA: max distance in tiles to the target tile. PROJECTILE: max flight distance.
@export var cast_range: int = 1
## AREA only: 1 = 3x3, 2 = 5x5 ...
@export var radius: int = 0
## "" = usable with any weapon, else "longsword" / "montante" (Lan swaps in battle).
@export var weapon: String = ""
## After damage, drag every target this many tiles toward the aimed centre (crowd control).
@export var pull: int = 0
## Extra damage = caster SPD * spd_scale (SPD-based skills).
@export var spd_scale: float = 0.0
## Number of separate hits (damage is split per hit, each hit checks DEF).
@export var hits: int = 1
## Fraction of the target's DEF ignored (magic usually pierces some).
@export_range(0.0, 1.0) var def_pierce: float = 0.0
## Optional buff/debuff applied to every target hit.
@export var effect: StatusEffect
## Ultimate charge gained by using it.
@export var charge_gain: float = 20.0
## Ultimates cost a FULL charge bar instead of SP and are not part of the 4-skill loadout.
@export var is_ultimate: bool = false

func shape_name() -> String:
	match shape:
		Shape.SINGLE: return "Single target"
		Shape.AREA: return "Area %dx%d" % [radius * 2 + 1, radius * 2 + 1]
		_: return "Projectile"

## One-line description for menus / tooltips.
func summary() -> String:
	var parts: PackedStringArray = ["Magic" if category == Category.MAGIC else "Physical", shape_name()]
	if shape == Shape.PROJECTILE:
		parts.append("range %d" % cast_range)
	elif cast_range > 0:
		parts.append("range %d" % cast_range)
	else:
		parts.append("self")
	if power > 0.0:
		parts.append("%.1fx" % power)
	if spd_scale > 0.0:
		parts.append("+%.1fx SPD" % spd_scale)
	if weapon != "":
		parts.append(weapon)
	if pull > 0:
		parts.append("pull %d" % pull)
	if hits > 1:
		parts.append("%d hits" % hits)
	if effect:
		parts.append("%s %+d %s" % [effect.display_name, effect.amount, StatusEffect.StatType.keys()[effect.stat_affected]])
	parts.append("CHARGE" if is_ultimate else "%d SP" % sp_cost)
	parts.append("%d AP" % ap_cost)
	return ", ".join(parts)
