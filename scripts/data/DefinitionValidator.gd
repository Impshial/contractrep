class_name DefinitionValidator
extends RefCounted

const DEFINITION_TYPES: Array[String] = [
	"item",
	"resource",
	"building",
	"bot",
	"player",
	"recipe",
	"terrain",
	"worldgen",
]

var errors: Array[String] = []


func has_errors() -> bool:
	return not errors.is_empty()


func add_error(message: String) -> void:
	errors.append(message)
	push_error(message)


func validate_manifest(manifest: Dictionary, file_path: String) -> bool:
	var valid := true
	valid = _require_string(manifest, "id", file_path, "manifest") and valid
	valid = _require_string(manifest, "name", file_path, "manifest") and valid
	valid = _require_string(manifest, "version", file_path, "manifest") and valid
	if not valid:
		return false

	var pack_id := str(manifest.get("id", ""))
	if not _is_plain_id(pack_id):
		add_error("%s: manifest id must be a plain namespace id, received '%s'." % [file_path, pack_id])
		valid = false

	return valid


func validate_definition(definition: Dictionary, file_path: String, expected_type: String, pack_id: String) -> bool:
	var valid := true
	valid = _require_string(definition, "id", file_path, expected_type) and valid
	valid = _require_string(definition, "type", file_path, expected_type) and valid
	if not valid:
		return false

	var definition_id := str(definition.get("id", ""))
	var definition_type := str(definition.get("type", ""))
	if definition_type != expected_type:
		add_error("%s: definition '%s' has type '%s', expected '%s'." % [file_path, definition_id, definition_type, expected_type])
		valid = false
	if not _is_namespaced_id(definition_id):
		add_error("%s: definition id '%s' must be namespaced, e.g. '%s:thing'." % [file_path, definition_id, pack_id])
		valid = false

	match expected_type:
		"item":
			valid = _validate_item(definition, file_path) and valid
		"resource":
			valid = _validate_resource(definition, file_path) and valid
		"building":
			valid = _validate_building(definition, file_path) and valid
		"bot":
			valid = _validate_bot(definition, file_path) and valid
		"worldgen":
			valid = _validate_worldgen(definition, file_path) and valid

	return valid


func validate_references(definitions_by_type: Dictionary) -> void:
	for resource: Dictionary in definitions_by_type.get("resource", {}).values():
		var item_id := str(resource.get("produces_item", ""))
		if not item_id.is_empty() and not definitions_by_type.get("item", {}).has(item_id):
			add_error("Resource '%s' references missing item '%s'." % [resource.get("id", ""), item_id])

	for recipe: Dictionary in definitions_by_type.get("recipe", {}).values():
		for entry: Dictionary in recipe.get("inputs", []):
			_validate_item_reference(entry, recipe, definitions_by_type)
		for entry: Dictionary in recipe.get("outputs", []):
			_validate_item_reference(entry, recipe, definitions_by_type)

	for worldgen: Dictionary in definitions_by_type.get("worldgen", {}).values():
		for entry: Dictionary in worldgen.get("resources", []):
			var resource_id := str(entry.get("resource", ""))
			if not resource_id.is_empty() and not definitions_by_type.get("resource", {}).has(resource_id):
				add_error("Worldgen '%s' references missing resource '%s'." % [worldgen.get("id", ""), resource_id])


func _validate_item_reference(entry: Dictionary, recipe: Dictionary, definitions_by_type: Dictionary) -> void:
	var item_id := str(entry.get("item", ""))
	if item_id.is_empty():
		add_error("Recipe '%s' has an item reference without item id." % [recipe.get("id", "")])
	elif not definitions_by_type.get("item", {}).has(item_id):
		add_error("Recipe '%s' references missing item '%s'." % [recipe.get("id", ""), item_id])


func _validate_item(definition: Dictionary, file_path: String) -> bool:
	var valid := _require_string(definition, "display_name", file_path, "item")
	if int(definition.get("stack_size", 1)) <= 0:
		add_error("%s: item '%s' stack_size must be > 0." % [file_path, definition.get("id", "")])
		valid = false
	return valid


func _validate_resource(definition: Dictionary, file_path: String) -> bool:
	var valid := _require_string(definition, "produces_item", file_path, "resource")
	if int(definition.get("starting_amount", 1)) <= 0:
		add_error("%s: resource '%s' starting_amount must be > 0." % [file_path, definition.get("id", "")])
		valid = false
	return valid


func _validate_building(definition: Dictionary, file_path: String) -> bool:
	var valid := _require_string(definition, "behavior", file_path, "building")
	var inventory: Dictionary = definition.get("inventory", {})
	for key: String in ["input_slots", "output_slots", "storage_slots", "slots_per_row"]:
		if inventory.has(key) and int(inventory.get(key, 0)) < 0:
			add_error("%s: building '%s' inventory.%s must not be negative." % [file_path, definition.get("id", ""), key])
			valid = false
	return valid


func _validate_bot(definition: Dictionary, file_path: String) -> bool:
	var valid := true
	if int(definition.get("inventory_capacity", 1)) <= 0:
		add_error("%s: bot '%s' inventory_capacity must be > 0." % [file_path, definition.get("id", "")])
		valid = false
	var harvest: Dictionary = definition.get("harvest", {})
	if harvest.has("cycle_seconds") and float(harvest.get("cycle_seconds", 0.0)) <= 0.0:
		add_error("%s: bot '%s' harvest.cycle_seconds must be > 0." % [file_path, definition.get("id", "")])
		valid = false
	return valid


func _validate_worldgen(definition: Dictionary, file_path: String) -> bool:
	var valid := true
	if int(definition.get("resource_region_size", 1)) <= 0:
		add_error("%s: worldgen '%s' resource_region_size must be > 0." % [file_path, definition.get("id", "")])
		valid = false
	return valid


func _require_string(definition: Dictionary, key: String, file_path: String, definition_type: String) -> bool:
	if not definition.has(key) or str(definition.get(key, "")).strip_edges().is_empty():
		add_error("%s: %s definition missing required string '%s'." % [file_path, definition_type, key])
		return false
	return true


func _is_namespaced_id(value: String) -> bool:
	var parts := value.split(":")
	return parts.size() == 2 and _is_plain_id(parts[0]) and _is_plain_id(parts[1])


func _is_plain_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true
