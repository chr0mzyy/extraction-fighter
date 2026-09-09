class_name KillVolume
extends Area3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("force_kill"):
		body.force_kill()

