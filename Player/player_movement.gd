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

## WEAPON ##
@export var aim_range: float = 500.0

@onready var camera: Camera3D = $Camera3D
@onready var aim_ray: RayCast3D = $Camera3D/AimRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_weapon: WeaponBase = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Configure the raycast
	aim_ray.enabled = true
	aim_ray.target_position = Vector3(0, 0, -aim_range)
	aim_ray.collision_mask = 0xFFFFFFFF  # hits everything — tighten per your layers


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
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


# ─────────────────────────────────────────────
#  AIM
# ─────────────────────────────────────────────
func get_aim_point() -> Vector3:
	if aim_ray.is_colliding():
		return aim_ray.get_collision_point()
	# No hit — return the end of the ray in world space
	return aim_ray.global_position + \
		   -camera.global_transform.basis.z * aim_range


# ─────────────────────────────────────────────
#  WEAPON MANAGEMENT
# ─────────────────────────────────────────────
func equip_weapon(weapon: WeaponBase) -> void:
	current_weapon = weapon
