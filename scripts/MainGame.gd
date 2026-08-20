extends Node2D

const GameDiagnosticsScript: Script = preload("res://scripts/diagnostics/GameDiagnostics.gd")
const SELECTION_DRAG_THRESHOLD: float = 6.0

@onready var _placement_controller: PlacementController = $PlacementController
@onready var _factory_simulation: FactorySimulation = $FactorySimulation
@onready var _save_manager: SaveManager = $SaveManager
@onready var _robot_controller: RobotController = $RobotController
@onready var _board: Board = $Board
@onready var _grid_renderer: GridRenderer = $Board/GridRenderer
@onready var _toolbar: Toolbar = $UI/Toolbar
@onready var _save_load_dialogs: SaveLoadDialogs = $UI/SaveLoadDialogs
@onready var _inspection_panel: InspectionPanel = $UI/InspectionPanel
@onready var _details_panel: PanelContainer = $UI/DetailsPanel
@onready var _details_label: Label = $UI/DetailsPanel/MarginContainer/DetailsLabel

var _player_inventory := Inventory.new()
var _inventory_cursor_stack: InventoryCursorStack
var _building_inventory_window: InventoryWindow
var _player_inventory_drawer: PlayerInventoryDrawer
var _game_diagnostics: Node
var _startup_overlay: Control
var _startup_panel: PanelContainer
var _escape_overlay: Control
var _escape_panel: PanelContainer
var _was_running_before_escape_menu: bool = false
var _restore_run_mode_after_save_load: bool = false
var _has_started_game: bool = false
var _selection_box: Panel
var _selection_drag_pending: bool = false
var _selection_drag_active: bool = false
var _selection_drag_start: Vector2 = Vector2.ZERO
var _selection_drag_current: Vector2 = Vector2.ZERO
var _measured_fps: float = 0.0
var _fps_sample_start_usec: int = 0
var _fps_sample_frames: int = 0


func _ready() -> void:
	_configure_game_window()
	_fps_sample_start_usec = Time.get_ticks_usec()
	_register_input_actions()
	_configure_player_inventory()
	_save_manager.set_player_inventory(_player_inventory)
	_build_inventory_ui()
	_build_selection_box()
	_build_game_diagnostics()
	_toolbar.building_selected.connect(_placement_controller.begin_placement)
	_toolbar.run_toggled.connect(_factory_simulation.set_running)
	_toolbar.add_bot_requested.connect(_on_add_bot_requested)
	_toolbar.grid_toggled.connect(_grid_renderer.set_grid_visible)
	_save_load_dialogs.load_completed.connect(_on_load_completed)
	_save_load_dialogs.dialogs_closed.connect(_on_save_load_dialogs_closed)
	_build_startup_dialog()
	_build_escape_dialog()
	_handle_launch_options()


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
	_start_new_game()
	_hide_startup_dialog()


func _start_new_game() -> void:
	var seed_value := _make_new_world_seed()
	_save_manager.start_new_game(seed_value)
	_set_run_mode(true)
	_details_panel.visible = false
	_update_details_text()
	_has_started_game = true


func _on_startup_load_game_pressed() -> void:
	_hide_startup_dialog()
	_save_load_dialogs.open_load_dialog()


func _on_startup_quit_pressed() -> void:
	get_tree().quit()


func _handle_launch_options() -> void:
	match LaunchOptions.action:
		LaunchOptions.ACTION_NEW_GAME:
			LaunchOptions.clear()
			_start_new_game()
		LaunchOptions.ACTION_LOAD_GAME:
			var save_name := LaunchOptions.save_name
			LaunchOptions.clear()
			if not _load_game_from_landing(save_name):
				_show_startup_dialog()
		_:
			_show_startup_dialog()


func _load_game_from_landing(save_name: String) -> bool:
	if save_name.is_empty():
		return false
	if not _save_manager.load_game_named(save_name):
		return false

	_on_load_completed()
	return true


