class_name Robot
extends Node2D

signal harvest_inventory_full(robot: Robot)
signal harvest_deposit_completed(robot: Robot)
signal harvest_target_depleted(robot: Robot, depleted_cell: Vector2i, inventory_item_id: String)

enum FacingDirection { NORTH, EAST, SOUTH, WEST, NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST }
enum RobotState { IDLE, MOVING, MOVING_TO_RESOURCE, HARVESTING, INVENTORY_FULL, MOVING_TO_CONTAINER, DEPOSITING, WAITING_FOR_CONTAINER }

const ARRIVAL_DISTANCE: float = 3.0
const SELECTION_RADIUS: float = 20.0
const BASIC_BOT_SPRITE_INDEX: int = 3
const BASIC_BOT_INVENTORY_CAPACITY: int = 5
const HARVEST_PROGRESS_BAR_SIZE: Vector2 = Vector2(34.0, 5.0)
const HARVEST_PROGRESS_BAR_OFFSET: Vector2 = Vector2(-17.0, -30.0)
const SPRITE_PATHS: Array[String] = [
	"res://assets/robots/robot_01.png",
	"res://assets/robots/robot_02.png",
	"res://assets/robots/robot_03.png",
	"res://assets/robots/robot_04.png",
	"res://assets/robots/robot_05.png",
	"res://assets/robots/robot_06.png",
	"res://assets/robots/robot_07.png",
	"res://assets/robots/robot_08.png",
]

@export var movement_speed: float = 100.0
@export var harvest_cycle_seconds: float = 5.0
@export var harvest_units_per_cycle: int = 1

var sprite_index: int = 0
var bot_definition_id: String = "contract:basic_bot"
var bot_number: int = 1
var is_selected: bool = false
var destination: Vector2
var is_moving: bool = false
var facing_direction: int = FacingDirection.SOUTH
var visual_offset: Vector2 = Vector2.ZERO
var inventory := Inventory.new(BASIC_BOT_INVENTORY_CAPACITY)
var robot_state: int = RobotState.IDLE
var current_job: BotJob

var _sprite: Sprite2D
var _path_points := PackedVector2Array()
var _path_index: int = 0
var _deposit_target: Building
var _harvest_board: Board
var _harvest_target_cell: Vector2i = RobotNavigation.INVALID_CELL
var _harvest_target: ResourceDeposit
var _harvest_cycle_progress: float = 0.0
var _return_to_harvest_after_deposit: bool = false
var _allow_partial_harvest_to_fill_inventory: bool = false
var _sprite_texture_path: String = ""


func _ready() -> void:
	_apply_bot_definition()
	destination = global_position
	_create_sprite()
	_apply_sprite_texture()
	_update_sprite_rotation()
	_update_visual_offset()
	queue_redraw()


func configure(_new_sprite_index: int, world_position: Vector2, new_bot_number: int = 1) -> void:
	_create_sprite()
	_apply_bot_definition()
	bot_number = maxi(1, new_bot_number)
	global_position = world_position
	destination = world_position
	is_moving = false
	robot_state = RobotState.IDLE
	facing_direction = FacingDirection.SOUTH
	_path_points.clear()
	_path_index = 0
	_deposit_target = null
	_clear_harvest_target()
	visual_offset = Vector2.ZERO
	inventory = Inventory.new(_bot_inventory_capacity())
	_apply_sprite_texture()
	_update_sprite_rotation()
	_update_visual_offset()
	queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func set_visual_offset(offset: Vector2) -> void:
	visual_offset = offset
	_update_visual_offset()
	queue_redraw()


func contains_world_point(world_position: Vector2) -> bool:
	return (global_position + visual_offset).distance_to(world_position) <= SELECTION_RADIUS


func move_to(world_position: Vector2) -> void:
	set_path(PackedVector2Array([world_position]), RobotState.MOVING)


