class_name InventorySlot
extends RefCounted

enum Role { STORAGE, INPUT, OUTPUT }

const DEFAULT_STACK_LIMIT: int = 100

var item_id: String = ""
var quantity: int = 0
var role: int = Role.STORAGE
var filter_enabled: bool = false
var filter_item_id: String = ""
var stack_limit: int = DEFAULT_STACK_LIMIT


func _init(new_role: int = Role.STORAGE, new_stack_limit: int = DEFAULT_STACK_LIMIT) -> void:
	role = new_role
	stack_limit = maxi(1, new_stack_limit)


func is_empty() -> bool:
	return item_id.is_empty() or quantity <= 0


func clear() -> void:
	item_id = ""
	quantity = 0


func accepts_item_id(candidate_item_id: String, manual: bool = true) -> bool:
	if candidate_item_id.is_empty():
		return false
	if manual and role == Role.OUTPUT:
		return false
	if filter_enabled and filter_item_id != candidate_item_id:
		return false

	return true


func can_accept_item(candidate_item_id: String, manual: bool = true) -> bool:
	if not accepts_item_id(candidate_item_id, manual):
		return false
	if not is_empty() and item_id != candidate_item_id:
		return false

	return quantity < stack_limit


func available_space_for(candidate_item_id: String, manual: bool = true) -> int:
	if not can_accept_item(candidate_item_id, manual):
		return 0

	return maxi(0, stack_limit - quantity)


func available_space_any() -> int:
	return maxi(0, stack_limit - quantity)


func add_item(candidate_item_id: String, amount: int, manual: bool = true) -> int:
	if amount <= 0:
		return 0

	var accepted := mini(amount, available_space_for(candidate_item_id, manual))
	if accepted <= 0:
		return 0

	if is_empty():
		item_id = candidate_item_id
		quantity = 0
	quantity += accepted
	return accepted


func remove_amount(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0

	var removed := mini(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		clear()

	return removed


func set_stack(candidate_item_id: String, amount: int) -> void:
	if candidate_item_id.is_empty() or amount <= 0:
		clear()
		return

	item_id = candidate_item_id
	quantity = mini(amount, stack_limit)


func serialize() -> Dictionary:
	return {
		"item_id": item_id,
		"quantity": quantity,
		"role": role,
		"filter_enabled": filter_enabled,
		"filter_item_id": filter_item_id,
		"stack_limit": stack_limit,
	}


func restore(data: Dictionary) -> void:
	role = int(data.get("role", role))
	filter_enabled = bool(data.get("filter_enabled", filter_enabled))
	filter_item_id = str(data.get("filter_item_id", filter_item_id))
	stack_limit = maxi(1, int(data.get("stack_limit", stack_limit)))
	set_stack(str(data.get("item_id", "")), int(data.get("quantity", 0)))
