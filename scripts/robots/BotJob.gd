class_name BotJob
extends RefCounted

enum JobType { NONE, HARVEST }

var job_type: int = JobType.NONE
var resource_id: String = ""
var inventory_item_id: String = ""
var target_cell: Vector2i = RobotNavigation.INVALID_CELL
var last_target_cell: Vector2i = RobotNavigation.INVALID_CELL
var target_deposit: ResourceDeposit


static func harvest(deposit: ResourceDeposit, cell: Vector2i) -> BotJob:
	var job := BotJob.new()
	job.job_type = JobType.HARVEST
	job.update_harvest_target(deposit, cell)
	return job


func update_harvest_target(deposit: ResourceDeposit, cell: Vector2i) -> void:
	target_deposit = deposit
	target_cell = cell
	last_target_cell = cell
	if deposit == null:
		return

	resource_id = deposit.resource_id
	inventory_item_id = deposit.inventory_item_id()


func clear_target() -> void:
	target_deposit = null
	target_cell = RobotNavigation.INVALID_CELL


func is_harvest_job() -> bool:
	return job_type == JobType.HARVEST


func designation_display_name() -> String:
	if not is_harvest_job():
		return "Idle"

	match inventory_item_id:
		"wood":
			return "Wood Cutter"
		"iron_ore", "copper_ore", "coal", "stone":
			return "Miner"
		_:
			return "Harvester"


func target_display_name() -> String:
	if target_deposit != null:
		return target_deposit.resource_name()

	if not resource_id.is_empty():
		return str(GameDefinitions.resource_definition(resource_id).get("resource_name", resource_id.capitalize()))

	return ""
