class_name Hurtbox3D
extends Area3D

@export var headshot: bool = false


func get_damage_receiver() -> Node:
	return get_parent()


func is_headshot_hitbox() -> bool:
	return headshot

