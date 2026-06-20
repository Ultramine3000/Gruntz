extends Node
class_name PlayerAnimation
# Run this to clean glb player model.
# Unused upper and lower tracks wil lstill be 'keyed' on import of GLB so this cleaner get rid of them.
@export var skeleton: Skeleton3D
@export var upper_anim_blend_time: float = 0.2
@onready var anim_player: AnimationPlayer = $"../3rdperson_player_model/LowerAnimationPlayer"
@onready var upper_anim_player: AnimationPlayer = $"../3rdperson_player_model/UpperAnimationPlayer"
@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = _player.get_node("Camera3D")
var _weapon_type: String = "Unarmed"
var _spine_bone_idx: int = -1
var _equipped_weapon: WeaponBase = null
var _third_person_muzzle_flash: Node3D = null
var _is_reloading: bool = false

const FIRST_PERSON_LAYER := 1 << 1   # layer 2
const THIRD_PERSON_LAYER := 1 << 2   # layer 3
const SPINE_PITCH_OFFSET_DEGREES := -8.00


func _ready() -> void:
	upper_anim_player.playback_default_blend_time = upper_anim_blend_time

	if skeleton:
		_spine_bone_idx = skeleton.find_bone("mixamorig_Spine")
		if _spine_bone_idx == -1:
			push_warning("PlayerAnimation: could not find bone 'mixamorig_Spine'")

	for child in _camera.get_children():
		if child is WeaponBase:
			_set_layer_recursive(child, FIRST_PERSON_LAYER)
			set_weapon_type(child.weapon_type)
			update_third_person_model()
			break

	# This camera sees its own 1st-person rig, not its own 3rd-person model.
	_camera.cull_mask |= FIRST_PERSON_LAYER
	_camera.cull_mask &= ~THIRD_PERSON_LAYER


func _process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_lower(input_dir)
	_update_spine(delta)


func _update_lower(input_dir: Vector2) -> void:
	if not _player.is_on_floor():
		_play_lower("Jump")
		return

	var is_moving := input_dir.length() > 0.1
	var is_crouching := Input.is_action_pressed("crouch")
	var is_sprinting := Input.is_action_pressed("sprint") and is_moving and not is_crouching
	var lower_anim: String

	if is_crouching:
		if not is_moving:
			lower_anim = "CrouchIdle"
		elif absf(input_dir.x) > absf(input_dir.y):
			lower_anim = "CrouchMoveLeft" if input_dir.x < 0.0 else "CrouchMoveRight"
		else:
			lower_anim = "CrouchMoveBack" if input_dir.y > 0.0 else "CrouchMoveForward"
	elif not is_moving:
		lower_anim = "Idle"
	elif is_sprinting:
		lower_anim = "Sprint"
	else:
		if absf(input_dir.x) > absf(input_dir.y):
			lower_anim = "MoveLeft" if input_dir.x < 0.0 else "MoveRight"
		else:
			lower_anim = "MoveBack" if input_dir.y > 0.0 else "MoveForward"
	_play_lower(lower_anim)


func _play_lower(anim_name: String) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _update_spine(delta: float) -> void:
	if _spine_bone_idx == -1:
		return
	var combined := Quaternion(Basis.from_euler(Vector3(
	-_camera.rotation.x * 1.6 + deg_to_rad(SPINE_PITCH_OFFSET_DEGREES),
	0.0,
	1.2 * _player._lean_target
)))
	var current := skeleton.get_bone_pose_rotation(_spine_bone_idx)
	skeleton.set_bone_pose_rotation(_spine_bone_idx, current.slerp(combined, 10.0 * delta))


