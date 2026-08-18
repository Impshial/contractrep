class_name Inventory
extends RefCounted

var capacity: int = 0
var _items: Dictionary = {}


func _init(new_capacity: int = 0) -> void:
	capacity = maxi(0, new_capacity)


func add_item(item_id: String, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var accepted: int = mini(amount, available_capacity())
	if accepted <= 0:
		print("Inventory full; could not accept %s x%d" % [item_id, amount])
		return 0

	_items[item_id] = get_quantity(item_id) + accepted
	return accepted


func remove_item(item_id: String, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var removed: int = mini(amount, get_quantity(item_id))
	if removed <= 0:
		return 0

	var remaining: int = get_quantity(item_id) - removed
	if remaining <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = remaining

	return removed


func transfer_to(destination: Inventory, item_id: String, amount: int) -> int:
	if destination == null:
		return 0

	var removable: int = mini(amount, get_quantity(item_id))
	var accepted: int = destination.add_item(item_id, removable)
	if accepted > 0:
		remove_item(item_id, accepted)
		print("Transferred %d %s" % [accepted, item_id])

	return accepted


func transfer_all_to(destination: Inventory) -> int:
	var total_transferred: int = 0
	for item_key: Variant in _items.keys():
		var item_id := str(item_key)
		total_transferred += transfer_to(destination, item_id, get_quantity(item_id))

	return total_transferred


func get_quantity(item_id: String) -> int:
	return int(_items.get(item_id, 0))


func used_capacity() -> int:
	var total := 0
	for amount: Variant in _items.values():
		total += int(amount)

	return total


func available_capacity() -> int:
	return maxi(0, capacity - used_capacity())


func can_accept(item_id: String, amount: int = 1) -> bool:
	return not item_id.is_empty() and amount > 0 and available_capacity() > 0


func acceptable_amount(_item_id: String, amount: int) -> int:
	return mini(maxi(0, amount), available_capacity())


func is_empty() -> bool:
	return _items.is_empty()


func contents() -> Dictionary:
	return _items.duplicate()


func serialize() -> Dictionary:
	return {
		"capacity": capacity,
		"items": contents(),
	}


func restore(data: Dictionary) -> void:
	capacity = int(data.get("capacity", capacity))
	_items.clear()
	var saved_items_variant: Variant = data.get("items", {})
	if not (saved_items_variant is Dictionary):
		return

	var saved_items: Dictionary = saved_items_variant
	for key: Variant in saved_items.keys():
		var amount: int = int(saved_items[key])
		if amount > 0:
			_items[str(key)] = amount
