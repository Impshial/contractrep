class_name InventorySlotControl
extends Control

const SLOT_SIZE: Vector2 = Vector2(34.0, 34.0)
const ICON_SIZE: float = 23.0

var inventory: Inventory
var slot_index: int = -1
var cursor_stack: InventoryCursorStack


func configure(new_inventory: Inventory, new_slot_index: int, new_cursor_stack: InventoryCursorStack) -> void:
	inventory = new_inventory
	slot_index = new_slot_index
	cursor_stack = new_cursor_stack
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = _make_tooltip()
	queue_redraw()


func _process(_delta: float) -> void:
	if inventory != null:
		tooltip_text = _make_tooltip()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if inventory == null or cursor_stack == null:
		return

	if cursor_stack.is_empty():
		_pick_up_from_slot(mouse_event)
	else:
		var new_cursor_stack := inventory.place_or_swap_slot(slot_index, cursor_stack.item_id, cursor_stack.quantity, true)
		cursor_stack.replace_with_stack(new_cursor_stack)

	accept_event()
	queue_redraw()


func _pick_up_from_slot(mouse_event: InputEventMouseButton) -> void:
	var slot: InventorySlot = inventory.get_slot(slot_index)
	if slot == null or slot.is_empty():
		return

	var amount := slot.quantity
	if mouse_event.shift_pressed:
		amount = 1
	elif mouse_event.ctrl_pressed:
		amount = int(ceil(float(slot.quantity) * 0.5))

	var stack_data := inventory.take_from_slot(slot_index, amount)
	cursor_stack.replace_with_stack(stack_data)


func _draw() -> void:
	var slot: InventorySlot = inventory.get_slot(slot_index) if inventory != null else null
	var rect := Rect2(Vector2.ZERO, SLOT_SIZE)
	var fill_rect := Rect2(Vector2.ONE, SLOT_SIZE - Vector2(2.0, 2.0))
	var fill_color := Color(0.12, 0.13, 0.14, 0.96)
	var border_color := Color(0.38, 0.42, 0.45, 0.95)

	if slot != null and slot.role == InventorySlot.Role.OUTPUT:
		fill_color = Color(0.15, 0.12, 0.10, 0.96)
		border_color = Color(0.78, 0.55, 0.30, 0.95)
	elif slot != null and slot.role == InventorySlot.Role.INPUT:
		fill_color = Color(0.10, 0.13, 0.15, 0.96)
		border_color = Color(0.35, 0.58, 0.72, 0.95)

	draw_rect(fill_rect, fill_color, true)
	_draw_even_border(rect, border_color)

	if slot == null or slot.is_empty():
		return

	var texture := FactoryItem.texture_for_item_id(slot.item_id)
	if texture != null:
		var icon_offset := (SLOT_SIZE - Vector2(ICON_SIZE, ICON_SIZE)) * 0.5
		draw_texture_rect(texture, Rect2(icon_offset, Vector2(ICON_SIZE, ICON_SIZE)), false)

	var font := ThemeDB.fallback_font
	var text := str(slot.quantity)
	var text_position := Vector2(3.0, SLOT_SIZE.y - 4.0)
	draw_string(font, text_position + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.0, 0.0, 0.0, 0.80))
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)


func _draw_even_border(rect: Rect2, color: Color) -> void:
	var left := rect.position.x + 0.5
	var top := rect.position.y + 0.5
	var right := rect.position.x + rect.size.x - 0.5
	var bottom := rect.position.y + rect.size.y - 0.5

	draw_line(Vector2(left, top), Vector2(right, top), color, 1.0)
	draw_line(Vector2(right, top), Vector2(right, bottom), color, 1.0)
	draw_line(Vector2(right, bottom), Vector2(left, bottom), color, 1.0)
	draw_line(Vector2(left, bottom), Vector2(left, top), color, 1.0)


func _make_tooltip() -> String:
	var slot: InventorySlot = inventory.get_slot(slot_index) if inventory != null else null
	if slot == null:
		return ""

	var role_name := Inventory.role_display_name(slot.role)
	if slot.is_empty():
		return "%s Slot" % role_name

	return GameDefinitions.inventory_item_display_name(slot.item_id)
