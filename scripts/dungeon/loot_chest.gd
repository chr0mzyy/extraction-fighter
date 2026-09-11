class_name LootChest
extends Node3D

signal opened(chest: LootChest, items: Array[ItemInstance], gold: int)

var loot_items: Array[ItemInstance] = []
var gold_reward: int = 0
var opened_once: bool = false
var is_boss_chest: bool = false
var lid: MeshInstance3D


func configure(items: Array[ItemInstance], gold: int, boss_chest: bool = false) -> void:
	loot_items = items
	gold_reward = gold
	is_boss_chest = boss_chest


func _ready() -> void:
	_build_visual()


func interact() -> void:
	if opened_once:
		return
	opened_once = true
	if lid != null:
		lid.rotation.x = -0.8
	opened.emit(self, loot_items, gold_reward)


func get_prompt() -> String:
	return "EMPTY CHEST" if opened_once else ("[X]  OPEN WARDEN CHEST" if is_boss_chest else "[X]  OPEN CHEST")


func _build_visual() -> void:
	var accent := Color(0.88, 0.56, 0.15) if is_boss_chest else Color(0.23, 0.55, 0.52)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.5, 0.7, 0.85)
	body.mesh = body_mesh
	body.position.y = 0.38
	body.material_override = _material(Color(0.14, 0.09, 0.055))
	add_child(body)
	lid = MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.58, 0.22, 0.92)
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 0.82, -0.34)
	lid.material_override = _material(accent)
	add_child(lid)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.18, 0.82, 0.92)
	band.mesh = band_mesh
	band.position.y = 0.43
	band.material_override = _material(accent)
	add_child(band)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
