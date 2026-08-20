class_name FactorySimulation
extends Node

@export var board_path: NodePath
@export var item_parent_path: NodePath
@export var item_scene: PackedScene
@export var tick_seconds: float = 0.5

var is_running: bool = false
var _board: Board
var _item_parent: Node2D
var _items: Array[FactoryItem] = []
var _tick_timer: float = 0.0


func _ready() -> void:
	_board = get_node(board_path) as Board
	_item_parent = get_node(item_parent_path) as Node2D


func set_running(running: bool) -> void:
	if running and not is_running:
		_tick_timer = tick_seconds
	is_running = running


func spawn_iron_ore_at(grid_position: Vector2i) -> bool:
	return spawn_item_at(FactoryItem.ItemType.IRON_ORE, grid_position)


func spawn_item_at(item_type: int, grid_position: Vector2i) -> bool:
	var conveyor := _get_conveyor_at(grid_position)
	if conveyor == null or not conveyor.can_accept_item_type(item_type):
		return false

	var item := item_scene.instantiate() as FactoryItem
	item.configure(item_type, grid_position, _board.grid_to_world(grid_position))
	item.set_visual_speed_pixels(Board.CELL_SIZE / tick_seconds)
	_item_parent.add_child(item)
	_items.append(item)
	conveyor.accept_item(item)
	return true


func handle_building_removed(building: Building) -> void:
	var holder: Variant = _as_item_holder(building)
	if holder == null:
		return

	for item: FactoryItem in _release_all_items_from_holder(holder):
		_items.erase(item)
		item.queue_free()


func get_iron_ore_count() -> int:
	return get_item_count(FactoryItem.ItemType.IRON_ORE)


func get_coal_count() -> int:
	return get_item_count(FactoryItem.ItemType.COAL)


func get_iron_plate_count() -> int:
	return get_item_count(FactoryItem.ItemType.IRON_PLATE)


func get_stone_count() -> int:
	return get_item_count(FactoryItem.ItemType.STONE)


func get_item_count(item_type: int) -> int:
	var count := 0
	var item_id := GameDefinitions.item_id_for_type(item_type)
	for item: FactoryItem in _items:
		if item.item_type == item_type:
			count += 1

	for building: Building in _board.get_all_buildings():
		if not building.has_visual_inventory():
			continue

		var inventory := building.visual_inventory()
		if inventory != null:
			count += inventory.get_quantity(item_id)

	return count


func get_factory_item_node_count() -> int:
	return _items.size()


func get_conveyor_count() -> int:
	var count := 0
	for building: Building in _board.get_all_buildings():
		if building is Conveyor:
			count += 1

	return count


func get_miner_count() -> int:
	var count := 0
	for building: Building in _board.get_all_buildings():
		if building is Miner:
			count += 1

	return count


func get_furnace_count() -> int:
	var count := 0
	for building: Building in _board.get_all_buildings():
		if building is Furnace:
			count += 1

	return count


func get_exchanger_count() -> int:
	var count := 0
	for building: Building in _board.get_all_buildings():
		if building is Exchanger:
			count += 1

	return count


func clear_items() -> void:
	for building: Building in _board.get_all_buildings():
		var holder: Variant = _as_item_holder(building)
		if holder != null:
			_release_all_items_from_holder(holder)

	for item: FactoryItem in _items:
		item.queue_free()

	_items.clear()


func serialize_items() -> Array[Dictionary]:
	var item_data: Array[Dictionary] = []
	var serialized_items: Dictionary = {}

	for building: Building in _board.get_all_buildings():
		var conveyor := building as Conveyor
		if conveyor == null:
			continue

		for item: FactoryItem in conveyor.stacked_items:
			if item == null:
				continue

			serialized_items[item] = true
			item_data.append({
				"type": item.item_type,
				"x": conveyor.grid_position.x,
				"y": conveyor.grid_position.y,
			})

	for item: FactoryItem in _items:
		if serialized_items.has(item):
			continue

		var holder: Variant = _as_item_holder(_board.get_building_at_cell(item.logical_grid_position))
		if holder is Exchanger:
			continue

		item_data.append({
			"type": item.item_type,
			"x": item.logical_grid_position.x,
			"y": item.logical_grid_position.y,
		})

	return item_data


