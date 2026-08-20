class_name RobotController
extends Node

const STARTING_ROBOT_COUNT: int = 3
const STARTING_OFFSETS: Array[Vector2] = [
	Vector2(-96.0, -48.0),
	Vector2(-48.0, 48.0),
	Vector2(0.0, -96.0),
	Vector2(48.0, 48.0),
	Vector2(96.0, -48.0),
]
const VISUAL_SEPARATION_RADIUS: float = 28.0
const VISUAL_SEPARATION_MAX_OFFSET: float = 10.0
const HARVEST_JOB_RECOVERY_SECONDS: float = 0.5
const MANUAL_SPAWN_CENTER_CELL: Vector2i = Board.START_CELL
const MANUAL_SPAWN_SEARCH_RADIUS: int = 12
const RESOURCE_RECOVERY_SEARCH_RADIUS: int = 40
const RESOURCE_RECOVERY_LOCAL_RADIUS: int = 8
const RESOURCE_ROUTE_PATHFIND_LIMIT: int = 64

@export var board_path: NodePath
@export var robot_parent_path: NodePath
@export var navigation_path: NodePath

var _board: Board
var _robot_parent: Node2D
var _navigation: RobotNavigation
var _robots: Array[Robot] = []
var _selected_robots: Array[Robot] = []
var _harvest_job_recovery_timer: float = 0.0
var _resource_recovery_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_board = get_node(board_path) as Board
	_robot_parent = get_node(robot_parent_path) as Node2D
	_navigation = get_node(navigation_path) as RobotNavigation
	_resource_recovery_rng.randomize()
	_board.building_placed.connect(_on_board_building_placed)


func _process(delta: float) -> void:
	_update_robot_visual_separation()
	_harvest_job_recovery_timer += delta
	if _harvest_job_recovery_timer >= HARVEST_JOB_RECOVERY_SECONDS:
		_harvest_job_recovery_timer = 0.0
		_recover_idle_harvest_jobs()


func spawn_starting_robots(_seed_value: int = 0) -> void:
	clear_robots()
	var start_center := _board.grid_to_world(Board.START_CELL)
	for index: int in range(mini(STARTING_ROBOT_COUNT, STARTING_OFFSETS.size())):
		var offset := STARTING_OFFSETS[index]
		_spawn_robot(Robot.BASIC_BOT_SPRITE_INDEX, start_center + offset)


func spawn_new_robot() -> Robot:
	var spawn_cell := _find_manual_spawn_cell()
	if spawn_cell == RobotNavigation.INVALID_CELL:
		push_warning("Could not find a walkable cell for a new bot.")
		return null

	var robot := _spawn_robot(Robot.BASIC_BOT_SPRITE_INDEX, _board.grid_to_world(spawn_cell))
	clear_selection()
	_select_robot(robot)
	return robot


func clear_robots() -> void:
	clear_selection()
	for robot: Robot in _robots:
		if robot != null:
			robot.queue_free()

	_robots.clear()


func handle_left_click(world_position: Vector2, shift_pressed: bool) -> bool:
	var robot := get_robot_at_world_position(world_position)
	if robot == null:
		if not shift_pressed:
			clear_selection()
		return false

	if shift_pressed:
		_toggle_robot_selection(robot)
	else:
		clear_selection()
		_select_robot(robot)

	return true


func handle_move_command(world_position: Vector2) -> bool:
	if _selected_robots.is_empty():
		return false

	var requested_cell := _board.world_to_grid(world_position)
	var reserved_cells: Dictionary = {}

	for robot: Robot in _selected_robots:
		if robot == null:
			continue

		var start_cell := _board.world_to_grid(robot.global_position)
		var target_cell := _navigation.find_reachable_destination(start_cell, requested_cell, reserved_cells)
		if target_cell == RobotNavigation.INVALID_CELL:
			print("No valid path found for robot.")
			continue

		var path := _navigation.get_world_path(start_cell, target_cell)
		if path.is_empty():
			print("No valid path found for robot.")
			continue

		reserved_cells[target_cell] = true
		robot.set_path(path)

	return true


