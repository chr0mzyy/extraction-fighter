class_name WeaponEffectRuntime
extends RefCounted

var weapon: WeaponBase
var wielder: CharacterBody3D
var special_effect_id: StringName
var affix_tiers: Dictionary = {}
var random := RandomNumberGenerator.new()
var last_damage_time: float = -100.0
var relentless_target_id: int = 0
var relentless_hits: int = 0
var bloodlust_remaining: float = 0.0
var counterweight_ready: bool = false
var duelist_ready: bool = false
var shock_target_id: int = 0
var shock_hits: int = 0
var special_counter: int = 0
var special_window: float = 0.0
var special_buff_remaining: float = 0.0
var empowered_attacks: int = 0
var rounds_since_reload: int = 0
var rift_orb: Node3D
var rift_cooldown: float = 0.0
var parkour_ready: bool = false
var quickdraw_remaining: float = 0.0
var special_target_id: int = 0
var special_last_hit_time: float = -100.0


func configure(p_weapon: WeaponBase, actor: CharacterBody3D, definition: ItemDefinition, instance: ItemInstance) -> void:
	weapon = p_weapon
	wielder = actor
	special_effect_id = definition.special_effect_id if definition != null else &""
	affix_tiers.clear()
	if instance != null:
		for index: int in instance.affix_ids.size():
			affix_tiers[instance.affix_ids[index]] = instance.affix_tiers[index] if index < instance.affix_tiers.size() else 1
	random.seed = hash(instance.instance_id if instance != null else String(definition.id))


func tick(delta: float) -> void:
	bloodlust_remaining = maxf(0.0, bloodlust_remaining - delta)
	special_window = maxf(0.0, special_window - delta)
	special_buff_remaining = maxf(0.0, special_buff_remaining - delta)
	rift_cooldown = maxf(0.0, rift_cooldown - delta)
	quickdraw_remaining = maxf(0.0, quickdraw_remaining - delta)
	if is_instance_valid(rift_orb) and rift_orb.is_queued_for_deletion():
		rift_orb = null


func has(affix_id: StringName) -> bool:
	return affix_tiers.has(affix_id)


func tier(affix_id: StringName) -> int:
	return int(affix_tiers.get(affix_id, 0))


func value(affix_id: StringName) -> float:
	var definition := AffixDatabase.get_definition(affix_id)
	return definition.value_for_tier(tier(affix_id)) if definition != null and tier(affix_id) > 0 else 0.0


func apply_static_stats() -> void:
	if weapon == null:
		return
	var damage_multiplier := 1.0
	var rate_multiplier := 1.0
	if has(&"heavy"):
		damage_multiplier *= 1.0 + value(&"heavy") / 100.0
		rate_multiplier *= 1.0 - AffixDatabase.get_definition(&"heavy").secondary_for_tier(tier(&"heavy")) / 100.0
	if has(&"rapid"):
		rate_multiplier *= 1.0 + value(&"rapid") / 100.0
		damage_multiplier *= 1.0 - AffixDatabase.get_definition(&"rapid").secondary_for_tier(tier(&"rapid")) / 100.0
	if has(&"gambler"):
		damage_multiplier *= 0.95
	for property_name: StringName in [&"body_damage", &"light_damage", &"heavy_damage", &"projectile_damage"]:
		_multiply_property(property_name, damage_multiplier)
	if has(&"deadeye"):
		_multiply_property(&"headshot_damage", 1.0 + value(&"deadeye") / 100.0)
	for property_name: StringName in [&"fire_delay", &"light_recovery", &"heavy_recovery", &"shot_cooldown"]:
		_multiply_property(property_name, 1.0 / maxf(rate_multiplier, 0.1))
	if has(&"stable"):
		var multiplier := 1.0 - value(&"stable") / 100.0
		_multiply_property(&"hipfire_spread_degrees", multiplier)
		_multiply_property(&"ads_spread_degrees", multiplier)
	if has(&"hipfire"):
		_multiply_property(&"hipfire_spread_degrees", 1.0 - value(&"hipfire") / 100.0)
	if has(&"fast_reload"):
		_multiply_property(&"reload_duration", 1.0 / (1.0 + value(&"fast_reload") / 100.0))
	if has(&"reach"):
		var multiplier := 1.0 + value(&"reach") / 100.0
		_multiply_property(&"light_range", multiplier)
		_multiply_property(&"heavy_range", multiplier)


