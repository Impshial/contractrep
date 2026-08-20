class_name GridRenderer
extends Node2D

@export var board_path: NodePath

const FOREST_VARIANT_COUNT: int = 16
const GROUND_TEXTURE_VARIANT_COUNT: int = 8
const GROUND_COLOR: Color = Color(0.58, 0.49, 0.34)
const WATER_COLOR: Color = Color(0.12, 0.33, 0.56)
const ROCK_COLOR: Color = Color(0.48, 0.36, 0.27)
const MAX_RENDERED_COLUMNS: int = 96
const MAX_RENDERED_ROWS: int = 72

var _board: Board
var _forest_textures: Array[Texture2D] = []
var _ground_textures: Array[Texture2D] = []
var _resource_textures: Dictionary = {}
var _last_canvas_scale: Vector2 = Vector2(-1.0, -1.0)
var _last_canvas_origin: Vector2 = Vector2(INF, INF)
var _last_viewport_size: Vector2 = Vector2.ZERO
var _grid_visible: bool = true


func _ready() -> void:
	_board = get_node(board_path) as Board
	if _board != null:
		_board.terrain_changed.connect(_on_board_terrain_changed)
		_board.resource_changed.connect(_on_board_resource_changed)
	_load_forest_textures()
	_load_ground_textures()
	_load_resource_textures()
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

	var visible_cells := _visible_cell_rect(2)
	var line_width: float = _screen_pixel_width(1.0)

	_draw_terrain(visible_cells)
	_draw_resource_deposits(visible_cells)
	if not _grid_visible:
		return

	var start_x := visible_cells.position.x
	var end_x := visible_cells.position.x + visible_cells.size.x
	var start_y := visible_cells.position.y
	var end_y := visible_cells.position.y + visible_cells.size.y
	var grid_color := Color(0.28, 0.34, 0.32)

	for column: int in range(start_x, end_x + 1):
		var x: float = column * Board.CELL_SIZE
		draw_line(Vector2(x, start_y * Board.CELL_SIZE), Vector2(x, end_y * Board.CELL_SIZE), grid_color, line_width)

	for row: int in range(start_y, end_y + 1):
		var y: float = row * Board.CELL_SIZE
		draw_line(Vector2(start_x * Board.CELL_SIZE, y), Vector2(end_x * Board.CELL_SIZE, y), grid_color, line_width)


func set_grid_visible(grid_visible: bool) -> void:
	if _grid_visible == grid_visible:
		return

	_grid_visible = grid_visible
	queue_redraw()


func _load_forest_textures() -> void:
	_forest_textures.clear()
	for index: int in range(FOREST_VARIANT_COUNT):
		var path := "res://assets/terrain/forest/forest_%02d.png" % [index + 1]
		var texture := load(path) as Texture2D
		if texture != null:
			_forest_textures.append(texture)


func _load_ground_textures() -> void:
	_ground_textures.clear()
	for index: int in range(GROUND_TEXTURE_VARIANT_COUNT):
		var path := "res://assets/terrain/ground/ground_%02d.png" % [index + 1]
		var texture := load(path) as Texture2D
		if texture != null:
			_ground_textures.append(texture)



func _load_resource_textures() -> void:
	_resource_textures.clear()
	for definition: Dictionary in DefinitionManager.definitions("resource").values():
		var textures: Array[Texture2D] = []
		for path: String in DefinitionManager.resolved_resource_texture_paths(str(definition.get("id", ""))):
			var texture := load(path) as Texture2D
			if texture != null:
				textures.append(texture)

		_resource_textures[str(definition.get("legacy_id", definition.get("id", "")))] = textures

func _draw_terrain(visible_cells: Rect2i) -> void:
	for x: int in range(visible_cells.position.x, visible_cells.position.x + visible_cells.size.x):
		for y: int in range(visible_cells.position.y, visible_cells.position.y + visible_cells.size.y):
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
					_draw_ground_tile(grid_position, cell_rect)
					_draw_forest_tile(grid_position, cell_rect)
				_:
					_draw_ground_tile(grid_position, cell_rect)


func _draw_ground_tile(grid_position: Vector2i, cell_rect: Rect2) -> void:
	if _ground_textures.is_empty():
		draw_rect(cell_rect, GROUND_COLOR, true)
		return

	var variant_index := _ground_variant_for_cell(grid_position)
	var texture := _ground_textures[variant_index]
	if texture == null:
		draw_rect(cell_rect, GROUND_COLOR, true)
		return

	draw_texture_rect(texture, cell_rect, false)


