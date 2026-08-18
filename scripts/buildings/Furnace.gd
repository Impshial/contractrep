class_name Furnace
extends Building

const SMELTING_DURATION_SECONDS: float = 2.0
const STACK_CAPACITY: int = 100
const FURNACE_TEXTURE: Texture2D = preload("res://assets/buildings/furnace.png")

var iron_ore_count: int = 0
var coal_count: int = 0
var iron_plate_count: int = 0
var smelting_progress: float = 0.0


func supports_logistics_interface() -> bool:
	return true


func can_accept_factory_item(item_type: int) -> bool:
	match item_type:
		FactoryItem.ItemType.IRON_ORE:
			return iron_ore_count < STACK_CAPACITY
		FactoryItem.ItemType.COAL:
			return coal_count < STACK_CAPACITY

	return false


func accept_factory_item(item_type: int) -> bool:
	if not can_accept_factory_item(item_type):
		return false

	match item_type:
		FactoryItem.ItemType.IRON_ORE:
			iron_ore_count += 1
		FactoryItem.ItemType.COAL:
			coal_count += 1

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

	iron_plate_count -= 1
	queue_redraw()
	return FactoryItem.ItemType.IRON_PLATE


func advance_smelting(delta_seconds: float) -> void:
	if not can_smelt_recipe():
		queue_redraw()
		return

	smelting_progress += delta_seconds
	if smelting_progress < SMELTING_DURATION_SECONDS:
		queue_redraw()
		return

	iron_ore_count -= 1
	coal_count -= 1
	iron_plate_count += 1
	smelting_progress = 0.0
	queue_redraw()


func can_smelt_recipe() -> bool:
	return iron_ore_count >= 1 and coal_count >= 1 and iron_plate_count < STACK_CAPACITY


func get_smelting_ratio() -> float:
	return clampf(smelting_progress / SMELTING_DURATION_SECONDS, 0.0, 1.0)


func placeable_id() -> String:
	return "furnace"


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


