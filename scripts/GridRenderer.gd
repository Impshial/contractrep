class_name GridRenderer
extends Node2D

@export var board_path: NodePath

const FOREST_VARIANT_COUNT: int = 16
const GROUND_COLOR: Color = Color(0.58, 0.49, 0.34)
const WATER_COLOR: Color = Color(0.12, 0.33, 0.56)
const ROCK_COLOR: Color = Color(0.22, 0.24, 0.24)

var _board: Board
var _forest_textures: Array[Texture2D] = []
var _last_canvas_scale: Vector2 = Vector2(-1.0, -1.0)
var _last_viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_board = get_node(board_path) as Board
	if _board != null:
		_board.terrain_changed.connect(_on_board_terrain_changed)
	_load_forest_textures()
	_update_draw_state()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_redraw_after_resize")


func _process(_delta: float) -> void:
	if _draw_state_changed():
		_update_draw_state()
		queue_redraw()


func _draw() -> void:
	if _board == null:
		return

	var board_size: Vector2 = _board.board_size_pixels()
	var line_width: float = _screen_pixel_width(1.0)
	var border_width: float = _screen_pixel_width(2.0)

	_draw_terrain()
	_draw_resource_deposits()
	draw_rect(Rect2(Vector2.ZERO, board_size), Color(0.45, 0.55, 0.5), false, border_width)

	for column: int in range(Board.COLUMNS + 1):
		var x: float = column * Board.CELL_SIZE
		draw_line(Vector2(x, 0.0), Vector2(x, board_size.y), Color(0.28, 0.34, 0.32), line_width)

	for row: int in range(Board.ROWS + 1):
		var y: float = row * Board.CELL_SIZE
		draw_line(Vector2(0.0, y), Vector2(board_size.x, y), Color(0.28, 0.34, 0.32), line_width)


func _load_forest_textures() -> void:
	_forest_textures.clear()
	for index: int in range(FOREST_VARIANT_COUNT):
		var path := "res://assets/terrain/forest/forest_%02d.png" % [index + 1]
		var texture := load(path) as Texture2D
		if texture != null:
			_forest_textures.append(texture)


func _draw_terrain() -> void:
	for x: int in range(Board.COLUMNS):
		for y: int in range(Board.ROWS):
			var grid_position := Vector2i(x, y)
			var cell_origin := Vector2(x * Board.CELL_SIZE, y * Board.CELL_SIZE)
			var cell_rect := Rect2(cell_origin, Vector2(Board.CELL_SIZE, Board.CELL_SIZE))
			var terrain_type := _board.get_terrain_at_cell(grid_position)

			match terrain_type:
				Board.TerrainType.WATER:
					draw_rect(cell_rect, WATER_COLOR, true)
				Board.TerrainType.ROCK:
					draw_rect(cell_rect, ROCK_COLOR, true)
				Board.TerrainType.FOREST:
					draw_rect(cell_rect, GROUND_COLOR, true)
					_draw_forest_tile(grid_position, cell_rect)
				_:
					draw_rect(cell_rect, GROUND_COLOR, true)


func _draw_forest_tile(grid_position: Vector2i, cell_rect: Rect2) -> void:
	if _forest_textures.is_empty():
		return

	var variant_index := _board.get_forest_variant_at_cell(grid_position) % _forest_textures.size()
	var texture := _forest_textures[variant_index]
	if texture == null:
		return

	draw_texture_rect(texture, cell_rect, false)


func _draw_resource_deposits() -> void:
	for key: Variant in _board.get_resource_cells().keys():
		var grid_position: Vector2i = key
		var deposit := _board.get_resource_at_cell(grid_position)
		if deposit == null:
			continue

		var cell_origin := Vector2(grid_position.x * Board.CELL_SIZE, grid_position.y * Board.CELL_SIZE)
		var deposit_rect := Rect2(cell_origin + Vector2(4.0, 4.0), Vector2(Board.CELL_SIZE - 8.0, Board.CELL_SIZE - 8.0))

		if deposit.resource_type == ResourceDeposit.ResourceType.COAL:
			draw_rect(deposit_rect, Color(0.04, 0.05, 0.05), true)
			draw_rect(deposit_rect, Color(0.35, 0.40, 0.39), false, 2.0)
			draw_circle(cell_origin + Vector2(16.0, 18.0), 6.0, Color(0.12, 0.14, 0.14))
			draw_circle(cell_origin + Vector2(31.0, 27.0), 7.0, Color(0.02, 0.025, 0.025))
			draw_circle(cell_origin + Vector2(22.0, 34.0), 4.0, Color(0.28, 0.31, 0.30))
		else:
			draw_rect(deposit_rect, Color(0.33, 0.21, 0.14), true)
			draw_rect(deposit_rect, Color(0.78, 0.47, 0.24), false, 2.0)
			draw_circle(cell_origin + Vector2(17.0, 17.0), 5.0, Color(0.95, 0.64, 0.31))
			draw_circle(cell_origin + Vector2(31.0, 28.0), 6.0, Color(0.70, 0.39, 0.20))
			draw_circle(cell_origin + Vector2(23.0, 34.0), 4.0, Color(1.0, 0.74, 0.41))


func _on_board_terrain_changed() -> void:
	queue_redraw()


func _redraw_after_resize() -> void:
	_update_draw_state()
	queue_redraw()


func _draw_state_changed() -> bool:
	var canvas_scale := _current_canvas_scale()
	var viewport_size := get_viewport_rect().size
	return not canvas_scale.is_equal_approx(_last_canvas_scale) or not viewport_size.is_equal_approx(_last_viewport_size)


func _update_draw_state() -> void:
	_last_canvas_scale = _current_canvas_scale()
	_last_viewport_size = get_viewport_rect().size


func _screen_pixel_width(screen_pixels: float) -> float:
	var canvas_scale := _current_canvas_scale()
	var scale := maxf(minf(absf(canvas_scale.x), absf(canvas_scale.y)), 0.001)
	return screen_pixels / scale


func _current_canvas_scale() -> Vector2:
	var transform := get_viewport().get_canvas_transform()
	return transform.get_scale()