func modify_damage(base_damage: float, target: Node, headshot: bool, is_melee: bool) -> float:
	var amount := base_damage
	var now := Time.get_ticks_msec() / 1000.0
	if has(&"executioner") and _health_ratio(target) < 0.3:
		amount *= 1.0 + value(&"executioner") / 100.0
	if has(&"first_strike") and now - last_damage_time >= 4.0:
		amount *= 1.0 + value(&"first_strike") / 100.0
	if has(&"relentless") and target != null:
		var target_id := target.get_instance_id()
		if target_id == relentless_target_id and now - last_damage_time < 2.0:
			relentless_hits = mini(relentless_hits + 1, 4)
		else:
			relentless_target_id = target_id
			relentless_hits = 0
		amount *= 1.0 + value(&"relentless") / 100.0 * float(relentless_hits) / 4.0
	if has(&"glass_cannon"):
		amount *= 1.0 + value(&"glass_cannon") / 100.0
	if has(&"berserker") and is_instance_valid(wielder):
		amount *= 1.0 + value(&"berserker") / 100.0 * (1.0 - _health_ratio(wielder))
	if has(&"gambler") and random.randf() < value(&"gambler") / 100.0:
		amount *= 1.65
	if has(&"reckless") and is_instance_valid(wielder) and not wielder.is_on_floor():
		amount *= 1.0 + value(&"reckless") / 100.0
	if has(&"predator") and is_melee and target is Node3D and wielder is Node3D:
		var target_forward := -(target as Node3D).global_basis.z
		var incoming := ((wielder as Node3D).global_position - (target as Node3D).global_position).normalized()
		if target_forward.dot(incoming) < -0.35:
			amount *= 1.0 + value(&"predator") / 100.0
	if has(&"fresh_mag") and rounds_since_reload <= 3:
		amount *= 1.0 + value(&"fresh_mag") / 100.0
	if has(&"hollow_point"):
		amount *= 1.0 + value(&"hollow_point") / 100.0 if _armor_value(target) <= 3.0 else 0.92
	if has(&"armor_piercing") and _armor_value(target) <= 0.0:
		amount *= 0.96
	elif has(&"armor_piercing"):
		amount *= 1.0 + value(&"armor_piercing") / 100.0 * clampf(_armor_value(target) / 20.0, 0.15, 1.0)
	if has(&"duelist") and duelist_ready:
		amount *= 1.0 + value(&"duelist") / 100.0
		duelist_ready = false
	if weapon != null and is_instance_valid(wielder) and wielder.has_method("get_affix_damage_multiplier"):
		amount *= float(wielder.get_affix_damage_multiplier(target, headshot, is_melee))
	if special_effect_id == &"trident" and empowered_attacks > 0:
		amount *= 1.12
		empowered_attacks -= 1
	last_damage_time = now
	return amount


func on_shot_fired() -> void:
	rounds_since_reload += 1
	if is_instance_valid(wielder) and wielder.has_method("notify_affix_attack"):
		wielder.notify_affix_attack()


func on_attack_missed() -> void:
	if special_effect_id == &"quickfang":
		special_counter = 0
	if special_effect_id == &"trident":
		special_counter = 0


