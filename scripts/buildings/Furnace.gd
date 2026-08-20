class_name Furnace
extends Building

const SMELTING_DURATION_SECONDS: float = 2.0
const STACK_CAPACITY: int = 100
const FURNACE_TEXTURE: Texture2D = preload("res://assets/buildings/furnace.png")

var inventory := Inventory.new()
var iron_ore_count: int:
	get:
		return inventory.get_quantity_in_role("iron_ore", InventorySlot.Role.INPUT)
	set(value):
		inventory.set_role_item_quantity("iron_ore", InventorySlot.Role.INPUT, value)
		queue_redraw()
var coal_count: int:
	get:
		return inventory.get_quantity_in_role("coal", InventorySlot.Role.INPUT)
	set(value):
		inventory.set_role_item_quantity("coal", InventorySlot.Role.INPUT, value)
		queue_redraw()
var iron_plate_count: int:
	get:
		return inventory.get_quantity_in_role("iron_plate", InventorySlot.Role.OUTPUT)
	set(value):
		inventory.set_role_item_quantity("iron_plate", InventorySlot.Role.OUTPUT, value)
		queue_redraw()
var smelting_progress: float = 0.0


func _init() -> void:
	_configure_inventory()


func supports_logistics_interface() -> bool:
	return true


func has_visual_inventory() -> bool:
	return true


func visual_inventory() -> Inventory:
	return inventory


func inventory_display_name() -> String:
	return GameDefinitions.placeable_display_name(placeable_id())


func can_accept_factory_item(item_type: int) -> bool:
	var item_id := GameDefinitions.item_id_for_type(item_type)
	if not _recipe_input_item_ids().has(item_id):
		return false

	return inventory.can_accept_in_role(item_id, 1, InventorySlot.Role.INPUT)


func accept_factory_item(item_type: int) -> bool:
	if not can_accept_factory_item(item_type):
		return false

	var item_id := GameDefinitions.item_id_for_type(item_type)
	var accepted := inventory.add_item_to_role(item_id, 1, InventorySlot.Role.INPUT)
	if accepted != 1:
		return false

	queue_redraw()
	return true


func can_provide_factory_item() -> bool:
	return iron_plate_count > 0


func peek_provided_factory_item_type() -> int:
	if can_provide_factory_item():
		return FactoryItem.ItemType.IRON_PLATE

	return -1


func provide_factory_item() -> int:
	if not can_provide_factory_item():
		return -1

	var removed := inventory.consume_from_role("iron_plate", 1, InventorySlot.Role.OUTPUT)
	if removed != 1:
		return -1

	queue_redraw()
	return FactoryItem.ItemType.IRON_PLATE


func advance_smelting(delta_seconds: float) -> void:
	if not can_smelt_recipe():
		queue_redraw()
		return

	smelting_progress += delta_seconds
	if smelting_progress < _smelting_duration_seconds():
		queue_redraw()
		return

	for input: Dictionary in _recipe_definition().get("inputs", []):
		inventory.consume_from_role(
			DefinitionManager.legacy_item_id(str(input.get("item", ""))),
			int(input.get("amount", 1)),
			InventorySlot.Role.INPUT
		)
	for output: Dictionary in _recipe_definition().get("outputs", []):
		inventory.add_item_to_role(
			DefinitionManager.legacy_item_id(str(output.get("item", ""))),
			int(output.get("amount", 1)),
			InventorySlot.Role.OUTPUT,
			false
		)
	smelting_progress = 0.0
	queue_redraw()


func can_smelt_recipe() -> bool:
	var recipe := _recipe_definition()
	for input: Dictionary in recipe.get("inputs", []):
		var item_id := DefinitionManager.legacy_item_id(str(input.get("item", "")))
		if inventory.get_quantity_in_role(item_id, InventorySlot.Role.INPUT) < int(input.get("amount", 1)):
			return false
	for output: Dictionary in recipe.get("outputs", []):
		var item_id := DefinitionManager.legacy_item_id(str(output.get("item", "")))
		if inventory.acceptable_amount_in_role(item_id, int(output.get("amount", 1)), InventorySlot.Role.OUTPUT, false) < int(output.get("amount", 1)):
			return false
	return true


