class_name WorldGenerator
extends RefCounted

const DEFAULT_SEED: int = 847291
const NOISE_FREQUENCY: float = 0.032
const FOREST_VARIANT_COUNT: int = 16
const RESOURCE_TEXTURE_VARIANT_COUNT: int = 8
const STARTING_AREA_SIZE: Vector2i = Vector2i(20, 15)
const STONE_FIELD_COUNT: int = 10
const COAL_FIELD_COUNT: int = 6
const IRON_ORE_FIELD_COUNT: int = 3
const GUARANTEED_SPAWN_RESOURCE_RADIUS: float = 25.0
const GUARANTEED_SPAWN_RESOURCE_MIN_RADIUS: float = 7.0
const RESOURCE_EDGE_RICHNESS: float = 0.35
const RESOURCE_CENTER_RICHNESS: float = 1.65
const RESOURCE_RICHNESS_NOISE: float = 0.18
const RANDOM_RESOURCE_START_EXCLUSION_RADIUS: float = 25.0
const RESOURCE_FIELD_EDGE_MARGIN: int = 2
const RESOURCE_FIELD_BASE_CELL_DENSITY: float = 0.82
const RESOURCE_FIELD_EDGE_CELL_DENSITY: float = 0.42
const RESOURCE_REGION_SIZE: int = 64

const TERRAIN_GROUND: int = 0
const TERRAIN_WATER: int = 1
const TERRAIN_ROCK: int = 2
const TERRAIN_FOREST: int = 3
const START_CELL: Vector2i = Vector2i.ZERO

var _terrain_noise := FastNoiseLite.new()
var _seed: int = DEFAULT_SEED
var _starter_resource_fields_by_id: Dictionary = {}
var _regional_resource_field_cache: Dictionary = {}
var _resource_data_cache: Dictionary = {}
var _worldgen_definition: Dictionary = {}
var _worldgen_resources: Array = []
var _field_size_rolls: Array = []
var _resource_region_size: int = RESOURCE_REGION_SIZE
var _starting_area_size: Vector2i = STARTING_AREA_SIZE
var _guaranteed_spawn_resource_radius: float = GUARANTEED_SPAWN_RESOURCE_RADIUS
var _guaranteed_spawn_resource_min_radius: float = GUARANTEED_SPAWN_RESOURCE_MIN_RADIUS
var _random_resource_start_exclusion_radius: float = RANDOM_RESOURCE_START_EXCLUSION_RADIUS
var _resource_edge_richness: float = RESOURCE_EDGE_RICHNESS
var _resource_center_richness: float = RESOURCE_CENTER_RICHNESS
var _resource_richness_noise: float = RESOURCE_RICHNESS_NOISE
var _resource_field_edge_margin: int = RESOURCE_FIELD_EDGE_MARGIN
var _resource_field_base_cell_density: float = RESOURCE_FIELD_BASE_CELL_DENSITY
var _resource_field_edge_cell_density: float = RESOURCE_FIELD_EDGE_CELL_DENSITY


func setup(seed_value: int) -> void:
	_apply_worldgen_definition()
	_seed = seed_value
	_terrain_noise.seed = seed_value
	_terrain_noise.frequency = float(_worldgen_definition.get("noise_frequency", NOISE_FREQUENCY))
	_starter_resource_fields_by_id.clear()
	_regional_resource_field_cache.clear()
	_resource_data_cache.clear()


func generate(column_count: int, row_count: int, seed_value: int = DEFAULT_SEED) -> Dictionary:
	setup(seed_value)
	var terrain_cells: Dictionary = {}
	var forest_variant_cells: Dictionary = {}
	var resource_cells: Dictionary = {}

	for x: int in range(column_count):
		for y: int in range(row_count):
			var grid_position := Vector2i(x, y)
			var terrain_type := _terrain_type_for_cell(grid_position)

			if _is_starting_area_cell(grid_position, column_count, row_count):
				terrain_type = TERRAIN_GROUND

			terrain_cells[grid_position] = terrain_type
			if terrain_type == TERRAIN_FOREST:
				forest_variant_cells[grid_position] = _forest_variant_for_cell(grid_position)

	_generate_resource_fields(resource_cells, column_count, row_count)

	return {
		"terrain_cells": terrain_cells,
		"forest_variant_cells": forest_variant_cells,
		"resource_cells": resource_cells,
	}


