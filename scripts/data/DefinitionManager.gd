class_name DefinitionManager
extends RefCounted

static var _loaded: bool = false
static var _load_ok: bool = false
static var _definitions_by_type: Dictionary = {}
static var _content_packs: Array[Dictionary] = []
static var _legacy_item_ids: Dictionary = {}
static var _legacy_item_types: Dictionary = {}
static var _legacy_resource_ids: Dictionary = {}
static var _legacy_building_ids: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func ensure_loaded() -> bool:
	if _loaded:
		return _load_ok

	_loaded = true
	var loader := DefinitionLoader.new()
	_load_ok = loader.load_all()
	_definitions_by_type = loader.definitions_by_type
	_content_packs = loader.content_packs
	_build_legacy_indexes()
	return _load_ok


static func reload() -> bool:
	_loaded = false
	_texture_cache.clear()
	return ensure_loaded()


static func content_packs() -> Array[Dictionary]:
	ensure_loaded()
	return _content_packs


static func save_content_pack_metadata() -> Array[Dictionary]:
	ensure_loaded()
	var metadata: Array[Dictionary] = []
	for pack: Dictionary in _content_packs:
		metadata.append({
			"id": str(pack.get("id", "")),
			"version": str(pack.get("version", "")),
		})
	return metadata


static func missing_content_packs(required_packs: Array) -> Array[String]:
	ensure_loaded()
	var loaded_ids: Dictionary = {}
	for pack: Dictionary in _content_packs:
		loaded_ids[str(pack.get("id", ""))] = true

	var missing: Array[String] = []
	for pack_variant: Variant in required_packs:
		var pack_id := ""
		if pack_variant is Dictionary:
			pack_id = str(pack_variant.get("id", ""))
		else:
			pack_id = str(pack_variant)
		if not pack_id.is_empty() and not loaded_ids.has(pack_id):
			missing.append(pack_id)
	return missing


static func get_definition(definition_type: String, definition_id: String) -> Dictionary:
	ensure_loaded()
	var normalized_id: String = normalize_id(definition_id)
	return (_definitions_by_type.get(definition_type, {}) as Dictionary).get(normalized_id, {})


static func has_item(item_id: String) -> bool:
	return not get_item(item_id).is_empty()


static func get_item(item_id: String) -> Dictionary:
	ensure_loaded()
	var normalized_id: String = normalize_item_id(item_id)
	return (_definitions_by_type.get("item", {}) as Dictionary).get(normalized_id, {})


static func get_item_by_type(item_type: int) -> Dictionary:
	ensure_loaded()
	return (_definitions_by_type.get("item", {}) as Dictionary).get(str(_legacy_item_types.get(item_type, "")), {})


static func get_resource(resource_id: String) -> Dictionary:
	ensure_loaded()
	var normalized_id: String = normalize_resource_id(resource_id)
	return (_definitions_by_type.get("resource", {}) as Dictionary).get(normalized_id, {})


static func get_building(building_id: String) -> Dictionary:
	ensure_loaded()
	var normalized_id: String = normalize_building_id(building_id)
	return (_definitions_by_type.get("building", {}) as Dictionary).get(normalized_id, {})


static func get_bot(bot_id: String = "contract:basic_bot") -> Dictionary:
	return get_definition("bot", bot_id)


static func get_player(player_id: String = "contract:player") -> Dictionary:
	return get_definition("player", player_id)


static func get_worldgen(worldgen_id: String = "contract:default_planet") -> Dictionary:
	return get_definition("worldgen", worldgen_id)


static func definitions(definition_type: String) -> Dictionary:
	ensure_loaded()
	return _definitions_by_type.get(definition_type, {})


static func normalize_id(definition_id: String) -> String:
	var trimmed: String = definition_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.contains(":"):
		return trimmed
	return "contract:%s" % [trimmed]


static func normalize_item_id(item_id: String) -> String:
	ensure_loaded()
	var trimmed: String = item_id.strip_edges()
	if _legacy_item_ids.has(trimmed):
		return str(_legacy_item_ids[trimmed])
	return normalize_id(trimmed)


static func normalize_resource_id(resource_id: String) -> String:
	ensure_loaded()
	var trimmed: String = resource_id.strip_edges()
	if _legacy_resource_ids.has(trimmed):
		return str(_legacy_resource_ids[trimmed])
	return normalize_id(trimmed)


static func normalize_building_id(building_id: String) -> String:
	ensure_loaded()
	var trimmed: String = building_id.strip_edges()
	if _legacy_building_ids.has(trimmed):
		return str(_legacy_building_ids[trimmed])
	return normalize_id(trimmed)


static func legacy_item_id(item_id: String) -> String:
	var definition: Dictionary = get_item(item_id)
	return str(definition.get("legacy_id", definition.get("id", item_id).get_slice(":", 1)))


static func legacy_resource_id(resource_id: String) -> String:
	var definition: Dictionary = get_resource(resource_id)
	return str(definition.get("legacy_id", definition.get("id", resource_id).get_slice(":", 1)))


static func legacy_building_id(building_id: String) -> String:
	var definition: Dictionary = get_building(building_id)
	return str(definition.get("legacy_id", definition.get("id", building_id).get_slice(":", 1)))


static func resolve_asset_path(definition: Dictionary, relative_path: String) -> String:
	if relative_path.is_empty() or relative_path.begins_with("res://") or relative_path.begins_with("user://"):
		return relative_path
	return str(definition.get("_asset_root", "res://")).path_join(relative_path)


static func texture_for_item_id(item_id: String) -> Texture2D:
	var definition: Dictionary = get_item(item_id)
	if definition.is_empty():
		return null
	return texture_for_definition_path(definition, str(definition.get("icon", "")))


static func texture_for_definition_path(definition: Dictionary, relative_path: String) -> Texture2D:
	var resolved_path: String = resolve_asset_path(definition, relative_path)
	if resolved_path.is_empty():
		return null
	if _texture_cache.has(resolved_path):
		return _texture_cache[resolved_path] as Texture2D

	var texture := load(resolved_path) as Texture2D
	_texture_cache[resolved_path] = texture
	return texture


static func resolved_resource_texture_paths(resource_id: String) -> Array[String]:
	var definition := get_resource(resource_id)
	var paths: Array[String] = []
	for path_variant: Variant in definition.get("textures", []):
		paths.append(resolve_asset_path(definition, str(path_variant)))
	return paths


static func _build_legacy_indexes() -> void:
	_legacy_item_ids.clear()
	_legacy_item_types.clear()
	_legacy_resource_ids.clear()
	_legacy_building_ids.clear()

	for item: Dictionary in definitions("item").values():
		var id := str(item.get("id", ""))
		var legacy_id := str(item.get("legacy_id", id.get_slice(":", 1)))
		_legacy_item_ids[legacy_id] = id
		if item.has("legacy_item_type"):
			_legacy_item_types[int(item.get("legacy_item_type", -1))] = id

	for resource: Dictionary in definitions("resource").values():
		var id := str(resource.get("id", ""))
		_legacy_resource_ids[str(resource.get("legacy_id", id.get_slice(":", 1)))] = id

	for building: Dictionary in definitions("building").values():
		var id := str(building.get("id", ""))
		_legacy_building_ids[str(building.get("legacy_id", id.get_slice(":", 1)))] = id