func on_damage_dealt(target: Node, info: DamageInfo, result: Dictionary, heavy_attack: bool = false) -> void:
	var applied := float(result.get("applied", 0.0))
	if applied <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_apply_elemental(target)
	if has(&"vampiric") and info.is_melee and is_instance_valid(wielder):
		wielder.health.heal(applied * value(&"vampiric") / 100.0)
	if bloodlust_remaining > 0.0 and has(&"bloodlust") and is_instance_valid(wielder):
		wielder.health.heal(applied * value(&"bloodlust") / 100.0)
	if has(&"momentum") and wielder.velocity.length() > 8.0:
		wielder.apply_temporary_movement_buff(1.0 + value(&"momentum") / 100.0, 1.2)
	if has(&"chaser") and target is CharacterBody3D:
		var away: Vector3 = (target.global_position - wielder.global_position).normalized()
		if (target as CharacterBody3D).velocity.dot(away) > 2.5:
			wielder.apply_temporary_movement_buff(1.0 + value(&"chaser") / 100.0, 1.2)
	if has(&"flow") and wielder.has_method("refund_recent_skill"):
		wielder.refund_recent_skill(value(&"flow") / 100.0)
	if has(&"echo") and random.randf() < value(&"echo") / 100.0:
		_echo_damage(target, applied * 0.3, info.is_melee)
	if has(&"shock"):
		var target_id := target.get_instance_id()
		shock_hits = shock_hits + 1 if target_id == shock_target_id else 1
		shock_target_id = target_id
		if shock_hits >= 3:
			shock_hits = 0
			if target.has_method("apply_stagger"): target.apply_stagger(0.18 + value(&"shock") * 0.005)
	if special_effect_id == &"bloodrush" and heavy_attack:
		special_counter = mini(special_counter + 1, 2)
	if special_effect_id == &"skybreaker" and info.headshot:
		special_window = 1.0
	if special_effect_id == &"rushfang":
		var rush_target_id := target.get_instance_id()
		if rush_target_id != special_target_id or now - special_last_hit_time > 1.1:
			special_counter = 0
		special_target_id = rush_target_id
		special_last_hit_time = now
		special_counter += 1
		if special_counter >= 5:
			special_counter = 0
			special_buff_remaining = 3.0
			wielder.apply_temporary_movement_buff(1.18, 3.0)
	if special_effect_id == &"trident":
		var trident_target_id := target.get_instance_id()
		if trident_target_id != special_target_id or now - special_last_hit_time > 0.55:
			special_counter = 0
		special_target_id = trident_target_id
		special_last_hit_time = now
		special_counter += 1
		if special_counter >= 3:
			special_counter = 0
			empowered_attacks = 3
			special_window = 3.0
	if special_effect_id == &"kingslayer" and info.headshot:
		special_window = 1.2
	if special_effect_id == &"quickfang":
		var quick_target_id := target.get_instance_id()
		if quick_target_id != special_target_id or now - special_last_hit_time > 1.5:
			special_counter = 0
		special_target_id = quick_target_id
		special_last_hit_time = now
		special_counter += 1
		if special_counter >= 3:
			special_counter = 0
			special_buff_remaining = 2.5
			wielder.apply_temporary_movement_buff(1.14, 2.5)
	if bool(result.get("killed", false)):
		on_kill(target, info)


func on_kill(target: Node, info: DamageInfo) -> void:
	if has(&"springloaded"): wielder.apply_temporary_jump_buff(1.0 + value(&"springloaded") / 100.0, 2.0)
	if has(&"charged"): wielder.reduce_skill_cooldowns(value(&"charged") / 100.0)
	if has(&"bloodlust"): bloodlust_remaining = 3.0
	if has(&"adrenaline"): wielder.reduce_movement_skill_cooldowns(value(&"adrenaline") / 100.0)
	if has(&"chain_reaction"): _transfer_elemental(target)
	if special_effect_id == &"phantom": special_window = 5.0
	if special_effect_id == &"hell_twins":
		special_buff_remaining = 2.0
		wielder.apply_temporary_air_control_buff(1.5, 2.0)


func on_block(perfect: bool) -> void:
	if has(&"counterweight"): counterweight_ready = true
	if perfect and has(&"duelist"): duelist_ready = true
	if perfect and special_effect_id == &"oathbreaker":
		empowered_attacks = 1
		special_window = 2.0


func on_traversal(event_name: StringName) -> void:
	if has(&"parkour") and event_name in [&"slide_jump", &"double_jump", &"landed"]:
		parkour_ready = true


func on_weapon_swap() -> void:
	if has(&"quickdraw"):
		quickdraw_remaining = 0.55