func set_path(world_path: PackedVector2Array, moving_state: int = RobotState.MOVING) -> void:
	_cancel_active_task()
	_path_points = world_path
	_path_index = 0

	if _path_points.is_empty():
		is_moving = false
		robot_state = RobotState.IDLE
		destination = global_position
		return

	while _path_index < _path_points.size() and global_position.distance_to(_path_points[_path_index]) <= ARRIVAL_DISTANCE:
		_path_index += 1

	destination = _path_points[_path_points.size() - 1]
	is_moving = _path_index < _path_points.size()
	robot_state = moving_state if is_moving else RobotState.IDLE
	if is_moving:
		_update_facing_from_vector(_path_points[_path_index] - global_position)


func start_deposit_to_container(container: Building, world_path: PackedVector2Array) -> void:
	_cancel_active_task()
	if container == null or not container.is_container():
		robot_state = RobotState.IDLE
		return

	_deposit_target = container
	_set_path_without_cancel(world_path, RobotState.MOVING_TO_CONTAINER)


func start_auto_deposit_for_harvest(container: Building, world_path: PackedVector2Array) -> void:
	if container == null or not container.is_container() or world_path.is_empty():
		return

	_deposit_target = container
	_return_to_harvest_after_deposit = true
	_allow_partial_harvest_to_fill_inventory = false
	_harvest_cycle_progress = 0.0
	_set_path_without_cancel(world_path, RobotState.MOVING_TO_CONTAINER)


func start_harvest_resource(board: Board, target_cell: Vector2i, deposit: ResourceDeposit, world_path: PackedVector2Array) -> void:
	_cancel_active_task()
	if board == null or deposit == null or not can_harvest_resource(deposit):
		robot_state = RobotState.IDLE
		return

	current_job = BotJob.harvest(deposit, target_cell)
	_start_harvest_target(board, target_cell, deposit, world_path)


func retarget_harvest_resource(board: Board, target_cell: Vector2i, deposit: ResourceDeposit, world_path: PackedVector2Array) -> void:
	if current_job == null or not current_job.is_harvest_job():
		current_job = BotJob.harvest(deposit, target_cell)
	elif deposit != null:
		current_job.update_harvest_target(deposit, target_cell)

	_start_harvest_target(board, target_cell, deposit, world_path)


func _start_harvest_target(board: Board, target_cell: Vector2i, deposit: ResourceDeposit, world_path: PackedVector2Array) -> void:
	if board == null or deposit == null or not can_harvest_resource(deposit):
		robot_state = RobotState.IDLE
		return

	_harvest_board = board
	_harvest_target_cell = target_cell
	_harvest_target = deposit
	_harvest_cycle_progress = 0.0
	_allow_partial_harvest_to_fill_inventory = false
	_set_path_without_cancel(world_path, RobotState.MOVING_TO_RESOURCE)


func return_to_harvest_resource(world_path: PackedVector2Array) -> void:
	if _harvest_board == null or _harvest_target == null:
		_clear_harvest_target()
		robot_state = RobotState.IDLE
		return
	if _harvest_target.is_depleted():
		_finish_harvesting_depleted()
		return

	_harvest_cycle_progress = 0.0
	_return_to_harvest_after_deposit = false
	_allow_partial_harvest_to_fill_inventory = false
	_set_path_without_cancel(world_path, RobotState.MOVING_TO_RESOURCE)


func can_harvest_resource(deposit: ResourceDeposit) -> bool:
	return deposit != null and deposit.is_harvestable()


func harvest_target_cell() -> Vector2i:
	return _harvest_target_cell


func harvest_target_deposit() -> ResourceDeposit:
	return _harvest_target


func has_active_harvest_target() -> bool:
	return _harvest_board != null and _harvest_target != null and not _harvest_target.is_depleted()


func can_continue_harvest_without_container() -> bool:
	return has_active_harvest_target() and inventory.available_capacity() > 0


func is_waiting_for_container() -> bool:
	return robot_state == RobotState.WAITING_FOR_CONTAINER or robot_state == RobotState.INVENTORY_FULL


