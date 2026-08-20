class_name InspectionPanel
extends PanelContainer

const PANEL_WIDTH: float = 320.0
const PANEL_MARGIN: float = 10.0
const TOOLBAR_CLEARANCE: float = 84.0
const PANEL_CONTENT_MARGIN: int = 10

var _target: Variant
var _target_kind: String = ""
var _title_label: Label
var _body_label: Label
var _bar: ProgressBar


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _position_panel() -> void:
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -PANEL_WIDTH - PANEL_MARGIN
	offset_top = PANEL_MARGIN
	offset_right = -PANEL_MARGIN
	offset_bottom = -TOOLBAR_CLEARANCE


func inspect_resource(grid_position: Vector2i, deposit: ResourceDeposit) -> void:
	_target = {"grid_position": grid_position, "deposit": deposit}
	_target_kind = "resource"
	visible = true
	_refresh()


func inspect_robot(robot: Robot) -> void:
	_target = robot
	_target_kind = "robot"
	visible = true
	_refresh()


func inspect_building(building: Building) -> void:
	_target = building
	_target_kind = "building"
	visible = true
	_refresh()


func clear_inspection() -> void:
	_target = null
	_target_kind = ""
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_CONTENT_MARGIN)
	margin.add_theme_constant_override("margin_top", PANEL_CONTENT_MARGIN)
	margin.add_theme_constant_override("margin_right", PANEL_CONTENT_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PANEL_CONTENT_MARGIN)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.custom_minimum_size = Vector2(PANEL_WIDTH - float(PANEL_CONTENT_MARGIN * 2), 0.0)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_title_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(PANEL_WIDTH - float(PANEL_CONTENT_MARGIN * 2), 12.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 11)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - float(PANEL_CONTENT_MARGIN * 2), 0.0)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body_label)


func _refresh() -> void:
	match _target_kind:
		"resource":
			_refresh_resource()
		"robot":
			_refresh_robot()
		"building":
			_refresh_building()
		_:
			clear_inspection()


func _refresh_resource() -> void:
	if not (_target is Dictionary):
		clear_inspection()
		return

	var target_data: Dictionary = _target
	var deposit: ResourceDeposit = target_data.get("deposit") as ResourceDeposit
	if deposit == null:
		clear_inspection()
		return

	var grid_position: Vector2i = target_data.get("grid_position", Vector2i.ZERO)
	var definition := GameDefinitions.resource_definition(deposit.resource_id)
	var item_id := deposit.inventory_item_id()
	var lines: Array[String] = []
	_append_property(lines, "Kind", "Resource Deposit")
	_append_property(lines, "Definition ID", GameDefinitions.resource_definition_id(deposit.resource_id))
	_append_property(lines, "Legacy ID", GameDefinitions.resource_display_id(deposit.resource_id))
	_append_property(lines, "Display Name", deposit.display_name())
	_append_property(lines, "Resource Name", deposit.resource_name())
	_append_property(lines, "Resource Type", _resource_type_name(deposit.resource_type))
	_append_property(lines, "Produced Item", _format_item_id(item_id))
	_append_property(lines, "Grid", _format_vector2i(grid_position))
	_append_property(lines, "Remaining", str(deposit.remaining_amount))
	_append_property(lines, "Maximum", str(deposit.maximum_amount))
	_append_property(lines, "Harvestable", _bool_text(deposit.is_harvestable()))
	_append_property(lines, "Depleted", _bool_text(deposit.is_depleted()))
	_append_property(lines, "Texture Variant", str(deposit.texture_variant))
	_append_definition_properties(lines, definition, ["id", "legacy_id", "display_name", "resource_name", "produces_item"])

	_title_label.text = deposit.display_name()
	_bar.visible = true
	_bar.max_value = max(1, deposit.maximum_amount)
	_bar.value = deposit.remaining_amount
	_body_label.text = "\n".join(lines)


