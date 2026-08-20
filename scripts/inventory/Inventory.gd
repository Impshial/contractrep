class_name Inventory
extends RefCounted

const DEFAULT_STACK_LIMIT: int = 100
const DEFAULT_SLOTS_PER_ROW: int = 10

var capacity: int = 0
var slots: Array[InventorySlot] = []
var slots_per_row: int = DEFAULT_SLOTS_PER_ROW

var _unit_capacity_limit: int = -1


func _init(new_capacity: int = 0) -> void:
	if new_capacity > 0:
		configure_storage_slots(new_capacity, DEFAULT_SLOTS_PER_ROW, DEFAULT_STACK_LIMIT, new_capacity)
	else:
		capacity = 0


func configure_storage_slots(
	slot_count: int,
	new_slots_per_row: int = DEFAULT_SLOTS_PER_ROW,
	stack_limit: int = DEFAULT_STACK_LIMIT,
	unit_capacity_limit: int = -1
) -> void:
	var role_counts := {
		InventorySlot.Role.STORAGE: maxi(0, slot_count),
	}
	configure_slots(role_counts, new_slots_per_row, stack_limit, unit_capacity_limit)


func configure_slots(
	role_counts: Dictionary,
	new_slots_per_row: int = DEFAULT_SLOTS_PER_ROW,
	stack_limit: int = DEFAULT_STACK_LIMIT,
	unit_capacity_limit: int = -1
) -> void:
	slots.clear()
	slots_per_row = maxi(1, new_slots_per_row)
	_unit_capacity_limit = unit_capacity_limit

	for role: int in [InventorySlot.Role.INPUT, InventorySlot.Role.OUTPUT, InventorySlot.Role.STORAGE]:
		var count := maxi(0, int(role_counts.get(role, 0)))
		for _index: int in range(count):
			slots.append(InventorySlot.new(role, stack_limit))

	_refresh_capacity()


func clear() -> void:
	for slot: InventorySlot in slots:
		slot.clear()


