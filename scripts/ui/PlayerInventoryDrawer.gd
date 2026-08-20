class_name PlayerInventoryDrawer
extends Control

const DRAWER_WIDTH: float = 402.0
const TAB_WIDTH: float = 34.0
const TOP_OFFSET: float = 92.0

var _inventory: Inventory
var _cursor_stack: InventoryCursorStack
var _is_open: bool = false
var _is_blocked: bool = false
var _panel: PanelContainer
var _tab_button: Button
var _grid: GridContainer
var _tween: Tween


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = -DRAWER_WIDTH
	offset_top = TOP_OFFSET
	offset_right = TAB_WIDTH
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if _inventory != null:
		_rebuild_slots()


func configure(inventory: Inventory, cursor_stack: InventoryCursorStack) -> void:
	_inventory = inventory
	_cursor_stack = cursor_stack
	if _grid != null:
		_rebuild_slots()


func toggle() -> void:
	if _is_blocked:
		return

	_set_open(not _is_open)


func set_blocked(blocked: bool) -> void:
	if _is_blocked == blocked:
		return

	_is_blocked = blocked
	if _is_blocked:
		_set_open(false)
	if _tab_button != null:
		_tab_button.disabled = _is_blocked


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(DRAWER_WIDTH, 148.0)
	_panel.size = _panel.custom_minimum_size
	_panel.position = Vector2.ZERO
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Player Inventory"
	title.add_theme_font_size_override("font_size", 13)
	rows.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	rows.add_child(_grid)

	_tab_button = Button.new()
	_tab_button.text = "INV"
	_tab_button.custom_minimum_size = Vector2(TAB_WIDTH, 86.0)
	_tab_button.size = _tab_button.custom_minimum_size
	_tab_button.position = Vector2(DRAWER_WIDTH, 0.0)
	_tab_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_button.pressed.connect(toggle)
	add_child(_tab_button)


func _rebuild_slots() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()

	if _inventory == null or _cursor_stack == null:
		return

	for index: int in range(_inventory.slot_count()):
		var slot_control := InventorySlotControl.new()
		slot_control.configure(_inventory, index, _cursor_stack)
		_grid.add_child(slot_control)


func _set_open(open: bool) -> void:
	_is_open = open
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "offset_left", 0.0 if _is_open else -DRAWER_WIDTH, 0.18)
	_tween.parallel().tween_property(self, "offset_right", DRAWER_WIDTH + TAB_WIDTH if _is_open else TAB_WIDTH, 0.18)
