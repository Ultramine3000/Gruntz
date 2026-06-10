extends Node3D
class_name BulletTracer

@export var speed: float = 100.0
@export var max_lifetime: float = 10.0

var target: Vector3 = Vector3.ZERO
var _alive: float = 0.0
var _done: bool = false


func init(from: Vector3, to: Vector3) -> void:
	global_position = from
	target = to
	look_at(to, Vector3.UP)


func _process(delta: float) -> void:
	if _done:
		return

	_alive += delta
	if _alive >= max_lifetime:
		queue_free()
		return

	var dir := target - global_position
	if dir.length() < 0.1:
		queue_free()
		return

	global_position += dir.normalized() * speed * delta
