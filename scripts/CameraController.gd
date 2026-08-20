class_name CameraController
extends Camera2D

@export var board_path: NodePath
@export var min_zoom: float = 0.35
@export var max_zoom: float = 1.35
@export var zoom_level_count: int = 3
@export var zoom_transition_seconds: float = 0.4
@export var wheel_gesture_cooldown_seconds: float = 0.28
@export var keyboard_pan_speed: float = 420.0
@export var initial_center_cell: Vector2 = Vector2.ZERO
@export var initial_visible_cells_wide: float = 20.0

var _board: Board
var _is_dragging: bool = false
var _last_drag_position: Vector2 = Vector2.ZERO
var _zoom_levels: Array[float] = []
var _zoom_level_index: int = 0
var _zoom_tween: Tween
var _wheel_gesture_cooldown: float = 0.0


func _ready() -> void:
	_board = get_node(board_path) as Board
	_rebuild_zoom_levels()
	make_current()
	_center_on_board()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		pass


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		_handle_mouse_button(mouse_button)
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _is_dragging:
		position -= mouse_motion.relative / zoom.x
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_wheel_gesture_cooldown = maxf(0.0, _wheel_gesture_cooldown - delta)

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


func _handle_mouse_button(mouse_button: InputEventMouseButton) -> void:
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
		_try_step_zoom_at_mouse(1)
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
		_try_step_zoom_at_mouse(-1)
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
		_is_dragging = mouse_button.pressed
		get_viewport().set_input_as_handled()


func _try_step_zoom_at_mouse(direction: int) -> void:
	if _wheel_gesture_cooldown > 0.0:
		return

	_wheel_gesture_cooldown = wheel_gesture_cooldown_seconds
	if _zoom_levels.is_empty():
		_rebuild_zoom_levels()

	_zoom_level_index = clampi(_zoom_level_index + direction, 0, _zoom_levels.size() - 1)
	_zoom_to_level_at_mouse(_zoom_level_index)


func _zoom_to_level_at_mouse(level_index: int) -> void:
	var before_zoom_mouse_position := get_global_mouse_position()
	var target_zoom_value: float = _zoom_levels[clampi(level_index, 0, _zoom_levels.size() - 1)]
	var current_zoom: Vector2 = zoom
	zoom = Vector2(target_zoom_value, target_zoom_value)
	var after_zoom_mouse_position := get_global_mouse_position()
	var target_position: Vector2 = position + before_zoom_mouse_position - after_zoom_mouse_position
	zoom = current_zoom

	if _zoom_tween != null:
		_zoom_tween.kill()

	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.tween_property(self, "zoom", Vector2(target_zoom_value, target_zoom_value), zoom_transition_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "position", target_position, zoom_transition_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _center_on_board() -> void:
	position = _board.global_position + initial_center_cell * Board.CELL_SIZE
	var target_world_width: float = initial_visible_cells_wide * Board.CELL_SIZE
	var initial_zoom: float = get_viewport_rect().size.x / target_world_width
	_zoom_level_index = _nearest_zoom_level_index(clampf(initial_zoom, min_zoom, max_zoom))
	var zoom_value: float = _zoom_levels[_zoom_level_index]
	zoom = Vector2.ONE * zoom_value


func _rebuild_zoom_levels() -> void:
	_zoom_levels.clear()
	var safe_level_count: int = maxi(2, zoom_level_count)
	var safe_min_zoom: float = maxf(0.001, min_zoom)
	var safe_max_zoom: float = maxf(safe_min_zoom, max_zoom)
	var zoom_ratio: float = safe_max_zoom / safe_min_zoom
	for index: int in range(safe_level_count):
		var ratio: float = float(index) / float(safe_level_count - 1)
		_zoom_levels.append(safe_min_zoom * pow(zoom_ratio, ratio))


func _nearest_zoom_level_index(zoom_value: float) -> int:
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index: int in range(_zoom_levels.size()):
		var distance: float = absf(_zoom_levels[index] - zoom_value)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	return nearest_index


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
