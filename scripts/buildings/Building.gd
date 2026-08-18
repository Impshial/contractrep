class_name Building
extends Node2D

enum Direction { NORTH, EAST, SOUTH, WEST }
const DIRECTION_COUNT: int = 4

var grid_position: Vector2i = Vector2i.ZERO
var facing_direction: int = Direction.EAST
var cell_size: int = Board.CELL_SIZE
var is_preview: bool = false
var is_valid_preview: bool = true


func configure(new_grid_position: Vector2i, new_direction: int, new_cell_size: int) -> void:
	grid_position = new_grid_position
	facing_direction = new_direction
	cell_size = new_cell_size
	queue_redraw()


func set_preview_mode(enabled: bool) -> void:
	is_preview = enabled
	modulate.a = 0.62 if enabled else 1.0
	queue_redraw()


func set_preview_valid(valid: bool) -> void:
	is_valid_preview = valid
	queue_redraw()


func can_place_on(board: Board, target_grid_position: Vector2i) -> bool:
	return board.can_place_at(target_grid_position)


func on_placed(_board: Board) -> void:
	return


func supports_logistics_interface() -> bool:
	return false


func can_accept_factory_item(_item_type: int) -> bool:
	return false


func accept_factory_item(_item_type: int) -> bool:
	return false


func can_provide_factory_item() -> bool:
	return false


func peek_provided_factory_item_type() -> int:
	return -1


func provide_factory_item() -> int:
	return -1


func placeable_id() -> String:
	return "unknown"


func placeable_category() -> int:
	return int(GameDefinitions.PLACEABLE_DEFINITIONS.get(placeable_id(), {}).get(
		"category",
		GameDefinitions.PlaceableCategory.LOGISTICS
	))


func rotate_clockwise() -> void:
	facing_direction = (facing_direction + 1) % DIRECTION_COUNT
	queue_redraw()


func direction_vector() -> Vector2:
	match facing_direction:
		Direction.NORTH:
			return Vector2.UP
		Direction.EAST:
			return Vector2.RIGHT
		Direction.SOUTH:
			return Vector2.DOWN
		Direction.WEST:
			return Vector2.LEFT

	return Vector2.RIGHT


func direction_grid_offset() -> Vector2i:
	match facing_direction:
		Direction.NORTH:
			return Vector2i.UP
		Direction.EAST:
			return Vector2i.RIGHT
		Direction.SOUTH:
			return Vector2i.DOWN
		Direction.WEST:
			return Vector2i.LEFT

	return Vector2i.RIGHT
