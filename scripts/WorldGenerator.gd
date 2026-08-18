class_name WorldGenerator
extends RefCounted

const DEFAULT_SEED: int = 847291
const NOISE_FREQUENCY: float = 0.032
const FOREST_VARIANT_COUNT: int = 16
const STARTING_AREA_SIZE: Vector2i = Vector2i(20, 15)

const TERRAIN_GROUND: int = 0
const TERRAIN_WATER: int = 1
const TERRAIN_ROCK: int = 2
const TERRAIN_FOREST: int = 3

var _terrain_noise := FastNoiseLite.new()
var _seed: int = DEFAULT_SEED


func setup(seed_value: int) -> void:
	_seed = seed_value
	_terrain_noise.seed = seed_value
	_terrain_noise.frequency = NOISE_FREQUENCY


func generate(column_count: int, row_count: int, seed_value: int = DEFAULT_SEED) -> Dictionary:
	setup(seed_value)
	var terrain_cells: Dictionary = {}
	var forest_variant_cells: Dictionary = {}

	for x: int in range(column_count):
		for y: int in range(row_count):
			var grid_position := Vector2i(x, y)
			var terrain_type := _terrain_type_for_cell(grid_position)

			if _is_starting_area_cell(grid_position, column_count, row_count):
				terrain_type = TERRAIN_GROUND

			terrain_cells[grid_position] = terrain_type
			if terrain_type == TERRAIN_FOREST:
				forest_variant_cells[grid_position] = _forest_variant_for_cell(grid_position)

	return {
		"terrain_cells": terrain_cells,
		"forest_variant_cells": forest_variant_cells,
	}


func _terrain_type_for_cell(grid_position: Vector2i) -> int:
	var noise_value := _terrain_noise.get_noise_2d(float(grid_position.x), float(grid_position.y))

	if noise_value < -0.35:
		return TERRAIN_WATER
	if noise_value < 0.15:
		return TERRAIN_GROUND
	if noise_value < 0.55:
		return TERRAIN_FOREST

	return TERRAIN_ROCK


func _is_starting_area_cell(grid_position: Vector2i, column_count: int, row_count: int) -> bool:
	var start_x := int(column_count * 0.5) - int(STARTING_AREA_SIZE.x * 0.5)
	var start_y := int(row_count * 0.5) - int(STARTING_AREA_SIZE.y * 0.5)
	return (
		grid_position.x >= start_x
		and grid_position.y >= start_y
		and grid_position.x < start_x + STARTING_AREA_SIZE.x
		and grid_position.y < start_y + STARTING_AREA_SIZE.y
	)


func _forest_variant_for_cell(grid_position: Vector2i) -> int:
	var value := _seed
	value = _mix_int(value, grid_position.x + 0x9E37)
	value = _mix_int(value, grid_position.y + 0x7F4A)
	return abs(value) % FOREST_VARIANT_COUNT


func _mix_int(value: int, salt: int) -> int:
	var mixed := value ^ (salt * 374761393)
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return mixed ^ (mixed >> 16)