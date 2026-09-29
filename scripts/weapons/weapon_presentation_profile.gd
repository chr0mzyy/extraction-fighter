class_name WeaponPresentationProfile
extends Resource

var family: StringName = &"generic"
var hip_position: Vector3 = Vector3(0.34, -0.29, -0.48)
var hip_rotation: Vector3 = Vector3(0.0, -0.04, 0.0)
var ads_position: Vector3 = Vector3(0.0, -0.225, -0.60)
var ads_rotation: Vector3 = Vector3.ZERO
var sprint_position: Vector3 = Vector3(0.43, -0.39, -0.34)
var sprint_rotation: Vector3 = Vector3(0.15, -0.20, 0.20)
var tpp_position: Vector3 = Vector3(0.31, -0.42, -0.18)
var tpp_rotation: Vector3 = Vector3(0.06, -0.10, 0.02)
var idle_sway_position: Vector3 = Vector3(0.005, 0.007, 0.004)
var idle_sway_rotation: Vector3 = Vector3(0.004, 0.006, 0.005)
var movement_sway_position: Vector3 = Vector3(0.010, 0.012, 0.008)
var movement_sway_rotation: Vector3 = Vector3(0.012, 0.016, 0.018)
var ads_transition_speed: float = 15.0
var pose_transition_speed: float = 12.0
var fire_kick_distance: float = 0.075
var fire_pitch_radians: float = 0.010
var fire_roll_radians: float = 0.006
var fire_recovery: float = 8.0
var crosshair_multiplier: float = 1.0
var fire_crosshair_impulse: float = 4.0
var hide_crosshair_in_ads: bool = false
var simple_melee_reticle: bool = false
var reload_tilt_radians: float = 0.30
var reload_drop: float = 0.055
var swap_duration: float = 0.18
var muzzle_flash_scale: float = 1.0
var muzzle_flash_duration: float = 0.045
var tracer_duration: float = 0.055


func is_valid() -> bool:
	return not family.is_empty() and ads_transition_speed > 0.0 and pose_transition_speed > 0.0 and fire_recovery > 0.0
