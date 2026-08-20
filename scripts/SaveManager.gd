class_name SaveManager
extends Node

const SAVE_STORE_PATH: String = "user://contract_saves.json"
const LEGACY_SAVE_STORE_PATH: String = "user://factori_no_saves.json"
const LEGACY_PROJECT_NAME: String = "FactoriNo"
const LEGACY_SAVE_FILE_NAME: String = "factori_no_saves.json"
const SAVE_VERSION: int = 7
const THUMBNAIL_SIZE: Vector2i = Vector2i(160, 90)

@export var board_path: NodePath
@export var building_parent_path: NodePath
@export var factory_simulation_path: NodePath
@export var robot_controller_path: NodePath
@export var conveyor_scene: PackedScene
@export var miner_scene: PackedScene
@export var furnace_scene: PackedScene
@export var exchanger_scene: PackedScene
@export var chest_scene: PackedScene
@export var item_scene: PackedScene

var _board: Board
var _building_parent: Node2D
var _factory_simulation: FactorySimulation
var _robot_controller: RobotController
var _player_inventory: Inventory


func _ready() -> void:
	_board = get_node(board_path) as Board
	_building_parent = get_node(building_parent_path) as Node2D
	_factory_simulation = get_node(factory_simulation_path) as FactorySimulation
	_robot_controller = get_node(robot_controller_path) as RobotController
	_migrate_legacy_save_store()


func save_game_named(save_name: String) -> bool:
	var trimmed_name := save_name.strip_edges()
	if trimmed_name.is_empty():
		trimmed_name = "Unnamed Save"

	var save_data := {
		"version": SAVE_VERSION,
		"id": _make_save_id(trimmed_name),
		"name": trimmed_name,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"world_seed": _board.active_world_seed,
		"content_packs": GameDefinitions.save_content_pack_metadata(),
		"resources": _board.serialize_resources(),
		"thumbnail": _capture_thumbnail_base64(),
		"buildings": _serialize_buildings(),
		"items": _factory_simulation.serialize_items(),
		"robots": _robot_controller.serialize_robots(),
		"player_inventory": _player_inventory.serialize() if _player_inventory != null else {},
	}

	var store := _load_store()
	var saves: Array = store.get("saves", [])
	var replaced := false

	for index: int in range(saves.size()):
		var existing_save: Variant = saves[index]
		if existing_save is Dictionary and str(existing_save.get("name", "")) == trimmed_name:
			saves[index] = save_data
			replaced = true
			break

	if not replaced:
		saves.append(save_data)

	store["saves"] = saves
	return _write_store(store)


func load_game_named(save_name: String) -> bool:
	var save_data := _find_save_by_name(save_name)
	if save_data.is_empty():
		push_warning("Could not find save named: %s" % save_name)
		return false

	_load_from_data(save_data)
	return true


func start_new_game(seed_value: int) -> void:
	_factory_simulation.set_running(false)
	_factory_simulation.clear_items()
	_robot_controller.clear_robots()
	_reset_player_inventory()
	_clear_buildings()
	_board.generate_terrain(seed_value)
	_robot_controller.spawn_starting_robots(seed_value)


func set_player_inventory(inventory: Inventory) -> void:
	_player_inventory = inventory
	_reset_player_inventory()


func get_save_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	var store := _load_store()

	for save_variant: Variant in store.get("saves", []):
		if not (save_variant is Dictionary):
			continue

		var save_data: Dictionary = save_variant
		var saved_buildings: Array = save_data.get("buildings", [])
		var saved_items: Array = save_data.get("items", [])
		var saved_robots: Array = save_data.get("robots", [])
		summaries.append({
			"name": str(save_data.get("name", "Unnamed Save")),
			"saved_at": str(save_data.get("saved_at", "")),
			"thumbnail": str(save_data.get("thumbnail", "")),
			"building_count": saved_buildings.size(),
			"item_count": saved_items.size(),
			"robot_count": saved_robots.size(),
		})

	return summaries


