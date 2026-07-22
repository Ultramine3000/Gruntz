extends Node3D
@export var player: Node3D
@export var skeleton_path: NodePath
@export var bone_name: String = "Head"
@export var detection_range: float = 6.0
@export var turn_speed: float = 5.0
@export var blend_in_speed: float = 4.0
@export var blend_out_speed: float = 4.0
@export var max_angle_degrees: float = 80.0
## Which local bone axis points "out of the face"
@export_enum("X", "Y", "Z", "-X", "-Y", "-Z") var forward_axis: String = "Z"
@export var debug_print_axes: bool = false
var skeleton: Skeleton3D
var bone_idx: int = -1
var current_weight: float = 0.0
var current_yaw: float = 0.0
func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	skeleton = get_node(skeleton_path) as Skeleton3D
	if skeleton:
		bone_idx = skeleton.find_bone(bone_name)
		if bone_idx == -1:
			push_warning("Bone '%s' not found on skeleton" % bone_name)
		elif debug_print_axes:
			var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
			print("Bone '%s' WORLD axes:" % bone_name)
			print("  X: ", world_pose.basis.x)
			print("  Y: ", world_pose.basis.y)
			print("  Z: ", world_pose.basis.z)
	else:
		push_warning("Skeleton3D not found at path: %s" % skeleton_path)
func _get_bone_forward(basis: Basis) -> Vector3:
	match forward_axis:
		"X": return basis.x
		"Y": return basis.y
		"Z": return basis.z
		"-X": return -basis.x
		"-Y": return -basis.y
		"-Z": return -basis.z
	return basis.z
func _process(delta: float) -> void:
	if not player or not skeleton or bone_idx == -1:
		return
	var dist := global_position.distance_to(player.global_position)
	var in_range := dist <= detection_range
	var local_base_pose := skeleton.get_bone_global_pose_no_override(bone_idx)
	var skel_transform := skeleton.global_transform
	var world_base_pose := skel_transform * local_base_pose
	if in_range:
		var to_player := player.global_position - world_base_pose.origin
		to_player.y = 0.0
		if to_player.length() < 0.001:
			return
		to_player = to_player.normalized()
		var world_forward := _get_bone_forward(world_base_pose.basis)
		world_forward.y = 0.0
		if world_forward.length() < 0.001:
			push_warning("forward_axis is near-vertical, pick a different axis")
			return
		world_forward = world_forward.normalized()
		var target_yaw := world_forward.signed_angle_to(to_player, Vector3.UP)
		target_yaw = clamp(target_yaw, deg_to_rad(-max_angle_degrees), deg_to_rad(max_angle_degrees))
		current_yaw = lerp_angle(current_yaw, target_yaw, turn_speed * delta)
		current_weight = move_toward(current_weight, 1.0, blend_in_speed * delta)
	else:
		current_yaw = lerp_angle(current_yaw, 0.0, blend_out_speed * delta)
		current_weight = move_toward(current_weight, 0.0, blend_out_speed * delta)
	if current_weight > 0.0:
		var yaw_rotation := Basis(Vector3.UP, current_yaw)
		var new_world_basis := yaw_rotation * world_base_pose.basis
		var new_world_transform := Transform3D(new_world_basis, world_base_pose.origin)
		var new_local_pose := skel_transform.affine_inverse() * new_world_transform
		skeleton.set_bone_global_pose_override(bone_idx, new_local_pose, current_weight, true)
	else:
		skeleton.set_bone_global_pose_override(bone_idx, Transform3D(), 0.0, false)
