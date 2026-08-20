class_name HarvestCommandIndicator
extends Node2D

const DURATION_SECONDS: float = 0.7
const START_RADIUS: float = 13.0
const END_RADIUS: float = 31.0

var _elapsed_seconds: float = 0.0


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	if _elapsed_seconds >= DURATION_SECONDS:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed_seconds / DURATION_SECONDS, 0.0, 1.0)
	var alpha := 1.0 - progress
	var radius := lerpf(START_RADIUS, END_RADIUS, progress)
	var color := Color(0.24, 0.86, 1.0, alpha)
	var accent := Color(0.92, 0.98, 1.0, alpha * 0.85)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 3.0)
	draw_arc(Vector2.ZERO, START_RADIUS, 0.0, TAU, 64, accent, 1.5)
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), accent, 1.5)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), accent, 1.5)
