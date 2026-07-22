extends Node3D
# Flies through a list of waypoints in order, then lands at landing_target.
# Assumes -Z is forward (Godot default forward).

@export var waypoints: Array[Node3D] = []
@export var landing_target: Node3D
@export var waypoint_radius: float = 2.0   # how close counts as "reached" a waypoint

@export var speed: float = 10.0            # units/sec while flying between waypoints
@export var turn_speed_deg: float = 90.0   # deg/sec, how fast it turns to face travel dir

@export_group("Landing")
@export var landing_speed: float = 3.0        # horizontal approach speed while landing
@export var descent_speed: float = 2.0        # vertical descent speed while landing
@export var landing_radius: float = 1.5       # horizontal distance that counts as "over" the pad
@export var landed_height_threshold: float = 0.2  # how close to target height counts as landed

@export_group("Debug")
@export var debug_loop: bool = true   # restart the sequence after landing, for debugging
@export var debug_loop_delay: float = 1.0

signal waypoint_reached(index: int)
signal landed

enum Mode { TRAVEL, LANDING, LANDED }
var _mode: Mode = Mode.TRAVEL
var _waypoint_index: int = 0
var _start_position: Vector3
var _start_basis: Basis

func _ready() -> void:
	_start_position = global_position
	if waypoints.size() > 0 and waypoints[0] != null:
		look_at(waypoints[0].global_position, Vector3.UP)
	_start_basis = global_transform.basis

func _process(delta: float) -> void:
	match _mode:
		Mode.TRAVEL:
			_process_travel(delta)
		Mode.LANDING:
			_process_landing(delta)
		Mode.LANDED:
			pass

# --- fly through waypoints in order ---
func _process_travel(delta: float) -> void:
	if _waypoint_index >= waypoints.size():
		_start_landing()
		return

	var target := waypoints[_waypoint_index]
	if target == null:
		_waypoint_index += 1
		return

	var target_pos := target.global_position
	var dist := global_position.distance_to(target_pos)

	if dist <= waypoint_radius:
		emit_signal("waypoint_reached", _waypoint_index)
		_waypoint_index += 1
		return

	var move_dir := (target_pos - global_position).normalized()
	global_position += move_dir * speed * delta
	_face_direction(move_dir, delta)

# --- approach and descend onto the landing spot ---
func _start_landing() -> void:
	_mode = Mode.LANDING

func _process_landing(delta: float) -> void:
	if landing_target == null:
		_land()
		return

	var target_pos := landing_target.global_position
	var flat_offset := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	var flat_dist := flat_offset.length()

	if flat_dist > 0.01:
		var move_dir := flat_offset.normalized()
		global_position += move_dir * landing_speed * delta
		_face_direction(move_dir, delta)

	var height_diff := global_position.y - target_pos.y
	if height_diff > landed_height_threshold:
		global_position.y -= descent_speed * delta

	if flat_dist <= landing_radius and height_diff <= landed_height_threshold:
		_land()

func _land() -> void:
	_mode = Mode.LANDED
	if landing_target != null:
		global_position = landing_target.global_position
	emit_signal("landed")

	if debug_loop:
		await get_tree().create_timer(debug_loop_delay).timeout
		_reset_sequence()

func _reset_sequence() -> void:
	global_position = _start_position
	global_transform.basis = _start_basis
	_waypoint_index = 0
	_mode = Mode.TRAVEL

func _face_direction(move_dir: Vector3, delta: float) -> void:
	var desired_transform := global_transform.looking_at(global_position + move_dir, Vector3.UP)
	var t: float = clamp(deg_to_rad(turn_speed_deg) * delta, 0.0, 1.0)
	global_transform.basis = global_transform.basis.slerp(desired_transform.basis, t)
