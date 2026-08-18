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
		"implemented": false,
	},
	"warehouse": {
		"display_name": "Warehouse",
		"category": PlaceableCategory.STORAGE,
		"implemented": false,
	},
}


static func item_display_name(item_type: int) -> String:
	return ITEM_DEFINITIONS.get(item_type, {}).get("display_name", "Unknown Item")


static func item_is_stackable(item_type: int) -> bool:
	return bool(ITEM_DEFINITIONS.get(item_type, {}).get("stackable", false))


static func placeable_display_name(placeable_id: String) -> String:
	return PLACEABLE_DEFINITIONS.get(placeable_id, {}).get("display_name", "Unknown Placeable")