func get_smelting_ratio() -> float:
	return clampf(smelting_progress / _smelting_duration_seconds(), 0.0, 1.0)


func placeable_id() -> String:
	return "furnace"


func serialize_inventory() -> Dictionary:
	return inventory.serialize()


func restore_inventory(data: Dictionary) -> void:
	_configure_inventory()
	inventory.restore(data)
	queue_redraw()


func restore_legacy_counts(ore_count: int, new_coal_count: int, plate_count: int) -> void:
	_configure_inventory()
	inventory.clear()
	iron_ore_count = ore_count
	coal_count = new_coal_count
	iron_plate_count = plate_count
	queue_redraw()


func _configure_inventory() -> void:
	var definition := GameDefinitions.placeable_definition(placeable_id())
	var inventory_definition: Dictionary = definition.get("inventory", {})
	var role_counts := {
		InventorySlot.Role.INPUT: int(inventory_definition.get("input_slots", 2)),
		InventorySlot.Role.OUTPUT: int(inventory_definition.get("output_slots", 1)),
		InventorySlot.Role.STORAGE: int(inventory_definition.get("storage_slots", 10)),
	}
	inventory.configure_slots(
		role_counts,
		int(inventory_definition.get("slots_per_row", 10)),
		int(inventory_definition.get("stack_size", STACK_CAPACITY))
	)

	for filter_definition: Dictionary in inventory_definition.get("slot_filters", []):
		var role := _inventory_role_from_string(str(filter_definition.get("role", "storage")))
		var role_indices := inventory.get_slot_indices_for_role(role)
		var role_slot_index := int(filter_definition.get("slot", 0))
		if role_slot_index < 0 or role_slot_index >= role_indices.size():
			continue

		var slot := inventory.get_slot(role_indices[role_slot_index])
		if slot == null:
			continue

		slot.filter_enabled = true
		slot.filter_item_id = DefinitionManager.legacy_item_id(str(filter_definition.get("item", "")))


func _recipe_definition() -> Dictionary:
	var building_definition := GameDefinitions.placeable_definition(placeable_id())
	return DefinitionManager.get_definition("recipe", str(building_definition.get("recipe", "contract:iron_plate")))


func _recipe_input_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for input: Dictionary in _recipe_definition().get("inputs", []):
		item_ids.append(DefinitionManager.legacy_item_id(str(input.get("item", ""))))
	return item_ids


func _smelting_duration_seconds() -> float:
	var recipe := _recipe_definition()
	return float(recipe.get("cycle_seconds", GameDefinitions.placeable_definition(placeable_id()).get("smelting_duration_seconds", SMELTING_DURATION_SECONDS)))


func _inventory_role_from_string(role_name: String) -> int:
	match role_name:
		"input":
			return InventorySlot.Role.INPUT
		"output":
			return InventorySlot.Role.OUTPUT
		_:
			return InventorySlot.Role.STORAGE


func _draw() -> void:
	var half_size: float = cell_size * 0.5
	var texture_rect := Rect2(Vector2(-half_size, -half_size), Vector2(cell_size, cell_size))

	draw_texture_rect(FURNACE_TEXTURE, texture_rect, false)

	if is_preview:
		var preview_color := Color(0.20, 0.68, 0.38, 0.34) if is_valid_preview else Color(0.85, 0.22, 0.18, 0.42)
		draw_rect(texture_rect, preview_color, true)

	_draw_progress_bar(half_size)


func _draw_progress_bar(half_size: float) -> void:
	var bar_rect := Rect2(Vector2(-half_size + 8.0, half_size - 11.0), Vector2(cell_size - 16.0, 5.0))
	var fill_width: float = bar_rect.size.x * get_smelting_ratio()

	draw_rect(bar_rect, Color(0.09, 0.08, 0.07), true)
	draw_rect(Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y)), Color(0.98, 0.62, 0.24), true)
	draw_rect(bar_rect, Color(0.84, 0.70, 0.58), false, 1.0)