func _serialize_buildings() -> Array[Dictionary]:
	var building_data: Array[Dictionary] = []

	for building: Building in _board.get_all_buildings():
		var entry := {
			"type": _building_type_id(building),
			"x": building.grid_position.x,
			"y": building.grid_position.y,
			"direction": building.facing_direction,
		}

		var miner := building as Miner
		if miner != null:
			entry["production_progress"] = miner.production_progress
			entry["pending_output"] = miner.pending_output
			entry["output_blocked"] = miner.output_blocked
			entry["mined_resource_type"] = miner.mined_resource_type

		var furnace := building as Furnace
		if furnace != null:
			entry["inventory"] = furnace.serialize_inventory()
			entry["iron_ore_count"] = furnace.iron_ore_count
			entry["coal_count"] = furnace.coal_count
			entry["iron_plate_count"] = furnace.iron_plate_count
			entry["smelting_progress"] = furnace.smelting_progress

		var chest := building as Chest
		if chest != null:
			entry["inventory"] = chest.serialize_inventory()

		var exchanger := building as Exchanger
		if exchanger != null:
			entry["transfer_progress"] = exchanger.transfer_progress
			if exchanger.current_item != null:
				entry["held_item_type"] = exchanger.current_item.item_type

		building_data.append(entry)

	return building_data


func _load_store() -> Dictionary:
	if not FileAccess.file_exists(SAVE_STORE_PATH):
		return {"version": SAVE_VERSION, "saves": []}

	var save_file := FileAccess.open(SAVE_STORE_PATH, FileAccess.READ)
	if save_file == null:
		push_warning("Could not open save store for reading: %s" % SAVE_STORE_PATH)
		return {"version": SAVE_VERSION, "saves": []}

	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Save store is not valid JSON object data.")
		return {"version": SAVE_VERSION, "saves": []}

	return parsed


