# File: res://Scripts/resources/EquipmentItem.gd
# One piece of equipment. The test items are defined in code in ItemDB.gd;
# later you can also make .tres files from this resource.
class_name EquipmentItem
extends Resource

enum SlotType { WEAPON, ARTIFACT, ARMOR, ACCESSORY }

@export var id: String = ""
@export var display_name: String = ""
@export var slot_type: SlotType = SlotType.WEAPON
@export_multiline var description: String = ""
## Stat bonuses while equipped. Keys: "max_hp", "max_sp", "atk", "def_stat", "spd".
@export var bonuses: Dictionary = {}