func update_third_person_model() -> void:
	var player := _player
	if not player:
		return

	var camera := _camera
	if not camera:
		push_warning("PlayerAnimation: no Camera3D found under Player")
		return

	var equipped_weapon: Node = null
	for child in camera.get_children():
		if child is WeaponBase:
			equipped_weapon = child
			break

	if not equipped_weapon:
		push_warning("PlayerAnimation: no equipped weapon found under Camera3D")
		return

	# Disconnect from previous weapon's signals
	if _equipped_weapon:
		_disconnect_weapon_signals(_equipped_weapon)

	_equipped_weapon = equipped_weapon
	_third_person_muzzle_flash = null
	_is_reloading = false

	var weapon_name_to_match: String = equipped_weapon.weapon_name
	var bone_attachment_name: String = "Rifle" if equipped_weapon.weapon_type == "Rifle" else "Pistol"

	var player_skeleton := skeleton
	if not player_skeleton:
		push_warning("PlayerAnimation: no Skeleton3D assigned")
		return

	var bone_attachment := player_skeleton.get_node_or_null(bone_attachment_name)
	if not bone_attachment:
		push_warning("PlayerAnimation: no BoneAttachment3D named '%s' found" % bone_attachment_name)
		return

	var found: bool = false
	for child in bone_attachment.get_children():
		if child.name == weapon_name_to_match:
			child.visible = true
			found = true

			# Look for a muzzle flash child on this weapon mesh
			for sub_child in child.get_children():
				if sub_child.name == "Muzzle_Flash" and sub_child is Node3D:
					_third_person_muzzle_flash = sub_child
					_third_person_muzzle_flash.visible = false
					_set_layer_recursive(_third_person_muzzle_flash, THIRD_PERSON_LAYER)
		else:
			child.visible = false

	if not found:
		print("no 3rd person player weapon model found for ", weapon_name_to_match)
		return

	_connect_weapon_signals(equipped_weapon)


func _connect_weapon_signals(weapon: WeaponBase) -> void:
	weapon.weapon_fired.connect(_on_weapon_fired)
	weapon.reload_started.connect(_on_reload_started)
	weapon.weapon_reloaded.connect(_on_reload_finished)


func _disconnect_weapon_signals(weapon: WeaponBase) -> void:
	if weapon.weapon_fired.is_connected(_on_weapon_fired):
		weapon.weapon_fired.disconnect(_on_weapon_fired)
	if weapon.reload_started.is_connected(_on_reload_started):
		weapon.reload_started.disconnect(_on_reload_started)
	if weapon.weapon_reloaded.is_connected(_on_reload_finished):
		weapon.weapon_reloaded.disconnect(_on_reload_finished)


func _on_weapon_fired(weapon: WeaponBase) -> void:
	if not _third_person_muzzle_flash:
		return
	_third_person_muzzle_flash.visible = true
	_third_person_muzzle_flash.rotation_degrees.z = randf_range(0.0, 360.0)
	get_tree().create_timer(0.05).timeout.connect(func(): _third_person_muzzle_flash.visible = false)

	_spawn_tracer_and_decal(weapon)


func _on_reload_started(weapon: WeaponBase) -> void:
	_is_reloading = true
	if upper_anim_player.has_animation("Reload"):
		upper_anim_player.play("Reload")
	else:
		push_warning("PlayerAnimation: missing reload animation 'Reload'")


func _on_reload_finished(weapon: WeaponBase) -> void:
	_is_reloading = false
	_play_upper_anim()


func _spawn_tracer_and_decal(weapon: WeaponBase) -> void:
	var player := _player
	if not player:
		return

	var aim_point: Vector3 = player.get_aim_point() if player else \
			_third_person_muzzle_flash.global_position + _third_person_muzzle_flash.global_transform.basis.z * -500.0

	if weapon.tracer_scene and _third_person_muzzle_flash:
		var from := _third_person_muzzle_flash.global_position
		var tracer = weapon.tracer_scene.instantiate()
		get_tree().current_scene.add_child(tracer)
		_set_layer_recursive(tracer, THIRD_PERSON_LAYER)
		tracer.init(from, aim_point)

	if weapon.decal_scene and player:
		var ray: RayCast3D = player.aim_ray
		if ray.is_colliding():
			var hit_point: Vector3 = ray.get_collision_point()
			var normal: Vector3 = ray.get_collision_normal()
			var decal := weapon.decal_scene.instantiate() as MeshInstance3D
			get_tree().current_scene.add_child(decal)
			decal.global_position = hit_point + normal * 0.02
			var up: Vector3 = Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
			var right: Vector3 = up.cross(normal).normalized()
			var up_corrected: Vector3 = normal.cross(right).normalized()
			decal.global_transform.basis = Basis(right, up_corrected, normal)
			_set_layer_recursive(decal, THIRD_PERSON_LAYER)


func _set_layer_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_layer_recursive(child, layer)


func set_weapon_type(type: String) -> void:
	_weapon_type = type
	_play_upper_anim()


func _play_upper_anim() -> void:
	match _weapon_type:
		"Rifle":  upper_anim_player.play("RifleUpperIdle")
		"Pistol": upper_anim_player.play("PistolUpperIdle")
		_:        upper_anim_player.play("UnarmedUpperIdle")
