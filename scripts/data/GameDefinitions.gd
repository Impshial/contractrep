class_name GameDefinitions
extends RefCounted

enum ItemCategory { RESOURCE, INTERMEDIATE, PRODUCT }
enum PlaceableCategory { LOGISTICS, EXTRACTION, SMELTING, STORAGE, CRAFTING }

const ITEM_DEFINITIONS: Dictionary = {
	FactoryItem.ItemType.IRON_ORE: {
		"id": "iron_ore",
		"display_name": "Iron Ore",
		"category": ItemCategory.RESOURCE,
		"stackable": true,
	},
	FactoryItem.ItemType.COAL: {
		"id": "coal",
		"display_name": "Coal",
		"category": ItemCategory.RESOURCE,
		"stackable": true,
	},
	FactoryItem.ItemType.IRON_PLATE: {
		"id": "iron_plate",
		"display_name": "Iron Plate",
		"category": ItemCategory.INTERMEDIATE,
		"stackable": true,
	},
}

const INVENTORY_ITEM_DEFINITIONS: Dictionary = {
	"iron_ore": {
		"display_name": "Iron Ore",
		"category": ItemCategory.RESOURCE,
	},
	"coal": {
		"display_name": "Coal",
		"category": ItemCategory.RESOURCE,
	},
	"iron_plate": {
		"display_name": "Iron Plate",
		"category": ItemCategory.INTERMEDIATE,
	},
	"wood": {
		"display_name": "Wood",
		"category": ItemCategory.RESOURCE,
	},
	"stone": {
		"display_name": "Stone",
		"category": ItemCategory.RESOURCE,
	},
}

const RESOURCE_DEFINITIONS: Dictionary = {
	"iron_ore": {
		"display_name": "Iron Ore Deposit",
		"resource_name": "Iron Ore",
		"inventory_item_id": "iron_ore",
		"starting_amount": 1200,
		"harvestable": true,
		"texture_prefix": "iron_ore",
		"texture_variant_count": 8,
	},
	"coal": {
		"display_name": "Coal Deposit",
		"resource_name": "Coal",
		"inventory_item_id": "coal",
		"starting_amount": 1000,
		"harvestable": true,
		"texture_prefix": "coal",
		"texture_variant_count": 8,
	},
	"wood": {
		"display_name": "Tree",
		"resource_name": "Wood",
		"inventory_item_id": "wood",
		"starting_amount": 300,
		"harvestable": true,
		"texture_prefix": "",
		"texture_variant_count": 0,
	},
}

const PLACEABLE_DEFINITIONS: Dictionary = {
	"conveyor": {
		"display_name": "Conveyor",
		"category": PlaceableCategory.LOGISTICS,
	},
	"miner": {
		"display_name": "Miner",
		"category": PlaceableCategory.EXTRACTION,
	},
	"furnace": {
		"display_name": "Furnace",
		"category": PlaceableCategory.SMELTING,
	},
	"exchanger": {
		"display_name": "Exchanger",
		"category": PlaceableCategory.LOGISTICS,
	},
	"chest": {
		"display_name": "Chest",
		"category": PlaceableCategory.STORAGE,
		"implemented": true,
	},
	"warehouse": {
		"display_name": "Warehouse",
		"category": PlaceableCategory.STORAGE,
		"implemented": false,
	},
}


static func item_display_name(item_type: int) -> String:
	return str(ITEM_DEFINITIONS.get(item_type, {}).get("display_name", "Unknown Item"))


static func item_id_for_type(item_type: int) -> String:
	return str(ITEM_DEFINITIONS.get(item_type, {}).get("id", "unknown"))


static func item_type_for_id(item_id: String) -> int:
	for type_key: Variant in ITEM_DEFINITIONS.keys():
		if str(ITEM_DEFINITIONS[type_key].get("id", "")) == item_id:
			return int(type_key)

	return -1


static func inventory_item_display_name(item_id: String) -> String:
	return str(INVENTORY_ITEM_DEFINITIONS.get(item_id, {}).get("display_name", item_id.capitalize()))


static func item_is_stackable(item_type: int) -> bool:
	return bool(ITEM_DEFINITIONS.get(item_type, {}).get("stackable", false))


static func resource_definition(resource_id: String) -> Dictionary:
	var definition: Variant = RESOURCE_DEFINITIONS.get(resource_id, {})
	return definition if definition is Dictionary else {}


static func placeable_display_name(placeable_id: String) -> String:
	return str(PLACEABLE_DEFINITIONS.get(placeable_id, {}).get("display_name", "Unknown Placeable"))