func handle_harvest_command(grid_position: Vector2i, deposit: ResourceDeposit) -> bool:
	if deposit == null or _selected_robots.is_empty():
		return false

	if not deposit.is_harvestable():
		return false

	var reserved_cells: Dictionary = {}
	var command_started := false
	for robot: Robot in _selected_robots:
		if robot == null or not robot.can_harvest_resource(deposit):
			continue

		var start_cell := _board.world_to_grid(robot.global_position)
		var target_cell := _navigation.find_reachable_adjacent_destination(start_cell, grid_position, reserved_cells)
		if target_cell == RobotNavigation.INVALID_CELL:
			print("No valid adjacent harvest position found for robot.")
			continue

		var path := _navigation.get_world_path(start_cell, target_cell)
		if path.is_empty():
			print("No valid path found for robot harvest command.")
			continue

		reserved_cells[target_cell] = true
		robot.start_harvest_resource(_board, grid_position, deposit, path)
		command_started = true

	return command_started


func handle_deposit_command(container: Building) -> bool:
	if container == null or not container.is_container() or _selected_robots.is_empty():
		return false

	var reserved_cells: Dictionary = {}
	for robot: Robot in _selected_robots:
		if robot == null:
			continue

		var start_cell := _board.world_to_grid(robot.global_position)
		var target_cell := _navigation.find_reachable_adjacent_destination(start_cell, container.grid_position, reserved_cells)
		if target_cell == RobotNavigation.INVALID_CELL:
			print("No valid path found for robot container deposit command.")
			continue

		var path := _navigation.get_world_path(start_cell, target_cell)
		if path.is_empty():
			print("No valid path found for robot container deposit command.")
			continue

		reserved_cells[target_cell] = true
		robot.start_deposit_to_container(container, path)

	return true


func clear_selection() -> void:
	for robot: Robot in _selected_robots:
		if robot != null:
			robot.set_selected(false)

	_selected_robots.clear()


func get_robot_at_world_position(world_position: Vector2) -> Robot:
	for index: int in range(_robots.size() - 1, -1, -1):
		var robot := _robots[index]
		if robot != null and robot.contains_world_point(world_position):
			return robot

	return null


func select_robots_in_screen_rect(selection_rect: Rect2, additive: bool = true) -> int:
	if not additive:
		clear_selection()

	var selected_count := 0
	var canvas_transform := get_viewport().get_canvas_transform()
	for robot: Robot in _robots:
		if robot == null:
			continue

		var robot_screen_position: Vector2 = canvas_transform * (robot.global_position + robot.visual_offset)
		if not selection_rect.has_point(robot_screen_position):
			continue

		_select_robot(robot)
		selected_count += 1

	return selected_count


func serialize_robots() -> Array[Dictionary]:
	var robot_data: Array[Dictionary] = []
	for robot: Robot in _robots:
		if robot != null:
			robot_data.append(robot.serialize())

	return robot_data


func load_robots(robot_data: Array) -> void:
	clear_robots()
	for entry_variant: Variant in robot_data:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var robot := _spawn_robot(Robot.BASIC_BOT_SPRITE_INDEX, Vector2.ZERO)
		robot.restore(entry)
		if bool(entry.get("is_moving", false)):
			_restore_robot_path(robot, entry)


func get_robot_count() -> int:
	return _robots.size()


func get_selected_robot_count() -> int:
	return _selected_robots.size()


func _spawn_robot(sprite_index: int, world_position: Vector2) -> Robot:
	var robot := Robot.new()
	_robot_parent.add_child(robot)
	_robots.append(robot)
	robot.configure(sprite_index, world_position, _robots.size())
	robot.harvest_inventory_full.connect(_on_robot_harvest_inventory_full)
	robot.harvest_deposit_completed.connect(_on_robot_harvest_deposit_completed)
	robot.harvest_target_depleted.connect(_on_robot_harvest_target_depleted)
	return robot