func add_item(item_id: String, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	return _add_item_to_matching_slots(item_id, amount, [], true)


func remove_item(item_id: String, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var remaining := amount
	var total_removed := 0

	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if slot.item_id != item_id or slot.is_empty():
			continue

		var removed := slot.remove_amount(remaining)
		remaining -= removed
		total_removed += removed

	return total_removed


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
	var current_contents := contents()
	for item_key: Variant in current_contents.keys():
		var item_id := str(item_key)
		total_transferred += transfer_to(destination, item_id, get_quantity(item_id))

	return total_transferred


func get_quantity(item_id: String) -> int:
	var total := 0
	for slot: InventorySlot in slots:
		if slot.item_id == item_id and not slot.is_empty():
			total += slot.quantity

	return total


func get_quantity_in_role(item_id: String, role: int) -> int:
	var total := 0
	for slot: InventorySlot in slots:
		if slot.role == role and slot.item_id == item_id and not slot.is_empty():
			total += slot.quantity

	return total


func used_capacity() -> int:
	var total := 0
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			total += slot.quantity

	return total


func available_capacity() -> int:
	if _unit_capacity_limit >= 0:
		return maxi(0, _unit_capacity_limit - used_capacity())

	var total := 0
	for slot: InventorySlot in slots:
		if slot.role == InventorySlot.Role.OUTPUT:
			continue
		total += slot.available_space_any()

	return total


func can_accept(item_id: String, amount: int = 1) -> bool:
	return not item_id.is_empty() and amount > 0 and acceptable_amount(item_id, amount) >= amount


func acceptable_amount(item_id: String, amount: int) -> int:
	return _acceptable_amount_in_matching_slots(item_id, amount, [], true)


func add_item_to_role(item_id: String, amount: int, role: int, manual: bool = true) -> int:
	return _add_item_to_matching_slots(item_id, amount, [role], manual)


func acceptable_amount_in_role(item_id: String, amount: int, role: int, manual: bool = true) -> int:
	return _acceptable_amount_in_matching_slots(item_id, amount, [role], manual)


func can_accept_in_role(item_id: String, amount: int, role: int, manual: bool = true) -> bool:
	return acceptable_amount_in_role(item_id, amount, role, manual) >= amount


func consume_from_role(item_id: String, amount: int, role: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var remaining := amount
	var total_removed := 0
	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if slot.role != role or slot.item_id != item_id or slot.is_empty():
			continue

		var removed := slot.remove_amount(remaining)
		remaining -= removed
		total_removed += removed

	return total_removed


func set_role_item_quantity(item_id: String, role: int, amount: int) -> void:
	for slot: InventorySlot in slots:
		if slot.role == role and slot.item_id == item_id:
			slot.clear()

	add_item_to_role(item_id, maxi(0, amount), role, role != InventorySlot.Role.OUTPUT)


func slot_count() -> int:
	return slots.size()


func get_slot(slot_index: int) -> InventorySlot:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	return slots[slot_index]


func get_slot_indices_for_role(role: int) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(slots.size()):
		if slots[index].role == role:
			indices.append(index)

	return indices


func get_section_definitions() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for role: int in [InventorySlot.Role.INPUT, InventorySlot.Role.OUTPUT, InventorySlot.Role.STORAGE]:
		var indices := get_slot_indices_for_role(role)
		if indices.is_empty():
			continue

		sections.append({
			"role": role,
			"title": role_display_name(role),
			"indices": indices,
			"columns": slots_per_row if role == InventorySlot.Role.STORAGE else mini(slots_per_row, maxi(1, indices.size())),
		})

	return sections


func add_item_to_slot(slot_index: int, item_id: String, amount: int, manual: bool = true) -> int:
	var slot := get_slot(slot_index)
	if slot == null:
		return 0

	var allowed_amount := mini(maxi(0, amount), _overall_available_capacity())
	if _unit_capacity_limit < 0:
		allowed_amount = maxi(0, amount)

	return slot.add_item(item_id, allowed_amount, manual)


func take_from_slot(slot_index: int, amount: int) -> Dictionary:
	var slot := get_slot(slot_index)
	if slot == null or slot.is_empty() or amount <= 0:
		return {}

	var removed_item_id := slot.item_id
	var removed := slot.remove_amount(amount)
	if removed <= 0:
		return {}

	return {
		"item_id": removed_item_id,
		"quantity": removed,
	}


func place_or_swap_slot(slot_index: int, held_item_id: String, held_quantity: int, manual: bool = true) -> Dictionary:
	var slot := get_slot(slot_index)
	if slot == null or held_item_id.is_empty() or held_quantity <= 0:
		return _stack_data(held_item_id, held_quantity)

	if slot.is_empty() or slot.item_id == held_item_id:
		var accepted := add_item_to_slot(slot_index, held_item_id, held_quantity, manual)
		return _stack_data(held_item_id, held_quantity - accepted)

	if not slot.accepts_item_id(held_item_id, manual):
		return _stack_data(held_item_id, held_quantity)
	if held_quantity > slot.stack_limit:
		return _stack_data(held_item_id, held_quantity)

	var old_item_id := slot.item_id
	var old_quantity := slot.quantity
	slot.set_stack(held_item_id, held_quantity)
	return _stack_data(old_item_id, old_quantity)


func first_item_id(roles: Array[int] = []) -> String:
	for slot: InventorySlot in slots:
		if not roles.is_empty() and not roles.has(slot.role):
			continue
		if not slot.is_empty():
			return slot.item_id

	return ""


func remove_first_item(roles: Array[int] = []) -> String:
	for slot: InventorySlot in slots:
		if not roles.is_empty() and not roles.has(slot.role):
			continue
		if slot.is_empty():
			continue

		var removed_item_id := slot.item_id
		slot.remove_amount(1)
		return removed_item_id

	return ""


func is_empty() -> bool:
	return used_capacity() <= 0


func contents() -> Dictionary:
	var current_contents: Dictionary = {}
	for slot: InventorySlot in slots:
		if slot.is_empty():
			continue

		current_contents[slot.item_id] = int(current_contents.get(slot.item_id, 0)) + slot.quantity

	return current_contents


func serialize() -> Dictionary:
	var serialized_slots: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		serialized_slots.append(slot.serialize())

	return {
		"slot_based": true,
		"capacity": capacity,
		"unit_capacity_limit": _unit_capacity_limit,
		"slots_per_row": slots_per_row,
		"slots": serialized_slots,
		"items": contents(),
	}


func restore(data: Dictionary) -> void:
	if data.has("slots"):
		slots.clear()
		slots_per_row = maxi(1, int(data.get("slots_per_row", slots_per_row)))
		_unit_capacity_limit = int(data.get("unit_capacity_limit", -1))

		var saved_slots: Array = data.get("slots", [])
		for slot_variant: Variant in saved_slots:
			if not (slot_variant is Dictionary):
				continue

			var slot := InventorySlot.new()
			slot.restore(slot_variant)
			slots.append(slot)

		_refresh_capacity()
		return

	if slots.is_empty():
		var saved_capacity := maxi(0, int(data.get("capacity", capacity)))
		configure_storage_slots(maxi(1, saved_capacity), DEFAULT_SLOTS_PER_ROW, DEFAULT_STACK_LIMIT, saved_capacity)

	clear()
	var saved_items_variant: Variant = data.get("items", {})
	if not (saved_items_variant is Dictionary):
		return

	var saved_items: Dictionary = saved_items_variant
	for key: Variant in saved_items.keys():
		var amount: int = int(saved_items[key])
		if amount > 0:
			add_item(str(key), amount)


static func role_display_name(role: int) -> String:
	match role:
		InventorySlot.Role.INPUT:
			return "Input"
		InventorySlot.Role.OUTPUT:
			return "Output"
		InventorySlot.Role.STORAGE:
			return "Storage"

	return "Slots"


func _add_item_to_matching_slots(item_id: String, amount: int, roles: Array[int], manual: bool) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var remaining := mini(amount, _overall_available_capacity())
	if _unit_capacity_limit < 0:
		remaining = amount

	var accepted_total := 0
	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if not roles.is_empty() and not roles.has(slot.role):
			continue
		if slot.item_id != item_id or slot.is_empty():
			continue

		var accepted := slot.add_item(item_id, remaining, manual)
		remaining -= accepted
		accepted_total += accepted

	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if not roles.is_empty() and not roles.has(slot.role):
			continue
		if not slot.is_empty():
			continue

		var accepted := slot.add_item(item_id, remaining, manual)
		remaining -= accepted
		accepted_total += accepted

	return accepted_total


func _acceptable_amount_in_matching_slots(item_id: String, amount: int, roles: Array[int], manual: bool) -> int:
	if item_id.is_empty() or amount <= 0:
		return 0

	var total := 0
	for slot: InventorySlot in slots:
		if not roles.is_empty() and not roles.has(slot.role):
			continue

		total += slot.available_space_for(item_id, manual)

	return mini(amount, mini(total, _overall_available_capacity()))


func _overall_available_capacity() -> int:
	if _unit_capacity_limit >= 0:
		return maxi(0, _unit_capacity_limit - used_capacity())

	return 2147483647


func _refresh_capacity() -> void:
	if _unit_capacity_limit >= 0:
		capacity = _unit_capacity_limit
		return

	var total := 0
	for slot: InventorySlot in slots:
		total += slot.stack_limit

	capacity = total


func _stack_data(item_id: String, amount: int) -> Dictionary:
	var quantity := maxi(0, amount)
	if item_id.is_empty() or quantity <= 0:
		return {}

	return {
		"item_id": item_id,
		"quantity": quantity,
	}
