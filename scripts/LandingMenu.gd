extends Control

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const SAVE_STORE_PATH: String = "user://contract_saves.json"
const LEGACY_SAVE_STORE_PATH: String = "user://factori_no_saves.json"

var _menu_panel: PanelContainer
var _load_overlay: Control
var _save_list: ItemList
var _load_status_label: Label
var _status_label: Label
var _saves: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	_load_save_summaries()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.060, 0.058)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_menu_panel = PanelContainer.new()
	_menu_panel.custom_minimum_size = Vector2(360.0, 280.0)
	center.add_child(_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_menu_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Contract"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Menu"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	rows.add_child(subtitle)

	rows.add_child(_create_button("New Game", _on_new_game_pressed))
	rows.add_child(_create_button("Load Game", _on_load_game_pressed))
	rows.add_child(_create_button("Quit", _on_quit_pressed))

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status_label)

	_build_load_dialog()


func _build_load_dialog() -> void:
	_load_overlay = Control.new()
	_load_overlay.name = "LoadGameDialog"
	_load_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.visible = false
	add_child(_load_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 430.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)

	_save_list = ItemList.new()
	_save_list.custom_minimum_size = Vector2(0.0, 230.0)
	_save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_list.item_activated.connect(_on_save_item_activated)
	rows.add_child(_save_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	rows.add_child(buttons)

	var load_button := _create_button("Load", _on_confirm_load_pressed)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(load_button)

	var cancel_button := _create_button("Cancel", _on_cancel_load_pressed)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel_button)

	_load_status_label = Label.new()
	_load_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_load_status_label)


func _create_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(callback)
	return button


func _load_save_summaries() -> void:
	_saves.clear()
	if _save_list != null:
		_save_list.clear()

	var store := _read_save_store()
	for save_variant: Variant in store.get("saves", []):
		if save_variant is Dictionary:
			_saves.append(save_variant)

	_saves.sort_custom(_sort_saves_newest_first)
	for save_data: Dictionary in _saves:
		var save_name := str(save_data.get("name", "Unnamed Save"))
		var saved_at := str(save_data.get("saved_at", ""))
		if _save_list != null:
			_save_list.add_item("%s  %s" % [save_name, saved_at])

	if _saves.is_empty() and _save_list != null:
		_save_list.add_item("No saves found")
		_save_list.set_item_disabled(0, true)


func _read_save_store() -> Dictionary:
	var save_path := SAVE_STORE_PATH
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(LEGACY_SAVE_STORE_PATH):
		save_path = LEGACY_SAVE_STORE_PATH
	if not FileAccess.file_exists(save_path):
		return {"saves": []}

	var save_file := FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return {"saves": []}

	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {"saves": []}


func _sort_saves_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("saved_at", "")) > str(b.get("saved_at", ""))


func _on_new_game_pressed() -> void:
	_status_label.text = "Loading..."
	LaunchOptions.request_new_game()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_load_game_pressed() -> void:
	_status_label.text = ""
	_load_status_label.text = ""
	_load_save_summaries()
	_load_overlay.visible = true


func _on_confirm_load_pressed() -> void:
	if _saves.is_empty():
		_load_status_label.text = "No saves found."
		return

	var selected_items := _save_list.get_selected_items()
	if selected_items.is_empty():
		_load_status_label.text = "Choose a save first."
		return

	var selected_index := int(selected_items[0])
	if selected_index < 0 or selected_index >= _saves.size():
		_load_status_label.text = "Choose a save first."
		return

	var save_name := str(_saves[selected_index].get("name", ""))
	if save_name.is_empty():
		_load_status_label.text = "That save is missing a name."
		return

	_load_status_label.text = "Loading..."
	LaunchOptions.request_load_game(save_name)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_save_item_activated(_index: int) -> void:
	_on_confirm_load_pressed()


func _on_cancel_load_pressed() -> void:
	_load_overlay.visible = false
	_load_status_label.text = ""


func _on_quit_pressed() -> void:
	get_tree().quit()