func _refresh_robot() -> void:
	var robot := _target as Robot
	if robot == null:
		clear_inspection()
		return

	var definition := GameDefinitions.bot_definition(robot.bot_definition_id)
	var lines: Array[String] = []
	_append_property(lines, "Kind", "Robot")
	_append_property(lines, "Definition ID", robot.bot_definition_id)
	_append_property(lines, "Display Name", str(definition.get("display_name", "Basic Bot")))
	_append_property(lines, "Bot Number", str(robot.bot_number))
	_append_property(lines, "Designation", robot.designation_display_name())
	_append_property(lines, "State", robot.state_display_name())
	_append_property(lines, "Selected", _bool_text(robot.is_selected))
	_append_property(lines, "World Position", _format_vector2(robot.global_position))
	_append_property(lines, "Destination", _format_vector2(robot.destination))
	_append_property(lines, "Moving", _bool_text(robot.is_moving))
	_append_property(lines, "Facing", _robot_facing_name(robot.facing_direction))
	_append_property(lines, "Movement Speed", "%.1f" % [robot.movement_speed])
	_append_property(lines, "Inventory", "%d / %d" % [robot.inventory.used_capacity(), robot.inventory.capacity])
	_append_property(lines, "Inventory Contents", _format_inventory(robot.inventory))
	_append_property(lines, "Harvest Cycle", "%.1fs" % [robot.harvest_cycle_seconds])
	_append_property(lines, "Harvest Yield", str(robot.harvest_units_per_cycle))
	_append_property(lines, "Harvest Progress", "%d%%" % [roundi(robot.harvest_cycle_progress_ratio() * 100.0)])
	_append_robot_job_properties(lines, robot)
	_append_definition_properties(lines, definition, ["id", "display_name", "sprite", "sprite_index", "inventory_capacity", "movement", "harvest"])

	_title_label.text = robot.display_name()
	_bar.visible = true
	_bar.max_value = max(1, robot.inventory.capacity)
	_bar.value = robot.inventory.used_capacity()
	_body_label.text = "\n".join(lines)


func _refresh_building() -> void:
	var building := _target as Building
	if building == null:
		clear_inspection()
		return

	var definition := GameDefinitions.placeable_definition(building.placeable_id())
	var title := building.inventory_display_name() if building.has_visual_inventory() else GameDefinitions.placeable_display_name(building.placeable_id())
	var lines: Array[String] = []
	_append_property(lines, "Kind", "Building")
	_append_property(lines, "Definition ID", DefinitionManager.normalize_building_id(building.placeable_id()))
	_append_property(lines, "Legacy ID", building.placeable_id())
	_append_property(lines, "Display Name", title)
	_append_property(lines, "Category", str(definition.get("category", "unknown")).capitalize())
	_append_property(lines, "Grid", _format_vector2i(building.grid_position))
	_append_property(lines, "Direction", _direction_name(building.facing_direction))
	_append_property(lines, "Preview", _bool_text(building.is_preview))
	_append_property(lines, "Valid Preview", _bool_text(building.is_valid_preview))
	_append_property(lines, "Logistics Interface", _bool_text(building.supports_logistics_interface()))
	_append_property(lines, "Container", _bool_text(building.is_container()))
	_append_property(lines, "Visual Inventory", _bool_text(building.has_visual_inventory()))
	_append_building_inventory_properties(lines, building)
	_append_building_specific_properties(lines, building)
	_append_definition_properties(lines, definition, ["id", "legacy_id", "display_name", "category", "inventory"])

	_title_label.text = title
	_bar.visible = building.has_visual_inventory()
	if building.has_visual_inventory():
		var inventory := building.visual_inventory()
		_bar.max_value = max(1, inventory.capacity)
		_bar.value = inventory.used_capacity()
	_body_label.text = "\n".join(lines)