func _find_manual_spawn_cell() -> Vector2i:
	var occupied_robot_cells: Dictionary = {}
	for robot: Robot in _robots:
		if robot != null:
			occupied_robot_cells[_board.world_to_grid(robot.global_position)] = true

	if _is_valid_manual_spawn_cell(MANUAL_SPAWN_CENTER_CELL, occupied_robot_cells):
		return MANUAL_SPAWN_CENTER_CELL

	for radius: int in range(1, MANUAL_SPAWN_SEARCH_RADIUS + 1):
		for candidate: Vector2i in _manual_spawn_ring(MANUAL_SPAWN_CENTER_CELL, radius):
			if _is_valid_manual_spawn_cell(candidate, occupied_robot_cells):
				return candidate

	return RobotNavigation.INVALID_CELL


func _is_valid_manual_spawn_cell(grid_position: Vector2i, occupied_robot_cells: Dictionary) -> bool:
	return _board.is_robot_walkable_cell(grid_position) and not occupied_robot_cells.has(grid_position)


func _manual_spawn_ring(center_cell: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx: int in range(-radius, radius + 1):
		cells.append(center_cell + Vector2i(dx, -radius))
		cells.append(center_cell + Vector2i(dx, radius))

	for dy: int in range(-radius + 1, radius):
		cells.append(center_cell + Vector2i(-radius, dy))
		cells.append(center_cell + Vector2i(radius, dy))

	cells.sort_custom(_sort_spawn_cells.bind(center_cell))
	return cells


func _sort_spawn_cells(a: Vector2i, b: Vector2i, center_cell: Vector2i) -> bool:
	var distance_a: int = absi(a.x - center_cell.x) + absi(a.y - center_cell.y)
	var distance_b: int = absi(b.x - center_cell.x) + absi(b.y - center_cell.y)
	if distance_a == distance_b:
		return a.y < b.y if a.x == b.x else a.x < b.x

	return distance_a < distance_b


func _restore_robot_path(robot: Robot, entry: Dictionary) -> void:
	var start_cell := _board.world_to_grid(robot.global_position)
	var destination_world := Vector2(float(entry.get("destination_x", robot.global_position.x)), float(entry.get("destination_y", robot.global_position.y)))
	var target_cell := _board.world_to_grid(destination_world)
	var resolved_cell := _navigation.find_reachable_destination(start_cell, target_cell)
	if resolved_cell == RobotNavigation.INVALID_CELL:
		return

	var path := _navigation.get_world_path(start_cell, resolved_cell)
	if not path.is_empty():
		robot.set_path(path)


func _toggle_robot_selection(robot: Robot) -> void:
	if _selected_robots.has(robot):
		_selected_robots.erase(robot)
		robot.set_selected(false)
	else:
		_select_robot(robot)


func _select_robot(robot: Robot) -> void:
	if _selected_robots.has(robot):
		return

	_selected_robots.append(robot)
	robot.set_selected(true)


func _update_robot_visual_separation() -> void:
	for index: int in range(_robots.size()):
		var robot := _robots[index]
		if robot == null:
			continue

		var offset := Vector2.ZERO
		for other_index: int in range(_robots.size()):
			if other_index == index:
				continue

			var other_robot := _robots[other_index]
			if other_robot == null:
				continue

			var difference := robot.global_position - other_robot.global_position
			var distance := difference.length()
			if distance >= VISUAL_SEPARATION_RADIUS:
				continue

			if distance <= 0.001:
				difference = Vector2.RIGHT.rotated(float(index) * TAU / maxf(1.0, float(_robots.size())))
				distance = 1.0

			var strength := 1.0 - (distance / VISUAL_SEPARATION_RADIUS)
			offset += difference.normalized() * strength * VISUAL_SEPARATION_MAX_OFFSET

		robot.set_visual_offset(offset.limit_length(VISUAL_SEPARATION_MAX_OFFSET))


func _on_robot_harvest_inventory_full(robot: Robot) -> void:
	if robot == null or robot.inventory.is_empty():
		return

	if _send_robot_to_available_container(robot):
		return

	if robot.can_continue_harvest_without_container():
		robot.continue_harvesting_until_container_needed()
	else:
		robot.wait_for_container()


func _on_robot_harvest_deposit_completed(robot: Robot) -> void:
	if robot == null:
		return

	if robot.inventory.available_capacity() <= 0 and not robot.inventory.is_empty():
		_on_robot_harvest_inventory_full(robot)
		return

	var deposit := robot.harvest_target_deposit()
	var target_cell := robot.harvest_target_cell()
	if deposit == null or not deposit.is_harvestable():
		var inventory_item_id := deposit.inventory_item_id() if deposit != null else robot.harvest_job_inventory_item_id()
		var search_origin := target_cell if target_cell != RobotNavigation.INVALID_CELL else robot.harvest_job_search_origin_cell()
		_on_robot_harvest_target_depleted(robot, search_origin, inventory_item_id)
		return

	var start_cell := _board.world_to_grid(robot.global_position)
	var harvest_cell := _navigation.find_reachable_adjacent_destination(start_cell, target_cell)
	if harvest_cell == RobotNavigation.INVALID_CELL:
		return

	var path := _navigation.get_world_path(start_cell, harvest_cell)
	if path.is_empty():
		return

	robot.return_to_harvest_resource(path)


func _on_robot_harvest_target_depleted(robot: Robot, depleted_cell: Vector2i, inventory_item_id: String) -> void:
	if robot == null or inventory_item_id.is_empty():
		return

	if robot.inventory.available_capacity() <= 0 and not robot.inventory.is_empty():
		_on_robot_harvest_inventory_full(robot)
		return

	var route := _find_nearest_resource_route(robot, inventory_item_id, depleted_cell)
	if route.is_empty():
		return

	robot.retarget_harvest_resource(
		_board,
		route.get("cell", RobotNavigation.INVALID_CELL),
		route.get("deposit") as ResourceDeposit,
		route.get("path", PackedVector2Array())
	)


func _recover_idle_harvest_jobs() -> void:
	for robot: Robot in _robots:
		if robot == null or not robot.should_recover_harvest_job():
			continue

		if robot.inventory.available_capacity() <= 0 and not robot.inventory.is_empty():
			_on_robot_harvest_inventory_full(robot)
			continue

		var route := _find_nearest_resource_route(
			robot,
			robot.harvest_job_inventory_item_id(),
			robot.harvest_job_search_origin_cell()
		)
		if route.is_empty():
			continue

		robot.retarget_harvest_resource(
			_board,
			route.get("cell", RobotNavigation.INVALID_CELL),
			route.get("deposit") as ResourceDeposit,
			route.get("path", PackedVector2Array())
		)


func _on_board_building_placed(building: Building) -> void:
	if building == null or not building.is_container():
		return

	for robot: Robot in _robots:
		if robot == null or not robot.should_use_new_container():
			continue

		var route := _find_nearest_container_route(robot, false, building)
		if route.is_empty():
			continue

		robot.start_auto_deposit_for_harvest(
			route.get("container") as Building,
			route.get("path", PackedVector2Array())
		)


func _send_robot_to_available_container(robot: Robot) -> bool:
	var route := _find_nearest_container_route(robot, true)
	if route.is_empty():
		route = _find_nearest_container_route(robot, false)
	if route.is_empty():
		return false

	robot.start_auto_deposit_for_harvest(
		route.get("container") as Building,
		route.get("path", PackedVector2Array())
	)
	return true


func _find_nearest_container_route(robot: Robot, require_full_capacity: bool, preferred_container: Building = null) -> Dictionary:
	var start_cell := _board.world_to_grid(robot.global_position)
	var carried_amount := robot.inventory.used_capacity()
	var best_route: Dictionary = {}
	var best_path_length := INF

	for building: Building in _board.get_all_buildings():
		if preferred_container != null and building != preferred_container:
			continue
		if building == null or not building.is_container():
			continue

		var inventory := building.container_inventory()
		if inventory == null:
			continue

		var available_capacity := inventory.available_capacity()
		if available_capacity <= 0:
			continue
		if require_full_capacity and available_capacity < carried_amount:
			continue

		var target_cell := _navigation.find_reachable_adjacent_destination(start_cell, building.grid_position)
		if target_cell == RobotNavigation.INVALID_CELL:
			continue

		var path := _navigation.get_world_path(start_cell, target_cell)
		if path.is_empty():
			continue

		var path_length := _path_length(path)
		if path_length >= best_path_length:
			continue

		best_path_length = path_length
		best_route = {
			"container": building,
			"path": path,
		}

	return best_route


func _find_nearest_resource_route(robot: Robot, inventory_item_id: String, exhausted_cell: Vector2i) -> Dictionary:
	var start_cell := _board.world_to_grid(robot.global_position)
	var search_origin_cell := exhausted_cell if exhausted_cell != RobotNavigation.INVALID_CELL else start_cell
	var route_origin_cell := _reachable_search_origin_cell(start_cell, search_origin_cell)
	var candidates := _random_resource_candidates(inventory_item_id, exhausted_cell, search_origin_cell, RESOURCE_RECOVERY_LOCAL_RADIUS)
	var route := _first_reachable_resource_route(start_cell, route_origin_cell, candidates)
	if not route.is_empty():
		return route

	candidates = _random_resource_candidates(inventory_item_id, exhausted_cell, search_origin_cell, RESOURCE_RECOVERY_SEARCH_RADIUS)
	return _first_reachable_resource_route(start_cell, route_origin_cell, candidates)


func _first_reachable_resource_route(start_cell: Vector2i, route_origin_cell: Vector2i, candidates: Array[Dictionary]) -> Dictionary:
	var pathfind_attempts := 0

	for candidate: Dictionary in candidates:
		if pathfind_attempts >= RESOURCE_ROUTE_PATHFIND_LIMIT:
			break

		var resource_cell: Vector2i = candidate.get("cell", RobotNavigation.INVALID_CELL)
		var deposit := candidate.get("deposit") as ResourceDeposit
		var harvest_cell := _navigation.find_reachable_adjacent_destination(route_origin_cell, resource_cell)
		pathfind_attempts += 1
		if harvest_cell == RobotNavigation.INVALID_CELL:
			continue

		var path := _path_to_harvest_cell(start_cell, route_origin_cell, harvest_cell)
		if path.is_empty():
			continue

		return {
			"cell": resource_cell,
			"deposit": deposit,
			"path": path,
		}

	return {}


func _random_resource_candidates(inventory_item_id: String, exhausted_cell: Vector2i, search_origin_cell: Vector2i, search_radius: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var nearby_resources := _board.get_resource_cells_near(search_origin_cell, search_radius, inventory_item_id)

	for key: Variant in nearby_resources.keys():
		var resource_cell: Vector2i = key
		if resource_cell == exhausted_cell:
			continue

		var deposit := nearby_resources.get(resource_cell) as ResourceDeposit
		if deposit == null or not deposit.is_harvestable():
			continue

		candidates.append({
			"cell": resource_cell,
			"deposit": deposit,
		})

	_shuffle_resource_candidates(candidates)
	return candidates


func _shuffle_resource_candidates(candidates: Array[Dictionary]) -> void:
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index := _resource_recovery_rng.randi_range(0, index)
		var candidate := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = candidate



func _reachable_search_origin_cell(start_cell: Vector2i, requested_origin_cell: Vector2i) -> Vector2i:
	if requested_origin_cell == RobotNavigation.INVALID_CELL or requested_origin_cell == start_cell:
		return start_cell
	if not _board.is_robot_walkable_cell(requested_origin_cell):
		return start_cell

	var path_to_origin := _navigation.get_world_path(start_cell, requested_origin_cell)
	if path_to_origin.is_empty():
		return start_cell

	return requested_origin_cell


func _path_to_harvest_cell(start_cell: Vector2i, route_origin_cell: Vector2i, harvest_cell: Vector2i) -> PackedVector2Array:
	if route_origin_cell == start_cell:
		return _navigation.get_world_path(start_cell, harvest_cell)

	var path_to_origin := _navigation.get_world_path(start_cell, route_origin_cell)
	var path_to_harvest := _navigation.get_world_path(route_origin_cell, harvest_cell)
	if path_to_origin.is_empty() or path_to_harvest.is_empty():
		return _navigation.get_world_path(start_cell, harvest_cell)

	var combined_path := PackedVector2Array(path_to_origin)
	var append_start_index := 1 if path_to_harvest.size() > 1 else path_to_harvest.size()
	for index: int in range(append_start_index, path_to_harvest.size()):
		combined_path.append(path_to_harvest[index])

	return combined_path


func _cell_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy


func _path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for index: int in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])

	return total
