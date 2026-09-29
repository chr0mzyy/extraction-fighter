class_name WeaponBase
extends Node3D

signal hit_confirmed(headshot: bool)
signal state_changed
signal presentation_fired

@export var weapon_display_name: String = "Weapon"
@export var automatic_fire: bool = false

var wielder: CharacterBody3D
var equipped: bool = false
var item_definition: ItemDefinition
var item_instance: ItemInstance
var effects := WeaponEffectRuntime.new()
var last_melee_wear_frame: int = -1
var presentation_profile := WeaponPresentationLibrary.for_family(&"generic")
var last_dry_fire_msec: int = -10000


func setup(actor: CharacterBody3D) -> void:
	wielder = actor
	presentation_profile = WeaponPresentationLibrary.for_family(_infer_family())


func configure_from_item(definition: ItemDefinition, instance: ItemInstance) -> void:
	item_definition = definition
	item_instance = instance
	weapon_display_name = definition.display_name
	presentation_profile = WeaponPresentationLibrary.for_family(definition.weapon_family)
	_apply_definition_stats(definition)
	effects.configure(self, wielder, definition, instance)
	effects.apply_static_stats()
	for child: Node in get_children():
		if child.has_method("configure_variant"):
			child.configure_variant(definition)


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
	if not can_operate():
		return
	effects.request_special()


func set_primary_held(_held: bool) -> void:
	pass


func reset_weapon() -> void:
	pass


func cancel_combat() -> void:
	set_primary_held(false)
	secondary_released()


func get_damage_response(_info: DamageInfo) -> Dictionary:
	return {}


func is_aiming_down_sights() -> bool:
	return false


func uses_ammunition() -> bool:
	return false


func get_ammo_text() -> String:
	return ""


func get_weapon_status() -> String:
	if is_broken():
		return "BROKEN"
	return effect_status_or("READY")


func get_presentation_profile() -> WeaponPresentationProfile:
	return presentation_profile


func notify_weapon_fired(ads: bool = false) -> void:
	presentation_fired.emit()
	if not is_instance_valid(wielder):
		return
	if wielder.has_method("on_weapon_fired"):
		wielder.on_weapon_fired(presentation_profile.family, ads)
	elif presentation_profile.family == &"sniper" and wielder.has_method("on_sniper_fired"):
		wielder.on_sniper_fired(ads)
	elif wielder.has_method("on_rifle_fired"):
		wielder.on_rifle_fired(ads)


func notify_weapon_trace(end_position: Vector3, hit: bool = false) -> void:
	if is_instance_valid(wielder) and wielder.has_method("emit_combat_feedback"):
		wielder.emit_combat_feedback(&"weapon_trace", {
			"position": end_position,
			"hit": hit,
			"family": presentation_profile.family,
			"duration": presentation_profile.tracer_duration,
		})


func notify_dry_fire() -> void:
	var now := Time.get_ticks_msec()
	if now - last_dry_fire_msec < 150:
		return
	last_dry_fire_msec = now
	if is_instance_valid(wielder) and wielder.has_method("on_empty_weapon"):
		wielder.on_empty_weapon()


func can_operate() -> bool:
	if not is_broken():
		return true
	if is_instance_valid(wielder) and wielder.has_method("emit_skill_feedback"):
		wielder.emit_skill_feedback(&"broken_weapon", {"name": weapon_display_name})
	return false


func is_broken() -> bool:
	return item_instance != null and item_instance.is_broken()


func get_durability_text() -> String:
	if item_instance == null or item_instance.max_durability <= 0.0:
		return ""
	return "%d / %d" % [ceili(item_instance.current_durability), ceili(item_instance.max_durability)]


func spend_shot_durability() -> void:
	if _durability_active() and item_instance != null:
		DurabilityService.apply_weapon_use(item_instance, DurabilityService.SHOT_WEAR)


func spend_melee_hit_durability() -> void:
	var frame := Engine.get_physics_frames()
	if frame == last_melee_wear_frame:
		return
	last_melee_wear_frame = frame
	if _durability_active() and item_instance != null:
		DurabilityService.apply_weapon_use(item_instance, DurabilityService.MELEE_HIT_WEAR)


func _durability_active() -> bool:
	return is_instance_valid(wielder) and wielder.has_method("uses_dungeon_durability") and bool(wielder.uses_dungeon_durability())


func effect_status_or(fallback: String) -> String:
	var hint := effects.get_status_hint()
	return hint if not hint.is_empty() else fallback


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


