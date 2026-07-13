extends Node3D
## Makes this node levitate with a smooth bob plus a subtle off-axis
## wobble -- a gentle back-and-forth tilt, not a continuous spin. Reads
## as an object unsettled in the air, like it's barely being held up
## rather than mounted and spinning.

@export var bob_height: float = 0.15       # how far up/down it drifts, in meters
@export var bob_speed: float = 1.0         # cycles per ~6 seconds; higher = faster bob
@export var sway_amount: float = 0.0       # optional slight horizontal drift; 0 = pure vertical bob
@export var sway_speed: float = 0.6

@export var wobble_amount_deg: float = 6.0 # max tilt in degrees, each axis
@export var wobble_speed_x: float = 0.7
@export var wobble_speed_z: float = 0.9    # slightly different from X speed so it doesn't tilt in a flat repeating loop

@export var randomize_phase: bool = true

var _base_position: Vector3
var _base_rotation: Quaternion
var _phase_offset: float = 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = quaternion
	if randomize_phase:
		_phase_offset = randf() * TAU


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase_offset

	var vertical_offset := sin(t * bob_speed) * bob_height
	var sway_offset := Vector3(
		sin(t * sway_speed) * sway_amount,
		0.0,
		cos(t * sway_speed * 0.7) * sway_amount
	)
	position = _base_position + Vector3(0.0, vertical_offset, 0.0) + sway_offset

	# gentle tilt on two axes, out of phase with each other so the wobble
	# traces a slow, irregular figure instead of a flat back-and-forth
	var tilt_x := sin(t * wobble_speed_x) * deg_to_rad(wobble_amount_deg)
	var tilt_z := cos(t * wobble_speed_z) * deg_to_rad(wobble_amount_deg)

	var wobble_rot := Quaternion(Vector3.RIGHT, tilt_x) * Quaternion(Vector3.FORWARD, tilt_z)
	quaternion = _base_rotation * wobble_rot
