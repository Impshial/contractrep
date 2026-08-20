class_name GameDiagnostics
extends Node

const DIAGNOSTICS_LOG_PATH: String = "user://diagnostics.log"
const HEARTBEAT_SECONDS: float = 10.0
const FRAME_STALL_THRESHOLD_MS: int = 500
const WATCHDOG_HANG_THRESHOLD_MS: int = 2000
const WATCHDOG_REPORT_COOLDOWN_MS: int = 5000
const WATCHDOG_POLL_MS: int = 500
const MAX_DIAGNOSTICS_LOG_CHARS: int = 500000

var _board: Board
var _factory_simulation: FactorySimulation
var _robot_controller: RobotController
var _watchdog_thread := Thread.new()
var _watchdog_mutex := Mutex.new()
var _file_mutex := Mutex.new()
var _watchdog_should_stop: bool = false
var _last_main_thread_tick_msec: int = 0
var _last_snapshot: String = ""
var _last_process_tick_msec: int = 0
var _heartbeat_elapsed: float = 0.0
var _max_frame_gap_msec: int = 0
var _measured_fps: float = 0.0
var _fps_sample_start_usec: int = 0
var _fps_sample_frames: int = 0


func configure(board: Board, factory_simulation: FactorySimulation, robot_controller: RobotController) -> void:
	_board = board
	_factory_simulation = factory_simulation
	_robot_controller = robot_controller


func _ready() -> void:
	_last_process_tick_msec = Time.get_ticks_msec()
	_fps_sample_start_usec = Time.get_ticks_usec()
	_last_main_thread_tick_msec = _last_process_tick_msec
	_last_snapshot = _make_snapshot()
	_log("DIAGNOSTICS_START file=%s" % [ProjectSettings.globalize_path(DIAGNOSTICS_LOG_PATH)])
	_watchdog_thread.start(_watchdog_loop)


func _exit_tree() -> void:
	_watchdog_mutex.lock()
	_watchdog_should_stop = true
	_watchdog_mutex.unlock()

	if _watchdog_thread.is_started():
		_watchdog_thread.wait_to_finish()

	_log("DIAGNOSTICS_STOP")


func _process(delta: float) -> void:
	_update_measured_fps()
	var now_msec := Time.get_ticks_msec()
	var frame_gap_msec := now_msec - _last_process_tick_msec
	_last_process_tick_msec = now_msec
	_max_frame_gap_msec = maxi(_max_frame_gap_msec, frame_gap_msec)

	if frame_gap_msec >= FRAME_STALL_THRESHOLD_MS:
		_log("FRAME_STALL gap_ms=%d delta_ms=%d %s" % [
			frame_gap_msec,
			roundi(delta * 1000.0),
			_make_snapshot(),
		])

	_heartbeat_elapsed += delta
	if _heartbeat_elapsed >= HEARTBEAT_SECONDS:
		_heartbeat_elapsed = 0.0
		_last_snapshot = _make_snapshot()
		_log("HEARTBEAT max_frame_gap_ms=%d %s" % [_max_frame_gap_msec, _last_snapshot])
		_max_frame_gap_msec = 0

	_update_watchdog_heartbeat(now_msec)


func _update_watchdog_heartbeat(now_msec: int) -> void:
	_watchdog_mutex.lock()
	_last_main_thread_tick_msec = now_msec
	_watchdog_mutex.unlock()


func _watchdog_loop() -> void:
	var last_watchdog_report_msec := 0

	while true:
		OS.delay_msec(WATCHDOG_POLL_MS)

		_watchdog_mutex.lock()
		var should_stop := _watchdog_should_stop
		var last_tick_msec := _last_main_thread_tick_msec
		var snapshot := _last_snapshot
		_watchdog_mutex.unlock()

		if should_stop:
			break

		var now_msec := Time.get_ticks_msec()
		var unresponsive_msec := now_msec - last_tick_msec
		if unresponsive_msec < WATCHDOG_HANG_THRESHOLD_MS:
			continue
		if now_msec - last_watchdog_report_msec < WATCHDOG_REPORT_COOLDOWN_MS:
			continue

		last_watchdog_report_msec = now_msec
		_append_diagnostics_line(
			_format_log_line("WATCHDOG_HANG main_thread_unresponsive_ms=%d %s" % [unresponsive_msec, snapshot])
		)


func _make_snapshot() -> String:
	var simulation_running := false
	var conveyor_count := 0
	var miner_count := 0
	var furnace_count := 0
	var exchanger_count := 0
	var factory_item_count := 0
	if _factory_simulation != null:
		simulation_running = _factory_simulation.is_running
		conveyor_count = _factory_simulation.get_conveyor_count()
		miner_count = _factory_simulation.get_miner_count()
		furnace_count = _factory_simulation.get_furnace_count()
		exchanger_count = _factory_simulation.get_exchanger_count()
		factory_item_count = _factory_simulation.get_factory_item_node_count()

	var building_count := _board.get_building_count() if _board != null else 0
	var robot_count := _robot_controller.get_robot_count() if _robot_controller != null else 0
	var selected_robot_count := _robot_controller.get_selected_robot_count() if _robot_controller != null else 0

	return "actual_fps=%.1f engine_fps=%d sim_running=%s buildings=%d conveyors=%d miners=%d furnaces=%d exchangers=%d items=%d robots=%d selected_robots=%d" % [
		_measured_fps,
		roundi(Performance.get_monitor(Performance.TIME_FPS)),
		str(simulation_running),
		building_count,
		conveyor_count,
		miner_count,
		furnace_count,
		exchanger_count,
		factory_item_count,
		robot_count,
		selected_robot_count,
	]


func _update_measured_fps() -> void:
	if _fps_sample_start_usec <= 0:
		_fps_sample_start_usec = Time.get_ticks_usec()

	_fps_sample_frames += 1
	var elapsed_seconds := float(Time.get_ticks_usec() - _fps_sample_start_usec) / 1000000.0
	if elapsed_seconds < 0.25:
		return

	_measured_fps = float(_fps_sample_frames) / maxf(elapsed_seconds, 0.0001)
	_fps_sample_start_usec = Time.get_ticks_usec()
	_fps_sample_frames = 0


func _log(message: String) -> void:
	var line := _format_log_line(message)
	print(line)
	_append_diagnostics_line(line)


func _format_log_line(message: String) -> String:
	return "[DIAGNOSTICS %s] %s" % [
		Time.get_datetime_string_from_system(false, true),
		message,
	]


func _append_diagnostics_line(line: String) -> void:
	_file_mutex.lock()

	var previous_text := ""
	if FileAccess.file_exists(DIAGNOSTICS_LOG_PATH):
		var read_file := FileAccess.open(DIAGNOSTICS_LOG_PATH, FileAccess.READ)
		if read_file != null:
			previous_text = read_file.get_as_text()

	if previous_text.length() > MAX_DIAGNOSTICS_LOG_CHARS:
		previous_text = previous_text.right(MAX_DIAGNOSTICS_LOG_CHARS)

	var file := FileAccess.open(DIAGNOSTICS_LOG_PATH, FileAccess.WRITE)
	if file == null:
		_file_mutex.unlock()
		return

	if not previous_text.is_empty():
		file.store_string(previous_text)
		if not previous_text.ends_with("\n"):
			file.store_line("")

	file.store_line(line)
	file.flush()
	_file_mutex.unlock()
