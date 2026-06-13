extends Node3D
class_name WeaponBase

# ─────────────────────────────────────────────
#  WEAPON IDENTITY
# ─────────────────────────────────────────────
@export_enum("Pistol", "Rifle") var weapon_type: String = "Pistol"

@export_group("Stats")
@export var weapon_name: String = "Unnamed Weapon"
@export var damage: float = 25.0
@export var fire_rate: float = 0.15
@export var mag_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0
@export var muzzle_flash: Node3D
@export var tracer_scene: PackedScene
@export var decal_scene: PackedScene

@export_group("ADS")
@export var ads_position: Vector3 = Vector3.ZERO
@export var ads_speed: float = 10.0

@export_group("Nodes")
@export var anim_player: AnimationPlayer

# ─────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────
enum WeaponState {
	IDLE,
	DRAWING,
	HOLSTERING,
	FIRING,
	RELOADING,
	INSPECTING,
}

var state: WeaponState = WeaponState.IDLE
var current_ammo: int = 0
var can_fire: bool = true
var fire_timer: float = 0.0
var is_ads: bool = false

var _hip_position: Vector3 = Vector3.ZERO

# ─────────────────────────────────────────────
#  ANIMATION NAMES
# ─────────────────────────────────────────────
const ANIM_IDLE     := "idle"
const ANIM_DRAW     := "draw"
const ANIM_HOLSTER  := "holster"
const ANIM_RELOAD   := "reload"
const ANIM_FIRE     := "fire"
const ANIM_INSPECT  := "inspect"

# ─────────────────────────────────────────────
#  INPUT ACTIONS
# ─────────────────────────────────────────────
const INPUT_FIRE    := "fire"
const INPUT_RELOAD  := "reload"
const INPUT_INSPECT := "inspect"
const INPUT_ADS     := "ads"

# ─────────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────────
signal weapon_fired(weapon: WeaponBase)
signal weapon_reloaded(weapon: WeaponBase)
signal ammo_changed(current: int, reserve: int)
signal holster_finished
signal draw_finished

# ─────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────
func _ready() -> void:
	current_ammo = mag_size
	_hip_position = position

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
	else:
		push_error("[%s] No AnimationPlayer assigned!" % weapon_name)

	play_anim(ANIM_DRAW)
	state = WeaponState.DRAWING


func _process(delta: float) -> void:
	_handle_fire_cooldown(delta)
	_handle_input()
	_update_ads(delta)


# ─────────────────────────────────────────────
#  ADS
# ─────────────────────────────────────────────
func _update_ads(delta: float) -> void:
	var target_pos := ads_position if is_ads else _hip_position
	position = position.lerp(target_pos, ads_speed * delta)


# ─────────────────────────────────────────────
#  INPUT HANDLING
# ─────────────────────────────────────────────
func _handle_input() -> void:
	if state in [WeaponState.DRAWING, WeaponState.HOLSTERING]:
		return

	is_ads = Input.is_action_pressed(INPUT_ADS)

	if Input.is_action_pressed(INPUT_FIRE):
		try_fire()

	if Input.is_action_just_pressed(INPUT_RELOAD):
		try_reload()

	if Input.is_action_just_pressed(INPUT_INSPECT):
		try_inspect()


# ─────────────────────────────────────────────
#  FIRE
# ─────────────────────────────────────────────
func try_fire() -> void:
	if not can_fire:
		return
	if state != WeaponState.IDLE and state != WeaponState.FIRING:
		return
	if current_ammo <= 0:
		try_reload()
		return

	state = WeaponState.FIRING
	current_ammo -= 1
	can_fire = false
	fire_timer = fire_rate

	play_anim(ANIM_FIRE)
	emit_signal("weapon_fired", self)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	_on_fire()


func _on_fire() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var aim_point: Vector3 = player.get_aim_point() if player else \
			muzzle_flash.global_position + muzzle_flash.global_transform.basis.z * -500.0

	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation_degrees.z = randf_range(0.0, 360.0)
		get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible = false)

	if tracer_scene and muzzle_flash:
		var from := muzzle_flash.global_position
		var tracer = tracer_scene.instantiate()
		get_tree().current_scene.add_child(tracer)
		tracer.init(from, aim_point)

	if decal_scene and player:
		var ray: RayCast3D = player.aim_ray
		print("ray colliding: ", ray.is_colliding())
		print("hit point: ", ray.get_collision_point())
		if ray.is_colliding():
			var hit_point: Vector3 = ray.get_collision_point()
			var normal: Vector3 = ray.get_collision_normal()
			var decal := decal_scene.instantiate() as MeshInstance3D
			get_tree().current_scene.add_child(decal)
			decal.global_position = hit_point + normal * 0.02
			var up: Vector3 = Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
			var right: Vector3 = up.cross(normal).normalized()
			var up_corrected: Vector3 = normal.cross(right).normalized()
			decal.global_transform.basis = Basis(right, up_corrected, normal)


func _handle_fire_cooldown(delta: float) -> void:
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true
			if state == WeaponState.FIRING:
				state = WeaponState.IDLE
				play_anim(ANIM_IDLE)


# ─────────────────────────────────────────────
#  RELOAD
# ─────────────────────────────────────────────
func try_reload() -> void:
	if state == WeaponState.RELOADING:
		return
	if current_ammo == mag_size:
		return
	if reserve_ammo <= 0:
		return

	state = WeaponState.RELOADING
	play_anim(ANIM_RELOAD)


func _finish_reload() -> void:
	var needed: int = mag_size - current_ammo
	var taken: int  = min(needed, reserve_ammo)
	current_ammo  += taken
	reserve_ammo  -= taken
	state = WeaponState.IDLE
	emit_signal("weapon_reloaded", self)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	anim_player.queue(ANIM_IDLE)


# ─────────────────────────────────────────────
#  INSPECT
# ─────────────────────────────────────────────
func try_inspect() -> void:
	if state not in [WeaponState.IDLE]:
		return
	state = WeaponState.INSPECTING
	play_anim(ANIM_INSPECT)


# ─────────────────────────────────────────────
#  DRAW / HOLSTER
# ─────────────────────────────────────────────
func draw() -> void:
	state = WeaponState.DRAWING
	play_anim(ANIM_DRAW)


func holster() -> void:
	state = WeaponState.HOLSTERING
	play_anim(ANIM_HOLSTER)


# ─────────────────────────────────────────────
#  ANIMATION
# ─────────────────────────────────────────────
func play_anim(anim_name: String) -> void:
	if not anim_player:
		return
	if not anim_player.has_animation(anim_name):
		push_warning("WeaponBase: missing animation '%s' on %s" % [anim_name, weapon_name])
		return
	anim_player.stop()
	anim_player.play(anim_name)


func _on_animation_finished(anim_name: String) -> void:
	match anim_name:
		ANIM_DRAW:
			state = WeaponState.IDLE
			emit_signal("draw_finished")
			anim_player.queue(ANIM_IDLE)

		ANIM_HOLSTER:
			state = WeaponState.IDLE
			emit_signal("holster_finished")

		ANIM_RELOAD:
			_finish_reload()

		ANIM_FIRE:
			pass

		ANIM_INSPECT:
			state = WeaponState.IDLE
			play_anim(ANIM_IDLE)

		ANIM_IDLE:
			play_anim(ANIM_IDLE)
