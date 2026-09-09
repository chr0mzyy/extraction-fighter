class_name DamageInfo
extends RefCounted

var amount: float
var attacker: Node
var damage_type: StringName
var headshot: bool
var is_melee: bool
var hit_position: Vector3
var knockback: Vector3
var can_reflect: bool
var bypass_defense: bool


func _init(
		p_amount: float = 0.0,
		p_attacker: Node = null,
		p_damage_type: StringName = &"generic",
		p_headshot: bool = false,
		p_is_melee: bool = false,
		p_hit_position: Vector3 = Vector3.ZERO,
		p_knockback: Vector3 = Vector3.ZERO,
		p_can_reflect: bool = true,
		p_bypass_defense: bool = false
) -> void:
	amount = p_amount
	attacker = p_attacker
	damage_type = p_damage_type
	headshot = p_headshot
	is_melee = p_is_melee
	hit_position = p_hit_position
	knockback = p_knockback
	can_reflect = p_can_reflect
	bypass_defense = p_bypass_defense


func make_reflection(defender: Node) -> DamageInfo:
	return DamageInfo.new(
		amount,
		defender,
		&"deflected_shot",
		false,
		false,
		hit_position,
		-knockback,
		false,
		false
	)

