class_name InventoryWindow
extends Control

const SLOT_SPACING: int = 4
const PANEL_MARGIN: int = 12
const SLOT_SIZE: float = 34.0

var cursor_stack: InventoryCursorStack
var player_inventory: Inventory
var _building: Building
var _panel: PanelContainer
var _title_label: Label
var _content_rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_center_panel)


func configure(new_cursor_stack: InventoryCursorStack, new_player_inventory: Inventory) -> void:
	cursor_stack = new_cursor_stack
	player_inventory = new_player_inventory


func open_for_building(building: Building) -> void:
	if building == null or not building.has_visual_inventory():
		return

	_building = building
	_title_label.text = building.inventory_display_name()
	_rebuild_slots()
	visible = true
	call_deferred("_center_panel")


func close() -> void:
	visible = false
	_building = null


func is_window_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if visible and (_building == null or not is_instance_valid(_building)):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PANEL_MARGIN)
	_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	rows.add_child(title_row)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28.0, 26.0)
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	_content_rows = VBoxContainer.new()
	_content_rows.add_theme_constant_override("separation", 8)
	rows.add_child(_content_rows)


func _rebuild_slots() -> void:
	_clear_content_rows()

	if _building == null:
		return

	var inventory: Inventory = _building.visual_inventory()
	if inventory == null:
		return

	var max_columns: int = 1
	for section: Dictionary in inventory.get_section_definitions():
		max_columns = maxi(max_columns, int(section.get("columns", 1)))
		_add_section(inventory, section)

	if player_inventory != null:
		max_columns = maxi(max_columns, player_inventory.slots_per_row)
		_add_player_inventory_section()

	var slot_area_width: float = float(max_columns) * SLOT_SIZE + float(maxi(0, max_columns - 1) * SLOT_SPACING)
	var panel_width: float = float(PANEL_MARGIN * 2) + maxf(240.0, slot_area_width)
	var panel_height: float = _estimate_panel_height(inventory)
	_set_panel_size(Vector2(panel_width, panel_height))


func _clear_content_rows() -> void:
	for child: Node in _content_rows.get_children():
		_content_rows.remove_child(child)
		child.free()


func _set_panel_size(panel_size: Vector2) -> void:
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size


func _add_section(inventory: Inventory, section: Dictionary) -> void:
	var section_rows := VBoxContainer.new()
	section_rows.add_theme_constant_override("separation", 4)
	_content_rows.add_child(section_rows)

	var label := Label.new()
	label.text = str(section.get("title", "Slots"))
	label.add_theme_font_size_override("font_size", 11)
	section_rows.add_child(label)

	var grid := GridContainer.new()
	grid.columns = maxi(1, int(section.get("columns", 1)))
	grid.add_theme_constant_override("h_separation", SLOT_SPACING)
	grid.add_theme_constant_override("v_separation", SLOT_SPACING)
	section_rows.add_child(grid)

	var indices: Array = section.get("indices", [])
	for index_variant: Variant in indices:
		var slot_control := InventorySlotControl.new()
		slot_control.configure(inventory, int(index_variant), cursor_stack)
		grid.add_child(slot_control)


func _add_player_inventory_section() -> void:
	var group_rows := VBoxContainer.new()
	group_rows.add_theme_constant_override("separation", 4)
	_content_rows.add_child(group_rows)

	var title := Label.new()
	title.text = "Player Inventory"
	title.add_theme_font_size_override("font_size", 13)
	group_rows.add_child(title)

	var player_sections := player_inventory.get_section_definitions()
	for section: Dictionary in player_sections:
		_add_section_to_parent(group_rows, player_inventory, section, player_sections.size() > 1)


func _add_section_to_parent(parent: Control, inventory: Inventory, section: Dictionary, show_title: bool) -> void:
	var section_rows := VBoxContainer.new()
	section_rows.add_theme_constant_override("separation", 4)
	parent.add_child(section_rows)

	if show_title:
		var label := Label.new()
		label.text = str(section.get("title", "Slots"))
		label.add_theme_font_size_override("font_size", 11)
		section_rows.add_child(label)

	var grid := GridContainer.new()
	grid.columns = maxi(1, int(section.get("columns", 1)))
	grid.add_theme_constant_override("h_separation", SLOT_SPACING)
	grid.add_theme_constant_override("v_separation", SLOT_SPACING)
	section_rows.add_child(grid)

	var indices: Array = section.get("indices", [])
	for index_variant: Variant in indices:
		var slot_control := InventorySlotControl.new()
		slot_control.configure(inventory, int(index_variant), cursor_stack)
		grid.add_child(slot_control)


func _estimate_panel_height(inventory: Inventory) -> float:
	var height := float(PANEL_MARGIN * 2 + 40)
	height += _estimate_inventory_height(inventory, true)
	if player_inventory != null:
		height += 13.0 + 4.0
		height += _estimate_inventory_height(player_inventory, player_inventory.get_section_definitions().size() > 1)

	return height


func _estimate_inventory_height(inventory: Inventory, include_section_titles: bool) -> float:
	var height := 0.0
	for section: Dictionary in inventory.get_section_definitions():
		var indices: Array = section.get("indices", [])
		var columns: int = maxi(1, int(section.get("columns", 1)))
		var row_count: int = int(ceil(float(indices.size()) / float(columns)))
		if include_section_titles:
			height += 17.0
		height += float(row_count) * SLOT_SIZE + float(maxi(0, row_count - 1) * SLOT_SPACING) + 8.0

	return height


func _center_panel() -> void:
	if _panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = _panel.custom_minimum_size
	_panel.size = panel_size

	_panel.position = (viewport_size - panel_size) * 0.5
