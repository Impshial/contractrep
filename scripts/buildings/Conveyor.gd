class_name Conveyor
extends Building

const STRAIGHT_ANIMATION: StringName = &"straight"
const STRAIGHT_FRAME_COUNT: int = 8
const STRAIGHT_FRAME_SIZE: Vector2i = Vector2i(48, 48)
const STRAIGHT_SHEET: Texture2D = preload("res://assets/conveyors/belt_straight_black_yellow_smooth.png")
const BELT_SECONDS_PER_TILE: float = 0.5
const FRAME_ADVANCE_PIXELS: float = 6.0
const MAX_STACKED_ITEMS: int = 4

var current_item: FactoryItem
var stacked_items: Array[FactoryItem] = []
var _animated_sprite: AnimatedSprite2D
var _preview_overlay: ColorRect


func can_accept_item() -> bool:
	return stacked_items.size() < MAX_STACKED_ITEMS


func can_accept_item_type(item_type: int) -> bool:
	if GameDefinitions.item_is_stackable(item_type):
		return stacked_items.size() < MAX_STACKED_ITEMS

	return stacked_items.is_empty()


func can_accept_item_from(source_grid_position: Vector2i) -> bool:
	if not can_accept_item():
		return false

	return can_receive_item_from_direction(source_grid_position)


func can_receive_item_from_direction(source_grid_position: Vector2i) -> bool:
	var entry_offset: Vector2i = source_grid_position - grid_position
	return entry_offset != direction_grid_offset()


func can_accept_after_departures(departing_count: int) -> bool:
	return max(0, stacked_items.size() - departing_count) < MAX_STACKED_ITEMS


func accept_item(item: FactoryItem) -> bool:
	if not can_accept_item_type(item.item_type):
		return false

	stacked_items.append(item)
	_update_current_item()
	_refresh_item_positions()
	return true


func accept_item_from(item: FactoryItem, source_grid_position: Vector2i) -> bool:
	if not can_receive_item_from_direction(source_grid_position) or not can_accept_item_type(item.item_type):
		return false

	stacked_items.append(item)
	_update_current_item()
	_refresh_item_positions()
	return true


func release_item() -> FactoryItem:
	if stacked_items.is_empty():
		current_item = null
		return null

	var item := stacked_items.pop_front() as FactoryItem
	_update_current_item()
	_refresh_item_positions()
	return item


func get_item_count() -> int:
	return stacked_items.size()


func get_item_global_position(item: FactoryItem) -> Vector2:
	var item_index := stacked_items.find(item)
	if item_index < 0:
		return global_position

	return _slot_global_position(item_index, stacked_items.size())


func _ready() -> void:
	_create_animated_sprite()
	_update_animated_sprite()


func configure(new_grid_position: Vector2i, new_direction: int, new_cell_size: int) -> void:
	super.configure(new_grid_position, new_direction, new_cell_size)
	_update_animated_sprite()
	_refresh_item_positions()


func set_preview_mode(enabled: bool) -> void:
	super.set_preview_mode(enabled)
	_update_animated_sprite()


func set_preview_valid(valid: bool) -> void:
	super.set_preview_valid(valid)
	_update_preview_overlay()


func rotate_clockwise() -> void:
	super.rotate_clockwise()
	_update_animated_sprite()
	_refresh_item_positions()


func placeable_id() -> String:
	return "conveyor"


func _draw() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		_draw_fallback_conveyor()


func _update_current_item() -> void:
	if stacked_items.is_empty():
		current_item = null
	else:
		current_item = stacked_items[0]


func _refresh_item_positions() -> void:
	var item_count := stacked_items.size()
	for item_index: int in range(item_count):
		var item := stacked_items[item_index] as FactoryItem
		if item == null:
			continue

		item.move_to_grid_position(grid_position, _slot_global_position(item_index, item_count))


func _slot_global_position(item_index: int, item_count: int) -> Vector2:
	var offsets := _slot_offsets(item_count)
	var forward := direction_vector()
	var local_offset := forward * offsets[item_index]
	return global_position + local_offset