func _draw_forest_tile(grid_position: Vector2i, cell_rect: Rect2) -> void:
	if _forest_textures.is_empty():
		return

	var variant_index := _board.get_forest_variant_at_cell(grid_position) % _forest_textures.size()
	var texture := _forest_textures[variant_index]
	if texture == null:
		return

	draw_texture_rect(texture, cell_rect, false)


func _draw_resource_deposits(visible_cells: Rect2i) -> void:
	for key: Variant in _board.get_resource_cells_in_rect(visible_cells).keys():
		var grid_position: Vector2i = key
		var deposit := _board.get_resource_at_cell(grid_position)
		if deposit == null or deposit.resource_id == "wood":
			continue

		var cell_origin := Vector2(grid_position.x * Board.CELL_SIZE, grid_position.y * Board.CELL_SIZE)
		var cell_rect := Rect2(cell_origin, Vector2(Board.CELL_SIZE, Board.CELL_SIZE))
		var textures: Array = _resource_textures.get(deposit.resource_id, [])
		if textures.is_empty():
			draw_rect(cell_rect, Color(0.33, 0.21, 0.14), true)
			continue

		var texture := textures[deposit.texture_variant % textures.size()] as Texture2D
		if texture != null:
			draw_texture_rect(texture, cell_rect, false)


func _ground_variant_for_cell(grid_position: Vector2i) -> int:
	var value := _board.active_world_seed
	value = _mix_int(value, grid_position.x + 0x51ED)
	value = _mix_int(value, grid_position.y + 0xA341)
	return absi(value) % _ground_textures.size()


func _mix_int(value: int, salt: int) -> int:
	var mixed := value ^ (salt * 374761393)
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return mixed ^ (mixed >> 16)


func _on_board_terrain_changed() -> void:
	queue_redraw()


func _on_board_resource_changed(_grid_position: Vector2i) -> void:
	queue_redraw()


func _redraw_after_resize() -> void:
	_update_draw_state()
	queue_redraw()


func _draw_state_changed() -> bool:
	var canvas_transform := get_viewport().get_canvas_transform()
	var canvas_scale := canvas_transform.get_scale()
	var canvas_origin := canvas_transform.origin
	var viewport_size := get_viewport_rect().size
	return (
		not canvas_scale.is_equal_approx(_last_canvas_scale)
		or not canvas_origin.is_equal_approx(_last_canvas_origin)
		or not viewport_size.is_equal_approx(_last_viewport_size)
	)


func _update_draw_state() -> void:
	var canvas_transform := get_viewport().get_canvas_transform()
	_last_canvas_scale = canvas_transform.get_scale()
	_last_canvas_origin = canvas_transform.origin
	_last_viewport_size = get_viewport_rect().size


func _screen_pixel_width(screen_pixels: float) -> float:
	var canvas_scale := _current_canvas_scale()
	var scale := maxf(minf(absf(canvas_scale.x), absf(canvas_scale.y)), 0.001)
	return screen_pixels / scale


func _current_canvas_scale() -> Vector2:
	var transform := get_viewport().get_canvas_transform()
	return transform.get_scale()


func _visible_cell_rect(padding: int) -> Rect2i:
	var viewport_size := get_viewport_rect().size
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := to_local(inverse_canvas * Vector2.ZERO)
	var bottom_right := to_local(inverse_canvas * viewport_size)
	var min_x := floori(minf(top_left.x, bottom_right.x) / Board.CELL_SIZE) - padding
	var max_x := ceili(maxf(top_left.x, bottom_right.x) / Board.CELL_SIZE) + padding
	var min_y := floori(minf(top_left.y, bottom_right.y) / Board.CELL_SIZE) - padding
	var max_y := ceili(maxf(top_left.y, bottom_right.y) / Board.CELL_SIZE) + padding
	if max_x - min_x > MAX_RENDERED_COLUMNS:
		var center_x := floori(float(min_x + max_x) * 0.5)
		min_x = center_x - int(MAX_RENDERED_COLUMNS * 0.5)
		max_x = min_x + MAX_RENDERED_COLUMNS
	if max_y - min_y > MAX_RENDERED_ROWS:
		var center_y := floori(float(min_y + max_y) * 0.5)
		min_y = center_y - int(MAX_RENDERED_ROWS * 0.5)
		max_y = min_y + MAX_RENDERED_ROWS

	return Rect2i(min_x, min_y, maxi(1, max_x - min_x), maxi(1, max_y - min_y))