func on_reload_completed() -> void:
	rounds_since_reload = 0


func get_rate_multiplier() -> float:
	var result := 1.0
	if counterweight_ready:
		result *= 1.0 + value(&"counterweight") / 100.0
		counterweight_ready = false
	if parkour_ready:
		result *= 1.0 + value(&"parkour") / 100.0
		parkour_ready = false
	if quickdraw_remaining > 0.0:
		result *= 1.0 + value(&"quickdraw") / 100.0
	if weapon != null and is_instance_valid(wielder) and wielder.has_method("get_affix_rate_multiplier"):
		result *= float(wielder.get_affix_rate_multiplier())
	if special_effect_id in [&"rushfang", &"quickfang"] and special_buff_remaining > 0.0:
		result *= 1.35
	if special_effect_id == &"trident" and special_window > 0.0 and empowered_attacks > 0:
		result *= 1.45
	if has(&"mag_dump") and weapon != null and _has_property(weapon, &"ammo") and _has_property(weapon, &"magazine_size"):
		if float(weapon.get("ammo")) <= float(weapon.get("magazine_size")) * 0.2:
			result *= 1.0 + value(&"mag_dump") / 100.0
	return result


func get_reload_multiplier() -> float:
	var result := get_rate_multiplier()
	if special_effect_id == &"quickfang" and special_buff_remaining > 0.0:
		result *= 2.5
	return result


func get_spread_multiplier(ads: bool) -> float:
	var result := 1.0
	if has(&"aerial_accuracy") and is_instance_valid(wielder) and not wielder.is_on_floor(): result *= 1.0 - value(&"aerial_accuracy") / 100.0
	if has(&"reckless") and is_instance_valid(wielder) and wielder.is_on_floor(): result *= 1.18
	if special_effect_id == &"trident" and special_window > 0.0 and empowered_attacks > 0: result = 0.08
	if special_effect_id == &"hell_twins" and special_buff_remaining > 0.0 and not ads: result = 0.04
	return result


func get_recoil_multiplier() -> float:
	return 1.0 - value(&"stable") / 100.0


func get_status_hint() -> String:
	if special_effect_id == &"phantom" and special_window > 0.0: return "PHANTOM STEP READY  /  R"
	if special_effect_id == &"skybreaker" and special_window > 0.0: return "SKY DASH READY  /  R"
	if special_effect_id == &"kingslayer" and special_window > 0.0: return "KINGSLAYER LUNGE  /  R"
	if special_effect_id == &"rift_wand" and is_instance_valid(rift_orb) and rift_cooldown <= 0.0: return "RIFT ANCHOR  /  R"
	if special_effect_id == &"trident" and empowered_attacks > 0: return "EMPOWERED BURST"
	if special_effect_id in [&"rushfang", &"quickfang", &"hell_twins"] and special_buff_remaining > 0.0: return "MYTHIC SURGE %.1fs" % special_buff_remaining
	return ""


func get_lunge_multiplier() -> float:
	if special_effect_id == &"bloodrush":
		var result := 1.25 + special_counter * 0.18
		special_counter = maxi(0, special_counter - 1)
		return result
	if special_effect_id == &"oathbreaker" and special_window > 0.0 and empowered_attacks > 0:
		return 1.45
	return 1.0


func get_heavy_windup_multiplier() -> float:
	if special_effect_id == &"oathbreaker" and special_window > 0.0 and empowered_attacks > 0:
		empowered_attacks -= 1
		return 0.35
	return 1.0


func request_special() -> bool:
	if not is_instance_valid(wielder): return false
	if special_effect_id == &"phantom" and special_window > 0.0:
		special_window = 0.0
		wielder.activate_phantom_state(5.0)
		return true
	if special_effect_id == &"skybreaker" and special_window > 0.0:
		special_window = 0.0
		wielder.apply_special_dash(20.0)
		wielder.apply_temporary_movement_buff(2.0, 1.0)
		return true
	if special_effect_id == &"kingslayer" and special_window > 0.0:
		special_window = 0.0
		wielder.apply_special_dash(7.0)
		return true
	if special_effect_id == &"rift_wand" and is_instance_valid(rift_orb) and rift_cooldown <= 0.0:
		if wielder.teleport_to_safe_point(rift_orb.global_position):
			rift_orb.queue_free()
			rift_orb = null
			rift_cooldown = 8.0
			return true
	return false