func _slot_offsets(item_count: int) -> PackedFloat32Array:
	match item_count:
		1:
			return PackedFloat32Array([0.0])
		2:
			return PackedFloat32Array([9.0, -9.0])
		3:
			return PackedFloat32Array([12.0, 0.0, -12.0])
		_:
			return PackedFloat32Array([12.0, 4.0, -4.0, -12.0])


func _create_animated_sprite() -> void:
	if _animated_sprite != null:
		return

	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.sprite_frames = _create_sprite_frames()
	_animated_sprite.animation = STRAIGHT_ANIMATION
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.play()
	add_child(_animated_sprite)

	_preview_overlay = ColorRect.new()
	_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_overlay.position = Vector2(-cell_size * 0.5 + 3.0, -cell_size * 0.5 + 3.0)
	_preview_overlay.size = Vector2(cell_size - 6.0, cell_size - 6.0)
	_preview_overlay.z_index = 1
	_preview_overlay.visible = false
	add_child(_preview_overlay)


func _create_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(STRAIGHT_ANIMATION)
	sprite_frames.set_animation_loop(STRAIGHT_ANIMATION, true)
	sprite_frames.set_animation_speed(STRAIGHT_ANIMATION, _belt_animation_fps())

	for frame_index: int in range(STRAIGHT_FRAME_COUNT):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = STRAIGHT_SHEET
		frame_texture.region = Rect2(
			Vector2(frame_index * STRAIGHT_FRAME_SIZE.x, 0),
			Vector2(STRAIGHT_FRAME_SIZE.x, STRAIGHT_FRAME_SIZE.y)
		)
		sprite_frames.add_frame(STRAIGHT_ANIMATION, frame_texture)

	return sprite_frames


func _belt_animation_fps() -> float:
	var belt_pixels_per_second := float(Board.CELL_SIZE) / BELT_SECONDS_PER_TILE
	return belt_pixels_per_second / FRAME_ADVANCE_PIXELS


func _update_animated_sprite() -> void:
	if _animated_sprite == null:
		return

	_animated_sprite.rotation = direction_vector().angle()
	_animated_sprite.visible = true
	_animated_sprite.play(STRAIGHT_ANIMATION)
	_update_preview_overlay()
	queue_redraw()


func _update_preview_overlay() -> void:
	if _preview_overlay == null:
		return

	_preview_overlay.position = Vector2(-cell_size * 0.5 + 3.0, -cell_size * 0.5 + 3.0)
	_preview_overlay.size = Vector2(cell_size - 6.0, cell_size - 6.0)
	_preview_overlay.color = Color(0.20, 0.68, 0.38, 0.30) if is_valid_preview else Color(0.85, 0.22, 0.18, 0.38)
	_preview_overlay.visible = is_preview


func _draw_fallback_conveyor() -> void:
	var half_size: float = cell_size * 0.5
	var body_rect := Rect2(Vector2(-half_size + 5.0, -half_size + 5.0), Vector2(cell_size - 10.0, cell_size - 10.0))
	var body_color := Color(0.34, 0.42, 0.46)
	var border_color := Color(0.77, 0.86, 0.88)

	if is_preview:
		body_color = Color(0.20, 0.68, 0.38) if is_valid_preview else Color(0.85, 0.22, 0.18)
		border_color = Color(0.90, 1.0, 0.92) if is_valid_preview else Color(1.0, 0.78, 0.72)

	draw_rect(body_rect, body_color, true)
	draw_rect(body_rect, border_color, false, 2.0)

	var arrow_direction: Vector2 = direction_vector()
	var arrow_tip: Vector2 = arrow_direction * (half_size - 10.0)
	var arrow_tail: Vector2 = -arrow_direction * (half_size - 13.0)
	var side_direction: Vector2 = Vector2(-arrow_direction.y, arrow_direction.x)
	var arrow_color := Color(1.0, 0.92, 0.24)

	draw_line(arrow_tail, arrow_tip, arrow_color, 5.0)
	draw_polygon(
		PackedVector2Array([
			arrow_tip,
			arrow_tip - arrow_direction * 14.0 + side_direction * 8.0,
			arrow_tip - arrow_direction * 14.0 - side_direction * 8.0,
		]),
		PackedColorArray([arrow_color, arrow_color, arrow_color])
	)