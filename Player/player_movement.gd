extends CharacterBody3D

## MOVEMENT ##
@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 4.5
@export var accel: float = 10.0
@export var decel: float = 12.0
## CAMERA ##
@export var sensitivity: float = 0.002
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
## WEAPON SWAY ##
@export var sway_amount: float = 0.03
@export var sway_speed: float = 8.0
## LEAN ##
@export var lean_distance: float = 0.4
@export var lean_roll: float = 8.0
@export var lean_speed: float = 10.0
## WEAPON ##
@export var aim_range: float = 500.0
## SKELETON ##
@export var skeleton: Skeleton3D

@onready var camera: Camera3D = $Camera3D
@onready var aim_ray: RayCast3D = $Camera3D/AimRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_weapon: WeaponBase = null
var _mouse_delta: Vector2 = Vector2.ZERO
var _sway_targets: Array[Node3D] = []
var _lean_target: float = 0.0
var _spine_bone_idx: int = -1

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	aim_ray.enabled = true
	aim_ray.target_position = Vector3(0, 0, -aim_range)
	aim_ray.collision_mask = 0xFFFFFFFF
	for child in camera.get_children():
		if child is Node3D and child != aim_ray:
			_sway_targets.append(child)
	if skeleton:
		_spine_bone_idx = skeleton.find_bone("mixamorig_Spine")
		if _spine_bone_idx == -1:
			push_warning("PlayerController: could not find bone 'mixamorig_Spine'")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clamp(
			camera.rotation.x - event.relative.y * sensitivity,
			deg_to_rad(pitch_min),
			deg_to_rad(pitch_max)
		)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	_update_sway(delta)
	_update_lean(delta)
	_mouse_delta = Vector2.ZERO

func _update_sway(delta: float) -> void:
	var target_rot := Vector3(
		_mouse_delta.y * sway_amount,
		-_mouse_delta.x * sway_amount,
		_mouse_delta.x * sway_amount * 0.5
	)
	for node in _sway_targets:
		node.rotation = node.rotation.lerp(target_rot, sway_speed * delta)

func _update_lean(delta: float) -> void:
	var lean_input := 0.0
	if Input.is_action_pressed("lean_left"):
		lean_input = -1.0
	elif Input.is_action_pressed("lean_right"):
		lean_input = 1.0
	_lean_target = lean_input

	camera.position.x = lerp(camera.position.x, lean_distance * _lean_target, lean_speed * delta)
	camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(-lean_roll * _lean_target), lean_speed * delta)

	if _spine_bone_idx != -1:
		var target_rot := Quaternion(Basis.from_euler(Vector3(0.0, 0.0, 0.3 * _lean_target)))
		var current := skeleton.get_bone_pose_rotation(_spine_bone_idx)
		skeleton.set_bone_pose_rotation(_spine_bone_idx, current.slerp(target_rot, lean_speed * delta))

func _movement_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)
	move_and_slide()

func _physics_process(delta: float) -> void:
	_movement_process(delta)

func get_aim_point() -> Vector3:
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		return aim_ray.get_collision_point()
	return camera.global_position + \
		   -camera.global_transform.basis.z * aim_range

func equip_weapon(weapon: WeaponBase) -> void:
	current_weapon = weapon
	if weapon is Node3D and weapon.get_parent() == camera and not _sway_targets.has(weapon):
		_sway_targets.append(weapon)

func unequip_weapon() -> void:
	if current_weapon != null and _sway_targets.has(current_weapon):
		_sway_targets.erase(current_weapon)
	current_weapon = null