func load_item(entry: Dictionary) -> bool:
	var item_type := int(entry.get("type", FactoryItem.ItemType.IRON_ORE))
	var grid_position := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	return spawn_item_at(item_type, grid_position)


func restore_item_on_exchanger(exchanger: Exchanger, item_type: int) -> bool:
	if exchanger == null or not exchanger.can_accept_item():
		return false

	var item := _create_item(item_type, exchanger.grid_position, _board.grid_to_world(exchanger.grid_position))
	_items.append(item)
	_item_parent.add_child(item)
	exchanger.accept_item(item)
	return true


func _process(delta: float) -> void:
	if not is_running:
		return

	_tick_timer += delta
	while _tick_timer >= tick_seconds:
		_tick_timer -= tick_seconds
		_tick()


func _tick() -> void:
	_advance_exchanger_transfer_progress()
	var moves: Array[Dictionary] = _plan_moves()
	_apply_moves(moves)
	_advance_furnaces()
	_try_pull_from_buildings()
	_advance_miners()


func _plan_moves() -> Array[Dictionary]:
	var proposed_moves: Dictionary = {}
	var claimed_destinations: Dictionary = {}
	var claimed_items: Dictionary = {}

	_plan_exchanger_pulls(proposed_moves, claimed_destinations, claimed_items)

	for item: FactoryItem in _items:
		if claimed_items.has(item):
			continue

		var source_building := _board.get_building_at_cell(item.logical_grid_position)
		var source: Variant = _as_item_holder(source_building)
		if source == null or source.current_item != item:
			continue
		if source is Exchanger and not (source as Exchanger).can_transfer():
			continue

		var destination_position: Vector2i = source.grid_position + source.direction_grid_offset()
		var destination_building := _board.get_building_at_cell(destination_position)

		if destination_building == null:
			continue

		var destination_kind := _destination_kind(source.grid_position, destination_building, item.item_type)
		if destination_kind.is_empty():
			continue

		# If two belts point at one destination, only the first claim can move this tick.
		if destination_kind != "building" and claimed_destinations.has(destination_position):
			continue

		if destination_kind != "building":
			claimed_destinations[destination_position] = item
		claimed_items[item] = true
		proposed_moves[item] = {
			"item": item,
			"source": source,
			"destination": destination_building,
			"destination_position": destination_position,
			"destination_kind": destination_kind,
			"transfer_actor": source if source is Exchanger else null,
		}

	return _resolve_moves(proposed_moves)


func _plan_exchanger_pulls(proposed_moves: Dictionary, claimed_destinations: Dictionary, claimed_items: Dictionary) -> void:
	for building: Building in _board.get_all_buildings():
		var exchanger := building as Exchanger
		if exchanger == null or not exchanger.can_accept_item() or not exchanger.can_transfer():
			continue

		var source_position: Vector2i = exchanger.grid_position - exchanger.direction_grid_offset()
		var source_building := _board.get_building_at_cell(source_position)
		var source: Variant = _as_item_holder(source_building)
		if source == null or source.current_item == null:
			continue

		var item: FactoryItem = source.current_item
		if claimed_items.has(item):
			continue
		if not exchanger.has_valid_output_path_for_item(item.item_type, _board):
			continue
		if claimed_destinations.has(exchanger.grid_position):
			continue

		claimed_destinations[exchanger.grid_position] = item
		claimed_items[item] = true
		proposed_moves[item] = {
			"item": item,
			"source": source,
			"destination": exchanger,
			"destination_position": exchanger.grid_position,
			"destination_kind": "exchanger_pull",
			"transfer_actor": exchanger,
		}


