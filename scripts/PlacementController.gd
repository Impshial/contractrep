class_name PlacementController
extends Node2D

@export var board_path: NodePath
@export var building_parent_path: NodePath
@export var factory_simulation_path: NodePath

var _board: Board
var _building_parent: Node2D
var _factory_simulation: FactorySimulation
var _active_building_scene: PackedScene
var _active_direction: int = Building.Direction.EAST
var _preview: Building
var _is_placing: bool = false
var _is_drag_placing: bool = false
var _last_drag_grid_position: Vector2i = Vector2i(-9999, -9999)
var _current_grid_position: Vector2i = Vector2i(-1, -1)
var _current_location_valid: bool = false


func _ready() -> void:
	_board = get_node(board_path) as Board
	_building_parent = get_node(building_parent_path) as Node2D
	_factory_simulation = get_node(factory_simulation_path) as FactorySimulation


func is_placing() -> bool:
	return _is_placing


func begin_placement(building_scene: PackedScene) -> void:
	_active_building_scene = building_scene
	_is_placing = true
	_create_preview()


func cancel_placement() -> void:
	_is_placing = false
	_is_drag_placing = false
	_active_building_scene = null
	if _preview != null:
		_preview.queue_free()
		_preview = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_placing:
		cancel_placement()
		get_viewport().set_input_as_handled()
		return

	if not _is_placing:
		return

	if event.is_action_pressed("rotate_building"):
		if _preview is Exchanger:
			_active_direction = (_active_direction + 2) % Building.DIRECTION_COUNT
		else:
			_active_direction = (_active_direction + 1) % Building.DIRECTION_COUNT
		_update_preview()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("place_building"):
		_begin_or_place_active_building()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("place_building"):
		_is_drag_placing = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("remove_building"):
		_remove_building_at_mouse()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _is_placing:
		_update_preview()
		if _is_drag_placing:
			_try_drag_place_active_building()


func _create_preview() -> void:
	if _preview != null:
		_preview.queue_free()

	_preview = _active_building_scene.instantiate() as Building
	add_child(_preview)
	_preview.set_preview_mode(true)
	_update_preview()


func _update_preview() -> void:
	if _preview == null:
		return

	_current_grid_position = _board.world_to_grid(get_global_mouse_position())
	_auto_align_exchanger_preview()
	_current_location_valid = _preview.can_place_on(_board, _current_grid_position)
	_preview.visible = true
	_preview.global_position = _board.grid_to_world(_current_grid_position)
	_preview.configure(_current_grid_position, _active_direction, Board.CELL_SIZE)
	_preview.set_preview_valid(_current_location_valid)


func _auto_align_exchanger_preview() -> void:
	if not (_preview is Exchanger):
		return

	for offset: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var adjacent_building := _board.get_building_at_cell(_current_grid_position + offset)
		if adjacent_building == null or not adjacent_building.supports_logistics_interface():
			continue

		var direction := _direction_from_offset(offset)
		if _active_direction != direction and _active_direction != (direction + 2) % Building.DIRECTION_COUNT:
			_active_direction = direction
		return

	if _has_logistics_holder_at(_current_grid_position + Vector2i.LEFT) and _has_logistics_holder_at(_current_grid_position + Vector2i.RIGHT):
		if _active_direction != Building.Direction.EAST and _active_direction != Building.Direction.WEST:
			_active_direction = Building.Direction.EAST
		return

	if _has_logistics_holder_at(_current_grid_position + Vector2i.UP) and _has_logistics_holder_at(_current_grid_position + Vector2i.DOWN):
		if _active_direction != Building.Direction.NORTH and _active_direction != Building.Direction.SOUTH:
			_active_direction = Building.Direction.SOUTH
		return


func _has_logistics_holder_at(grid_position: Vector2i) -> bool:
	var building := _board.get_building_at_cell(grid_position)
	return building is Conveyor or building is Exchanger


func _place_active_building() -> void:
	if not _current_location_valid or _active_building_scene == null:
		return

	var building := _active_building_scene.instantiate() as Building
	if not building.can_place_on(_board, _current_grid_position):
		building.queue_free()
		_update_preview()
		return

	building.configure(_current_grid_position, _active_direction, Board.CELL_SIZE)
	building.global_position = _board.grid_to_world(_current_grid_position)

	if _board.occupy_cell(_current_grid_position, building):
		building.on_placed(_board)
		_building_parent.add_child(building)
	else:
		building.queue_free()

	_update_preview()


func _begin_or_place_active_building() -> void:
	if _preview is Conveyor:
		_is_drag_placing = true
		_last_drag_grid_position = Vector2i(-9999, -9999)
		_try_drag_place_active_building()
	else:
		_place_active_building()


func _try_drag_place_active_building() -> void:
	if _current_grid_position == _last_drag_grid_position:
		return

	_last_drag_grid_position = _current_grid_position
	_place_active_building()


func _direction_from_offset(offset: Vector2i) -> int:
	if offset == Vector2i.UP:
		return Building.Direction.NORTH
	if offset == Vector2i.RIGHT:
		return Building.Direction.EAST
	if offset == Vector2i.DOWN:
		return Building.Direction.SOUTH

	return Building.Direction.WEST


func _remove_building_at_mouse() -> void:
	var grid_position: Vector2i = _board.world_to_grid(get_global_mouse_position())
	var building := _board.get_building_at_cell(grid_position)

	if building == null:
		return

	_factory_simulation.handle_building_removed(building)
	_board.clear_cell(grid_position)
	building.queue_free()
	_update_preview()
