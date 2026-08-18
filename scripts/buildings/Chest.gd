class_name Chest
extends Building

const DEFAULT_CAPACITY: int = 500

var inventory := Inventory.new(DEFAULT_CAPACITY)


func placeable_id() -> String:
	return "chest"


func supports_logistics_interface() -> bool:
	return true


func can_accept_factory_item(item_type: int) -> bool:
	return inventory.can_accept(GameDefinitions.item_id_for_type(item_type), 1)


func accept_factory_item(item_type: int) -> bool:
	var accepted := inventory.add_item(GameDefinitions.item_id_for_type(item_type), 1)
	queue_redraw()
	return accepted == 1


func can_provide_factory_item() -> bool:
	return false


func serialize_inventory() -> Dictionary:
	return inventory.serialize()


func restore_inventory(data: Dictionary) -> void:
	inventory.restore(data)
	queue_redraw()


func _draw() -> void:
	var half_size := cell_size * 0.5
	var body_rect := Rect2(Vector2(-half_size + 5.0, -half_size + 7.0), Vector2(cell_size - 10.0, cell_size - 12.0))
	var lid_rect := Rect2(Vector2(-half_size + 4.0, -half_size + 4.0), Vector2(cell_size - 8.0, 13.0))
	var fill_color := Color(0.45, 0.25, 0.12)
	var lid_color := Color(0.62, 0.36, 0.16)
	var trim_color := Color(0.93, 0.72, 0.32)

	if is_preview:
		fill_color = Color(0.20, 0.68, 0.38) if is_valid_preview else Color(0.85, 0.22, 0.18)
		lid_color = fill_color.lightened(0.12)
		trim_color = Color(0.90, 1.0, 0.92) if is_valid_preview else Color(1.0, 0.78, 0.72)

	draw_rect(body_rect, fill_color, true)
	draw_rect(lid_rect, lid_color, true)
	draw_rect(body_rect, Color(0.13, 0.08, 0.04), false, 2.0)
	draw_rect(lid_rect, Color(0.13, 0.08, 0.04), false, 2.0)
	draw_line(Vector2(-half_size + 8.0, -3.0), Vector2(half_size - 8.0, -3.0), trim_color, 2.0)
	draw_rect(Rect2(Vector2(-5.0, 3.0), Vector2(10.0, 8.0)), trim_color, true)