func terrain_type_for_cell(grid_position: Vector2i) -> int:
	var terrain_type := _terrain_type_for_cell(grid_position)
	if _is_starting_area_cell_around(grid_position, START_CELL):
		terrain_type = TERRAIN_GROUND

	return terrain_type


func forest_variant_for_cell(grid_position: Vector2i) -> int:
	return _forest_variant_for_cell(grid_position)


func resource_data_for_cell(grid_position: Vector2i) -> Dictionary:
	if _resource_data_cache.has(grid_position):
		return _resource_data_cache[grid_position]

	var best_candidate: Dictionary = {}
	for resource_id: String in _worldgen_resource_ids():
		for field: Dictionary in _starter_resource_fields_for(resource_id):
			var candidate := _resource_candidate_for_field(grid_position, resource_id, field)
			if _candidate_is_better(candidate, best_candidate):
				best_candidate = candidate

	for region_x: int in range(_floor_div(grid_position.x, _resource_region_size) - 1, _floor_div(grid_position.x, _resource_region_size) + 2):
		for region_y: int in range(_floor_div(grid_position.y, _resource_region_size) - 1, _floor_div(grid_position.y, _resource_region_size) + 2):
			for resource_id: String in _worldgen_resource_ids():
				var field := _regional_resource_field(resource_id, Vector2i(region_x, region_y))
				var candidate := _resource_candidate_for_field(grid_position, resource_id, field)
				if _candidate_is_better(candidate, best_candidate):
					best_candidate = candidate

	_resource_data_cache[grid_position] = best_candidate
	return best_candidate


func _terrain_type_for_cell(grid_position: Vector2i) -> int:
	var noise_value := _terrain_noise.get_noise_2d(float(grid_position.x), float(grid_position.y))

	if noise_value < -0.35:
		return TERRAIN_WATER
	if noise_value < 0.15:
		return TERRAIN_GROUND
	if noise_value < 0.48:
		return TERRAIN_FOREST

	return TERRAIN_ROCK


func _generate_resource_fields(resource_cells: Dictionary, column_count: int, row_count: int) -> void:
	var center := Vector2i(int(column_count * 0.5), int(row_count * 0.5))
	var reserved_centers: Array[Vector2i] = []

	_add_guaranteed_spawn_resource_field(resource_cells, "iron_ore", center, column_count, row_count, 0x1A0B, reserved_centers)
	_add_guaranteed_spawn_resource_field(resource_cells, "coal", center, column_count, row_count, 0xC041, reserved_centers)
	_add_guaranteed_spawn_resource_field(resource_cells, "stone", center, column_count, row_count, 0x57A1, reserved_centers)

	_add_random_resource_fields(resource_cells, "stone", STONE_FIELD_COUNT, column_count, row_count, 0x5727)
	_add_random_resource_fields(resource_cells, "coal", COAL_FIELD_COUNT, column_count, row_count, 0xC059)
	_add_random_resource_fields(resource_cells, "iron_ore", IRON_ORE_FIELD_COUNT, column_count, row_count, 0x1A31)


