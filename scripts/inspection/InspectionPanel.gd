class_name InspectionPanel
extends PanelContainer

const PANEL_WIDTH: float = 280.0
const PANEL_MARGIN: float = 12.0
const TOOLBAR_CLEARANCE: float = 84.0

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
	size.x = PANEL_WIDTH

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
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0.0)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_title_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 18.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_bar)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0.0)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_body_label)


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

	var deposit := _target.get("deposit") as ResourceDeposit
	if deposit == null:
		clear_inspection()
		return

	_title_label.text = deposit.display_name()
	_bar.visible = true
	_bar.max_value = max(1, deposit.maximum_amount)
	_bar.value = deposit.remaining_amount
	_body_label.text = "Resource: %s\nRemaining: %d\nMaximum: %d\n\n%d / %d" % [
		deposit.resource_name(),
		deposit.remaining_amount,
		deposit.maximum_amount,
		deposit.remaining_amount,
		deposit.maximum_amount,
	]


func _refresh_robot() -> void:
	var robot := _target as Robot
	if robot == null:
		clear_inspection()
		return

	_title_label.text = robot.display_name()
	_bar.visible = true
	_bar.max_value = max(1, robot.inventory.capacity)
	_bar.value = robot.inventory.used_capacity()
	_body_label.text = "Type: Basic Bot\nState: %s\n\nInventory:\n%s\n\nCapacity:\n%d / %d" % [
		robot.state_display_name(),
		_format_inventory(robot.inventory),
		robot.inventory.used_capacity(),
		robot.inventory.capacity,
	]


func _refresh_building() -> void:
	var building := _target as Building
	if building == null:
		clear_inspection()
		return

	var chest := building as Chest
	if chest != null:
		_title_label.text = "Storage Chest"
		_bar.visible = true
		_bar.max_value = max(1, chest.inventory.capacity)
		_bar.value = chest.inventory.used_capacity()
		_body_label.text = "Contents:\n%s\n\nStorage:\n%d / %d" % [
			_format_inventory(chest.inventory),
			chest.inventory.used_capacity(),
			chest.inventory.capacity,
		]
		return

	_title_label.text = GameDefinitions.placeable_display_name(building.placeable_id())
	_bar.visible = false
	_body_label.text = "Direction: %s\nGrid: %d, %d" % [
		_direction_name(building.facing_direction),
		building.grid_position.x,
		building.grid_position.y,
	]


func _format_inventory(inventory: Inventory) -> String:
	if inventory == null or inventory.is_empty():
		return "Empty"

	var lines: Array[String] = []
	var contents := inventory.contents()
	for item_key: Variant in contents.keys():
		var item_id := str(item_key)
		lines.append("%s: %d" % [GameDefinitions.inventory_item_display_name(item_id), int(contents[item_key])])

	return "\n".join(lines)


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