func should_use_new_container() -> bool:
	return has_active_harvest_target() and not inventory.is_empty() and (
		is_waiting_for_container() or _allow_partial_harvest_to_fill_inventory
	)


func continue_harvesting_until_container_needed() -> void:
	if not can_continue_harvest_without_container():
		wait_for_container()
		return

	_deposit_target = null
	_return_to_harvest_after_deposit = false
	_allow_partial_harvest_to_fill_inventory = true
	_harvest_cycle_progress = 0.0
	is_moving = false
	_path_points.clear()
	_path_index = 0
	_face_harvest_target()
	robot_state = RobotState.HARVESTING
	queue_redraw()


func wait_for_container() -> void:
	_deposit_target = null
	_return_to_harvest_after_deposit = true
	_allow_partial_harvest_to_fill_inventory = false
	_harvest_cycle_progress = 0.0
	is_moving = false
	_path_points.clear()
	_path_index = 0
	robot_state = RobotState.WAITING_FOR_CONTAINER
	queue_redraw()


func display_name() -> String:
	return "Basic Bot %02d" % [bot_number]


func designation_display_name() -> String:
	if current_job != null and current_job.job_type != BotJob.JobType.NONE:
		return current_job.designation_display_name()

	if robot_state == RobotState.MOVING_TO_CONTAINER or robot_state == RobotState.DEPOSITING or robot_state == RobotState.WAITING_FOR_CONTAINER:
		return "Hauler"

	return "Idle"


func state_display_name() -> String:
	match robot_state:
		RobotState.MOVING:
			return "Moving"
		RobotState.MOVING_TO_RESOURCE:
			return "Moving to Resource"
		RobotState.HARVESTING:
			return "Harvesting %s" % [_harvest_target.resource_name()] if _harvest_target != null else "Harvesting"
		RobotState.INVENTORY_FULL:
			return "Inventory Full"
		RobotState.MOVING_TO_CONTAINER:
			return "Moving to Container"
		RobotState.DEPOSITING:
			return "Depositing"
		RobotState.WAITING_FOR_CONTAINER:
			return "Waiting for Container"
		_:
			return "Idle"


func harvest_target_name() -> String:
	return current_job.target_display_name() if current_job != null else ""


func harvest_target_remaining() -> int:
	return _harvest_target.remaining_amount if _harvest_target != null else 0


func harvest_target_maximum() -> int:
	return _harvest_target.maximum_amount if _harvest_target != null else 0


func harvest_job_inventory_item_id() -> String:
	if current_job == null or not current_job.is_harvest_job():
		return ""

	return current_job.inventory_item_id


func harvest_job_search_origin_cell() -> Vector2i:
	if current_job == null or not current_job.is_harvest_job():
		return RobotNavigation.INVALID_CELL
	if current_job.target_cell != RobotNavigation.INVALID_CELL:
		return current_job.target_cell

	return current_job.last_target_cell


func should_recover_harvest_job() -> bool:
	return (
		robot_state == RobotState.IDLE
		and current_job != null
		and current_job.is_harvest_job()
		and not current_job.inventory_item_id.is_empty()
		and not has_active_harvest_target()
	)


func harvest_cycle_progress_ratio() -> float:
	return clampf(_harvest_cycle_progress, 0.0, 1.0)


func serialize() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"destination_x": destination.x,
		"destination_y": destination.y,
		"sprite_index": sprite_index,
		"bot_definition_id": bot_definition_id,
		"bot_number": bot_number,
		"facing_direction": facing_direction,
		"is_moving": is_moving,
		"inventory": inventory.serialize(),
		"robot_state": robot_state,
	}


