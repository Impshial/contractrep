class_name ResourceDeposit
extends RefCounted

enum ResourceType { IRON_ORE, COAL }

var resource_type: int = ResourceType.IRON_ORE


func _init(new_resource_type: int = ResourceType.IRON_ORE) -> void:
	resource_type = new_resource_type


func display_name() -> String:
	match resource_type:
		ResourceType.IRON_ORE:
			return "Iron Ore"
		ResourceType.COAL:
			return "Coal"

	return "Unknown"
