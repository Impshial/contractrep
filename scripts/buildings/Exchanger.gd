class_name Exchanger
extends Building

const TRANSFER_DURATION_SECONDS: float = 0.75
const EXCHANGER_TEXTURE: Texture2D = preload("res://assets/buildings/exchanger.png")

var current_item: FactoryItem
var transfer_progress: float = TRANSFER_DURATION_SECONDS


func can_accept_item() -> bool:
	return current_item == null


func can_accept_item_from(source_grid_position: Vector2i, item_type: int, board: Board) -> bool:
	if not can_accept_item():
		return false

	if not can_receive_item_from_direction(source_grid_position):
		return false

	return has_valid_output_path_for_item(item_type, board)


func accept_item(item: FactoryItem) -> bool:
	if not can_accept_item():
		return false

	current_item = item
	return true


func accept_item_from(item: FactoryItem, source_grid_position: Vector2i, board: Board) -> bool:
	if not can_accept_item_from(source_grid_position, item.item_type, board):
		return false

	current_item = item
	return true


func release_item() -> FactoryItem:
	var item := current_item
	current_item = null
	return item


func advance_transfer(delta_seconds: float) -> void:
	transfer_progress = minf(transfer_progress + delta_seconds, _transfer_duration_seconds())


func can_transfer() -> bool:
	return transfer_progress >= _transfer_duration_seconds()


func consume_transfer_charge() -> void:
	transfer_progress = maxf(transfer_progress - _transfer_duration_seconds(), 0.0)


func has_valid_output_path_for_item(item_type: int, board: Board) -> bool:
	var output_position := grid_position + direction_grid_offset()
	var output_building := board.get_building_at_cell(output_position)
	if output_building == null:
		return false

	if output_building is Conveyor:
		return (output_building as Conveyor).can_receive_item_from_direction(grid_position)

	if output_building is Exchanger:
		return (output_building as Exchanger).can_receive_item_from_direction(grid_position)

	if output_building.supports_logistics_interface():
		return output_building.can_accept_factory_item(item_type)

	return false


func can_receive_item_from_direction(source_grid_position: Vector2i) -> bool:
	var entry_offset: Vector2i = source_grid_position - grid_position
	return entry_offset == -direction_grid_offset()


func get_connected_building(board: Board) -> Building:
	var forward_building := board.get_building_at_cell(grid_position + direction_grid_offset())
	if forward_building != null and forward_building.supports_logistics_interface():
		return forward_building

	var backward_building := board.get_building_at_cell(grid_position - direction_grid_offset())
	if backward_building != null and backward_building.supports_logistics_interface():
		return backward_building

	return null


func is_loading_building(board: Board) -> bool:
	var forward_building := board.get_building_at_cell(grid_position + direction_grid_offset())
	return forward_building != null and forward_building.supports_logistics_interface()


func is_unloading_building(board: Board) -> bool:
	var backward_building := board.get_building_at_cell(grid_position - direction_grid_offset())
	return backward_building != null and backward_building.supports_logistics_interface()


func rotate_clockwise() -> void:
	facing_direction = (facing_direction + 2) % DIRECTION_COUNT
	queue_redraw()


func placeable_id() -> String:
	return "exchanger"


func _transfer_duration_seconds() -> float:
	return float(GameDefinitions.placeable_definition(placeable_id()).get("transfer_duration_seconds", TRANSFER_DURATION_SECONDS))


func _draw() -> void:
	var half_size: float = cell_size * 0.5
	var texture_rect := Rect2(Vector2(-half_size, -half_size), Vector2(cell_size, cell_size))

	draw_texture_rect(EXCHANGER_TEXTURE, texture_rect, false)

	if is_preview:
		var preview_color := Color(0.20, 0.68, 0.38, 0.34) if is_valid_preview else Color(0.85, 0.22, 0.18, 0.42)
		draw_rect(texture_rect, preview_color, true)

	var arrow_direction: Vector2 = direction_vector()
	var side_direction: Vector2 = Vector2(-arrow_direction.y, arrow_direction.x)
	var arrow_tip: Vector2 = arrow_direction * (half_size - 6.0)
	var arrow_tail: Vector2 = -arrow_direction * (half_size - 7.0)
	var arrow_color := Color(0.35, 0.84, 1.0)

	draw_line(arrow_tail, arrow_tip, arrow_color, 3.0)
	draw_polygon(
		PackedVector2Array([
			arrow_tip,
			arrow_tip - arrow_direction * 9.0 + side_direction * 5.0,
			arrow_tip - arrow_direction * 9.0 - side_direction * 5.0,
		]),
		PackedColorArray([arrow_color, arrow_color, arrow_color])
	)


