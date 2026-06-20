@tool
extends EditorScript
func _run():
	var lower_bones = [
		"mixamorig_Hips",
		"mixamorig_LeftUpLeg",
		"mixamorig_LeftLeg",
		"mixamorig_LeftFoot",
		"mixamorig_LeftToeBase",
		"mixamorig_LeftToe_End",
		"mixamorig_RightUpLeg",
		"mixamorig_RightLeg",
		"mixamorig_RightFoot",
		"mixamorig_RightToeBase",
		"mixamorig_RightToe_End",
	]
	
	var upper_bones = [
		"mixamorig_Spine",
		"mixamorig_Spine1",
		"mixamorig_Spine2",
		"mixamorig_Neck",
		"mixamorig_LeftShoulder",
		"mixamorig_LeftArm",
		"mixamorig_LeftForeArm",
		"mixamorig_LeftHand",
		"mixamorig_LeftHandThumb1",
		"mixamorig_LeftHandThumb2",
		"mixamorig_LeftHandThumb3",
		"mixamorig_LeftHandThumb4",
		"mixamorig_LeftHandThumb4_end",
		"mixamorig_LeftHandIndex1",
		"mixamorig_LeftHandIndex2",
		"mixamorig_LeftHandIndex3",
		"mixamorig_LeftHandIndex4",
		"mixamorig_LeftHandIndex4_end",
		"mixamorig_LeftHandMiddle1",
		"mixamorig_LeftHandMiddle2",
		"mixamorig_LeftHandMiddle3",
		"mixamorig_LeftHandMiddle4",
		"mixamorig_LeftHandMiddle4_end",
		"mixamorig_LeftHandRing1",
		"mixamorig_LeftHandRing2",
		"mixamorig_LeftHandRing3",
		"mixamorig_LeftHandRing4",
		"mixamorig_LeftHandRing4_end",
		"mixamorig_LeftHandPinky1",
		"mixamorig_LeftHandPinky2",
		"mixamorig_LeftHandPinky3",
		"mixamorig_LeftHandPinky4",
		"mixamorig_LeftHandPinky4_end",
		"mixamorig_RightShoulder",
		"mixamorig_RightArm",
		"mixamorig_RightForeArm",
		"mixamorig_RightHand",
		"mixamorig_RightHandThumb1",
		"mixamorig_RightHandThumb2",
		"mixamorig_RightHandThumb3",
		"mixamorig_RightHandThumb4",
		"mixamorig_RightHandThumb4_end",
		"mixamorig_RightHandIndex1",
		"mixamorig_RightHandIndex2",
		"mixamorig_RightHandIndex3",
		"mixamorig_RightHandIndex4",
		"mixamorig_RightHandIndex4_end",
		"mixamorig_RightHandMiddle1",
		"mixamorig_RightHandMiddle2",
		"mixamorig_RightHandMiddle3",
		"mixamorig_RightHandMiddle4",
		"mixamorig_RightHandMiddle4_end",
		"mixamorig_RightHandRing1",
		"mixamorig_RightHandRing2",
		"mixamorig_RightHandRing3",
		"mixamorig_RightHandRing4",
		"mixamorig_RightHandRing4_end",
		"mixamorig_RightHandPinky1",
		"mixamorig_RightHandPinky2",
		"mixamorig_RightHandPinky3",
		"mixamorig_RightHandPinky4",
		"mixamorig_RightHandPinky4_end",
		"mixamorig_Head",
		"mixamorig_HeadTop_End",
	]
	
	# The base spine bone is driven procedurally (PlayerAnimation._update_spine),
	# so it shouldn't be baked into any animation track at all — upper or lower.
	var base_spine_bone := "mixamorig_Spine"
	
	var leg_anims = [
		"Idle", "MoveForward", "MoveBack", "MoveLeft", "MoveRight",
		"Sprint", "Jump","CrouchIdle","CrouchMoveBack","CrouchMoveForward","CrouchMoveLeft","CrouchMoveRight"
	]
	var upper_anims = [
		"RifleUpperIdle", "PistolUpperIdle", "UnarmedUpperIdle", "UnarmedUpperPunch",
		"Reload", "PistolInspect", "RifleInspect", "UnarmedInspect",
		"RifleUpperSprint", "PistolUpperSprint", "PistolUpperDraw", "PistolUpperHolster",
		"RifleUpperDraw", "RifleUpperHolster"
	]
	
	var anim_library = load("res://Player/Player_Model/3rdperson_player_model.glb")
	if not anim_library:
		print("Could not load file!")
		return
	
	var instance = anim_library.instantiate()
	var anim_player = instance.find_child("AnimationPlayer", true, false)
	if not anim_player:
		print("Could not find AnimationPlayer!")
		return
	
	print("Found AnimationPlayer, animations: ", anim_player.get_animation_list())
	
	# LEG ANIMATIONS — Keep ONLY lower_bones, remove ALL upper_bones
	# (this already drops the base spine bone too, since it's not in lower_bones)
	for anim_name in leg_anims:
		if not anim_player.has_animation(anim_name):
			print("Skipping missing: ", anim_name)
			continue
		var anim = anim_player.get_animation(anim_name)
		var tracks_to_remove = []
		
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			var is_lower = false
			
			# Check if this track belongs to a lower bone
			for bone in lower_bones:
				if bone in path:
					is_lower = true
					break
			
			# If it's not a lower bone, remove it (it's upper)
			if not is_lower:
				tracks_to_remove.append(i)
		
		tracks_to_remove.reverse()
		for i in tracks_to_remove:
			anim.remove_track(i)
		print("Leg animation cleaned: ", anim_name, " | removed ", tracks_to_remove.size(), " upper bone tracks")
	
	# UPPER ANIMATIONS — Keep ONLY upper_bones, remove ALL lower_bones, and strip
	# the base spine bone specifically since it's procedurally driven, not baked.
	for anim_name in upper_anims:
		if not anim_player.has_animation(anim_name):
			print("Skipping missing: ", anim_name)
			continue
		var anim = anim_player.get_animation(anim_name)
		var tracks_to_remove = []
		
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			var is_lower = false
			
			# Check if this track belongs to a lower bone
			for bone in lower_bones:
				if bone in path:
					is_lower = true
					break
			
			# Exact match on the base spine bone only — must not also catch
			# mixamorig_Spine1 / mixamorig_Spine2, which should stay.
			var is_base_spine := path.ends_with(":" + base_spine_bone)
			
			# Remove if it's a lower bone OR the base spine bone
			if is_lower or is_base_spine:
				tracks_to_remove.append(i)
		
		tracks_to_remove.reverse()
		for i in tracks_to_remove:
			anim.remove_track(i)
		print("Upper animation cleaned: ", anim_name, " | removed ", tracks_to_remove.size(), " lower bone / base spine tracks")
	
	var save_result = ResourceSaver.save(anim_library, "res://assets/rigs/full_body/3rdperson_omni_cleaned.res")
	if save_result == OK:
		print("Saved to 3rdperson_omni_cleaned.res!")
	else:
		print("Save failed!")
	print("Done!")
