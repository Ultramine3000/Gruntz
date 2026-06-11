extends Node
class_name PlayerAnimation

@export var skeleton: Skeleton3D

@onready var anim_player: AnimationPlayer = $"../3rdperson_player_model/AnimationPlayer"
@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = _player.get_node("Camera3D")

var _weapon_type: String = "Unarmed"
var _spine_bone_idx: int = -1

func _ready() -> void:
	if skeleton:
		_spine_bone_idx = skeleton.find_bone("mixamorig_Spine")
		if _spine_bone_idx == -1:
			push_warning("PlayerAnimation: could not find bone 'mixamorig_Spine'")
	for child in _player.get_children():
		if child is WeaponBase:
			set_weapon_type(child.weapon_type)
			break

func _process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_lower(input_dir)
	_update_spine(delta)

func _update_lower(input_dir: Vector2) -> void:
	var is_moving := input_dir.length() > 0.1
	var is_sprinting := Input.is_action_pressed("sprint") and is_moving

	var lower_anim: String
	if not is_moving:
		lower_anim = "Idle"
	elif is_sprinting:
		lower_anim = "Sprint"
	else:
		if absf(input_dir.x) > absf(input_dir.y):
			lower_anim = "MoveLeft" if input_dir.x < 0.0 else "MoveRight"
		else:
			lower_anim = "MoveBack" if input_dir.y > 0.0 else "MoveForward"

	if anim_player.current_animation != lower_anim:
		anim_player.play(lower_anim)

func _update_spine(delta: float) -> void:
	if _spine_bone_idx == -1:
		return
	var combined := Quaternion(Basis.from_euler(Vector3(
	-_camera.rotation.x * 1.6,
	0.0,
	1.2 * _player._lean_target
)))
	var current := skeleton.get_bone_pose_rotation(_spine_bone_idx)
	skeleton.set_bone_pose_rotation(_spine_bone_idx, current.slerp(combined, 10.0 * delta))

func set_weapon_type(type: String) -> void:
	_weapon_type = type
	_play_upper_anim()

func _play_upper_anim() -> void:
	match _weapon_type:
		"Rifle":  anim_player.play("RifleUpperIdle")
		"Pistol": anim_player.play("PistolUpperIdle")
		_:        anim_player.play("UnarmedUpperIdle")