func _build_escape_dialog() -> void:
	_escape_overlay = Control.new()
	_escape_overlay.name = "EscapeMenu"
	_escape_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escape_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_overlay.visible = false
	$UI.add_child(_escape_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_overlay.add_child(dim)

	_escape_panel = PanelContainer.new()
	_escape_panel.custom_minimum_size = Vector2(320.0, 356.0)
	_escape_panel.set_anchors_preset(Control.PRESET_CENTER)
	_escape_panel.offset_left = -160.0
	_escape_panel.offset_top = -178.0
	_escape_panel.offset_right = 160.0
	_escape_panel.offset_bottom = 178.0
	_escape_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_overlay.add_child(_escape_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_escape_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)

	rows.add_child(_create_startup_button("Resume", _close_escape_dialog))
	rows.add_child(_create_startup_button("New Game", _on_escape_new_game_pressed))
	rows.add_child(_create_startup_button("Save Game", _on_escape_save_game_pressed))
	rows.add_child(_create_startup_button("Load Game", _on_escape_load_game_pressed))
	rows.add_child(_create_startup_button("Quit", _on_escape_quit_pressed))


func _open_escape_dialog() -> void:
	if _escape_overlay == null or _escape_overlay.visible:
		return

	_was_running_before_escape_menu = _factory_simulation.is_running
	_set_run_mode(false)
	_escape_overlay.visible = true


func _close_escape_dialog() -> void:
	if _escape_overlay == null or not _escape_overlay.visible:
		return

	_escape_overlay.visible = false
	_set_run_mode(_was_running_before_escape_menu)


func _hide_escape_dialog_without_resuming() -> void:
	if _escape_overlay != null:
		_escape_overlay.visible = false


func _on_escape_save_game_pressed() -> void:
	_hide_escape_dialog_without_resuming()
	_restore_run_mode_after_save_load = true
	_save_load_dialogs.open_save_dialog()


func _on_escape_new_game_pressed() -> void:
	_hide_escape_dialog_without_resuming()
	_start_new_game()


func _on_escape_load_game_pressed() -> void:
	_hide_escape_dialog_without_resuming()
	_restore_run_mode_after_save_load = true
	_save_load_dialogs.open_load_dialog()


func _on_escape_quit_pressed() -> void:
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
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		if _save_load_dialogs.is_dialog_open():
			_save_load_dialogs.close_dialogs()
			get_viewport().set_input_as_handled()
			return
		if _placement_controller.is_placing():
			return
		if _escape_overlay != null and _escape_overlay.visible:
			_close_escape_dialog()
		else:
			_open_escape_dialog()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
		_details_panel.visible = not _details_panel.visible
		_update_details_text()
		get_viewport().set_input_as_handled()
		return

	if _placement_controller.is_placing():
		return
	if _escape_overlay != null and _escape_overlay.visible:
		return
	if _text_input_has_focus():
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _selection_drag_pending:
		_update_selection_drag(mouse_motion.position)
		get_viewport().set_input_as_handled()
		return

	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
		_rotate_building_at_mouse()
		get_viewport().set_input_as_handled()
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and _selection_drag_pending and not mouse_event.pressed:
		_finish_selection_drag(mouse_event.position)
		get_viewport().set_input_as_handled()
		return

	if not mouse_event.pressed:
		return

	var mouse_world_position := get_global_mouse_position()
	var grid_position: Vector2i = _board.world_to_grid(mouse_world_position)
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var building := _board.get_building_at_cell(grid_position)
		if building != null and building.is_container() and _robot_controller.handle_deposit_command(building):
			get_viewport().set_input_as_handled()
			return
		var deposit := _board.get_resource_at_cell(grid_position)
		if deposit != null and _robot_controller.handle_harvest_command(grid_position, deposit):
			_show_harvest_command_indicator(grid_position)
			get_viewport().set_input_as_handled()
			return
		if _robot_controller.handle_move_command(mouse_world_position):
			get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.shift_pressed:
		_begin_selection_drag(mouse_event.position)
		get_viewport().set_input_as_handled()
		return

	var clicked_robot := _robot_controller.get_robot_at_world_position(mouse_world_position)
	if clicked_robot != null:
		_robot_controller.handle_left_click(mouse_world_position, mouse_event.shift_pressed)
		get_viewport().set_input_as_handled()
		return

	if mouse_event.shift_pressed and _factory_simulation.spawn_iron_ore_at(grid_position):
		get_viewport().set_input_as_handled()
		return

	var building := _board.get_building_at_cell(grid_position)
	if building != null:
		if not mouse_event.shift_pressed:
			_robot_controller.clear_selection()
		if building.has_visual_inventory():
			_building_inventory_window.open_for_building(building)
		get_viewport().set_input_as_handled()
		return

	var deposit := _board.get_resource_at_cell(grid_position)
	if deposit != null:
		if not mouse_event.shift_pressed:
			_robot_controller.clear_selection()
		get_viewport().set_input_as_handled()
		return

	if not mouse_event.shift_pressed:
		_robot_controller.clear_selection()


func _process(_delta: float) -> void:
	_update_measured_fps()
	_update_player_inventory_drawer_access()
	_update_hover_inspection()
	if _details_panel.visible:
		_update_details_text()


func _update_measured_fps() -> void:
	if _fps_sample_start_usec <= 0:
		_fps_sample_start_usec = Time.get_ticks_usec()

	_fps_sample_frames += 1
	var elapsed_seconds := float(Time.get_ticks_usec() - _fps_sample_start_usec) / 1000000.0
	if elapsed_seconds < 0.25:
		return

	_measured_fps = float(_fps_sample_frames) / maxf(elapsed_seconds, 0.0001)
	_fps_sample_start_usec = Time.get_ticks_usec()
	_fps_sample_frames = 0


func _update_details_text() -> void:
	_details_label.text = "Details\nActual FPS: %.1f\nEngine FPS: %d\nConveyors: %d\nMiners: %d\nFurnaces: %d\nExchangers: %d\nIron Ore: %d\nCoal: %d\nStone: %d\nIron Plates: %d\nRobots: %d\nSelected Robots: %d" % [
		_measured_fps,
		roundi(Performance.get_monitor(Performance.TIME_FPS)),
		_factory_simulation.get_conveyor_count(),
		_factory_simulation.get_miner_count(),
		_factory_simulation.get_furnace_count(),
		_factory_simulation.get_exchanger_count(),
		_factory_simulation.get_iron_ore_count(),
		_factory_simulation.get_coal_count(),
		_factory_simulation.get_stone_count(),
		_factory_simulation.get_iron_plate_count(),
		_robot_controller.get_robot_count(),
		_robot_controller.get_selected_robot_count(),
	]


func _update_hover_inspection() -> void:
	if _startup_overlay != null and _startup_overlay.visible:
		_inspection_panel.clear_inspection()
		return
	if _is_modal_window_open():
		_inspection_panel.clear_inspection()
		return
	if _placement_controller.is_placing() or _text_input_has_focus():
		_inspection_panel.clear_inspection()
		return
	if _mouse_over_inspection_panel():
		return

	var mouse_world_position := get_global_mouse_position()
	var hovered_robot := _robot_controller.get_robot_at_world_position(mouse_world_position)
	if hovered_robot != null:
		_inspection_panel.inspect_robot(hovered_robot)
		return

	var grid_position := _board.world_to_grid(mouse_world_position)
	var building := _board.get_building_at_cell(grid_position)
	if building != null:
		_inspection_panel.inspect_building(building)
		return

	var deposit := _board.get_resource_at_cell(grid_position)
	if deposit != null:
		_inspection_panel.inspect_resource(grid_position, deposit)
		return

	_inspection_panel.clear_inspection()


func _mouse_over_inspection_panel() -> bool:
	return _inspection_panel.visible and _inspection_panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _update_player_inventory_drawer_access() -> void:
	if _player_inventory_drawer == null:
		return

	_player_inventory_drawer.set_blocked(_is_modal_window_open())


func _is_modal_window_open() -> bool:
	return (
		(_startup_overlay != null and _startup_overlay.visible)
		or (_escape_overlay != null and _escape_overlay.visible)
		or (_save_load_dialogs != null and _save_load_dialogs.is_dialog_open())
		or (_building_inventory_window != null and _building_inventory_window.is_window_open())
	)


func _rotate_building_at_mouse() -> void:
	var grid_position: Vector2i = _board.world_to_grid(get_global_mouse_position())
	var building := _board.get_building_at_cell(grid_position)

	if building == null:
		return

	building.rotate_clockwise()


func _show_harvest_command_indicator(grid_position: Vector2i) -> void:
	var indicator := HarvestCommandIndicator.new()
	_board.add_child(indicator)
	indicator.global_position = _board.grid_to_world(grid_position)


func _text_input_has_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _on_load_completed() -> void:
	_restore_run_mode_after_save_load = false
	_set_run_mode(true)
	_has_started_game = true
	_hide_startup_dialog()
	_hide_escape_dialog_without_resuming()
	_update_details_text()


func _on_save_load_dialogs_closed() -> void:
	if not _has_started_game:
		_show_startup_dialog()
		return
	if _restore_run_mode_after_save_load:
		_restore_run_mode_after_save_load = false
		_set_run_mode(_was_running_before_escape_menu)


func _set_run_mode(running: bool) -> void:
	_factory_simulation.set_running(running)
	_toolbar.set_running_visual(running)


func _on_add_bot_requested() -> void:
	_robot_controller.spawn_new_robot()
	_update_details_text()


func _configure_player_inventory() -> void:
	var inventory_definition: Dictionary = GameDefinitions.player_definition().get("inventory", {})
	var storage_slots := int(inventory_definition.get("storage_slots", 30))
	_player_inventory.configure_storage_slots(
		storage_slots,
		int(inventory_definition.get("slots_per_row", 10)),
		int(inventory_definition.get("stack_size", Inventory.DEFAULT_STACK_LIMIT)),
		storage_slots
	)


func _build_inventory_ui() -> void:
	_inventory_cursor_stack = InventoryCursorStack.new()
	$UI.add_child(_inventory_cursor_stack)

	_building_inventory_window = InventoryWindow.new()
	_building_inventory_window.configure(_inventory_cursor_stack, _player_inventory)
	$UI.add_child(_building_inventory_window)

	_player_inventory_drawer = PlayerInventoryDrawer.new()
	_player_inventory_drawer.configure(_player_inventory, _inventory_cursor_stack)
	$UI.add_child(_player_inventory_drawer)


func _build_selection_box() -> void:
	_selection_box = Panel.new()
	_selection_box.name = "SelectionBox"
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	_selection_box.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.72, 1.0, 0.12)
	style.border_color = Color(0.38, 0.88, 1.0, 0.85)
	style.set_border_width_all(2)
	_selection_box.add_theme_stylebox_override("panel", style)
	$UI.add_child(_selection_box)


