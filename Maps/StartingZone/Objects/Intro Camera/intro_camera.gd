extends Camera3D

## Assign these in the inspector
@export var anim_player: AnimationPlayer
@export var animation_name: StringName = "intro"
@export var player: CharacterBody3D

## Flash timing (all in seconds, measured from scene start)
@export var appear_time: float = 1.0     # when it starts becoming visible
@export var fade_in_time: float = 0.3    # how long the fade in takes

@export var disappear_time: float = 2.0  # when it starts becoming invisible
@export var fade_out_time: float = 0.4   # how long the fade out takes

@export var flash_mesh: MeshInstance3D

var _flash_material: ShaderMaterial

func _ready() -> void:
	current = true

	if flash_mesh:
		_flash_material = flash_mesh.get_active_material(0) as ShaderMaterial
		if _flash_material:
			_flash_material.set_shader_parameter("flash_alpha", 0.0)
			flash_mesh.visible = false
			_run_flash()
		else:
			push_warning("flash_mesh has no ShaderMaterial with flash_alpha")

	if not anim_player:
		push_warning("No AnimationPlayer assigned to cutscene camera")
		return

	if player:
		player.set_physics_process(false)
		player.set_process(false)
		player.set_process_unhandled_input(false)
		player.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play(animation_name)

func _run_flash() -> void:
	var tween := create_tween()

	# wait until appear_time, then fade in
	tween.tween_interval(appear_time)
	tween.tween_callback(func():
		flash_mesh.visible = true
	)
	tween.tween_method(_set_flash_alpha, 0.0, 1.0, fade_in_time)

	# wait until disappear_time, then fade out
	# (disappear_time is measured from scene start, so subtract everything already elapsed)
	var elapsed := appear_time + fade_in_time
	var wait_before_fade_out: float = max(0.0, disappear_time - elapsed)
	tween.tween_interval(wait_before_fade_out)
	tween.tween_method(_set_flash_alpha, 1.0, 0.0, fade_out_time)

	tween.tween_callback(func():
		flash_mesh.visible = false
	)

func _set_flash_alpha(value: float) -> void:
	if _flash_material:
		_flash_material.set_shader_parameter("flash_alpha", value)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != animation_name:
		return
	_switch_to_player()

func _switch_to_player() -> void:
	if player:
		var cam := player.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.current = true
		else:
			push_warning("Couldn't find Camera3D under player")
		player.set_physics_process(true)
		player.set_process(true)
		player.set_process_unhandled_input(true)
		player.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
