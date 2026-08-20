class_name Board
extends Node2D

signal terrain_changed()
signal traversability_changed(grid_position: Vector2i)
signal resource_changed(grid_position: Vector2i)
signal building_placed(building: Building)

const COLUMNS: int = 100
const ROWS: int = 100
const CELL_SIZE: int = 48
const DEFAULT_WORLD_SEED: int = WorldGenerator.DEFAULT_SEED
const START_CELL: Vector2i = WorldGenerator.START_CELL
const WORLD_HALF_SIZE_TILES: int = 65536
const REFRESH_ALL_CELLS: Vector2i = Vector2i(-999999998, -999999998)

const RESOURCE_TEXTURE_VARIANT_COUNT: int = 8

enum TerrainType { GROUND, WATER, ROCK, FOREST }

var active_world_seed: int = DEFAULT_WORLD_SEED

var _occupied_cells: Dictionary = {}
var _resource_cells: Dictionary = {}
var _modified_resource_cells: Dictionary = {}
var _terrain_cells: Dictionary = {}
var _forest_variant_cells: Dictionary = {}
var _generated_resource_cells: Dictionary = {}
var _world_generator := WorldGenerator.new()


func _ready() -> void:
	_world_generator.setup(active_world_seed)


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
	return Vector2(WORLD_HALF_SIZE_TILES * 2 * CELL_SIZE, WORLD_HALF_SIZE_TILES * 2 * CELL_SIZE)


