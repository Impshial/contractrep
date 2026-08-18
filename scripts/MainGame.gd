extends Node2D

@onready var _placement_controller: PlacementController = $PlacementController
@onready var _factory_simulation: FactorySimulation = $FactorySimulation
@onready var _save_manager: SaveManager = $SaveManager
@onready var _robot_controller: RobotController = $RobotController
@onready var _board: Board = $Board
@onready var _toolbar: Toolbar = $UI/Toolbar
@onready var _save_load_dialogs: SaveLoadDialogs = $UI/SaveLoadDialogs
@onready var _furnace_inventory_dialog: FurnaceInventoryDialog = $UI/FurnaceInventoryDialog
@onready var _details_panel: PanelContainer = $UI/DetailsPanel
@onready var _details_label: Label = $UI/DetailsPanel/MarginContainer/DetailsLabel

var _startup_overlay: Control
var _startup_panel: PanelContainer
var _has_started_game: bool = false


func _ready() -> void:
	_configure_game_window()
	_register_input_actions()
	_toolbar.building_selected.connect(_placement_controller.begin_placement)
	_toolbar.run_toggled.connect(_factory_simulation.set_running)
	_toolbar.save_requested.connect(_on_save_requested)
	_toolbar.load_requested.connect(_on_load_requested)
	_save_load_dialogs.load_completed.connect(_on_load_completed)
	_save_load_dialogs.dialogs_closed.connect(_on_save_load_dialogs_closed)
	_build_startup_dialog()
	_show_startup_dialog()


func _build_startup_dialog() -> void:
	_startup_overlay = Control.new()
	_startup_overlay.name = "StartupMenu"
	_startup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_startup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_overlay.visible = false
	$UI.add_child(_startup_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_overlay.add_child(dim)

	_startup_panel = PanelContainer.new()
	_startup_panel.custom_minimum_size = Vector2(320.0, 245.0)
	_startup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_startup_panel.offset_left = -160.0
	_startup_panel.offset_top = -122.0
	_startup_panel.offset_right = 160.0
	_startup_panel.offset_bottom = 122.0
	_startup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_overlay.add_child(_startup_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_startup_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Contract"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	rows.add_child(title)

	rows.add_child(_create_startup_button("New Game", _on_startup_new_game_pressed))
	rows.add_child(_create_startup_button("Load Game", _on_startup_load_game_pressed))
	rows.add_child(_create_startup_button("Quit", _on_startup_quit_pressed))


func _create_startup_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(callback)
	return button


func _show_startup_dialog() -> void:
	_factory_simulation.set_running(false)
	_toolbar.set_running_visual(false)
	_startup_overlay.visible = true


func _hide_startup_dialog() -> void:
	if _startup_overlay != null:
		_startup_overlay.visible = false


func _on_startup_new_game_pressed() -> void:
	var seed_value := _make_new_world_seed()
	_save_manager.start_new_game(seed_value)
	_toolbar.set_running_visual(false)
	_details_panel.visible = false
	_update_details_text()
	_has_started_game = true
	_hide_startup_dialog()


func _on_startup_load_game_pressed() -> void:
	_hide_startup_dialog()
	_save_load_dialogs.open_load_dialog()


func _on_startup_quit_pressed() -> void:
	get_tree().quit()


func _make_new_world_seed() -> int:
	var timestamp := int(Time.get_unix_time_from_system() * 1000.0)
	return abs(timestamp ^ randi())

func _configure_game_window() -> void:
	var game_window := get_window()
	if game_window != null and game_window.mode == Window.MODE_WINDOWED:
		game_window.mode = Window.MODE_MAXIMIZED

func _unhandled_input(event: InputEvent) -> void:
	if _startup_overlay != null and _startup_overlay.visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
		_details_panel.visible = not _details_panel.visible
		_update_details_text()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5:
		_on_save_requested()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9:
		_on_load_requested()
		get_viewport().set_input_as_handled()
		return

	if _placement_controller.is_placing():
		return
	if _text_input_has_focus():
		return

	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
		_rotate_building_at_mouse()
		get_viewport().set_input_as_handled()
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	var mouse_world_position := get_global_mouse_position()
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if _robot_controller.handle_move_command(mouse_world_position):
			get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _robot_controller.handle_left_click(mouse_world_position, mouse_event.shift_pressed):
		get_viewport().set_input_as_handled()
		return

	var grid_position: Vector2i = _board.world_to_grid(mouse_world_position)
	if mouse_event.shift_pressed and _factory_simulation.spawn_iron_ore_at(grid_position):
		get_viewport().set_input_as_handled()
		return

	var furnace := _board.get_building_at_cell(grid_position) as Furnace
	if furnace != null:
		_furnace_inventory_dialog.open_for_furnace(furnace)
		get_viewport().set_input_as_handled()
		return

	if not mouse_event.shift_pressed:
		_robot_controller.clear_selection()


func _process(_delta: float) -> void:
	if _details_panel.visible:
		_update_details_text()


func _update_details_text() -> void:
	_details_label.text = "Details\nConveyors: %d\nMiners: %d\nFurnaces: %d\nExchangers: %d\nIron Ore: %d\nCoal: %d\nIron Plates: %d\nRobots: %d\nSelected Robots: %d" % [
		_factory_simulation.get_conveyor_count(),
		_factory_simulation.get_miner_count(),
		_factory_simulation.get_furnace_count(),
		_factory_simulation.get_exchanger_count(),
		_factory_simulation.get_iron_ore_count(),
		_factory_simulation.get_coal_count(),
		_factory_simulation.get_iron_plate_count(),
		_robot_controller.get_robot_count(),
		_robot_controller.get_selected_robot_count(),
	]


func _rotate_building_at_mouse() -> void:
	var grid_position: Vector2i = _board.world_to_grid(get_global_mouse_position())
	var building := _board.get_building_at_cell(grid_position)

	if building == null:
		return

	building.rotate_clockwise()


func _text_input_has_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _on_save_requested() -> void:
	_save_load_dialogs.open_save_dialog()


func _on_load_requested() -> void:
	_save_load_dialogs.open_load_dialog()


func _on_load_completed() -> void:
	_toolbar.set_running_visual(false)
	_has_started_game = true
	_hide_startup_dialog()
	_update_details_text()


func _on_save_load_dialogs_closed() -> void:
	if not _has_started_game:
		_show_startup_dialog()


func _register_input_actions() -> void:
	# Keeping these mappings near the prototype keeps the controls easy to find while the project is small.
	_add_mouse_action("place_building", MOUSE_BUTTON_LEFT)
	_add_mouse_action("remove_building", MOUSE_BUTTON_RIGHT)
	_add_key_action("rotate_building", KEY_R)


func _add_mouse_action(action_name: StringName, mouse_button: int) -> void:
	if InputMap.has_action(action_name):
		return

	var event := InputEventMouseButton.new()
	event.button_index = mouse_button
	InputMap.add_action(action_name)
	InputMap.action_add_event(action_name, event)


func _add_key_action(action_name: StringName, keycode: int) -> void:
	if InputMap.has_action(action_name):
		return

	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.add_action(action_name)
	InputMap.action_add_event(action_name, event)


