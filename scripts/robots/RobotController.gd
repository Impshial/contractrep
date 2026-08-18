class_name RobotController
extends Node

const STARTING_ROBOT_COUNT: int = 5
const STARTING_OFFSETS: Array[Vector2] = [
	Vector2(-96.0, -48.0),
	Vector2(-48.0, 48.0),
	Vector2(0.0, -96.0),
	Vector2(48.0, 48.0),
	Vector2(96.0, -48.0),
]
const VISUAL_SEPARATION_RADIUS: float = 28.0
const VISUAL_SEPARATION_MAX_OFFSET: float = 10.0

@export var board_path: NodePath
@export var robot_parent_path: NodePath
@export var navigation_path: NodePath

var _board: Board
var _robot_parent: Node2D
var _navigation: RobotNavigation
var _robots: Array[Robot] = []
var _selected_robots: Array[Robot] = []


func _ready() -> void:
	_board = get_node(board_path) as Board
	_robot_parent = get_node(robot_parent_path) as Node2D
	_navigation = get_node(navigation_path) as RobotNavigation


func _process(_delta: float) -> void:
	_update_robot_visual_separation()


func spawn_starting_robots(seed_value: int = 0) -> void:
	clear_robots()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	var start_center := _board.grid_to_world(Vector2i(50, 50))
	for offset: Vector2 in STARTING_OFFSETS:
		_spawn_robot(rng.randi_range(0, Robot.SPRITE_PATHS.size() - 1), start_center + offset)


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
		var robot := _spawn_robot(0, Vector2.ZERO)
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
	robot.configure(sprite_index, world_position)
	_robots.append(robot)
	return robot


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