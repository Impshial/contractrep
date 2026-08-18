class_name Robot
extends Node2D

enum FacingDirection { NORTH, EAST, SOUTH, WEST }
enum RobotState { IDLE, MOVING, MOVING_TO_CHEST, DEPOSITING }

const ARRIVAL_DISTANCE: float = 3.0
const SELECTION_RADIUS: float = 20.0
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

@export var movement_speed: float = 140.0

var sprite_index: int = 0
var is_selected: bool = false
var destination: Vector2
var is_moving: bool = false
var facing_direction: int = FacingDirection.SOUTH
var visual_offset: Vector2 = Vector2.ZERO
var inventory := Inventory.new(50)
var robot_state: int = RobotState.IDLE

var _sprite: Sprite2D
var _path_points := PackedVector2Array()
var _path_index: int = 0
var _deposit_target: Chest


func _ready() -> void:
	destination = global_position
	_create_sprite()
	_apply_sprite_texture()
	_update_sprite_rotation()
	_update_visual_offset()
	queue_redraw()


func configure(new_sprite_index: int, world_position: Vector2) -> void:
	_create_sprite()
	sprite_index = clampi(new_sprite_index, 0, SPRITE_PATHS.size() - 1)
	global_position = world_position
	destination = world_position
	is_moving = false
	robot_state = RobotState.IDLE
	facing_direction = FacingDirection.SOUTH
	_path_points.clear()
	_path_index = 0
	_deposit_target = null
	visual_offset = Vector2.ZERO
	inventory = Inventory.new(50)
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


func start_deposit_to_chest(chest: Chest, world_path: PackedVector2Array) -> void:
	_deposit_target = chest
	set_path(world_path, RobotState.MOVING_TO_CHEST)


func display_name() -> String:
	return "Manufacturing Bot %02d" % [sprite_index + 1]


func state_display_name() -> String:
	match robot_state:
		RobotState.MOVING:
			return "Moving"
		RobotState.MOVING_TO_CHEST:
			return "Moving to Chest"
		RobotState.DEPOSITING:
			return "Depositing"
		_:
			return "Idle"


func serialize() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"destination_x": destination.x,
		"destination_y": destination.y,
		"sprite_index": sprite_index,
		"facing_direction": facing_direction,
		"is_moving": is_moving,
		"inventory": inventory.serialize(),
		"robot_state": robot_state,
	}


func restore(entry: Dictionary) -> void:
	var world_position := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	configure(int(entry.get("sprite_index", 0)), world_position)
	destination = Vector2(float(entry.get("destination_x", world_position.x)), float(entry.get("destination_y", world_position.y)))
	facing_direction = int(entry.get("facing_direction", FacingDirection.SOUTH))
	inventory.restore(entry.get("inventory", inventory.serialize()))
	robot_state = RobotState.IDLE
	is_moving = false
	_path_points.clear()
	_path_index = 0
	_deposit_target = null
	_update_sprite_rotation()


func _process(delta: float) -> void:
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
	if robot_state == RobotState.MOVING_TO_CHEST and _deposit_target != null:
		robot_state = RobotState.DEPOSITING
		var transferred := inventory.transfer_all_to(_deposit_target.inventory)
		if transferred > 0:
			_deposit_target.queue_redraw()
		else:
			print("Robot had nothing to deposit or chest was full.")
		_deposit_target = null

	robot_state = RobotState.IDLE


func _draw() -> void:
	if not is_selected:
		return

	draw_arc(visual_offset, 21.0, 0.0, TAU, 48, Color(0.28, 0.92, 1.0), 2.5)
	draw_arc(visual_offset, 24.0, 0.0, TAU, 48, Color(0.04, 0.16, 0.20, 0.85), 1.0)


func _create_sprite() -> void:
	if _sprite != null:
		return

	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)


func _apply_sprite_texture() -> void:
	if _sprite == null:
		return

	_sprite.texture = load(SPRITE_PATHS[sprite_index]) as Texture2D


func _update_visual_offset() -> void:
	if _sprite != null:
		_sprite.position = visual_offset


func _update_facing_from_vector(movement_vector: Vector2) -> void:
	if movement_vector.length_squared() <= 0.0001:
		return

	if absf(movement_vector.x) > absf(movement_vector.y):
		facing_direction = FacingDirection.EAST if movement_vector.x > 0.0 else FacingDirection.WEST
	else:
		facing_direction = FacingDirection.SOUTH if movement_vector.y > 0.0 else FacingDirection.NORTH

	_update_sprite_rotation()


func _update_sprite_rotation() -> void:
	if _sprite == null:
		return

	match facing_direction:
		FacingDirection.NORTH:
			_sprite.rotation_degrees = 180.0
		FacingDirection.EAST:
			_sprite.rotation_degrees = -90.0
		FacingDirection.WEST:
			_sprite.rotation_degrees = 90.0
		_:
			_sprite.rotation_degrees = 0.0