func track_projectile(projectile: Node3D) -> void:
	if special_effect_id == &"rift_wand": rift_orb = projectile


func incoming_damage_multiplier() -> float:
	return 1.0 + (AffixDatabase.get_definition(&"glass_cannon").secondary_for_tier(tier(&"glass_cannon")) / 100.0 if has(&"glass_cannon") else 0.0)


func armor_penetration() -> float:
	return value(&"armor_piercing") / 100.0


func should_ricochet() -> bool:
	return has(&"ricochet") and random.randf() < value(&"ricochet") / 100.0


func movement_multiplier() -> float:
	return 1.0 + value(&"lightweight") / 100.0


func air_control_multiplier() -> float:
	return 1.0 + value(&"airborne") / 100.0


func slide_multiplier() -> float:
	return 1.0 + value(&"slider") / 100.0


func _apply_elemental(target: Node) -> void:
	var status := target.get_node_or_null("StatusEffects") as StatusEffectComponent
	if status == null: return
	if has(&"burning") and random.randf() < value(&"burning") / 100.0: status.apply_status(&"burning", 2.5, value(&"burning"), wielder)
	if has(&"frost"): status.apply_status(&"frost", 1.4, value(&"frost"), wielder)
	if has(&"poisoned") and random.randf() < value(&"poisoned") / 100.0: status.apply_status(&"poisoned", 4.0, value(&"poisoned"), wielder)
	if has(&"bleeding") and random.randf() < value(&"bleeding") / 100.0: status.apply_status(&"bleeding", 3.2, value(&"bleeding"), wielder)
	if has(&"void"): status.apply_status(&"void", 3.0, value(&"void"), wielder)


func force_apply_elemental_for_test(target: Node, affix_id: StringName) -> void:
	var status := target.get_node_or_null("StatusEffects") as StatusEffectComponent
	if status != null and has(affix_id): status.apply_status(affix_id, 2.0, value(affix_id), wielder)


func force_echo_for_test(target: Node, amount: float, melee: bool = false) -> void:
	_echo_damage(target, amount, melee)


func _echo_damage(target: Node, amount: float, melee: bool) -> void:
	await weapon.get_tree().create_timer(0.4).timeout
	if is_instance_valid(target) and target.has_method("receive_damage"):
		target.receive_damage(DamageInfo.new(amount, wielder, &"echo", false, melee, (target as Node3D).global_position, Vector3.ZERO, false, true))


func _transfer_elemental(target: Node) -> void:
	var source_status := target.get_node_or_null("StatusEffects") as StatusEffectComponent
	if source_status == null: return
	var snapshot := source_status.get_elemental_snapshot()
	for actor: Node in wielder.get_tree().get_nodes_in_group("damageable"):
		if actor == target or actor == wielder or not actor is Node3D: continue
		if (actor as Node3D).global_position.distance_to((target as Node3D).global_position) > 6.0: continue
		var status := actor.get_node_or_null("StatusEffects") as StatusEffectComponent
		if status == null: continue
		for status_id: Variant in snapshot:
			var data: Dictionary = snapshot[status_id]
			status.apply_status(StringName(String(status_id)), float(data.remaining) * 0.6, float(data.strength) * value(&"chain_reaction") / 100.0, wielder)
		break


func _health_ratio(target: Node) -> float:
	if target == null: return 1.0
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	return health.current_health / maxf(health.max_health, 1.0) if health != null else 1.0


func _armor_value(target: Node) -> float:
	return float(target.get_total_armor()) if target != null and target.has_method("get_total_armor") else 0.0


func _multiply_property(property_name: StringName, multiplier: float) -> void:
	if _has_property(weapon, property_name):
		weapon.set(property_name, float(weapon.get(property_name)) * multiplier)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.name == property_name: return true
	return false
