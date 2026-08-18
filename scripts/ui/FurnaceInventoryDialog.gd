class_name FurnaceInventoryDialog
extends Control

var _panel: PanelContainer
var _title_label: Label
var _iron_ore_label: Label
var _coal_label: Label
var _iron_plate_label: Label
var _progress_bar: ProgressBar
var _furnace: Furnace


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dialog()


func open_for_furnace(furnace: Furnace) -> void:
	_furnace = furnace
	_center_panel()
	_panel.visible = true
	_update_text()


func close() -> void:
	_panel.visible = false
	_furnace = null


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if not is_instance_valid(_furnace):
		close()
		return

	_update_text()


func _build_dialog() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(300.0, 300.0)
	_panel.size = _panel.custom_minimum_size
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	_center_panel()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var title_row := HBoxContainer.new()
	rows.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Furnace"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34.0, 30.0)
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	rows.add_child(_section_label("INPUT"))
	_iron_ore_label = _item_label()
	rows.add_child(_iron_ore_label)
	_coal_label = _item_label()
	rows.add_child(_coal_label)

	rows.add_child(_section_label("OUTPUT"))
	_iron_plate_label = _item_label()
	rows.add_child(_iron_plate_label)

	rows.add_child(_section_label("Smelting"))
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.custom_minimum_size = Vector2(0.0, 22.0)
	rows.add_child(_progress_bar)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label


func _item_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _update_text() -> void:
	if _furnace == null:
		return

	_iron_ore_label.text = "Iron Ore\n%d / %d" % [_furnace.iron_ore_count, Furnace.STACK_CAPACITY]
	_coal_label.text = "Coal\n%d / %d" % [_furnace.coal_count, Furnace.STACK_CAPACITY]
	_iron_plate_label.text = "Iron Plate\n%d / %d" % [_furnace.iron_plate_count, Furnace.STACK_CAPACITY]
	_progress_bar.value = _furnace.get_smelting_ratio() * 100.0


func _center_panel() -> void:
	if _panel == null:
		return

	var viewport_size := get_viewport_rect().size
	_panel.size = _panel.custom_minimum_size
	_panel.position = (viewport_size - _panel.size) * 0.5


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.085, 1.0)
	style.border_color = Color(0.62, 0.70, 0.66, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
