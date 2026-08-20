class_name ResourceDeposit
extends RefCounted

enum ResourceType { IRON_ORE, COAL, WOOD, STONE }

var resource_type: int = ResourceType.IRON_ORE
var resource_id: String = "iron_ore"
var remaining_amount: int = 0
var maximum_amount: int = 0
var texture_variant: int = 0


func _init(new_resource_type: int = ResourceType.IRON_ORE, amount: int = -1, variant: int = 0) -> void:
	resource_type = new_resource_type
	resource_id = _resource_id_for_type(new_resource_type)
	var definition := GameDefinitions.resource_definition(resource_id)
	maximum_amount = int(definition.get("starting_amount", 1000)) if amount < 0 else amount
	remaining_amount = maximum_amount
	texture_variant = variant


static func from_resource_id(new_resource_id: String, amount: int = -1, variant: int = 0) -> ResourceDeposit:
	var deposit := ResourceDeposit.new(_resource_type_for_id(new_resource_id), amount, variant)
	deposit.resource_id = DefinitionManager.legacy_resource_id(new_resource_id)
	var definition := GameDefinitions.resource_definition(new_resource_id)
	deposit.maximum_amount = int(definition.get("starting_amount", 1000)) if amount < 0 else amount
	deposit.remaining_amount = deposit.maximum_amount
	deposit.texture_variant = variant
	return deposit


func display_name() -> String:
	return str(GameDefinitions.resource_definition(resource_id).get("display_name", "Unknown Resource"))


func resource_name() -> String:
	return str(GameDefinitions.resource_definition(resource_id).get("resource_name", display_name()))


func inventory_item_id() -> String:
	return str(GameDefinitions.resource_definition(resource_id).get("inventory_item_id", resource_id))


func is_harvestable() -> bool:
	return bool(GameDefinitions.resource_definition(resource_id).get("harvestable", false)) and not is_depleted()


func is_depleted() -> bool:
	return remaining_amount <= 0


func remove_amount(amount: int) -> int:
	if amount <= 0 or is_depleted():
		return 0

	var removed: int = mini(amount, remaining_amount)
	remaining_amount -= removed
	return removed


func restore_amount(remaining: int, maximum: int = -1) -> void:
	if maximum >= 0:
		maximum_amount = maximum
	remaining_amount = clampi(remaining, 0, maximum_amount)


func serialize(grid_position: Vector2i) -> Dictionary:
	return {
		"x": grid_position.x,
		"y": grid_position.y,
		"resource_id": DefinitionManager.normalize_resource_id(resource_id),
		"legacy_resource_id": resource_id,
		"resource_type": resource_type,
		"remaining_amount": remaining_amount,
		"maximum_amount": maximum_amount,
		"texture_variant": texture_variant,
	}


static func _resource_id_for_type(type_id: int) -> String:
	match type_id:
		ResourceType.COAL:
			return "coal"
		ResourceType.WOOD:
			return "wood"
		ResourceType.STONE:
			return "stone"
		_:
			return "iron_ore"


static func _resource_type_for_id(new_resource_id: String) -> int:
	match DefinitionManager.legacy_resource_id(new_resource_id):
		"coal":
			return ResourceType.COAL
		"wood":
			return ResourceType.WOOD
		"stone":
			return ResourceType.STONE
		_:
			return ResourceType.IRON_ORE
