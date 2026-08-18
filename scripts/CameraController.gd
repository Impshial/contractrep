class_name CameraController
extends Camera2D

@export var board_path: NodePath
@export var min_zoom: float = 0.35
@export var max_zoom: float = 2.25
@export var zoom_step: float = 1.12
@export var keyboard_pan_speed: float = 640.0
@export var initial_center_cell: Vector2 = Vector2(50.0, 50.0)
@export var initial_visible_cells_wide: float = 20.0

var _board: Board
var _is_dragging: bool = false
var _last_drag_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_board = get_node(board_path) as Board
	make_current()
	_center_on_board()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_clamp_to_board()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		_handle_mouse_button(mouse_button)
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _is_dragging:
		position -= mouse_motion.relative / zoom.x
		_clamp_to_board()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _is_text_input_focused():
		return

	var pan_direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		pan_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan_direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		pan_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan_direction.y += 1.0

	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * keyboard_pan_speed * delta / zoom.x
		_clamp_to_board()


func _handle_mouse_button(mouse_button: InputEventMouseButton) -> void:
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
		_zoom_at_mouse(zoom_step)
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
		_zoom_at_mouse(1.0 / zoom_step)
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
		_is_dragging = mouse_button.pressed
		get_viewport().set_input_as_handled()


func _zoom_at_mouse(multiplier: float) -> void:
	var before_zoom_mouse_position := get_global_mouse_position()
	var new_zoom_value: float = clampf(zoom.x * multiplier, min_zoom, max_zoom)
	zoom = Vector2(new_zoom_value, new_zoom_value)
	var after_zoom_mouse_position := get_global_mouse_position()
	position += before_zoom_mouse_position - after_zoom_mouse_position
	_clamp_to_board()


func _center_on_board() -> void:
	position = _board.global_position + initial_center_cell * Board.CELL_SIZE
	var target_world_width: float = initial_visible_cells_wide * Board.CELL_SIZE
	var initial_zoom: float = get_viewport_rect().size.x / target_world_width
	zoom = Vector2.ONE * clampf(initial_zoom, min_zoom, max_zoom)
	_clamp_to_board()


func _clamp_to_board() -> void:
	if _board == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size / zoom
	var board_min: Vector2 = _board.global_position
	var board_max: Vector2 = _board.global_position + _board.board_size_pixels()

	if viewport_size.x >= _board.board_size_pixels().x:
		position.x = (board_min.x + board_max.x) * 0.5
	else:
		position.x = clampf(position.x, board_min.x + viewport_size.x * 0.5, board_max.x - viewport_size.x * 0.5)

	if viewport_size.y >= _board.board_size_pixels().y:
		position.y = (board_min.y + board_max.y) * 0.5
	else:
		position.y = clampf(position.y, board_min.y + viewport_size.y * 0.5, board_max.y - viewport_size.y * 0.5)


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
