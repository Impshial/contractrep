class_name SaveLoadDialogs
extends Control

signal load_completed()
signal dialogs_closed()

@export var save_manager_path: NodePath

var _save_manager: SaveManager
var _save_panel: PanelContainer
var _load_panel: PanelContainer
var _save_name_edit: LineEdit
var _save_status_label: Label
var _load_status_label: Label
var _save_list: ItemList
var _load_list: ItemList
var _load_thumbnail: TextureRect
var _load_summary_label: Label
var _save_summaries: Array[Dictionary] = []


func _ready() -> void:
	_save_manager = get_node(save_manager_path) as SaveManager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dialogs()


func open_save_dialog() -> void:
	_refresh_save_lists()
	_save_name_edit.text = _default_save_name()
	_save_status_label.text = ""
	_save_panel.visible = true
	_load_panel.visible = false
	_save_name_edit.grab_focus()


func open_load_dialog() -> void:
	_refresh_save_lists()
	_load_status_label.text = ""
	_load_panel.visible = true
	_save_panel.visible = false


func is_dialog_open() -> bool:
	return (_save_panel != null and _save_panel.visible) or (_load_panel != null and _load_panel.visible)


func close_dialogs() -> void:
	_on_close_pressed()


func _build_dialogs() -> void:
	_save_panel = _create_panel(Vector2(32.0, 32.0), Vector2(430.0, 360.0))
	add_child(_save_panel)
	_build_save_panel()

	_load_panel = _create_panel(Vector2(500.0, 32.0), Vector2(520.0, 430.0))
	add_child(_load_panel)
	_build_load_panel()


func _create_panel(panel_position: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = panel_position
	panel.size = panel_size
	return panel


func _build_save_panel() -> void:
	var margin := _create_margin_container()
	_save_panel.add_child(margin)
	var rows := _create_vbox()
	margin.add_child(rows)

	rows.add_child(_create_title("Save Game"))
	_save_name_edit = LineEdit.new()
	_save_name_edit.placeholder_text = "Save name"
	rows.add_child(_save_name_edit)

	rows.add_child(_create_label("Existing saves"))
	_save_list = ItemList.new()
	_save_list.custom_minimum_size = Vector2(0.0, 145.0)
	_save_list.item_selected.connect(_on_save_list_item_selected)
	rows.add_child(_save_list)

	_save_status_label = _create_label("")
	rows.add_child(_save_status_label)
	rows.add_child(_create_button_row("Save", "_on_confirm_save_pressed", "Close", "_on_close_pressed"))


func _build_load_panel() -> void:
	var margin := _create_margin_container()
	_load_panel.add_child(margin)
	var rows := _create_vbox()
	margin.add_child(rows)

	rows.add_child(_create_title("Load Game"))
	_load_list = ItemList.new()
	_load_list.custom_minimum_size = Vector2(0.0, 150.0)
	_load_list.item_selected.connect(_on_load_list_item_selected)
	rows.add_child(_load_list)

	_load_thumbnail = TextureRect.new()
	_load_thumbnail.custom_minimum_size = Vector2(160.0, 90.0)
	_load_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rows.add_child(_load_thumbnail)

	_load_summary_label = _create_label("")
	rows.add_child(_load_summary_label)
	_load_status_label = _create_label("")
	rows.add_child(_load_status_label)
	rows.add_child(_create_button_row("Load", "_on_confirm_load_pressed", "Close", "_on_close_pressed"))


func _create_margin_container() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin


func _create_vbox() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	return rows


func _create_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_button_row(primary_text: String, primary_method: StringName, secondary_text: String, secondary_method: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var primary_button := Button.new()
	primary_button.text = primary_text
	primary_button.custom_minimum_size = Vector2(110.0, 38.0)
	primary_button.pressed.connect(Callable(self, primary_method))
	row.add_child(primary_button)

	var secondary_button := Button.new()
	secondary_button.text = secondary_text
	secondary_button.custom_minimum_size = Vector2(110.0, 38.0)
	secondary_button.pressed.connect(Callable(self, secondary_method))
	row.add_child(secondary_button)
	return row


func _refresh_save_lists() -> void:
	_save_summaries = _save_manager.get_save_summaries()
	_save_list.clear()
	_load_list.clear()

	for summary: Dictionary in _save_summaries:
		var label := "%s  %s" % [summary.get("name", "Unnamed Save"), summary.get("saved_at", "")]
		_save_list.add_item(label)
		_load_list.add_item(label)

	_update_load_preview(-1)


func _on_save_list_item_selected(index: int) -> void:
	if index < 0 or index >= _save_summaries.size():
		return

	_save_name_edit.text = str(_save_summaries[index].get("name", "Unnamed Save"))


func _on_load_list_item_selected(index: int) -> void:
	_update_load_preview(index)


func _update_load_preview(index: int) -> void:
	if index < 0 or index >= _save_summaries.size():
		_load_thumbnail.texture = null
		_load_summary_label.text = "Select a save to preview it."
		return

	var summary := _save_summaries[index]
	_load_thumbnail.texture = _save_manager.thumbnail_texture_from_base64(str(summary.get("thumbnail", "")))
	_load_summary_label.text = "Buildings: %d\nItems: %d\nRobots: %d" % [
		int(summary.get("building_count", 0)),
		int(summary.get("item_count", 0)),
		int(summary.get("robot_count", 0)),
	]


func _on_confirm_save_pressed() -> void:
	_save_panel.visible = false
	await get_tree().process_frame

	if _save_manager.save_game_named(_save_name_edit.text):
		_refresh_save_lists()
		_save_status_label.text = "Saved."
	else:
		_save_status_label.text = "Save failed."

	_save_panel.visible = true


func _on_confirm_load_pressed() -> void:
	var selected_items := _load_list.get_selected_items()
	if selected_items.is_empty():
		_load_status_label.text = "Select a save first."
		return

	var selected_index := selected_items[0]
	var save_name := str(_save_summaries[selected_index].get("name", ""))
	if _save_manager.load_game_named(save_name):
		_load_status_label.text = "Loaded."
		_load_panel.visible = false
		load_completed.emit()
	else:
		_load_status_label.text = "Load failed."


func _on_close_pressed() -> void:
	_save_panel.visible = false
	_load_panel.visible = false
	dialogs_closed.emit()


func _default_save_name() -> String:
	return "Factory %s" % Time.get_datetime_string_from_system(false, true).replace(":", "-")
