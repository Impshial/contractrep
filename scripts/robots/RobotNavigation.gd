class_name RobotNavigation
extends Node

const INVALID_CELL: Vector2i = Vector2i(-999999999, -999999999)
const DESTINATION_SEARCH_RADIUS: int = 12
const PATH_REGION_PADDING: int = 16

@export var board_path: NodePath

var _board: Board
var _astar := AStarGrid2D.new()
var _is_ready: bool = false


func _ready() -> void:
	_board = get_node(board_path) as Board
	_board.traversability_changed.connect(_on_traversability_changed)


func get_path_cells(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	if not _can_query_path(start_cell, target_cell):
		return []

	_configure_grid_for_path(start_cell, target_cell)
	var path_cells: Array[Vector2i] = []
	for cell: Vector2i in _astar.get_id_path(start_cell, target_cell):
		path_cells.append(cell)

	return path_cells


func get_world_path(start_cell: Vector2i, target_cell: Vector2i) -> PackedVector2Array:
	var world_path := PackedVector2Array()
	for cell: Vector2i in get_path_cells(start_cell, target_cell):
		world_path.append(_board.grid_to_world(cell))

	return world_path


func find_reachable_destination(start_cell: Vector2i, requested_cell: Vector2i, reserved_cells: Dictionary = {}) -> Vector2i:
	if _is_usable_destination(start_cell, requested_cell, reserved_cells):
		return requested_cell

	for radius: int in range(1, DESTINATION_SEARCH_RADIUS + 1):
		for candidate: Vector2i in _candidate_ring(requested_cell, radius):
			if _is_usable_destination(start_cell, candidate, reserved_cells):
				return candidate

	return INVALID_CELL


func find_reachable_adjacent_destination(start_cell: Vector2i, target_cell: Vector2i, reserved_cells: Dictionary = {}) -> Vector2i:
	var candidates: Array[Vector2i] = [
		target_cell + Vector2i(0, -1),
		target_cell + Vector2i(1, -1),
		target_cell + Vector2i(1, 0),
		target_cell + Vector2i(1, 1),
		target_cell + Vector2i(0, 1),
		target_cell + Vector2i(-1, 1),
		target_cell + Vector2i(-1, 0),
		target_cell + Vector2i(-1, -1),
	]
	candidates.sort_custom(_sort_candidates_by_distance_to_start.bind(start_cell))

	for candidate: Vector2i in candidates:
		if _is_usable_destination(start_cell, candidate, reserved_cells):
			return candidate

	return INVALID_CELL


func refresh_cell(grid_position: Vector2i) -> void:
	if not _is_ready:
		return

	if grid_position == Board.REFRESH_ALL_CELLS:
		_rebuild_region_points()
		return

	if not _board.is_in_bounds(grid_position) or not _astar.region.has_point(grid_position):
		return

	_astar.set_point_solid(grid_position, not _board.is_robot_walkable_cell(grid_position))


func _configure_grid_for_path(start_cell: Vector2i, target_cell: Vector2i) -> void:
	var min_x := mini(start_cell.x, target_cell.x) - PATH_REGION_PADDING
	var min_y := mini(start_cell.y, target_cell.y) - PATH_REGION_PADDING
	var max_x := maxi(start_cell.x, target_cell.x) + PATH_REGION_PADDING
	var max_y := maxi(start_cell.y, target_cell.y) + PATH_REGION_PADDING
	var new_region := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	if _is_ready and _astar.region == new_region:
		return

	_astar.region = new_region
	_astar.cell_size = Vector2(Board.CELL_SIZE, Board.CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_is_ready = true
	_rebuild_region_points()


func _rebuild_region_points() -> void:
	if not _is_ready:
		return

	for x: int in range(_astar.region.position.x, _astar.region.position.x + _astar.region.size.x):
		for y: int in range(_astar.region.position.y, _astar.region.position.y + _astar.region.size.y):
			refresh_cell(Vector2i(x, y))


func _can_query_path(start_cell: Vector2i, target_cell: Vector2i) -> bool:
	return (
		_board.is_in_bounds(start_cell)
		and _board.is_in_bounds(target_cell)
		and _board.is_robot_walkable_cell(start_cell)
		and _board.is_robot_walkable_cell(target_cell)
	)


func _is_usable_destination(start_cell: Vector2i, candidate_cell: Vector2i, reserved_cells: Dictionary) -> bool:
	if reserved_cells.has(candidate_cell):
		return false

	if not _can_query_path(start_cell, candidate_cell):
		return false

	return not get_path_cells(start_cell, candidate_cell).is_empty()


func _candidate_ring(center_cell: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx: int in range(-radius, radius + 1):
		cells.append(center_cell + Vector2i(dx, -radius))
		cells.append(center_cell + Vector2i(dx, radius))

	for dy: int in range(-radius + 1, radius):
		cells.append(center_cell + Vector2i(-radius, dy))
		cells.append(center_cell + Vector2i(radius, dy))

	cells.sort_custom(_sort_candidates_by_distance_to_center.bind(center_cell))
	return cells


func _sort_candidates_by_distance_to_center(a: Vector2i, b: Vector2i, center_cell: Vector2i) -> bool:
	var distance_a: int = absi(a.x - center_cell.x) + absi(a.y - center_cell.y)
	var distance_b: int = absi(b.x - center_cell.x) + absi(b.y - center_cell.y)
	if distance_a == distance_b:
		return a.y < b.y if a.x == b.x else a.x < b.x

	return distance_a < distance_b


func _sort_candidates_by_distance_to_start(a: Vector2i, b: Vector2i, start_cell: Vector2i) -> bool:
	var distance_a: int = absi(a.x - start_cell.x) + absi(a.y - start_cell.y)
	var distance_b: int = absi(b.x - start_cell.x) + absi(b.y - start_cell.y)
	if distance_a == distance_b:
		return a.y < b.y if a.x == b.x else a.x < b.x

	return distance_a < distance_b


func _on_traversability_changed(grid_position: Vector2i) -> void:
	refresh_cell(grid_position)
