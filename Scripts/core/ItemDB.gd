# File: res://Scripts/core/ItemDB.gd
# Every equipment item in the game (basic test set for now). Add new items in
# _build(). Use ItemDB.get_item("iron_sword") anywhere.
class_name ItemDB
extends RefCounted

static var _items: Dictionary = {}

static func _ensure() -> void:
	if _items.is_empty():
		_build()

static func _add(id: String, display_name: String, type: EquipmentItem.SlotType, desc: String, bonuses: Dictionary) -> void:
	var item := EquipmentItem.new()
	item.id = id
	item.display_name = display_name
	item.slot_type = type
	item.description = desc
	item.bonuses = bonuses
	_items[id] = item

static func _build() -> void:
	var W := EquipmentItem.SlotType.WEAPON
	var A := EquipmentItem.SlotType.ARTIFACT
	var R := EquipmentItem.SlotType.ARMOR
	var C := EquipmentItem.SlotType.ACCESSORY
	# Weapons
	_add("iron_sword", "Iron Sword", W, "A plain but reliable blade.", {"atk": 3})
	_add("steel_blade", "Steel Blade", W, "Well balanced. Hits hard.", {"atk": 6})
	_add("apprentice_staff", "Apprentice Staff", W, "Focuses your mana.", {"atk": 2, "max_sp": 8})
	# Artifacts
	_add("ancient_relic", "Ancient Relic", A, "Hums faintly with old magic.", {"max_sp": 10})
	_add("guardian_sigil", "Guardian Sigil", A, "Wards off blows.", {"max_hp": 15, "def_stat": 1})
	# Armor
	_add("leather_vest", "Leather Vest", R, "Light and comfortable.", {"max_hp": 10, "def_stat": 2})
	_add("knight_plate", "Knight Plate", R, "Heavy steel plating.", {"max_hp": 20, "def_stat": 5})
	# Accessories
	_add("power_ring", "Power Ring", C, "Sharpens your strikes.", {"atk": 2})
	_add("vitality_band", "Vitality Band", C, "You feel sturdier.", {"max_hp": 20})
	_add("swift_boots", "Swift Boots", C, "Move more each turn.", {"spd": 1})
	_add("focus_charm", "Focus Charm", C, "Clears the mind.", {"max_sp": 8})
	_add("lucky_coin", "Lucky Coin", C, "Small bonus to everything useful.", {"atk": 1, "def_stat": 1})

static func get_item(id: String) -> EquipmentItem:
	_ensure()
	return _items.get(id)

static func all_ids() -> Array:
	_ensure()
	return _items.keys()

static func ids_for_slot_type(type: int) -> Array:
	_ensure()
	var list: Array = []
	for id in _items:
		if int(_items[id].slot_type) == type:
			list.append(id)
	return list

## Everything you own at the start of a new game (one of each - for testing).
static func starter_inventory() -> Array:
	return all_ids()

static func bonus_text(item: EquipmentItem) -> String:
	var parts: PackedStringArray = []
	for stat in Progression.STATS:
		var v: int = int(item.bonuses.get(stat, 0))
		if v != 0:
			parts.append("%+d %s" % [v, Progression.STAT_LABELS[stat]])
	return ", ".join(parts)