func _append_building_inventory_properties(lines: Array[String], building: Building) -> void:
	if not building.has_visual_inventory():
		return

	var inventory := building.visual_inventory()
	if inventory == null:
		return

	_append_section_header(lines, "Inventory")
	_append_property(lines, "Capacity", "%d / %d" % [inventory.used_capacity(), inventory.capacity])
	_append_property(lines, "Slots", str(inventory.slot_count()))
	_append_property(lines, "Slots Per Row", str(inventory.slots_per_row))
	_append_property(lines, "Contents", _format_inventory(inventory))
	for section: Dictionary in inventory.get_section_definitions():
		var role_name := str(section.get("title", "Slots"))
		var indices: Array = section.get("indices", [])
		_append_property(lines, "%s Slots" % [role_name], str(indices.size()))


func _append_building_specific_properties(lines: Array[String], building: Building) -> void:
	if building is Conveyor:
		var conveyor := building as Conveyor
		var conveyor_definition := GameDefinitions.placeable_definition(conveyor.placeable_id())
		_append_section_header(lines, "Conveyor")
		_append_property(lines, "Item Count", "%d / %d" % [conveyor.stacked_items.size(), int(conveyor_definition.get("max_stacked_items", Conveyor.MAX_STACKED_ITEMS))])
		_append_property(lines, "Current Item", _format_factory_item(conveyor.current_item))
		_append_property(lines, "Belt Seconds Per Tile", "%.2f" % [float(conveyor_definition.get("belt_seconds_per_tile", Conveyor.BELT_SECONDS_PER_TILE))])
		return

	if building is Exchanger:
		var exchanger := building as Exchanger
		var exchanger_definition := GameDefinitions.placeable_definition(exchanger.placeable_id())
		_append_section_header(lines, "Exchanger")
		_append_property(lines, "Held Item", _format_factory_item(exchanger.current_item))
		_append_property(lines, "Transfer Progress", "%.2f / %.2f" % [exchanger.transfer_progress, float(exchanger_definition.get("transfer_duration_seconds", Exchanger.TRANSFER_DURATION_SECONDS))])
		_append_property(lines, "Can Transfer", _bool_text(exchanger.can_transfer()))
		return

	if building is Miner:
		var miner := building as Miner
		var miner_definition := GameDefinitions.placeable_definition(miner.placeable_id())
		_append_section_header(lines, "Miner")
		_append_property(lines, "Mined Resource", _resource_type_name(miner.mined_resource_type))
		_append_property(lines, "Output Item", _format_factory_item_type(miner.get_output_item_type()))
		_append_property(lines, "Production Progress", "%d%%" % [roundi(miner.get_production_ratio() * 100.0)])
		_append_property(lines, "Production Duration", "%.2fs" % [float(miner_definition.get("production_duration_seconds", Miner.PRODUCTION_DURATION_SECONDS))])
		_append_property(lines, "Pending Output", _bool_text(miner.pending_output))
		_append_property(lines, "Output Blocked", _bool_text(miner.output_blocked))
		return

	if building is Furnace:
		var furnace := building as Furnace
		_append_section_header(lines, "Furnace")
		_append_property(lines, "Iron Ore", str(furnace.iron_ore_count))
		_append_property(lines, "Coal", str(furnace.coal_count))
		_append_property(lines, "Iron Plate", str(furnace.iron_plate_count))
		_append_property(lines, "Smelting Progress", "%d%%" % [roundi(furnace.get_smelting_ratio() * 100.0)])
		_append_property(lines, "Can Smelt", _bool_text(furnace.can_smelt_recipe()))


func _append_robot_job_properties(lines: Array[String], robot: Robot) -> void:
	_append_section_header(lines, "Current Job")
	if robot.current_job == null or robot.current_job.job_type == BotJob.JobType.NONE:
		_append_property(lines, "Job", "None")
		return

	_append_property(lines, "Job", "Harvest" if robot.current_job.is_harvest_job() else "Unknown")
	_append_property(lines, "Target", robot.harvest_target_name())
	_append_property(lines, "Target Cell", _format_vector2i(robot.harvest_target_cell()))
	_append_property(lines, "Search Origin", _format_vector2i(robot.harvest_job_search_origin_cell()))
	_append_property(lines, "Target Remaining", "%d / %d" % [robot.harvest_target_remaining(), robot.harvest_target_maximum()])
	_append_property(lines, "Inventory Item", _format_item_id(robot.harvest_job_inventory_item_id()))
	_append_property(lines, "Has Active Target", _bool_text(robot.has_active_harvest_target()))
	_append_property(lines, "Waiting For Container", _bool_text(robot.is_waiting_for_container()))


