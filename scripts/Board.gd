class_name Board
extends Node2D

signal terrain_changed()
signal traversability_changed(grid_position: Vector2i)

const COLUMNS: int = 100
const ROWS: int = 100
const CELL_SIZE: int = 48
const DEFAULT_WORLD_SEED: int = WorldGenerator.DEFAULT_SEED

enum TerrainType { GROUND, WATER, ROCK, FOREST }

var active_world_seed: int = DEFAULT_WORLD_SEED

var _occupied_cells: Dictionary = {}
var _resource_cells: Dictionary = {}
var _terrain_cells: Dictionary = {}
var _forest_variant_cells: Dictionary = {}
var _world_generator := WorldGenerator.new()


func _ready() -> void:
	generate_terrain(active_world_seed)
	_create_fixed_resource_patches()


func world_to_grid(world_position: Vector2) -> Vector2i:
	var local_position: Vector2 = to_local(world_position)
	return Vector2i(
		floori(local_position.x / CELL_SIZE),
		floori(local_position.y / CELL_SIZE)
	)


func grid_to_world(grid_position: Vector2i) -> Vector2:
	var local_center: Vector2 = Vector2(
		(grid_position.x + 0.5) * CELL_SIZE,
		(grid_position.y + 0.5) * CELL_SIZE
	)
	return to_global(local_center)


func board_size_pixels() -> Vector2:
	return Vector2(COLUMNS * CELL_SIZE, ROWS * CELL_SIZE)


func is_in_bounds(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 0
		and grid_position.y >= 0
		and grid_position.x < COLUMNS
		and grid_position.y < ROWS
	)


func is_cell_occupied(grid_position: Vector2i) -> bool:
	return _occupied_cells.has(grid_position)


func get_building_at_cell(grid_position: Vector2i) -> Building:
	return _occupied_cells.get(grid_position) as Building


func can_place_at(grid_position: Vector2i) -> bool:
	return is_in_bounds(grid_position) and not is_cell_occupied(grid_position)


func occupy_cell(grid_position: Vector2i, building: Building) -> bool:
	if not can_place_at(grid_position):
		return false

	_occupied_cells[grid_position] = building
	traversability_changed.emit(grid_position)
	return true


func clear_cell(grid_position: Vector2i) -> void:
	_occupied_cells.erase(grid_position)
	traversability_changed.emit(grid_position)


func clear_all_buildings() -> void:
	_occupied_cells.clear()
	traversability_changed.emit(Vector2i(-1, -1))


func get_building_count() -> int:
	return _occupied_cells.size()


func get_all_buildings() -> Array[Building]:
	var buildings: Array[Building] = []
	for value: Variant in _occupied_cells.values():
		var building := value as Building
		if building == null:
			continue

		buildings.append(building)

	return buildings


func generate_terrain(seed_value: int) -> void:
	var terrain_data := _world_generator.generate(COLUMNS, ROWS, seed_value)
	active_world_seed = seed_value
	_terrain_cells = terrain_data.get("terrain_cells", {}) as Dictionary
	_forest_variant_cells = terrain_data.get("forest_variant_cells", {}) as Dictionary
	terrain_changed.emit()
	traversability_changed.emit(Vector2i(-1, -1))


func clear_terrain() -> void:
	_terrain_cells.clear()
	_forest_variant_cells.clear()


func set_terrain_at_cell(grid_position: Vector2i, terrain_type: int, forest_variant: int = 0) -> void:
	if not is_in_bounds(grid_position):
		return

	_terrain_cells[grid_position] = terrain_type
	if terrain_type == TerrainType.FOREST:
		_forest_variant_cells[grid_position] = forest_variant
	else:
		_forest_variant_cells.erase(grid_position)

	terrain_changed.emit()
	traversability_changed.emit(grid_position)


func get_terrain_at_cell(grid_position: Vector2i) -> int:
	return int(_terrain_cells.get(grid_position, TerrainType.GROUND))


func get_forest_variant_at_cell(grid_position: Vector2i) -> int:
	return int(_forest_variant_cells.get(grid_position, 0))


func get_terrain_cells() -> Dictionary:
	return _terrain_cells

func is_robot_terrain_walkable(grid_position: Vector2i) -> bool:
	if not is_in_bounds(grid_position):
		return false

	if has_any_resource_at_cell(grid_position):
		return true

	return get_terrain_at_cell(grid_position) == TerrainType.GROUND


func is_robot_walkable_cell(grid_position: Vector2i) -> bool:
	if not is_robot_terrain_walkable(grid_position):
		return false

	var building := get_building_at_cell(grid_position)
	return building == null or building is Conveyor

func get_resource_at_cell(grid_position: Vector2i) -> ResourceDeposit:
	return _resource_cells.get(grid_position) as ResourceDeposit


func has_resource_at_cell(grid_position: Vector2i, resource_type: int) -> bool:
	var deposit := get_resource_at_cell(grid_position)
	return deposit != null and deposit.resource_type == resource_type


func has_any_resource_at_cell(grid_position: Vector2i) -> bool:
	return get_resource_at_cell(grid_position) != null


func get_resource_cells() -> Dictionary:
	return _resource_cells


func _create_fixed_resource_patches() -> void:
	# Resource data is separate from building occupancy and terrain: miners can sit on deposits.
	for x: int in range(43, 47):
		for y: int in range(45, 49):
			_resource_cells[Vector2i(x, y)] = ResourceDeposit.new(ResourceDeposit.ResourceType.IRON_ORE)

	for x: int in range(54, 58):
		for y: int in range(51, 54):
			_resource_cells[Vector2i(x, y)] = ResourceDeposit.new(ResourceDeposit.ResourceType.IRON_ORE)

	for x: int in range(58, 63):
		for y: int in range(44, 48):
			_resource_cells[Vector2i(x, y)] = ResourceDeposit.new(ResourceDeposit.ResourceType.COAL)

	for x: int in range(47, 51):
		for y: int in range(56, 60):
			_resource_cells[Vector2i(x, y)] = ResourceDeposit.new(ResourceDeposit.ResourceType.COAL)

	traversability_changed.emit(Vector2i(-1, -1))