func _resolve_moves(proposed_moves: Dictionary) -> Array[Dictionary]:
	var resolved_moves: Dictionary = proposed_moves.duplicate()
	var changed := true

	while changed:
		changed = false

		for key: Variant in resolved_moves.keys():
			var item := key as FactoryItem
			var move := resolved_moves[item] as Dictionary
			var destination_building := move["destination"] as Building
			if destination_building == null:
				resolved_moves.erase(item)
				changed = true
				continue

			var destination_holder: Variant = _as_item_holder(destination_building)
			if destination_holder == null:
				continue

			var planned_departures := _planned_departure_count(destination_holder, resolved_moves)
			if _holder_can_accept_after_departures(destination_holder, planned_departures):
				continue

			resolved_moves.erase(item)
			changed = true

	var moves: Array[Dictionary] = []
	for item: FactoryItem in _items:
		if resolved_moves.has(item):
			moves.append(resolved_moves[item])

	return moves


func _apply_moves(moves: Array[Dictionary]) -> void:
	for move: Dictionary in moves:
		var source := move["source"] as Building
		if source != null:
			_as_item_holder(source).release_item()

	for move: Dictionary in moves:
		var item := move["item"] as FactoryItem
		var source := move["source"] as Building
		var destination := move["destination"] as Building
		var destination_position: Vector2i = move["destination_position"]
		var destination_kind := str(move.get("destination_kind", ""))
		var transfer_actor := move.get("transfer_actor", null) as Exchanger

		if item == null or source == null or destination == null:
			continue

		if destination_kind != "building":
			item.set_visual_speed_pixels(_visual_speed_for_move(destination_kind, transfer_actor))

		if _apply_item_to_destination(item, source, destination, destination_kind):
			if transfer_actor != null:
				transfer_actor.consume_transfer_charge()
			if destination_kind == "building" or destination_kind == "conveyor":
				continue
			item.move_to_grid_position(destination_position, _board.grid_to_world(destination_position))
		else:
			_as_item_holder(source).accept_item(item)


func _get_conveyor_at(grid_position: Vector2i) -> Conveyor:
	if not _board.is_in_bounds(grid_position):
		return null

	return _board.get_building_at_cell(grid_position) as Conveyor


func _get_exchanger_at(grid_position: Vector2i) -> Exchanger:
	if not _board.is_in_bounds(grid_position):
		return null

	return _board.get_building_at_cell(grid_position) as Exchanger


func _as_item_holder(building: Building) -> Variant:
	if building is Conveyor or building is Exchanger:
		return building

	return null


func _release_all_items_from_holder(holder: Variant) -> Array[FactoryItem]:
	var released_items: Array[FactoryItem] = []
	while true:
		var item := holder.release_item() as FactoryItem
		if item == null:
			break

		released_items.append(item)

	return released_items


func _planned_departure_count(holder: Variant, resolved_moves: Dictionary) -> int:
	var count := 0
	for move_variant: Variant in resolved_moves.values():
		var move := move_variant as Dictionary
		if move.get("source", null) == holder:
			count += 1

	return count


func _holder_can_accept_after_departures(holder: Variant, planned_departures: int) -> bool:
	var conveyor := holder as Conveyor
	if conveyor != null:
		return conveyor.can_accept_after_departures(planned_departures)

	var exchanger := holder as Exchanger
	if exchanger != null:
		return planned_departures > 0 or exchanger.can_accept_item()

	return false


