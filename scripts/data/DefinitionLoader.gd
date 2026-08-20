class_name DefinitionLoader
extends RefCounted

const BASE_PACK_PATH: String = "res://data/contract"
const USER_MODS_PATH: String = "user://mods"
const TYPE_FOLDERS: Dictionary = {
	"items": "item",
	"resources": "resource",
	"buildings": "building",
	"bots": "bot",
	"players": "player",
	"recipes": "recipe",
	"terrain": "terrain",
	"worldgen": "worldgen",
}

var validator := DefinitionValidator.new()
var definitions_by_type: Dictionary = {}
var content_packs: Array[Dictionary] = []
var patches: Array[Dictionary] = []


func load_all() -> bool:
	definitions_by_type.clear()
	content_packs.clear()
	patches.clear()
	for definition_type: String in DefinitionValidator.DEFINITION_TYPES:
		definitions_by_type[definition_type] = {}

	print("CONTENT_LOAD_START")
	_load_pack(BASE_PACK_PATH, true)
	_discover_user_mods()
	_apply_patches()
	validator.validate_references(definitions_by_type)

	var summary := "DEFINITIONS_LOADED items=%d resources=%d buildings=%d bots=%d recipes=%d terrain=%d worldgen=%d packs=%d" % [
		definitions_by_type["item"].size(),
		definitions_by_type["resource"].size(),
		definitions_by_type["building"].size(),
		definitions_by_type["bot"].size(),
		definitions_by_type["recipe"].size(),
		definitions_by_type["terrain"].size(),
		definitions_by_type["worldgen"].size(),
		content_packs.size(),
	]
	print(summary)

	if validator.has_errors():
		print("CONTENT_LOAD_ERROR count=%d" % [validator.errors.size()])
		return false

	print("CONTENT_LOAD_COMPLETE")
	return true


func _discover_user_mods() -> void:
	var mods_dir := DirAccess.open(USER_MODS_PATH)
	if mods_dir == null:
		return

	mods_dir.list_dir_begin()
	var entry := mods_dir.get_next()
	while not entry.is_empty():
		if mods_dir.current_is_dir() and not entry.begins_with("."):
			_load_pack(USER_MODS_PATH.path_join(entry), false)
		entry = mods_dir.get_next()
	mods_dir.list_dir_end()


func _load_pack(pack_path: String, required: bool) -> void:
	var manifest_path := pack_path.path_join("manifest.json")
	var manifest := _read_json_object(manifest_path, required)
	if manifest.is_empty():
		return
	if not validator.validate_manifest(manifest, manifest_path):
		return

	var pack_id := str(manifest.get("id", ""))
	for dependency: Variant in manifest.get("dependencies", []):
		if not _has_content_pack(str(dependency)):
			validator.add_error("%s: content pack '%s' is missing dependency '%s'." % [manifest_path, pack_id, dependency])
			return

	var asset_root := str(manifest.get("asset_root", pack_path))
	if not asset_root.begins_with("res://") and not asset_root.begins_with("user://"):
		asset_root = pack_path.path_join(asset_root)

	var pack_info := manifest.duplicate(true)
	pack_info["root_path"] = pack_path
	pack_info["asset_root"] = asset_root
	content_packs.append(pack_info)

	for folder_name: String in TYPE_FOLDERS.keys():
		_load_definition_folder(pack_path.path_join(folder_name), TYPE_FOLDERS[folder_name], pack_info)
	_load_patch_folder(pack_path.path_join("patches"), pack_info)
	print("CONTENT_PACK_LOADED id=%s version=%s" % [pack_id, manifest.get("version", "")])


func _load_definition_folder(folder_path: String, definition_type: String, pack_info: Dictionary) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_definition_file(folder_path.path_join(file_name), definition_type, pack_info)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_definition_file(file_path: String, definition_type: String, pack_info: Dictionary) -> void:
	var definition := _read_json_object(file_path, true)
	if definition.is_empty():
		return
	if not validator.validate_definition(definition, file_path, definition_type, str(pack_info.get("id", ""))):
		return

	definition["_source_file"] = file_path
	definition["_content_pack"] = str(pack_info.get("id", ""))
	definition["_asset_root"] = str(pack_info.get("asset_root", ""))
	var definition_id := str(definition.get("id", ""))
	var registry: Dictionary = definitions_by_type[definition_type]
	if registry.has(definition_id) and not bool(definition.get("override", false)):
		validator.add_error("%s: duplicate definition id '%s'. Add explicit override=true to replace it." % [file_path, definition_id])
		return

	registry[definition_id] = definition


func _load_patch_folder(folder_path: String, pack_info: Dictionary) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path := folder_path.path_join(file_name)
			var patch := _read_json_object(file_path, true)
			if not patch.is_empty():
				patch["_source_file"] = file_path
				patch["_content_pack"] = str(pack_info.get("id", ""))
				patches.append(patch)
		file_name = dir.get_next()
	dir.list_dir_end()


func _apply_patches() -> void:
	for patch: Dictionary in patches:
		if str(patch.get("type", "")) != "patch":
			validator.add_error("%s: patch file must have type='patch'." % [patch.get("_source_file", "")])
			continue

		var target_id := str(patch.get("target", ""))
		var target := _find_definition(target_id)
		if target.is_empty():
			validator.add_error("%s: patch target '%s' was not found." % [patch.get("_source_file", ""), target_id])
			continue

		_merge_dictionary(target, patch.get("changes", {}))


func _find_definition(definition_id: String) -> Dictionary:
	for definition_type: String in definitions_by_type.keys():
		var registry: Dictionary = definitions_by_type[definition_type]
		if registry.has(definition_id):
			return registry[definition_id]
	return {}


func _merge_dictionary(target: Dictionary, changes: Dictionary) -> void:
	for key: Variant in changes.keys():
		if target.has(key) and target[key] is Dictionary and changes[key] is Dictionary:
			_merge_dictionary(target[key], changes[key])
		else:
			target[key] = changes[key]


func _read_json_object(file_path: String, required: bool) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		if required:
			validator.add_error("Missing JSON file: %s" % [file_path])
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		validator.add_error("Could not open JSON file: %s" % [file_path])
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		validator.add_error("Malformed JSON object: %s" % [file_path])
		return {}

	return parsed


func _has_content_pack(pack_id: String) -> bool:
	for pack: Dictionary in content_packs:
		if str(pack.get("id", "")) == pack_id:
			return true
	return false