func make_damage_info(base_damage: float, target: Node, damage_type: StringName, headshot: bool, melee: bool, hit_position: Vector3, knockback: Vector3) -> DamageInfo:
	var final_damage := effects.modify_damage(base_damage, target, headshot, melee)
	var info := DamageInfo.new(final_damage, wielder, damage_type, headshot, melee, hit_position, knockback)
	info.armor_penetration = effects.armor_penetration()
	if is_instance_valid(wielder) and wielder.has_method("consume_phase_penetration"):
		info.armor_penetration = maxf(info.armor_penetration, float(wielder.consume_phase_penetration()))
	return info


func resolve_damage(target: Node, info: DamageInfo, heavy_attack: bool = false) -> Dictionary:
	var result: Dictionary = target.receive_damage(info)
	result["armor_hit"] = target.has_method("has_armor_feedback") and bool(target.has_armor_feedback()) and float(result.get("applied", 0.0)) > 0.0
	result["heavy_attack"] = heavy_attack
	result["critical"] = effects.last_damage_was_critical
	result["proc"] = effects.last_damage_was_proc
	if is_instance_valid(wielder) and wielder.has_method("on_damage_dealt_feedback"):
		wielder.on_damage_dealt_feedback(target, info, result)
	if float(result.get("applied", 0.0)) > 0.0:
		if info.is_melee:
			spend_melee_hit_durability()
		hit_confirmed.emit(info.headshot)
		effects.on_damage_dealt(target, info, result, heavy_attack)
		if info.is_melee and heavy_attack and is_instance_valid(wielder) and wielder.has_method("request_combat_hit_stop"):
			wielder.request_combat_hit_stop(0.042)
		if is_instance_valid(wielder) and wielder.has_method("notify_gear_damage_dealt"):
			wielder.notify_gear_damage_dealt(target, info, result, heavy_attack)
	return result


func notify_attack_missed() -> void:
	effects.on_attack_missed()


func try_special_activation() -> bool:
	return effects.request_special()


func try_ricochet_hit(origin: Vector3, first_hit: Dictionary, max_distance: float) -> Dictionary:
	if first_hit.is_empty() or not effects.should_ricochet():
		return {}
	var hit_position: Vector3 = first_hit.get("position", origin)
	var normal: Vector3 = first_hit.get("normal", Vector3.UP)
	var incoming := (hit_position - origin).normalized()
	var reflected := incoming.bounce(normal).normalized()
	var query := PhysicsRayQueryParameters3D.create(hit_position + normal * 0.04, hit_position + normal * 0.04 + reflected * max_distance * 0.55, 1 | 2 | 4, get_query_exclusions())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _apply_definition_stats(definition: ItemDefinition) -> void:
	if definition.damage > 0.0:
		if _has_property(&"body_damage"): set("body_damage", definition.damage)
		elif _has_property(&"light_damage"): set("light_damage", definition.damage)
		elif _has_property(&"projectile_damage"): set("projectile_damage", definition.damage)
	if definition.heavy_damage > 0.0 and _has_property(&"heavy_damage"): set("heavy_damage", definition.heavy_damage)
	if definition.headshot_damage > 0.0 and _has_property(&"headshot_damage"): set("headshot_damage", definition.headshot_damage)
	if definition.magazine_size > 0 and _has_property(&"magazine_size"):
		set("magazine_size", definition.magazine_size)
		if _has_property(&"ammo"): set("ammo", definition.magazine_size)
	if definition.reload_time > 0.0 and _has_property(&"reload_duration"): set("reload_duration", definition.reload_time)
	if definition.fire_rate > 0.0:
		if _has_property(&"fire_delay"): set("fire_delay", 1.0 / definition.fire_rate)
		elif _has_property(&"shot_cooldown"): set("shot_cooldown", 1.0 / definition.fire_rate)
	if definition.block_reduction > 0.0 and _has_property(&"blocked_damage_multiplier"): set("blocked_damage_multiplier", 1.0 - definition.block_reduction)
	if definition.deflect_window > 0.0 and _has_property(&"perfect_deflect_duration"): set("perfect_deflect_duration", definition.deflect_window)
	for property_key: Variant in definition.special_parameters:
		var property_name := StringName(String(property_key))
		if _has_property(property_name): set(property_name, definition.special_parameters[property_key])


func _has_property(property_name: StringName) -> bool:
	for property: Dictionary in get_property_list():
		if property.name == property_name: return true
	return false


func _infer_family() -> StringName:
	if self is WarNodachiWeapon: return &"nodachi"
	if self is KnightSwordWeapon: return &"sword"
	if self is KatanaWeapon: return &"katana"
	if self is FalconBurstWeapon: return &"burst_rifle"
	if self is IroncladRifleWeapon: return &"battle_rifle"
	if self is ServiceGlockWeapon: return &"pistol"
	if self is TwinGlockWeapon: return &"akimbo_pistols"
	if self is SniperWeapon: return &"sniper"
	if self is ArcaneWandWeapon: return &"magic"
	if self is VanguardRifleWeapon: return &"assault_rifle"
	return &"generic"
