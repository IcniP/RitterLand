# File: res://Scripts/resources/StatusEffect.gd
# A reusable buff/debuff definition. Create .tres instances of this for
# specific effects (e.g. "Weaken", "Haste", "Armor Break").
class_name StatusEffect
extends Resource

enum StatType { ATK, DEF, SPD, SP, HP }

@export var id: String = "status_effect"
@export var display_name: String = "Status Effect"
@export var stat_affected: StatType = StatType.ATK
## Positive = buff, negative = debuff.
@export var amount: int = 0
@export var duration_turns: int = 3
## PLACEHOLDER: assign a real icon texture once art exists.
@export var icon: Texture2D

func is_debuff() -> bool:
	return amount < 0
