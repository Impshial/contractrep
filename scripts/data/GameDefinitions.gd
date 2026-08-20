class_name GameDefinitions
extends RefCounted

enum ItemCategory { RESOURCE, INTERMEDIATE, PRODUCT }
enum PlaceableCategory { LOGISTICS, EXTRACTION, SMELTING, STORAGE, CRAFTING }

const CATEGORY_NAMES: Dictionary = {
	"resource": ItemCategory.RESOURCE,
	"intermediate": ItemCategory.INTERMEDIATE,
	"product": ItemCategory.PRODUCT,
	"logistics": PlaceableCategory.LOGISTICS,
	"extraction": PlaceableCategory.EXTRACTION,
	"smelting": PlaceableCategory.SMELTING,
	"storage": PlaceableCategory.STORAGE,
	"crafting": PlaceableCategory.CRAFTING,
}


static func ensure_loaded() -> bool:
	return DefinitionManager.ensure_loaded()


static func item_display_name(item_type: int) -> String:
	return str(DefinitionManager.get_item_by_type(item_type).get("display_name", "Unknown Item"))


static func item_id_for_type(item_type: int) -> String:
	return str(DefinitionManager.get_item_by_type(item_type).get("legacy_id", "unknown"))


static func namespaced_item_id_for_type(item_type: int) -> String:
	return str(DefinitionManager.get_item_by_type(item_type).get("id", ""))


static func item_type_for_id(item_id: String) -> int:
	var definition := DefinitionManager.get_item(item_id)
	return int(definition.get("legacy_item_type", -1))


static func inventory_item_display_name(item_id: String) -> String:
	var definition := DefinitionManager.get_item(item_id)
	return str(definition.get("display_name", item_id.capitalize()))


static func item_is_stackable(item_type: int) -> bool:
	return bool(DefinitionManager.get_item_by_type(item_type).get("stackable", false))


static func item_stack_size(item_id: String) -> int:
	return int(DefinitionManager.get_item(item_id).get("stack_size", Inventory.DEFAULT_STACK_LIMIT))


static func item_texture(item_id: String) -> Texture2D:
	return DefinitionManager.texture_for_item_id(item_id)


static func resource_definition(resource_id: String) -> Dictionary:
	var definition := DefinitionManager.get_resource(resource_id).duplicate(true)
	if definition.is_empty():
		return {}

	definition["inventory_item_id"] = DefinitionManager.legacy_item_id(str(definition.get("produces_item", "")))
	return definition


static func resource_display_id(resource_id: String) -> String:
	return DefinitionManager.legacy_resource_id(resource_id)


static func resource_definition_id(resource_id: String) -> String:
	return DefinitionManager.normalize_resource_id(resource_id)


static func placeable_definition(placeable_id: String) -> Dictionary:
	return DefinitionManager.get_building(placeable_id)


static func placeable_display_name(placeable_id: String) -> String:
	return str(placeable_definition(placeable_id).get("display_name", "Unknown Placeable"))


static func placeable_category(placeable_id: String) -> int:
	var category_name := str(placeable_definition(placeable_id).get("category", "logistics"))
	return int(CATEGORY_NAMES.get(category_name, PlaceableCategory.LOGISTICS))


static func player_definition(player_id: String = "contract:player") -> Dictionary:
	return DefinitionManager.get_player(player_id)


static func bot_definition(bot_id: String = "contract:basic_bot") -> Dictionary:
	return DefinitionManager.get_bot(bot_id)


static func worldgen_definition(worldgen_id: String = "contract:default_planet") -> Dictionary:
	return DefinitionManager.get_worldgen(worldgen_id)


static func save_content_pack_metadata() -> Array[Dictionary]:
	return DefinitionManager.save_content_pack_metadata()


static func missing_content_packs(required_packs: Array) -> Array[String]:
	return DefinitionManager.missing_content_packs(required_packs)