func _destination_kind(source_grid_position: Vector2i, destination: Building, item_type: int) -> String:
	var conveyor := destination as Conveyor
	if conveyor != null:
		return "conveyor" if conveyor.can_receive_item_from_direction(source_grid_position) else ""

	var exchanger := destination as Exchanger
	if exchanger != null:
		if exchanger.can_receive_item_from_direction(source_grid_position) and exchanger.has_valid_output_path_for_item(item_type, _board):
			return "exchanger"
		return ""

	var source_building := _board.get_building_at_cell(source_grid_position)
	if source_building is Exchanger and destination.supports_logistics_interface() and destination.can_accept_factory_item(item_type):
		return "building"

	return ""


func _apply_item_to_destination(item: FactoryItem, source: Building, destination: Building, destination_kind: String) -> bool:
	match destination_kind:
		"conveyor":
			return (destination as Conveyor).accept_item_from(item, source.grid_position)
		"exchanger":
			return (destination as Exchanger).accept_item_from(item, source.grid_position, _board)
		"exchanger_pull":
			return (destination as Exchanger).accept_item(item)
		"building":
			if not destination.accept_factory_item(item.item_type):
				return false

			_items.erase(item)
			item.queue_free()
			return true

	return false


func _create_item(item_type: int, grid_position: Vector2i, global_center: Vector2) -> FactoryItem:
	var item := item_scene.instantiate() as FactoryItem
	item.configure(item_type, grid_position, global_center)
	item.set_visual_speed_pixels(Board.CELL_SIZE / tick_seconds)
	return item


func _visual_speed_for_move(destination_kind: String, transfer_actor: Exchanger) -> float:
	if transfer_actor != null or destination_kind == "exchanger_pull":
		return Board.CELL_SIZE / Exchanger.TRANSFER_DURATION_SECONDS

	return Board.CELL_SIZE / tick_seconds


func _advance_furnaces() -> void:
	for building: Building in _board.get_all_buildings():
		var furnace := building as Furnace
		if furnace == null:
			continue

		furnace.advance_smelting(tick_seconds)


func _advance_exchanger_transfer_progress() -> void:
	for building: Building in _board.get_all_buildings():
		var exchanger := building as Exchanger
		if exchanger == null:
			continue

		exchanger.advance_transfer(tick_seconds)


func _try_pull_from_buildings() -> void:
	for building: Building in _board.get_all_buildings():
		var exchanger := building as Exchanger
		if exchanger == null or not exchanger.can_accept_item() or not exchanger.can_transfer() or not exchanger.is_unloading_building(_board):
			continue

		var connected_building := _board.get_building_at_cell(exchanger.grid_position - exchanger.direction_grid_offset())
		if connected_building == null or not connected_building.supports_logistics_interface():
			continue
		if not connected_building.can_provide_factory_item():
			continue

		var item_type := connected_building.peek_provided_factory_item_type()
		if item_type < 0:
			continue

		var provided_item_type := connected_building.provide_factory_item()
		if provided_item_type != item_type:
			continue

		var item := _create_item(provided_item_type, exchanger.grid_position, _board.grid_to_world(exchanger.grid_position))
		_items.append(item)
		_item_parent.add_child(item)
		exchanger.accept_item(item)
		exchanger.consume_transfer_charge()


func _advance_miners() -> void:
	for building: Building in _board.get_all_buildings():
		var miner := building as Miner
		if miner == null:
			continue

		miner.advance_production(tick_seconds)
		if miner.pending_output:
			_try_output_miner(miner)


func _try_output_miner(miner: Miner) -> void:
	var output_position: Vector2i = miner.grid_position + miner.direction_grid_offset()
	var output_conveyor := _get_conveyor_at(output_position)

	if output_conveyor == null or not output_conveyor.can_accept_item_from(miner.grid_position):
		# The ore stays as pending Miner state until a future tick finds a valid output.
		miner.mark_output_blocked()
		return

	var item := _create_item(
		miner.get_output_item_type(),
		output_position,
		_board.grid_to_world(miner.grid_position)
	)
	_item_parent.add_child(item)
	_items.append(item)
	output_conveyor.accept_item_from(item, miner.grid_position)
	miner.mark_output_successful()