func _begin_selection_drag(screen_position: Vector2) -> void:
	_selection_drag_pending = true
	_selection_drag_active = false
	_selection_drag_start = screen_position
	_selection_drag_current = screen_position
	_hide_selection_box()


func _update_selection_drag(screen_position: Vector2) -> void:
	_selection_drag_current = screen_position
	if not _selection_drag_active and _selection_drag_start.distance_to(_selection_drag_current) >= SELECTION_DRAG_THRESHOLD:
		_selection_drag_active = true
	if _selection_drag_active:
		_update_selection_box(_selection_drag_rect())


func _finish_selection_drag(screen_position: Vector2) -> void:
	_selection_drag_current = screen_position
	var was_dragging := _selection_drag_active and _selection_drag_start.distance_to(_selection_drag_current) >= SELECTION_DRAG_THRESHOLD
	_selection_drag_pending = false
	_selection_drag_active = false
	_hide_selection_box()

	if was_dragging:
		_robot_controller.select_robots_in_screen_rect(_selection_drag_rect(), true)
		_update_details_text()
		return

	_handle_left_click_at_screen_position(screen_position, true)


func _selection_drag_rect() -> Rect2:
	var top_left := Vector2(
		minf(_selection_drag_start.x, _selection_drag_current.x),
		minf(_selection_drag_start.y, _selection_drag_current.y)
	)
	var bottom_right := Vector2(
		maxf(_selection_drag_start.x, _selection_drag_current.x),
		maxf(_selection_drag_start.y, _selection_drag_current.y)
	)
	return Rect2(top_left, bottom_right - top_left)


