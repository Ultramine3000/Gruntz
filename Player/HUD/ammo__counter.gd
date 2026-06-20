extends Label
class_name AmmoCounter

var _equipped_weapon: WeaponBase = null


func _ready() -> void:
	_find_and_connect_weapon()


func _process(_delta: float) -> void:
	# Re-checks each frame so this picks up the weapon on load and follows
	# along if the player switches weapons later.
	if _equipped_weapon == null or not is_instance_valid(_equipped_weapon):
		_find_and_connect_weapon()


func _find_and_connect_weapon() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return

	var camera: Camera3D = player.get_node_or_null("Camera3D")
	if not camera:
		return

	var weapon: WeaponBase = null
	for child in camera.get_children():
		if child is WeaponBase:
			weapon = child
			break

	if weapon == _equipped_weapon:
		return

	if _equipped_weapon and _equipped_weapon.ammo_changed.is_connected(_on_ammo_changed):
		_equipped_weapon.ammo_changed.disconnect(_on_ammo_changed)

	_equipped_weapon = weapon

	if _equipped_weapon:
		_equipped_weapon.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(_equipped_weapon.current_ammo, _equipped_weapon.reserve_ammo)
	else:
		text = ""


func _on_ammo_changed(current: int, reserve: int) -> void:
	text = "%d | %s" % [reserve, "I".repeat(current)]
