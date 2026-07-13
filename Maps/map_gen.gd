extends Node3D
## Prefab-based dungeon generator (PackedScene version).
##
## SETUP:
## 1. Each prefab lives in its own .tscn file (e.g. res://prefabs/shaft.tscn),
##    with connector children named "connect_1", "connect_2", etc.
## 2. Drag those .tscn files into the `Prefab Scenes` array in the Inspector.
## 3. Attach this script to any Node3D in your level scene. Nothing needs to
##    be hidden or toggled — prefabs don't exist in the live tree until
##    they're instantiated, so there's no visibility-inheritance trap.
##
## CONNECTOR CONVENTION:
## A connector's local -Z axis points OUT of the piece through that doorway,
## and its origin sits exactly at the doorway threshold.

@export var prefab_scenes: Array[PackedScene] = []
@export var end_scene: PackedScene  # the "end" cap, used to close leftover connectors
@export var max_pieces: int = 60
@export var connector_prefix: String = "connect_"
@export var generation_seed: int = -1
@export var overlap_tolerance: float = 0.05
@export var debug_draw_connectors: bool = true

var _rng := RandomNumberGenerator.new()
var _placed_root: Node3D
var _open_connectors: Array[Dictionary] = []  # {xform: Transform3D, groups: PackedStringArray}
var _placed_bounds: Array[AABB] = []
var _piece_count: int = 0


func _ready() -> void:
	if generation_seed >= 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()
	generate()


func generate() -> void:
	if prefab_scenes.is_empty():
		push_error("prefab_scenes is empty — assign your .tscn prefabs in the Inspector.")
		return
	if end_scene == null:
		push_error("end_scene is not assigned — assign the 'end' cap prefab in the Inspector.")
		return

	_placed_root = Node3D.new()
	_placed_root.name = "GeneratedDungeon"
	add_child(_placed_root)

	var start_scene: PackedScene = prefab_scenes[_rng.randi_range(0, prefab_scenes.size() - 1)]
	_place_piece(start_scene, Transform3D.IDENTITY, "")

	while _open_connectors.size() > 0 and _piece_count < max_pieces:
		var conn: Dictionary = _open_connectors.pop_back()
		_try_fill_connector(conn)

	while _open_connectors.size() > 0:
		var conn: Dictionary = _open_connectors.pop_back()
		if not _attempt_place_at(end_scene, conn, true):
			push_warning("Could not cap connector at ", conn.xform.origin, " even ignoring overlap — check that end_scene has a connector with a compatible socket group.")

	print("Dungeon generated: ", _piece_count, " pieces.")


func _get_connectors(piece: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in piece.get_children():
		if child is Node3D and child.name.begins_with(connector_prefix):
			out.append(child)
	out.sort_custom(func(a, b): return a.name < b.name)
	return out


## A connector with no groups assigned is a wildcard — matches anything.
## A connector with groups only matches another connector sharing >=1 group.
func _sockets_compatible(entry_groups: PackedStringArray, target_groups: PackedStringArray) -> bool:
	if entry_groups.is_empty() or target_groups.is_empty():
		return true
	for g in entry_groups:
		if target_groups.has(g):
			return true
	return false


func _try_fill_connector(conn: Dictionary) -> void:
	var candidates := prefab_scenes.duplicate()
	candidates.shuffle()

	for scene in candidates:
		if _attempt_place_at(scene, conn):
			return

	if not _attempt_place_at(end_scene, conn, true):
		push_warning("Could not cap connector at ", conn.xform.origin, " during generation — leaving it open.")


func _attempt_place_at(scene: PackedScene, conn: Dictionary, ignore_overlap: bool = false) -> bool:
	var target_xform: Transform3D = conn.xform
	var target_groups: PackedStringArray = conn.groups

	if debug_draw_connectors:
		_spawn_debug_marker(target_xform, Color.YELLOW, "target")

	var probe: Node3D = scene.instantiate()
	var entries := _get_connectors(probe)
	entries.shuffle()

	for entry in entries:
		if not _sockets_compatible(entry.get_groups(), target_groups):
			continue

		var world_xform := _solve_placement_transform(entry, target_xform)
		var bounds := _estimate_world_aabb(probe, world_xform)

		if not ignore_overlap and _overlaps_existing(bounds):
			continue

		probe.name = probe.name + "_" + str(_piece_count)
		_placed_root.add_child(probe)
		probe.global_transform = world_xform
		_piece_count += 1
		_placed_bounds.append(bounds)

		if debug_draw_connectors:
			_spawn_debug_marker(entry.global_transform, Color.RED, "entry:" + entry.name)

		for connector in _get_connectors(probe):
			if connector.name == entry.name:
				continue
			var open_xform := _flip_connector(connector.global_transform)
			_open_connectors.append({
				"xform": open_xform,
				"groups": connector.get_groups()
			})
			if debug_draw_connectors:
				_spawn_debug_marker(connector.global_transform, Color.GREEN, "open:" + connector.name)
		return true

	probe.queue_free()
	return false


## Spawns a small sphere at xform's position plus a short line along its
## local -Z, so you can see connector position AND facing direction at
## runtime (editor gizmos don't render during Play).
func _spawn_debug_marker(xform: Transform3D, color: Color, label: String) -> void:
	var marker := Node3D.new()
	marker.name = "DebugMarker_" + label.replace(":", "_")
	_placed_root.add_child(marker)
	marker.global_transform = xform

	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.08
	sphere_mesh.height = 0.16
	sphere.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override = mat
	marker.add_child(sphere)

	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, 0.5)
	line.mesh = box
	line.position = Vector3(0, 0, -0.25)  # extends along local -Z, matching the connector convention
	line.material_override = mat
	marker.add_child(line)

	print("DEBUG marker [", label, "] pos=", xform.origin, " -Z dir=", -xform.basis.z)


func _place_piece(scene: PackedScene, world_xform: Transform3D, entry_name: String) -> void:
	var inst: Node3D = scene.instantiate()
	_placed_root.add_child(inst)
	inst.global_transform = world_xform
	_piece_count += 1

	for connector in _get_connectors(inst):
		if connector.name == entry_name:
			continue
		_open_connectors.append({
			"xform": _flip_connector(connector.global_transform),
			"groups": connector.get_groups()
		})


func _solve_placement_transform(entry: Node3D, target_xform: Transform3D) -> Transform3D:
	# entry.transform is already relative to its parent (the piece root),
	# regardless of what leftover Transform the root itself was saved with.
	return target_xform * entry.transform.affine_inverse()


func _flip_connector(xform: Transform3D) -> Transform3D:
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return xform * flip


func _estimate_world_aabb(template: Node3D, world_xform: Transform3D) -> AABB:
	var local_aabb := AABB()
	var first := true
	for child in template.get_children():
		if child is MeshInstance3D:
			var mesh_aabb: AABB = child.mesh.get_aabb() if child.mesh else AABB()
			var xform_aabb: AABB = child.transform * mesh_aabb
			if first:
				local_aabb = xform_aabb
				first = false
			else:
				local_aabb = local_aabb.merge(xform_aabb)
	return (world_xform * local_aabb).abs()


func _overlaps_existing(bounds: AABB) -> bool:
	var shrunk := bounds.grow(-overlap_tolerance).abs()
	for existing in _placed_bounds:
		if shrunk.intersects(existing):
			return true
	return false
