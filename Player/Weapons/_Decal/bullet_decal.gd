extends MeshInstance3D
class_name BulletDecal

@export var lifetime: float = 10.0
@export var fade_time: float = 1.0

func _ready() -> void:
	var mat := get_active_material(0) as StandardMaterial3D
	if mat:
		set_surface_override_material(0, mat.duplicate())
	await get_tree().create_timer(lifetime).timeout
	_fade_out()

func _fade_out() -> void:
	var tween := create_tween()
	var mat := get_active_material(0) as StandardMaterial3D
	if mat:
		tween.tween_method(func(v: float):
			mat.albedo_color.a = v
		, 1.0, 0.0, fade_time)
	tween.tween_callback(queue_free)