func _add_guaranteed_spawn_resource_field(
	resource_cells: Dictionary,
	resource_id: String,
	spawn_center: Vector2i,
	column_count: int,
	row_count: int,
	salt: int,
	reserved_centers: Array[Vector2i]
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(_mix_int(_seed, salt))
	var center := _random_center_near_spawn(rng, spawn_center, column_count, row_count, reserved_centers)
	var size := _random_resource_field_size(rng)
	reserved_centers.append(center)
	_add_resource_field(resource_cells, resource_id, center, size.x, size.y, column_count, row_count)


func _add_random_resource_fields(
	resource_cells: Dictionary,
	resource_id: String,
	field_count: int,
	column_count: int,
	row_count: int,
	salt: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(_mix_int(_seed, salt))
	var start_center := Vector2(int(column_count * 0.5), int(row_count * 0.5))
	var placed_count := 0
	var attempt_count := 0
	var max_attempt_count := field_count * 12

	while placed_count < field_count and attempt_count < max_attempt_count:
		attempt_count += 1
		var center := Vector2i(
			rng.randi_range(RESOURCE_FIELD_EDGE_MARGIN, column_count - RESOURCE_FIELD_EDGE_MARGIN - 1),
			rng.randi_range(RESOURCE_FIELD_EDGE_MARGIN, row_count - RESOURCE_FIELD_EDGE_MARGIN - 1)
		)
		if Vector2(center).distance_to(start_center) < _random_resource_start_exclusion_radius:
			continue

		var size := _random_resource_field_size(rng)
		_add_resource_field(resource_cells, resource_id, center, size.x, size.y, column_count, row_count)
		placed_count += 1


func _random_center_near_spawn(
	rng: RandomNumberGenerator,
	spawn_center: Vector2i,
	column_count: int,
	row_count: int,
	reserved_centers: Array[Vector2i]
) -> Vector2i:
	var best_candidate := spawn_center
	var best_distance := 0.0

	for _attempt: int in range(80):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(_guaranteed_spawn_resource_min_radius, _guaranteed_spawn_resource_radius)
		var candidate := Vector2i(
			clampi(int(roundi(float(spawn_center.x) + cos(angle) * distance)), _resource_field_edge_margin, column_count - _resource_field_edge_margin - 1),
			clampi(int(roundi(float(spawn_center.y) + sin(angle) * distance)), _resource_field_edge_margin, row_count - _resource_field_edge_margin - 1)
		)
		if Vector2(candidate).distance_to(Vector2(spawn_center)) > _guaranteed_spawn_resource_radius:
			continue

		var candidate_distance := Vector2(candidate).distance_to(Vector2(spawn_center))
		if candidate_distance > best_distance:
			best_candidate = candidate
			best_distance = candidate_distance

		if _is_too_close_to_reserved_center(candidate, reserved_centers):
			continue

		return candidate

	return best_candidate


func _random_center_near_start(rng: RandomNumberGenerator, reserved_centers: Array[Vector2i]) -> Vector2i:
	var best_candidate := START_CELL
	var best_distance := 0.0

	for _attempt: int in range(80):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(_guaranteed_spawn_resource_min_radius, _guaranteed_spawn_resource_radius)
		var candidate := Vector2i(
			int(roundi(float(START_CELL.x) + cos(angle) * distance)),
			int(roundi(float(START_CELL.y) + sin(angle) * distance))
		)
		var candidate_distance := Vector2(candidate).distance_to(Vector2(START_CELL))
		if candidate_distance > _guaranteed_spawn_resource_radius:
			continue
		if candidate_distance > best_distance:
			best_candidate = candidate
			best_distance = candidate_distance
		if _is_too_close_to_reserved_center(candidate, reserved_centers):
			continue

		return candidate

	return best_candidate


func _is_too_close_to_reserved_center(candidate: Vector2i, reserved_centers: Array[Vector2i]) -> bool:
	for reserved_center: Vector2i in reserved_centers:
		if Vector2(candidate).distance_to(Vector2(reserved_center)) < 8.0:
			return true

	return false


func _random_resource_field_size(rng: RandomNumberGenerator) -> Vector2i:
	var size_roll := rng.randf()
	var radius_x: int
	var radius_y: int

	var selected_roll: Dictionary = {}
	for roll: Dictionary in _field_size_rolls:
		if size_roll <= float(roll.get("max_roll", 1.0)):
			selected_roll = roll
			break
	if selected_roll.is_empty():
		selected_roll = {
			"min_radius_x": 3,
			"max_radius_x": 6,
			"min_radius_y": 3,
			"max_radius_y": 5,
		}

	radius_x = rng.randi_range(int(selected_roll.get("min_radius_x", 1)), int(selected_roll.get("max_radius_x", 6)))
	radius_y = rng.randi_range(int(selected_roll.get("min_radius_y", 1)), int(selected_roll.get("max_radius_y", 5)))

	if rng.randf() < 0.35:
		radius_x = maxi(1, int(roundi(float(radius_x) * rng.randf_range(0.65, 1.15))))
	if rng.randf() < 0.35:
		radius_y = maxi(1, int(roundi(float(radius_y) * rng.randf_range(0.65, 1.15))))

	return Vector2i(
		mini(radius_x, int(_worldgen_definition.get("max_radius_x", 9))),
		mini(radius_y, int(_worldgen_definition.get("max_radius_y", 8)))
	)


func _starter_resource_fields_for(resource_id: String) -> Array[Dictionary]:
	if _starter_resource_fields_by_id.has(resource_id):
		return _starter_resource_fields_by_id[resource_id]

	var fields: Array[Dictionary] = []
	var reserved_centers: Array[Vector2i] = []

	for entry: Dictionary in _worldgen_resources:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(_mix_int(_seed, int(entry.get("starter_salt", 0))))
		var center := _random_center_near_start(rng, reserved_centers)
		var size := _random_resource_field_size(rng)
		reserved_centers.append(center)
		if _worldgen_legacy_resource_id(entry) == resource_id:
			fields.append({
				"center": center,
				"radius": size,
				"valid": true,
			})

	_starter_resource_fields_by_id[resource_id] = fields
	return fields


func _regional_resource_field(resource_id: String, region: Vector2i) -> Dictionary:
	var cache_key := "%s:%d:%d" % [resource_id, region.x, region.y]
	if _regional_resource_field_cache.has(cache_key):
		return _regional_resource_field_cache[cache_key]

	var resource_entry := _worldgen_resource_entry(resource_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(_mix_int(
		_mix_int(_seed, region.x + resource_id.length() * int(resource_entry.get("regional_salt_x", 7907))),
		region.y + resource_id.length() * int(resource_entry.get("regional_salt_y", 9719))
	))
	if rng.randf() > _resource_region_chance(resource_id):
		_regional_resource_field_cache[cache_key] = {}
		return {}

	var region_origin := region * _resource_region_size
	var center := region_origin + Vector2i(
		rng.randi_range(4, _resource_region_size - 5),
		rng.randi_range(4, _resource_region_size - 5)
	)
	if Vector2(center).distance_to(Vector2(START_CELL)) < _random_resource_start_exclusion_radius:
		_regional_resource_field_cache[cache_key] = {}
		return {}

	var field := {
		"center": center,
		"radius": _random_resource_field_size(rng),
		"valid": true,
	}
	_regional_resource_field_cache[cache_key] = field
	return field


func _resource_region_chance(resource_id: String) -> float:
	return float(_worldgen_resource_entry(resource_id).get("region_chance", 0.0))


func _resource_candidate_for_field(grid_position: Vector2i, resource_id: String, field: Dictionary) -> Dictionary:
	if field.is_empty() or not bool(field.get("valid", false)):
		return {}

	var center := field.get("center", Vector2i.ZERO) as Vector2i
	var radius := field.get("radius", Vector2i.ONE) as Vector2i
	var normalized_x := float(grid_position.x - center.x) / maxf(1.0, float(radius.x))
	var normalized_y := float(grid_position.y - center.y) / maxf(1.0, float(radius.y))
	var distance := normalized_x * normalized_x + normalized_y * normalized_y
	var edge_noise := float(absi(_mix_int(_mix_int(_seed, grid_position.x + resource_id.length() * 211), grid_position.y + resource_id.length() * 503)) % 100) / 100.0
	if distance > 1.0 + edge_noise * 0.08:
		return {}

	var cell_noise := float(absi(_mix_int(_mix_int(_seed, grid_position.x + resource_id.length() * 271), grid_position.y + resource_id.length() * 509)) % 100) / 100.0
	var center_factor := clampf(1.0 - distance, 0.0, 1.0)
	var cell_density := lerpf(_resource_field_edge_cell_density, _resource_field_base_cell_density, center_factor)
	if cell_noise > cell_density:
		return {}

	var richness := _resource_richness_for_cell(grid_position, resource_id, distance)
	return {
		"resource_id": resource_id,
		"texture_variant": _resource_variant_for_cell(grid_position, resource_id),
		"maximum_amount": _resource_amount_for_cell(resource_id, richness),
		"score": center_factor,
	}


func _candidate_is_better(candidate: Dictionary, current_best: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	if current_best.is_empty():
		return true

	return float(candidate.get("score", 0.0)) > float(current_best.get("score", 0.0))


func _add_resource_field(
	resource_cells: Dictionary,
	resource_id: String,
	center: Vector2i,
	radius_x: int,
	radius_y: int,
	column_count: int,
	row_count: int
) -> void:
	for x: int in range(center.x - radius_x, center.x + radius_x + 1):
		for y: int in range(center.y - radius_y, center.y + radius_y + 1):
			var grid_position := Vector2i(x, y)
			if grid_position.x < 0 or grid_position.y < 0 or grid_position.x >= column_count or grid_position.y >= row_count:
				continue

			var normalized_x := float(grid_position.x - center.x) / maxf(1.0, float(radius_x))
			var normalized_y := float(grid_position.y - center.y) / maxf(1.0, float(radius_y))
			var distance := normalized_x * normalized_x + normalized_y * normalized_y
			var edge_noise := float(absi(_mix_int(_mix_int(_seed, grid_position.x + resource_id.length() * 211), grid_position.y + resource_id.length() * 503)) % 100) / 100.0
			if distance > 1.0 + edge_noise * 0.08:
				continue

			var cell_noise := float(absi(_mix_int(_mix_int(_seed, grid_position.x + resource_id.length() * 271), grid_position.y + resource_id.length() * 509)) % 100) / 100.0
			var center_factor := clampf(1.0 - distance, 0.0, 1.0)
			var cell_density := lerpf(_resource_field_edge_cell_density, _resource_field_base_cell_density, center_factor)
			if cell_noise > cell_density:
				continue

			var richness := _resource_richness_for_cell(grid_position, resource_id, distance)
			resource_cells[grid_position] = {
				"resource_id": resource_id,
				"texture_variant": _resource_variant_for_cell(grid_position, resource_id),
				"maximum_amount": _resource_amount_for_cell(resource_id, richness),
			}


func _is_starting_area_cell(grid_position: Vector2i, column_count: int, row_count: int) -> bool:
	var start_x := int(column_count * 0.5) - int(_starting_area_size.x * 0.5)
	var start_y := int(row_count * 0.5) - int(_starting_area_size.y * 0.5)
	return (
		grid_position.x >= start_x
		and grid_position.y >= start_y
		and grid_position.x < start_x + _starting_area_size.x
		and grid_position.y < start_y + _starting_area_size.y
	)


func _is_starting_area_cell_around(grid_position: Vector2i, center: Vector2i) -> bool:
	var start_x := center.x - int(_starting_area_size.x * 0.5)
	var start_y := center.y - int(_starting_area_size.y * 0.5)
	return (
		grid_position.x >= start_x
		and grid_position.y >= start_y
		and grid_position.x < start_x + _starting_area_size.x
		and grid_position.y < start_y + _starting_area_size.y
	)


func _forest_variant_for_cell(grid_position: Vector2i) -> int:
	var value := _seed
	value = _mix_int(value, grid_position.x + 0x9E37)
	value = _mix_int(value, grid_position.y + 0x7F4A)
	return abs(value) % FOREST_VARIANT_COUNT


func _resource_variant_for_cell(grid_position: Vector2i, resource_id: String) -> int:
	var value := _seed
	value = _mix_int(value, grid_position.x + resource_id.length() * 97)
	value = _mix_int(value, grid_position.y + resource_id.length() * 131)
	var definition := GameDefinitions.resource_definition(resource_id)
	return absi(value) % maxi(1, int(definition.get("texture_variant_count", RESOURCE_TEXTURE_VARIANT_COUNT)))


func _resource_richness_for_cell(grid_position: Vector2i, resource_id: String, distance: float) -> float:
	var center_factor := clampf(1.0 - distance, 0.0, 1.0)
	var richness := lerpf(_resource_edge_richness, _resource_center_richness, center_factor)
	var noise := float(absi(_mix_int(_mix_int(_seed, grid_position.x + resource_id.length() * 617), grid_position.y + resource_id.length() * 983)) % 100) / 100.0
	richness += (noise - 0.5) * _resource_richness_noise
	return maxf(0.15, richness)


func _apply_worldgen_definition() -> void:
	_worldgen_definition = GameDefinitions.worldgen_definition()
	_worldgen_resources = _worldgen_definition.get("resources", [])
	_field_size_rolls = _worldgen_definition.get("field_size_rolls", [])
	_resource_region_size = int(_worldgen_definition.get("resource_region_size", RESOURCE_REGION_SIZE))
	var starting_size: Dictionary = _worldgen_definition.get("starting_area_size", {})
	_starting_area_size = Vector2i(
		int(starting_size.get("x", STARTING_AREA_SIZE.x)),
		int(starting_size.get("y", STARTING_AREA_SIZE.y))
	)
	_guaranteed_spawn_resource_radius = float(_worldgen_definition.get("guaranteed_spawn_resource_radius", GUARANTEED_SPAWN_RESOURCE_RADIUS))
	_guaranteed_spawn_resource_min_radius = float(_worldgen_definition.get("guaranteed_spawn_resource_min_radius", GUARANTEED_SPAWN_RESOURCE_MIN_RADIUS))
	_random_resource_start_exclusion_radius = float(_worldgen_definition.get("random_resource_start_exclusion_radius", RANDOM_RESOURCE_START_EXCLUSION_RADIUS))
	_resource_edge_richness = float(_worldgen_definition.get("resource_edge_richness", RESOURCE_EDGE_RICHNESS))
	_resource_center_richness = float(_worldgen_definition.get("resource_center_richness", RESOURCE_CENTER_RICHNESS))
	_resource_richness_noise = float(_worldgen_definition.get("resource_richness_noise", RESOURCE_RICHNESS_NOISE))
	_resource_field_edge_margin = int(_worldgen_definition.get("resource_field_edge_margin", RESOURCE_FIELD_EDGE_MARGIN))
	_resource_field_base_cell_density = float(_worldgen_definition.get("resource_field_base_cell_density", RESOURCE_FIELD_BASE_CELL_DENSITY))
	_resource_field_edge_cell_density = float(_worldgen_definition.get("resource_field_edge_cell_density", RESOURCE_FIELD_EDGE_CELL_DENSITY))
	if _worldgen_resources.is_empty():
		_worldgen_resources = [
			{"legacy_resource_id": "stone", "region_chance": 0.30, "starter_salt": 0x57A1},
			{"legacy_resource_id": "coal", "region_chance": 0.18, "starter_salt": 0xC041},
			{"legacy_resource_id": "iron_ore", "region_chance": 0.10, "starter_salt": 0x1A0B},
		]


func _worldgen_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in _worldgen_resources:
		ids.append(_worldgen_legacy_resource_id(entry))
	return ids


func _worldgen_resource_entry(resource_id: String) -> Dictionary:
	for entry: Dictionary in _worldgen_resources:
		if _worldgen_legacy_resource_id(entry) == resource_id:
			return entry
	return {}


func _worldgen_legacy_resource_id(entry: Dictionary) -> String:
	return str(entry.get("legacy_resource_id", DefinitionManager.legacy_resource_id(str(entry.get("resource", "")))))


func _resource_amount_for_cell(resource_id: String, richness: float) -> int:
	var definition := GameDefinitions.resource_definition(resource_id)
	var base_amount := int(definition.get("starting_amount", 1000))
	return maxi(1, int(roundi(float(base_amount) * richness)))


func _mix_int(value: int, salt: int) -> int:
	var mixed := value ^ (salt * 374761393)
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return mixed ^ (mixed >> 16)


func _floor_div(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))
