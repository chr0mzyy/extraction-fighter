extends Node

signal changed

const SAVE_VERSION := 1
const SAVE_PATH := "user://game_settings.json"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var resolution: Vector2i = Vector2i(1280, 720)
var fullscreen: bool = false
var vsync: bool = true
var base_fov: float = 90.0
var fps_cap: int = 144
var shadow_quality: int = 1
var render_scale: float = 1.0
var effects_quality: int = 1
var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
var damage_numbers: bool = true
var camera_shake_strength: float = 0.55
var headbob_strength: float = 0.45
var crosshair_enabled: bool = true
var master_volume: float = 0.80
var music_volume: float = 0.65
var sfx_volume: float = 0.85
var _save_pending: bool = false
var _save_delay_remaining: float = 0.0


func _ready() -> void:
	load_settings()


func _process(delta: float) -> void:
	if not _save_pending:
		return
	_save_delay_remaining -= delta
	if _save_delay_remaining <= 0.0:
		save_settings()


func reset_defaults(apply_now: bool = true) -> void:
	resolution = Vector2i(1280, 720)
	fullscreen = false
	vsync = true
	base_fov = 90.0
	fps_cap = 144
	shadow_quality = 1
	render_scale = 1.0
	effects_quality = 1
	mouse_sensitivity = 0.0022
	invert_y = false
	damage_numbers = true
	camera_shake_strength = 0.55
	headbob_strength = 0.45
	crosshair_enabled = true
	master_volume = 0.80
	music_volume = 0.65
	sfx_volume = 0.85
	if apply_now:
		apply_settings()


func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	match key:
		&"resolution": resolution = value as Vector2i
		&"fullscreen": fullscreen = bool(value)
		&"vsync": vsync = bool(value)
		&"base_fov": base_fov = clampf(float(value), 70.0, 110.0)
		&"fps_cap": fps_cap = clampi(int(value), 30, 360)
		&"shadow_quality": shadow_quality = clampi(int(value), 0, 2)
		&"render_scale": render_scale = clampf(float(value), 0.5, 1.0)
		&"effects_quality": effects_quality = clampi(int(value), 0, 2)
		&"mouse_sensitivity": mouse_sensitivity = clampf(float(value), 0.0005, 0.006)
		&"invert_y": invert_y = bool(value)
		&"damage_numbers": damage_numbers = bool(value)
		&"camera_shake_strength": camera_shake_strength = clampf(float(value), 0.0, 1.0)
		&"headbob_strength": headbob_strength = clampf(float(value), 0.0, 1.0)
		&"crosshair_enabled": crosshair_enabled = bool(value)
		&"master_volume": master_volume = clampf(float(value), 0.0, 1.0)
		&"music_volume": music_volume = clampf(float(value), 0.0, 1.0)
		&"sfx_volume": sfx_volume = clampf(float(value), 0.0, 1.0)
		_: return
	apply_settings()
	if persist:
		_save_pending = true
		_save_delay_remaining = 0.25


func apply_settings() -> void:
	Engine.max_fps = fps_cap
	get_viewport().scaling_3d_scale = render_scale
	RenderingServer.directional_shadow_atlas_set_size([0, 2048, 4096][shadow_quality], true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			DisplayServer.window_set_size(resolution)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
	_apply_optional_audio_bus("Music", music_volume)
	_apply_optional_audio_bus("SFX", sfx_volume)
	changed.emit()


func _apply_optional_audio_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


func to_dictionary() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"resolution": [resolution.x, resolution.y],
		"fullscreen": fullscreen,
		"vsync": vsync,
		"base_fov": base_fov,
		"fps_cap": fps_cap,
		"shadow_quality": shadow_quality,
		"render_scale": render_scale,
		"effects_quality": effects_quality,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"damage_numbers": damage_numbers,
		"camera_shake_strength": camera_shake_strength,
		"headbob_strength": headbob_strength,
		"crosshair_enabled": crosshair_enabled,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}


func apply_dictionary(data: Dictionary, apply_now: bool = true) -> bool:
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		return false
	var saved_resolution: Array = data.get("resolution", [1280, 720])
	if saved_resolution.size() != 2:
		return false
	resolution = Vector2i(clampi(int(saved_resolution[0]), 640, 7680), clampi(int(saved_resolution[1]), 360, 4320))
	fullscreen = bool(data.get("fullscreen", false))
	vsync = bool(data.get("vsync", true))
	base_fov = clampf(float(data.get("base_fov", 90.0)), 70.0, 110.0)
	fps_cap = clampi(int(data.get("fps_cap", 144)), 30, 360)
	shadow_quality = clampi(int(data.get("shadow_quality", 1)), 0, 2)
	render_scale = clampf(float(data.get("render_scale", 1.0)), 0.5, 1.0)
	effects_quality = clampi(int(data.get("effects_quality", 1)), 0, 2)
	mouse_sensitivity = clampf(float(data.get("mouse_sensitivity", 0.0022)), 0.0005, 0.006)
	invert_y = bool(data.get("invert_y", false))
	damage_numbers = bool(data.get("damage_numbers", true))
	camera_shake_strength = clampf(float(data.get("camera_shake_strength", 0.55)), 0.0, 1.0)
	headbob_strength = clampf(float(data.get("headbob_strength", 0.45)), 0.0, 1.0)
	crosshair_enabled = bool(data.get("crosshair_enabled", true))
	master_volume = clampf(float(data.get("master_volume", 0.80)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.65)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.85)), 0.0, 1.0)
	if apply_now:
		apply_settings()
	return true


func save_settings(path: String = SAVE_PATH) -> bool:
	_save_pending = false
	_save_delay_remaining = 0.0
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	return true


func load_settings(path: String = SAVE_PATH, create_default: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		reset_defaults()
		if create_default:
			save_settings(path)
		return create_default
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var parsed: Variant = parser.data
	if parse_error != OK or not parsed is Dictionary or not apply_dictionary(parsed as Dictionary):
		reset_defaults()
		if create_default:
			save_settings(path)
		return false
	return true
