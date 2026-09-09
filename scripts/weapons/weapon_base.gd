class_name WeaponBase
extends Node3D

signal hit_confirmed(headshot: bool)
signal state_changed

@export var weapon_display_name: String = "Weapon"

var wielder: CharacterBody3D
var equipped: bool = false


func setup(actor: CharacterBody3D) -> void:
	wielder = actor


func equip() -> void:
	equipped = true
	visible = true
	state_changed.emit()


func unequip() -> void:
	equipped = false
	visible = false
	state_changed.emit()


func request_primary() -> void:
	pass


func request_heavy() -> void:
	pass


func secondary_pressed() -> void:
	pass


func secondary_released() -> void:
	pass


func request_reload() -> void:
	pass


func reset_weapon() -> void:
	pass


func get_aim_origin() -> Vector3:
	if is_instance_valid(wielder) and wielder.has_method("get_aim_origin"):
		return wielder.get_aim_origin()
	return global_position


func get_aim_direction() -> Vector3:
	if is_instance_valid(wielder) and wielder.has_method("get_aim_direction"):
		return wielder.get_aim_direction()
	return -global_basis.z


func get_query_exclusions() -> Array[RID]:
	if is_instance_valid(wielder) and wielder.has_method("get_aim_exclusions"):
		return wielder.get_aim_exclusions()
	return []