func _append_definition_properties(lines: Array[String], definition: Dictionary, skipped_keys: Array[String]) -> void:
	if definition.is_empty():
		return

	var definition_lines: Array[String] = []
	var keys: Array = definition.keys()
	keys.sort()
	for key_variant: Variant in keys:
		var key := str(key_variant)
		if skipped_keys.has(key):
			continue

		definition_lines.append("%s: %s" % [key.capitalize(), _format_variant(definition[key_variant])])

	if definition_lines.is_empty():
		return

	_append_section_header(lines, "Definition")
	lines.append_array(definition_lines)


func _append_property(lines: Array[String], label: String, value: String) -> void:
	lines.append("%s: %s" % [label, value])


func _append_section_header(lines: Array[String], title: String) -> void:
	if not lines.is_empty():
		lines.append("")
	lines.append(title)


func _format_inventory(inventory: Inventory) -> String:
	if inventory == null or inventory.is_empty():
		return "Empty"

	var lines: Array[String] = []
	var contents := inventory.contents()
	for item_key: Variant in contents.keys():
		var item_id := str(item_key)
		lines.append("%s: %d" % [GameDefinitions.inventory_item_display_name(item_id), int(contents[item_key])])

	return "\n".join(lines)


func _format_factory_item(item: FactoryItem) -> String:
	if item == null:
		return "None"

	return "%s at %s" % [_format_factory_item_type(item.item_type), _format_vector2i(item.logical_grid_position)]


func _format_factory_item_type(item_type: int) -> String:
	var item_id := GameDefinitions.item_id_for_type(item_type)
	return "%s (%s)" % [GameDefinitions.item_display_name(item_type), item_id]


func _format_item_id(item_id: String) -> String:
	if item_id.is_empty():
		return "None"

	return "%s (%s)" % [GameDefinitions.inventory_item_display_name(item_id), item_id]


func _format_variant(value: Variant) -> String:
	if value is Dictionary:
		return JSON.stringify(value)
	if value is Array:
		return JSON.stringify(value)

	return str(value)


func _format_vector2(value: Vector2) -> String:
	return "%.1f, %.1f" % [value.x, value.y]


func _format_vector2i(value: Vector2i) -> String:
	return "%d, %d" % [value.x, value.y]


func _bool_text(value: bool) -> String:
	return "Yes" if value else "No"


func _direction_name(direction: int) -> String:
	match direction:
		Building.Direction.NORTH:
			return "North"
		Building.Direction.EAST:
			return "East"
		Building.Direction.SOUTH:
			return "South"
		Building.Direction.WEST:
			return "West"
		_:
			return "Unknown"


func _robot_facing_name(direction: int) -> String:
	match direction:
		Robot.FacingDirection.NORTH:
			return "North"
		Robot.FacingDirection.EAST:
			return "East"
		Robot.FacingDirection.SOUTH:
			return "South"
		Robot.FacingDirection.WEST:
			return "West"
		Robot.FacingDirection.NORTH_EAST:
			return "North East"
		Robot.FacingDirection.SOUTH_EAST:
			return "South East"
		Robot.FacingDirection.SOUTH_WEST:
			return "South West"
		Robot.FacingDirection.NORTH_WEST:
			return "North West"
		_:
			return "Unknown"


func _resource_type_name(resource_type: int) -> String:
	match resource_type:
		ResourceDeposit.ResourceType.IRON_ORE:
			return "Iron Ore"
		ResourceDeposit.ResourceType.COAL:
			return "Coal"
		ResourceDeposit.ResourceType.STONE:
			return "Stone"
		ResourceDeposit.ResourceType.WOOD:
			return "Wood"
		_:
			return "Unknown"