func _write_store(store: Dictionary) -> bool:
	var save_file := FileAccess.open(SAVE_STORE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("Could not open save store for writing: %s" % SAVE_STORE_PATH)
		return false

	save_file.store_string(JSON.stringify(store, "\t"))
	return true


func _migrate_legacy_save_store() -> void:
	if FileAccess.file_exists(SAVE_STORE_PATH):
		return

	var legacy_store := _read_store_from_path(LEGACY_SAVE_STORE_PATH)
	if legacy_store.is_empty():
		legacy_store = _read_store_from_path(_legacy_user_data_save_path())
	if legacy_store.is_empty():
		return

	legacy_store["version"] = SAVE_VERSION
	_write_store(legacy_store)


func _read_store_from_path(save_path: String) -> Dictionary:
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return {}

	var save_file := FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return {}

	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {}


func _legacy_user_data_save_path() -> String:
	var current_user_data_dir := OS.get_user_data_dir()
	if current_user_data_dir.is_empty():
		return ""

	return current_user_data_dir.get_base_dir().path_join(LEGACY_PROJECT_NAME).path_join(LEGACY_SAVE_FILE_NAME)


func _find_save_by_name(save_name: String) -> Dictionary:
	var store := _load_store()

	for save_variant: Variant in store.get("saves", []):
		if not (save_variant is Dictionary):
			continue

		var save_data: Dictionary = save_variant
		if str(save_data.get("name", "")) == save_name:
			return save_data

	return {}


func _load_from_data(save_data: Dictionary) -> void:
	var missing_content := GameDefinitions.missing_content_packs(save_data.get("content_packs", []))
	if not missing_content.is_empty():
		push_error("Cannot load save. Missing content packs: %s" % [", ".join(missing_content)])
		return

	_factory_simulation.set_running(false)
	_factory_simulation.clear_items()
	_robot_controller.clear_robots()
	if save_data.has("player_inventory") and _player_inventory != null:
		_player_inventory.restore(save_data.get("player_inventory", {}))
	else:
		_reset_player_inventory()
	_clear_buildings()
	_board.generate_terrain(int(save_data.get("world_seed", Board.DEFAULT_WORLD_SEED)))
	if save_data.has("resources"):
		_board.restore_resources(save_data.get("resources", []))

	for entry_variant: Variant in save_data.get("buildings", []):
		if entry_variant is Dictionary:
			_load_building(entry_variant)

	for entry_variant: Variant in save_data.get("items", []):
		if entry_variant is Dictionary:
			_factory_simulation.load_item(entry_variant)

	if save_data.has("robots"):
		_robot_controller.load_robots(save_data.get("robots", []))
	else:
		_robot_controller.spawn_starting_robots(_board.active_world_seed)


func _capture_thumbnail_base64() -> String:
	var viewport_image := get_viewport().get_texture().get_image()
	viewport_image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return Marshalls.raw_to_base64(viewport_image.save_png_to_buffer())


func _make_save_id(save_name: String) -> String:
	var timestamp := str(Time.get_unix_time_from_system())
	var cleaned_name := save_name.to_lower().replace(" ", "_")
	return "%s_%s" % [cleaned_name, timestamp]


func thumbnail_texture_from_base64(thumbnail_base64: String) -> ImageTexture:
	if thumbnail_base64.is_empty():
		return null

	var image_bytes := Marshalls.base64_to_raw(thumbnail_base64)
	var image := Image.new()
	if image.load_png_from_buffer(image_bytes) != OK:
		return null

	return ImageTexture.create_from_image(image)


func _load_building(entry: Dictionary) -> void:
	var building_scene := _scene_for_building_type(str(entry.get("type", "")))
	if building_scene == null:
		return

	var grid_position := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	var direction := int(entry.get("direction", Building.Direction.EAST))
	var building := building_scene.instantiate() as Building

	if building == null:
		return

	building.configure(grid_position, direction, Board.CELL_SIZE)
	building.global_position = _board.grid_to_world(grid_position)

	if not building.can_place_on(_board, grid_position) or not _board.occupy_cell(grid_position, building):
		building.queue_free()
		return

	building.on_placed(_board)
	_restore_miner_state(building, entry)
	_restore_furnace_state(building, entry)
	_restore_chest_state(building, entry)
	_building_parent.add_child(building)
	_restore_exchanger_state(building, entry)


func _restore_miner_state(building: Building, entry: Dictionary) -> void:
	var miner := building as Miner
	if miner == null:
		return

	miner.production_progress = float(entry.get("production_progress", miner.production_progress))
	miner.pending_output = bool(entry.get("pending_output", miner.pending_output))
	miner.output_blocked = bool(entry.get("output_blocked", miner.output_blocked))
	miner.mined_resource_type = int(entry.get("mined_resource_type", miner.mined_resource_type))
	miner.queue_redraw()


func _restore_furnace_state(building: Building, entry: Dictionary) -> void:
	var furnace := building as Furnace
	if furnace == null:
		return

	if entry.has("inventory"):
		furnace.restore_inventory(entry.get("inventory", furnace.serialize_inventory()))
	else:
		furnace.restore_legacy_counts(
			int(entry.get("iron_ore_count", furnace.iron_ore_count)),
			int(entry.get("coal_count", furnace.coal_count)),
			int(entry.get("iron_plate_count", furnace.iron_plate_count))
		)
	furnace.smelting_progress = float(entry.get("smelting_progress", furnace.smelting_progress))
	furnace.queue_redraw()



func _restore_chest_state(building: Building, entry: Dictionary) -> void:
	var chest := building as Chest
	if chest == null:
		return

	chest.restore_inventory(entry.get("inventory", chest.serialize_inventory()))

func _restore_exchanger_state(building: Building, entry: Dictionary) -> void:
	var exchanger := building as Exchanger
	if exchanger == null:
		return

	exchanger.transfer_progress = float(entry.get("transfer_progress", exchanger.transfer_progress))
	if entry.has("held_item_type"):
		_factory_simulation.restore_item_on_exchanger(exchanger, int(entry.get("held_item_type", FactoryItem.ItemType.IRON_ORE)))


func _clear_buildings() -> void:
	for building: Building in _board.get_all_buildings():
		building.queue_free()

	_board.clear_all_buildings()


func _reset_player_inventory() -> void:
	if _player_inventory == null:
		return

	var inventory_definition: Dictionary = GameDefinitions.player_definition().get("inventory", {})
	var storage_slots := int(inventory_definition.get("storage_slots", 30))
	_player_inventory.configure_storage_slots(
		storage_slots,
		int(inventory_definition.get("slots_per_row", 10)),
		int(inventory_definition.get("stack_size", Inventory.DEFAULT_STACK_LIMIT)),
		storage_slots
	)
	_player_inventory.clear()


func _building_type_id(building: Building) -> String:
	return DefinitionManager.normalize_building_id(building.placeable_id())


func _scene_for_building_type(type_id: String) -> PackedScene:
	match DefinitionManager.legacy_building_id(type_id):
		"conveyor":
			return conveyor_scene
		"miner":
			return miner_scene
		"furnace":
			return furnace_scene
		"exchanger":
			return exchanger_scene
		"chest":
			return chest_scene

	return null