func restore(entry: Dictionary) -> void:
	var world_position := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	bot_definition_id = DefinitionManager.normalize_id(str(entry.get("bot_definition_id", bot_definition_id)))
	configure(int(entry.get("sprite_index", BASIC_BOT_SPRITE_INDEX)), world_position, int(entry.get("bot_number", 1)))
	destination = Vector2(float(entry.get("destination_x", world_position.x)), float(entry.get("destination_y", world_position.y)))
	facing_direction = int(entry.get("facing_direction", FacingDirection.SOUTH))
	_restore_inventory_with_basic_bot_capacity(entry.get("inventory", inventory.serialize()))
	robot_state = RobotState.IDLE
	is_moving = false
	_path_points.clear()
	_path_index = 0
	_deposit_target = null
	_clear_harvest_target()
	current_job = null
	_return_to_harvest_after_deposit = false
	_allow_partial_harvest_to_fill_inventory = false
	_update_sprite_rotation()


func _process(delta: float) -> void:
	if robot_state == RobotState.HARVESTING:
		_process_harvesting(delta)
		queue_redraw()
		return

	if not is_moving:
		return

	if _path_index >= _path_points.size():
		is_moving = false
		_handle_path_finished()
		return

	var waypoint := _path_points[_path_index]
	var movement_vector := waypoint - global_position
	if movement_vector.length() <= ARRIVAL_DISTANCE:
		global_position = waypoint
		_path_index += 1
		if _path_index >= _path_points.size():
			is_moving = false
			_handle_path_finished()
			return
		waypoint = _path_points[_path_index]
		movement_vector = waypoint - global_position

	_update_facing_from_vector(movement_vector)
	global_position = global_position.move_toward(waypoint, movement_speed * delta)


func _handle_path_finished() -> void:
	if robot_state == RobotState.MOVING_TO_RESOURCE:
		if _harvest_target != null and not _harvest_target.is_depleted():
			_face_harvest_target()
			robot_state = RobotState.HARVESTING
		else:
			_finish_harvesting_depleted()
		return

	if robot_state == RobotState.MOVING_TO_CONTAINER and _deposit_target != null:
		robot_state = RobotState.DEPOSITING
		var target_inventory := _deposit_target.container_inventory()
		var transferred := inventory.transfer_all_to(target_inventory)
		if transferred > 0:
			_deposit_target.queue_redraw()
		else:
			print("Robot had nothing to deposit or container was full.")
		_deposit_target = null
		if _return_to_harvest_after_deposit:
			_return_to_harvest_after_deposit = false
			robot_state = RobotState.IDLE
			harvest_deposit_completed.emit(self)
			return

	robot_state = RobotState.IDLE


func _process_harvesting(delta: float) -> void:
	if _harvest_board == null or _harvest_target == null or _harvest_target.is_depleted():
		_finish_harvesting_depleted()
		return

	var item_id := _harvest_target.inventory_item_id()
	var requested_units := _next_harvest_cycle_amount()
	if requested_units <= 0:
		if inventory.available_capacity() <= 0:
			_request_container_deposit()
		else:
			_finish_harvesting_depleted()
		return

	if inventory.acceptable_amount(item_id, requested_units) < requested_units:
		_request_container_deposit()
		return

	_harvest_cycle_progress += delta / maxf(0.001, harvest_cycle_seconds)
	if _harvest_cycle_progress < 1.0:
		return

	requested_units = _next_harvest_cycle_amount()
	if requested_units <= 0:
		_finish_harvesting_depleted()
		return

	if inventory.acceptable_amount(item_id, requested_units) < requested_units:
		_request_container_deposit()
		return

	var removed_units := _harvest_target.remove_amount(requested_units)
	if removed_units <= 0:
		_finish_harvesting_depleted()
		return

	var accepted_units := inventory.add_item(item_id, removed_units)
	if accepted_units < removed_units:
		_harvest_target.restore_amount(_harvest_target.remaining_amount + (removed_units - accepted_units))

	_harvest_cycle_progress = maxf(0.0, _harvest_cycle_progress - 1.0)
	_harvest_board.mark_resource_changed(_harvest_target_cell)

	if _harvest_target.is_depleted():
		_finish_harvesting_depleted()
	else:
		var next_cycle_amount := _next_harvest_cycle_amount()
		if next_cycle_amount <= 0 and inventory.available_capacity() <= 0:
			_request_container_deposit()
		elif inventory.acceptable_amount(item_id, next_cycle_amount) < next_cycle_amount:
			_request_container_deposit()


