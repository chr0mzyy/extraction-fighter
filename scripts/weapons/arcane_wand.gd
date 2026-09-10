class_name ArcaneWandWeapon
extends WeaponBase

@export var projectile_damage: float = 31.0
@export var projectile_speed: float = 34.0
@export var shot_cooldown: float = 0.48

var fire_cooldown_remaining: float = 0.0
var primary_held: bool = false


func _ready() -> void:
	weapon_display_name = "Arcane Wand"
	automatic_fire = true


func _process(delta: float) -> void:
	effects.tick(delta)
	fire_cooldown_remaining = maxf(0.0, fire_cooldown_remaining - delta)
	if primary_held and equipped:
		request_primary()


func request_primary() -> void:
	if not equipped or fire_cooldown_remaining > 0.0 or not is_instance_valid(wielder) or not can_operate():
		return
	fire_cooldown_remaining = shot_cooldown / effects.get_rate_multiplier()
	spend_shot_durability()
	effects.on_shot_fired()
	var projectile := MagicProjectile.new()
	get_tree().current_scene.add_child(projectile)
	projectile.setup(self, wielder, get_aim_origin() + get_aim_direction() * 0.65, get_aim_direction(), projectile_damage, projectile_speed)
	effects.track_projectile(projectile)
	if wielder.has_method("on_rifle_fired"):
		wielder.on_rifle_fired(false)
	state_changed.emit()


func set_primary_held(held: bool) -> void:
	primary_held = held


func unequip() -> void:
	primary_held = false
	super.unequip()


func reset_weapon() -> void:
	fire_cooldown_remaining = 0.0
	primary_held = false
	state_changed.emit()


func request_reload() -> void:
	try_special_activation()


func get_weapon_status() -> String:
	return "CHANNEL %.1fs" % fire_cooldown_remaining if fire_cooldown_remaining > 0.0 else effect_status_or("ARCANE READY")
