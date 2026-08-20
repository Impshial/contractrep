class_name InventoryCursorStack
extends Control

const ICON_SIZE: float = 24.0
const BACKGROUND_SIZE: float = 32.0

var item_id: String = ""
var quantity: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	set_process(true)


func is_empty() -> bool:
	return item_id.is_empty() or quantity <= 0


func set_stack(new_item_id: String, new_quantity: int) -> void:
	item_id = new_item_id
	quantity = maxi(0, new_quantity)
	if quantity <= 0 or item_id.is_empty():
		clear()
	else:
		queue_redraw()


func clear() -> void:
	item_id = ""
	quantity = 0
	queue_redraw()


func replace_with_stack(stack_data: Dictionary) -> void:
	set_stack(str(stack_data.get("item_id", "")), int(stack_data.get("quantity", 0)))


func _process(_delta: float) -> void:
	if not is_empty():
		queue_redraw()


func _draw() -> void:
	if is_empty():
		return

	var mouse_position := get_local_mouse_position()
	var background_rect := Rect2(mouse_position + Vector2(12.0, 12.0), Vector2(BACKGROUND_SIZE, BACKGROUND_SIZE))
	draw_rect(background_rect, Color(0.07, 0.08, 0.09, 0.90), true)
	draw_rect(background_rect, Color(0.82, 0.86, 0.90, 0.75), false, 1.0)

	var texture := FactoryItem.texture_for_item_id(item_id)
	if texture != null:
		var icon_rect := Rect2(background_rect.position + Vector2(4.0, 3.0), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(texture, icon_rect, false)

	var font := ThemeDB.fallback_font
	var text := str(quantity)
	var text_position := background_rect.position + Vector2(3.0, BACKGROUND_SIZE - 4.0)
	draw_string(font, text_position + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)