func _finish_harvesting_depleted() -> void:
	var depleted_cell := _harvest_target_cell
	var inventory_item_id := _harvest_target.inventory_item_id() if _harvest_target != null else ""
	if _harvest_board != null and _harvest_target_cell != RobotNavigation.INVALID_CELL:
		_harvest_board.deplete_resource_at_cell(_harvest_target_cell)

	_clear_harvest_target()
	robot_state = RobotState.IDLE
	harvest_target_depleted.emit(self, depleted_cell, inventory_item_id)


func _set_path_without_cancel(world_path: PackedVector2Array, moving_state: int) -> void:
	_path_points = world_path
	_path_index = 0

	if _path_points.is_empty():
		is_moving = false
		robot_state = RobotState.IDLE
		destination = global_position
		return

	while _path_index < _path_points.size() and global_position.distance_to(_path_points[_path_index]) <= ARRIVAL_DISTANCE:
		_path_index += 1

	destination = _path_points[_path_points.size() - 1]
	is_moving = _path_index < _path_points.size()
	if is_moving:
		robot_state = moving_state
	elif moving_state == RobotState.MOVING_TO_RESOURCE:
		_face_harvest_target()
		robot_state = RobotState.HARVESTING
	elif moving_state == RobotState.MOVING_TO_CONTAINER:
		robot_state = RobotState.MOVING_TO_CONTAINER
		_handle_path_finished()
	else:
		robot_state = RobotState.IDLE
	if is_moving:
		_update_facing_from_vector(_path_points[_path_index] - global_position)


func _cancel_active_task() -> void:
	_deposit_target = null
	_return_to_harvest_after_deposit = false
	_allow_partial_harvest_to_fill_inventory = false
	_clear_harvest_target()
	current_job = null


func _clear_harvest_target() -> void:
	_harvest_board = null
	_harvest_target_cell = RobotNavigation.INVALID_CELL
	_harvest_target = null
	_harvest_cycle_progress = 0.0
	if current_job != null:
		current_job.clear_target()


func _face_harvest_target() -> void:
	if _harvest_board == null or _harvest_target_cell == RobotNavigation.INVALID_CELL:
		return

	_update_facing_from_vector(_harvest_board.grid_to_world(_harvest_target_cell) - global_position)


func _draw() -> void:
	if robot_state == RobotState.HARVESTING:
		_draw_harvest_progress_bar()

	if not is_selected:
		return

	draw_arc(visual_offset, 21.0, 0.0, TAU, 48, Color(0.28, 0.92, 1.0), 2.5)
	draw_arc(visual_offset, 24.0, 0.0, TAU, 48, Color(0.04, 0.16, 0.20, 0.85), 1.0)


func _draw_harvest_progress_bar() -> void:
	var progress := harvest_cycle_progress_ratio()
	var bar_rect := Rect2(visual_offset + HARVEST_PROGRESS_BAR_OFFSET, HARVEST_PROGRESS_BAR_SIZE)
	var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y))

	draw_rect(bar_rect.grow(1.0), Color(0.02, 0.03, 0.03, 0.85), true)
	draw_rect(bar_rect, Color(0.10, 0.13, 0.14, 0.92), true)
	draw_rect(fill_rect, Color(0.24, 0.86, 1.0), true)
	draw_rect(bar_rect, Color(0.75, 0.94, 1.0, 0.75), false, 1.0)


func _next_harvest_cycle_amount() -> int:
	if _harvest_target == null or _harvest_target.is_depleted():
		return 0

	var requested_amount := mini(harvest_units_per_cycle, _harvest_target.remaining_amount)
	if _allow_partial_harvest_to_fill_inventory:
		requested_amount = mini(requested_amount, inventory.available_capacity())

	return requested_amount


func _request_container_deposit() -> void:
	_harvest_cycle_progress = 0.0
	robot_state = RobotState.INVENTORY_FULL
	harvest_inventory_full.emit(self)


