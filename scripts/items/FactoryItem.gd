class_name FactoryItem
extends Node2D

enum ItemType { IRON_ORE, COAL, IRON_PLATE }

const ITEM_VISUAL_SIZE: float = 24.0
const IRON_ORE_TEXTURE: Texture2D = preload("res://assets/resources/iron_ore.png")
const COAL_TEXTURE: Texture2D = preload("res://assets/resources/coal.png")
const IRON_PLATE_TEXTURE: Texture2D = preload("res://assets/resources/iron_plate.png")

var item_type: int = ItemType.IRON_ORE
var logical_grid_position: Vector2i = Vector2i.ZERO
var _queued_global_positions: Array[Vector2] = []
var _visual_speed_pixels: float = 96.0


func configure(new_item_type: int, grid_position: Vector2i, global_center: Vector2) -> void:
	item_type = new_item_type
	logical_grid_position = grid_position
	global_position = global_center
	_queued_global_positions.clear()
	queue_redraw()


func move_to_grid_position(grid_position: Vector2i, global_center: Vector2) -> void:
	logical_grid_position = grid_position
	_queued_global_positions.append(global_center)


func set_visual_speed_pixels(speed_pixels: float) -> void:
	_visual_speed_pixels = speed_pixels


func _process(delta: float) -> void:
	if _queued_global_positions.is_empty():
		return

	var target_global_position: Vector2 = _queued_global_positions[0]
	global_position = global_position.move_toward(target_global_position, _visual_speed_pixels * delta)

	if global_position.is_equal_approx(target_global_position):
		_queued_global_positions.pop_front()


func _draw() -> void:
	var texture := _item_texture()
	if texture == null:
		return

	var half_size: float = ITEM_VISUAL_SIZE * 0.5
	draw_texture_rect(texture, Rect2(Vector2(-half_size, -half_size), Vector2(ITEM_VISUAL_SIZE, ITEM_VISUAL_SIZE)), false)


func _item_texture() -> Texture2D:
	match item_type:
		ItemType.IRON_ORE:
			return IRON_ORE_TEXTURE
		ItemType.COAL:
			return COAL_TEXTURE
		ItemType.IRON_PLATE:
			return IRON_PLATE_TEXTURE

	return null