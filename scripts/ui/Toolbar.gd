class_name Toolbar
extends Control

signal building_selected(building_scene: PackedScene)
signal run_toggled(running: bool)
signal add_bot_requested()
signal grid_toggled(visible: bool)

@export var conveyor_scene: PackedScene
@export var miner_scene: PackedScene
@export var furnace_scene: PackedScene
@export var exchanger_scene: PackedScene
@export var chest_scene: PackedScene

@onready var _conveyor_button: Button = %ConveyorButton
@onready var _miner_button: Button = %MinerButton
@onready var _furnace_button: Button = %FurnaceButton
@onready var _exchanger_button: Button = %ExchangerButton
@onready var _chest_button: Button = %ChestButton
@onready var _add_bot_button: Button = %AddBotButton
@onready var _run_button: Button = %RunButton
@onready var _grid_check_box: CheckBox = %GridCheckBox


func _ready() -> void:
	_conveyor_button.pressed.connect(_on_conveyor_button_pressed)
	_miner_button.pressed.connect(_on_miner_button_pressed)
	_furnace_button.pressed.connect(_on_furnace_button_pressed)
	_exchanger_button.pressed.connect(_on_exchanger_button_pressed)
	_chest_button.pressed.connect(_on_chest_button_pressed)
	_add_bot_button.pressed.connect(_on_add_bot_button_pressed)
	_run_button.toggled.connect(_on_run_button_toggled)
	_grid_check_box.toggled.connect(_on_grid_check_box_toggled)


func _on_conveyor_button_pressed() -> void:
	building_selected.emit(conveyor_scene)


func _on_miner_button_pressed() -> void:
	building_selected.emit(miner_scene)


func _on_furnace_button_pressed() -> void:
	building_selected.emit(furnace_scene)


func _on_exchanger_button_pressed() -> void:
	building_selected.emit(exchanger_scene)


func _on_chest_button_pressed() -> void:
	building_selected.emit(chest_scene)


func _on_add_bot_button_pressed() -> void:
	add_bot_requested.emit()


func _on_run_button_toggled(running: bool) -> void:
	_run_button.text = "Pause" if running else "Run"
	run_toggled.emit(running)


func set_running_visual(running: bool) -> void:
	_run_button.set_pressed_no_signal(running)
	_run_button.text = "Pause" if running else "Run"


func _on_grid_check_box_toggled(visible: bool) -> void:
	grid_toggled.emit(visible)