func is_in_bounds(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= -WORLD_HALF_SIZE_TILES
		and grid_position.y >= -WORLD_HALF_SIZE_TILES
		and grid_position.x <= WORLD_HALF_SIZE_TILES
		and grid_position.y <= WORLD_HALF_SIZE_TILES
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
	building_placed.emit(building)
	return true


func clear_cell(grid_position: Vector2i) -> void:
	_occupied_cells.erase(grid_position)
	traversability_changed.emit(grid_position)


func clear_all_buildings() -> void:
	_occupied_cells.clear()
	traversability_changed.emit(REFRESH_ALL_CELLS)


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
	active_world_seed = seed_value
	_world_generator.setup(seed_value)
	_terrain_cells.clear()
	_forest_variant_cells.clear()
	_generated_resource_cells.clear()
	_resource_cells.clear()
	_modified_resource_cells.clear()
	terrain_changed.emit()
	traversability_changed.emit(REFRESH_ALL_CELLS)


func clear_terrain() -> void:
	_terrain_cells.clear()
	_forest_variant_cells.clear()
	_resource_cells.clear()
	_modified_resource_cells.clear()
	_generated_resource_cells.clear()


func set_terrain_at_cell(grid_position: Vector2i, terrain_type: int, forest_variant: int = 0) -> void:
	if not is_in_bounds(grid_position):
		return

	_terrain_cells[grid_position] = terrain_type
	if terrain_type == TerrainType.FOREST:
		_forest_variant_cells[grid_position] = forest_variant
		_resource_cells[grid_position] = ResourceDeposit.from_resource_id("wood", -1, forest_variant)
	else:
		_forest_variant_cells.erase(grid_position)
		var deposit := get_resource_at_cell(grid_position)
		if deposit != null:
			_resource_cells.erase(grid_position)

	terrain_changed.emit()
	traversability_changed.emit(grid_position)


func get_terrain_at_cell(grid_position: Vector2i) -> int:
	if _terrain_cells.has(grid_position):
		return int(_terrain_cells.get(grid_position, TerrainType.GROUND))

	return _world_generator.terrain_type_for_cell(grid_position)


func get_forest_variant_at_cell(grid_position: Vector2i) -> int:
	if _forest_variant_cells.has(grid_position):
		return int(_forest_variant_cells.get(grid_position, 0))

	return _world_generator.forest_variant_for_cell(grid_position)


func get_terrain_cells() -> Dictionary:
	return _terrain_cells


func is_robot_terrain_walkable(grid_position: Vector2i) -> bool:
	if not is_in_bounds(grid_position):
		return false

	var terrain_type := get_terrain_at_cell(grid_position)
	if terrain_type == TerrainType.FOREST or terrain_type == TerrainType.WATER or terrain_type == TerrainType.ROCK:
		return false

	return true


func is_robot_walkable_cell(grid_position: Vector2i) -> bool:
	if not is_robot_terrain_walkable(grid_position):
		return false

	var building := get_building_at_cell(grid_position)
	return building == null or building is Conveyor


func get_resource_at_cell(grid_position: Vector2i) -> ResourceDeposit:
	_ensure_resource_cell(grid_position)
	var deposit := _resource_cells.get(grid_position) as ResourceDeposit
	if deposit != null and deposit.is_depleted():
		return null

	return deposit


func get_resource_record_at_cell(grid_position: Vector2i) -> ResourceDeposit:
	_ensure_resource_cell(grid_position)
	return _resource_cells.get(grid_position) as ResourceDeposit


func mark_resource_changed(grid_position: Vector2i) -> void:
	_modified_resource_cells[grid_position] = true
	resource_changed.emit(grid_position)


func deplete_resource_at_cell(grid_position: Vector2i) -> void:
	var deposit := get_resource_record_at_cell(grid_position)
	if deposit == null or not deposit.is_depleted():
		return

	if deposit.resource_id == "wood":
		_terrain_cells[grid_position] = TerrainType.GROUND
		_forest_variant_cells.erase(grid_position)

	_modified_resource_cells[grid_position] = true
	resource_changed.emit(grid_position)
	if deposit.resource_id == "wood":
		traversability_changed.emit(grid_position)


func has_resource_at_cell(grid_position: Vector2i, resource_type: int) -> bool:
	var deposit := get_resource_at_cell(grid_position)
	return deposit != null and deposit.resource_type == resource_type


func has_any_resource_at_cell(grid_position: Vector2i) -> bool:
	return get_resource_at_cell(grid_position) != null


func get_resource_cells() -> Dictionary:
	return _resource_cells


func get_resource_cells_in_rect(cell_rect: Rect2i) -> Dictionary:
	var visible_resource_cells: Dictionary = {}
	for x: int in range(cell_rect.position.x, cell_rect.position.x + cell_rect.size.x):
		for y: int in range(cell_rect.position.y, cell_rect.position.y + cell_rect.size.y):
			var grid_position := Vector2i(x, y)
			var deposit := get_resource_at_cell(grid_position)
			if deposit != null:
				visible_resource_cells[grid_position] = deposit

	return visible_resource_cells


func get_resource_cells_near(center_cell: Vector2i, radius: int, resource_item_id: String = "") -> Dictionary:
	var nearby_resource_cells: Dictionary = {}
	var radius_squared := radius * radius
	for x: int in range(center_cell.x - radius, center_cell.x + radius + 1):
		for y: int in range(center_cell.y - radius, center_cell.y + radius + 1):
			var grid_position := Vector2i(x, y)
			var dx := grid_position.x - center_cell.x
			var dy := grid_position.y - center_cell.y
			if dx * dx + dy * dy > radius_squared:
				continue

			var deposit := get_resource_at_cell(grid_position)
			if deposit == null or not deposit.is_harvestable():
				continue
			if not resource_item_id.is_empty() and deposit.inventory_item_id() != resource_item_id:
				continue

			nearby_resource_cells[grid_position] = deposit

	return nearby_resource_cells


func serialize_resources() -> Array[Dictionary]:
	var resource_data: Array[Dictionary] = []
	for key: Variant in _modified_resource_cells.keys():
		var grid_position: Vector2i = key
		var deposit := get_resource_record_at_cell(grid_position)
		if deposit != null:
			resource_data.append(deposit.serialize(grid_position))

	return resource_data


func restore_resources(resource_data: Array) -> void:
	for entry_variant: Variant in resource_data:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var grid_position := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var resource_id := str(entry.get("resource_id", "iron_ore"))
		var maximum := int(entry.get("maximum_amount", GameDefinitions.resource_definition(resource_id).get("starting_amount", 1000)))
		var remaining := int(entry.get("remaining_amount", maximum))
		var variant := int(entry.get("texture_variant", _resource_variant_for_cell(grid_position, resource_id)))
		var deposit := ResourceDeposit.from_resource_id(resource_id, maximum, variant)
		deposit.restore_amount(remaining, maximum)
		_resource_cells[grid_position] = deposit
		_modified_resource_cells[grid_position] = true
		if deposit.is_depleted() and deposit.resource_id == "wood":
			_terrain_cells[grid_position] = TerrainType.GROUND
			_forest_variant_cells.erase(grid_position)

	terrain_changed.emit()
	traversability_changed.emit(REFRESH_ALL_CELLS)


func _create_resource_cells() -> void:
	_resource_cells.clear()
	_modified_resource_cells.clear()
	_generated_resource_cells.clear()


func _create_forest_resource_cells() -> void:
	pass


func _create_generated_resource_cells() -> void:
	pass


func _set_resource_deposit(grid_position: Vector2i, resource_id: String, variant: int = -1, amount: int = -1) -> void:
	_terrain_cells[grid_position] = TerrainType.GROUND
	_forest_variant_cells.erase(grid_position)
	_resource_cells[grid_position] = ResourceDeposit.from_resource_id(
		resource_id,
		amount,
		_resource_variant_for_cell(grid_position, resource_id) if variant < 0 else variant
	)
	_modified_resource_cells[grid_position] = true


func _resource_variant_for_cell(grid_position: Vector2i, resource_id: String) -> int:
	var value := active_world_seed
	value = _mix_int(value, grid_position.x + resource_id.length() * 97)
	value = _mix_int(value, grid_position.y + resource_id.length() * 131)
	return absi(value) % RESOURCE_TEXTURE_VARIANT_COUNT


func _mix_int(value: int, salt: int) -> int:
	var mixed := value ^ (salt * 374761393)
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return mixed ^ (mixed >> 16)


func _ensure_resource_cell(grid_position: Vector2i) -> void:
	if _resource_cells.has(grid_position):
		return
	if _terrain_cells.has(grid_position) and int(_terrain_cells.get(grid_position, TerrainType.GROUND)) != TerrainType.FOREST:
		return

	var resource_entry := _world_generator.resource_data_for_cell(grid_position)
	if not resource_entry.is_empty():
		_terrain_cells[grid_position] = TerrainType.GROUND
		_forest_variant_cells.erase(grid_position)
		_resource_cells[grid_position] = ResourceDeposit.from_resource_id(
			str(resource_entry.get("resource_id", "iron_ore")),
			int(resource_entry.get("maximum_amount", -1)),
			int(resource_entry.get("texture_variant", 0))
		)
		return

	var terrain_type := get_terrain_at_cell(grid_position)
	if terrain_type == TerrainType.FOREST:
		_resource_cells[grid_position] = ResourceDeposit.from_resource_id("wood", -1, get_forest_variant_at_cell(grid_position))