func _update_selection_box(selection_rect: Rect2) -> void:
	if _selection_box == null:
		return

	_selection_box.position = selection_rect.position
	_selection_box.size = selection_rect.size
	_selection_box.visible = true


func _hide_selection_box() -> void:
	if _selection_box != null:
		_selection_box.visible = false


func _handle_left_click_at_screen_position(screen_position: Vector2, shift_pressed: bool) -> void:
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var mouse_world_position := inverse_canvas * screen_position
	var grid_position: Vector2i = _board.world_to_grid(mouse_world_position)
	var clicked_robot := _robot_controller.get_robot_at_world_position(mouse_world_position)
	if clicked_robot != null:
		_robot_controller.handle_left_click(mouse_world_position, shift_pressed)
		return

	if shift_pressed and _factory_simulation.spawn_iron_ore_at(grid_position):
		return

	var building := _board.get_building_at_cell(grid_position)
	if building != null:
		if not shift_pressed:
			_robot_controller.clear_selection()
		if building.has_visual_inventory():
			_building_inventory_window.open_for_building(building)
		return

	var deposit := _board.get_resource_at_cell(grid_position)
	if deposit != null:
		if not shift_pressed:
			_robot_controller.clear_selection()
		return

	if not shift_pressed:
		_robot_controller.clear_selection()


func _build_game_diagnostics() -> void:
	_game_diagnostics = GameDiagnosticsScript.new()
	_game_diagnostics.call("configure", _board, _factory_simulation, _robot_controller)
	add_child(_game_diagnostics)


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
