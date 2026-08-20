class_name Miner
extends Building

const PRODUCTION_DURATION_SECONDS: float = 2.0
const MINER_TEXTURE: Texture2D = preload("res://assets/buildings/miner.png")

var production_progress: float = 0.0
var pending_output: bool = false
var output_blocked: bool = false
var mined_resource_type: int = ResourceDeposit.ResourceType.IRON_ORE


func can_place_on(board: Board, target_grid_position: Vector2i) -> bool:
	var deposit := board.get_resource_at_cell(target_grid_position)
	if deposit != null:
		mined_resource_type = deposit.resource_type

	return board.can_place_at(target_grid_position) and _is_supported_deposit(deposit)


func on_placed(board: Board) -> void:
	var deposit := board.get_resource_at_cell(grid_position)
	if deposit != null:
		mined_resource_type = deposit.resource_type
		queue_redraw()


func advance_production(delta_seconds: float) -> void:
	if pending_output:
		output_blocked = true
		queue_redraw()
		return

	production_progress += delta_seconds
	if production_progress >= _production_duration_seconds():
		production_progress = _production_duration_seconds()
		pending_output = true
		output_blocked = true

	queue_redraw()


func mark_output_successful() -> void:
	pending_output = false
	output_blocked = false
	production_progress = 0.0
	queue_redraw()


func mark_output_blocked() -> void:
	output_blocked = true
	queue_redraw()


func get_production_ratio() -> float:
	return clampf(production_progress / _production_duration_seconds(), 0.0, 1.0)


func get_output_item_type() -> int:
	match mined_resource_type:
		ResourceDeposit.ResourceType.COAL:
			return FactoryItem.ItemType.COAL
		ResourceDeposit.ResourceType.STONE:
			return FactoryItem.ItemType.STONE

	return FactoryItem.ItemType.IRON_ORE


func _is_supported_deposit(deposit: ResourceDeposit) -> bool:
	if deposit == null:
		return false

	var supported_resources: Array = GameDefinitions.placeable_definition(placeable_id()).get("supported_resources", [])
	return supported_resources.has(DefinitionManager.normalize_resource_id(deposit.resource_id))


func placeable_id() -> String:
	return "miner"


func _production_duration_seconds() -> float:
	return float(GameDefinitions.placeable_definition(placeable_id()).get("production_duration_seconds", PRODUCTION_DURATION_SECONDS))


func _draw() -> void:
	var half_size: float = cell_size * 0.5
	var texture_rect := Rect2(Vector2(-half_size, -half_size), Vector2(cell_size, cell_size))
	var resource_dot_color := Color(0.95, 0.58, 0.25)

	if mined_resource_type == ResourceDeposit.ResourceType.COAL:
		resource_dot_color = Color(0.08, 0.09, 0.09)
	elif mined_resource_type == ResourceDeposit.ResourceType.STONE:
		resource_dot_color = Color(0.62, 0.63, 0.67)

	draw_texture_rect(MINER_TEXTURE, texture_rect, false)

	if is_preview:
		var preview_color := Color(0.20, 0.68, 0.38, 0.34) if is_valid_preview else Color(0.85, 0.22, 0.18, 0.42)
		draw_rect(texture_rect, preview_color, true)

	draw_circle(Vector2(-half_size + 11.0, -half_size + 11.0), 4.5, resource_dot_color)
	draw_arc(Vector2(-half_size + 11.0, -half_size + 11.0), 4.5, 0.0, TAU, 16, Color(0.82, 0.84, 0.80), 1.0)

	_draw_output_nub(half_size)
	_draw_progress_bar(half_size)


func _draw_output_nub(half_size: float) -> void:
	var output_direction: Vector2 = direction_vector()
	var side_direction: Vector2 = Vector2(-output_direction.y, output_direction.x)
	var inner_edge: Vector2 = output_direction * half_size
	var outer_edge: Vector2 = output_direction * (half_size + 2.0)
	var half_width: float = 5.0
	var nub_color := Color(0.20, 0.95, 0.38)

	draw_polygon(
		PackedVector2Array([
			inner_edge - side_direction * half_width,
			inner_edge + side_direction * half_width,
			outer_edge + side_direction * half_width,
			outer_edge - side_direction * half_width,
		]),
		PackedColorArray([nub_color, nub_color, nub_color, nub_color])
	)


func _draw_progress_bar(half_size: float) -> void:
	var bar_rect := Rect2(Vector2(-half_size + 8.0, half_size - 10.0), Vector2(cell_size - 16.0, 5.0))
	var fill_width: float = bar_rect.size.x * get_production_ratio()
	var fill_color := Color(0.95, 0.58, 0.25) if output_blocked else Color(0.30, 0.86, 0.45)

	draw_rect(bar_rect, Color(0.09, 0.10, 0.09), true)
	draw_rect(Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y)), fill_color, true)
	draw_rect(bar_rect, Color(0.78, 0.82, 0.78), false, 1.0)

