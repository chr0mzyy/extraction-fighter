class_name WeaponPresentationLibrary
extends RefCounted


static func for_family(family: StringName) -> WeaponPresentationProfile:
	var profile := WeaponPresentationProfile.new()
	profile.family = family if not family.is_empty() else &"generic"
	match profile.family:
		&"sniper":
			profile.hip_position = Vector3(0.36, -0.31, -0.52)
			profile.ads_position = Vector3(0.0, -0.255, -0.68)
			profile.sprint_position = Vector3(0.48, -0.40, -0.27)
			profile.sprint_rotation = Vector3(0.12, -0.24, 0.24)
			profile.tpp_position = Vector3(0.30, -0.46, -0.30)
			profile.fire_kick_distance = 0.145
			profile.fire_pitch_radians = 0.027
			profile.fire_roll_radians = 0.012
			profile.fire_recovery = 4.8
			profile.fire_crosshair_impulse = 8.0
			profile.hide_crosshair_in_ads = true
			profile.muzzle_flash_scale = 1.55
			profile.muzzle_flash_duration = 0.075
			profile.tracer_duration = 0.085
		&"assault_rifle":
			profile.hip_position = Vector3(0.35, -0.30, -0.49)
			profile.ads_position = Vector3(0.0, -0.245, -0.62)
			profile.fire_kick_distance = 0.064
			profile.fire_pitch_radians = 0.0085
			profile.fire_roll_radians = 0.006
			profile.fire_recovery = 10.5
			profile.fire_crosshair_impulse = 3.8
			profile.muzzle_flash_scale = 0.82
			profile.muzzle_flash_duration = 0.038
		&"burst_rifle":
			profile.hip_position = Vector3(0.34, -0.29, -0.50)
			profile.ads_position = Vector3(0.0, -0.242, -0.63)
			profile.fire_kick_distance = 0.070
			profile.fire_pitch_radians = 0.0105
			profile.fire_roll_radians = 0.004
			profile.fire_recovery = 8.0
			profile.fire_crosshair_impulse = 3.0
			profile.muzzle_flash_scale = 0.95
			profile.muzzle_flash_duration = 0.042
		&"battle_rifle":
			profile.hip_position = Vector3(0.37, -0.31, -0.50)
			profile.ads_position = Vector3(0.0, -0.248, -0.65)
			profile.sprint_position = Vector3(0.48, -0.40, -0.31)
			profile.fire_kick_distance = 0.105
			profile.fire_pitch_radians = 0.017
			profile.fire_roll_radians = 0.009
			profile.fire_recovery = 6.2
			profile.fire_crosshair_impulse = 5.4
			profile.muzzle_flash_scale = 1.25
			profile.muzzle_flash_duration = 0.058
			profile.tracer_duration = 0.070
		&"pistol":
			profile.hip_position = Vector3(0.30, -0.27, -0.43)
			profile.ads_position = Vector3(0.0, -0.225, -0.52)
			profile.sprint_position = Vector3(0.39, -0.35, -0.30)
			profile.tpp_position = Vector3(0.27, -0.39, -0.08)
			profile.fire_kick_distance = 0.082
			profile.fire_pitch_radians = 0.012
			profile.fire_roll_radians = 0.008
			profile.fire_recovery = 13.0
			profile.fire_crosshair_impulse = 3.2
			profile.muzzle_flash_scale = 0.78
			profile.muzzle_flash_duration = 0.034
			profile.reload_tilt_radians = 0.42
		&"akimbo_pistols":
			profile.hip_position = Vector3(0.25, -0.28, -0.39)
			profile.ads_position = profile.hip_position
			profile.sprint_position = Vector3(0.35, -0.38, -0.27)
			profile.tpp_position = Vector3(0.25, -0.39, -0.06)
			profile.movement_sway_position = Vector3(0.020, 0.018, 0.014)
			profile.movement_sway_rotation = Vector3(0.020, 0.030, 0.032)
			profile.fire_kick_distance = 0.088
			profile.fire_pitch_radians = 0.010
			profile.fire_roll_radians = 0.018
			profile.fire_recovery = 12.0
			profile.fire_crosshair_impulse = 5.0
			profile.crosshair_multiplier = 1.22
			profile.muzzle_flash_scale = 0.82
			profile.muzzle_flash_duration = 0.035
			profile.reload_tilt_radians = 0.52
		&"magic":
			profile.hip_position = Vector3(0.31, -0.28, -0.46)
			profile.ads_position = Vector3(0.09, -0.25, -0.54)
			profile.sprint_position = Vector3(0.42, -0.37, -0.30)
			profile.tpp_position = Vector3(0.29, -0.40, -0.14)
			profile.idle_sway_position = Vector3(0.008, 0.012, 0.008)
			profile.fire_kick_distance = 0.052
			profile.fire_pitch_radians = 0.007
			profile.fire_roll_radians = 0.010
			profile.fire_recovery = 7.0
			profile.fire_crosshair_impulse = 3.6
			profile.crosshair_multiplier = 0.92
			profile.muzzle_flash_scale = 1.18
			profile.muzzle_flash_duration = 0.070
		&"katana":
			_configure_melee(profile, false, false)
		&"sword":
			_configure_melee(profile, true, false)
		&"nodachi":
			_configure_melee(profile, true, true)
		_:
			pass
	return profile


static func _configure_melee(profile: WeaponPresentationProfile, heavy: bool, long_blade: bool) -> void:
	profile.hip_position = Vector3(0.42 if long_blade else 0.38, -0.35, -0.45)
	profile.hip_rotation = Vector3(0.05, -0.12, 0.07)
	profile.ads_position = profile.hip_position
	profile.ads_rotation = profile.hip_rotation
	profile.sprint_position = Vector3(0.47, -0.44, -0.25)
	profile.sprint_rotation = Vector3(0.18, -0.30, 0.34)
	profile.tpp_position = Vector3(0.33, -0.45, -0.16 if long_blade else -0.10)
	profile.tpp_rotation = Vector3(0.08, -0.18, 0.11)
	profile.fire_kick_distance = 0.035
	profile.fire_pitch_radians = 0.004
	profile.fire_roll_radians = 0.014 if heavy else 0.010
	profile.fire_recovery = 7.5 if heavy else 10.0
	profile.fire_crosshair_impulse = 4.4 if heavy else 3.5
	profile.crosshair_multiplier = 0.68
	profile.simple_melee_reticle = true
	profile.reload_tilt_radians = 0.0
	profile.reload_drop = 0.0
	profile.swap_duration = 0.20 if long_blade else 0.16