func _restore_inventory_with_basic_bot_capacity(data: Dictionary) -> void:
	var capacity := _bot_inventory_capacity()
	var restored_inventory := Inventory.new(capacity)
	restored_inventory.restore(data)

	inventory = Inventory.new(capacity)
	for item_key: Variant in restored_inventory.contents().keys():
		if inventory.available_capacity() <= 0:
			return

		var item_id := str(item_key)
		inventory.add_item(item_id, mini(restored_inventory.get_quantity(item_id), inventory.available_capacity()))


func _apply_bot_definition() -> void:
	var definition := GameDefinitions.bot_definition(bot_definition_id)
	if definition.is_empty():
		sprite_index = BASIC_BOT_SPRITE_INDEX
		_sprite_texture_path = ""
		movement_speed = 100.0
		harvest_cycle_seconds = 5.0
		harvest_units_per_cycle = 1
		return

	sprite_index = int(definition.get("sprite_index", BASIC_BOT_SPRITE_INDEX))
	_sprite_texture_path = DefinitionManager.resolve_asset_path(definition, str(definition.get("sprite", "")))
	var movement: Dictionary = definition.get("movement", {})
	movement_speed = float(movement.get("speed", movement_speed))
	var harvest: Dictionary = definition.get("harvest", {})
	harvest_cycle_seconds = float(harvest.get("cycle_seconds", harvest_cycle_seconds))
	harvest_units_per_cycle = int(harvest.get("units_per_cycle", harvest_units_per_cycle))


func _bot_inventory_capacity() -> int:
	return int(GameDefinitions.bot_definition(bot_definition_id).get("inventory_capacity", BASIC_BOT_INVENTORY_CAPACITY))


func _create_sprite() -> void:
	if _sprite != null:
		return

	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)


func _apply_sprite_texture() -> void:
	if _sprite == null:
		return

	if not _sprite_texture_path.is_empty():
		_sprite.texture = load(_sprite_texture_path) as Texture2D
		return

	_sprite.texture = load(SPRITE_PATHS[clampi(sprite_index, 0, SPRITE_PATHS.size() - 1)]) as Texture2D


func _update_visual_offset() -> void:
	if _sprite != null:
		_sprite.position = visual_offset


func _update_facing_from_vector(movement_vector: Vector2) -> void:
	if movement_vector.length_squared() <= 0.0001:
		return

	facing_direction = _facing_direction_for_vector(movement_vector)
	_update_sprite_rotation()


func _facing_direction_for_vector(movement_vector: Vector2) -> int:
	var angle := fposmod(rad_to_deg(movement_vector.angle()) + 360.0, 360.0)
	if angle >= 337.5 or angle < 22.5:
		return FacingDirection.EAST
	if angle < 67.5:
		return FacingDirection.SOUTH_EAST
	if angle < 112.5:
		return FacingDirection.SOUTH
	if angle < 157.5:
		return FacingDirection.SOUTH_WEST
	if angle < 202.5:
		return FacingDirection.WEST
	if angle < 247.5:
		return FacingDirection.NORTH_WEST
	if angle < 292.5:
		return FacingDirection.NORTH

	return FacingDirection.NORTH_EAST


func _update_sprite_rotation() -> void:
	if _sprite == null:
		return

	match facing_direction:
		FacingDirection.NORTH:
			_sprite.rotation_degrees = 180.0
		FacingDirection.NORTH_EAST:
			_sprite.rotation_degrees = -135.0
		FacingDirection.EAST:
			_sprite.rotation_degrees = -90.0
		FacingDirection.SOUTH_EAST:
			_sprite.rotation_degrees = -45.0
		FacingDirection.SOUTH_WEST:
			_sprite.rotation_degrees = 45.0
		FacingDirection.WEST:
			_sprite.rotation_degrees = 90.0
		FacingDirection.NORTH_WEST:
			_sprite.rotation_degrees = 135.0
		_:
			_sprite.rotation_degrees = 0.0
