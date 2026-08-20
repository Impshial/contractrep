class_name LaunchOptions
extends RefCounted

const ACTION_NONE: String = ""
const ACTION_NEW_GAME: String = "new_game"
const ACTION_LOAD_GAME: String = "load_game"

static var action: String = ACTION_NONE
static var save_name: String = ""


static func request_new_game() -> void:
	action = ACTION_NEW_GAME
	save_name = ""


static func request_load_game(new_save_name: String) -> void:
	action = ACTION_LOAD_GAME
	save_name = new_save_name


static func clear() -> void:
	action = ACTION_NONE
	save_name = ""
