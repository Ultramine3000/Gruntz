extends Node3D

# Attach to the propeller/rotor mesh. Spins it around its local Y axis.

@export var rotation_speed_deg: float = 720.0  # degrees/sec
@export var axis: Vector3 = Vector3.UP         # change to Vector3.FORWARD etc if needed

func _process(delta: float) -> void:
	rotate(axis, deg_to_rad(rotation_speed_deg) * delta)
