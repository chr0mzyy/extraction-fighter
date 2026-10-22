class_name ArenaRebornTestSuite
extends RefCounted

const TEST_PATH := "user://arena_reborn_profile_test.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	_test_catalog_and_fairness(failures)
	_test_new_profile_access(failures)
	_test_legacy_migration(failures)
	_test_progression_and_persistence(failures)
	_test_reward_save_failure(failures)
	_test_camera_policy(failures)
	if not PlayerProfile.apply_save_data(snapshot, false):
		failures.append("Test cleanup could not restore the starting profile snapshot")
	_remove_test_files()
	return failures


func _test_catalog_and_fairness(failures: Array[String]) -> void:
	if ArenaEquipmentResolver.FAMILY_ORDER.size() != 10:
		failures.append("Arena catalog does not expose exactly 10 gameplay families")
	if ArenaEquipmentResolver.all_skill_ids().size() != 10:
		failures.append("Arena catalog does not expose all 10 implemented skills")
	for family: StringName in ArenaEquipmentResolver.FAMILY_ORDER:
		var gameplay := ArenaEquipmentResolver.gameplay_definition(family)
		var cosmetics := ArenaEquipmentResolver.cosmetics_for_family(family)
		if gameplay == null or cosmetics.is_empty():
			failures.append("Missing gameplay or cosmetic definition for %s" % String(family))
			continue
		var expected := ArenaEquipmentResolver.gameplay_fingerprint(family, cosmetics[0].skin_id)
		for cosmetic: WeaponCosmeticDefinition in cosmetics:
			var actual := ArenaEquipmentResolver.gameplay_fingerprint(family, cosmetic.skin_id)
			if actual != expected:
				failures.append("Skin %s changes gameplay for %s" % [String(cosmetic.skin_id), String(family)])
			if not (actual.get("affixes", []) as Array).is_empty() or not String(actual.get("special", "")).is_empty():
				failures.append("Legacy affix/Mythic effect leaked through skin %s" % String(cosmetic.skin_id))
	if ArenaEquipmentResolver.gameplay_definition(&"sniper").headshot_damage >= 100.0:
		failures.append("Standard sniper can one-shot a full-health Arena player")
	var mode_1v1 := load("res://resources/arena/mode_1v1.tres") as ArenaModeDefinition
	var mode_2v2 := load("res://resources/arena/mode_2v2.tres") as ArenaModeDefinition
	if mode_1v1.max_reward_exchanges != 0 or mode_2v2.max_reward_exchanges != 0:
		failures.append("Legacy item stealing remains enabled in active Arena modes")


func _test_new_profile_access(failures: Array[String]) -> void:
	PlayerProfile.reset_to_defaults(false)
	if PlayerProfile.unlocked_cosmetic_ids.size() < 10:
		failures.append("New profile is missing one or more default family skins")
	for family: StringName in ArenaEquipmentResolver.FAMILY_ORDER:
		if ArenaEquipmentResolver.resolve_item(family, ArenaEquipmentResolver.default_skin_for_family(family)) == null:
			failures.append("New profile cannot resolve %s" % String(family))
	if not PlayerProfile.equip_arena_skill(0, "grapple", false) or not PlayerProfile.equip_arena_skill(1, "blink", false):
		failures.append("Unowned Arena skills were not selectable from the universal arsenal")
	if PlayerProfile.get_skill_power() != 200:
		failures.append("Grapple + Blink did not enforce the exact 200 Power total")
	if PlayerProfile.equip_arena_skill(0, "invisibility", false):
		failures.append("Skill loadout above 200 Power was accepted")
	if not bool(PlayerProfile.validate_arena_loadout().get("valid", false)):
		failures.append("Default Arena loadout is invalid")


func _test_legacy_migration(failures: Array[String]) -> void:
	PlayerProfile.reset_to_defaults(false)
	for legacy_id: String in ["phantom_katana", "skybreaker"]:
		var definition := PlayerProfile.get_definition(legacy_id)
		var instance := ItemInstance.create(definition, "legacy:%s" % legacy_id)
		PlayerProfile.owned_item_ids.append(legacy_id)
		PlayerProfile.owned_item_instances.append(instance)
		PlayerProfile.instance_index[instance.instance_id] = instance
	PlayerProfile.gold = 742
	PlayerProfile.scrap = 91
	var legacy := PlayerProfile.to_save_data()
	legacy["save_version"] = 6
	for key: String in ["arena_weapon_families", "selected_weapon_cosmetics", "unlocked_cosmetic_ids", "cosmetic_gear_slots", "account_xp", "account_level", "style_tokens", "weapon_mastery_xp", "arena_progression_result_ids", "statistics"]:
		legacy.erase(key)
	var legacy_instance_count := (legacy.owned_item_instances as Array).size()
	var legacy_gold := int(legacy.gold)
	var legacy_scrap := int(legacy.scrap)
	if not PlayerProfile.apply_save_data(legacy, false):
		failures.append("Version-6 profile did not migrate")
		return
	if PlayerProfile.owned_item_instances.size() != legacy_instance_count or PlayerProfile.gold != legacy_gold or PlayerProfile.scrap != legacy_scrap:
		failures.append("Legacy inventory or currency changed during migration")
	if not PlayerProfile.unlocked_cosmetic_ids.has("phantom_katana") or not PlayerProfile.unlocked_cosmetic_ids.has("skybreaker"):
		failures.append("Verified legacy weapon ownership did not map to cosmetic unlocks")
	var migrated_again := PlayerProfile.to_save_data()
	if not PlayerProfile.apply_save_data(migrated_again, false):
		failures.append("Migrated version-7 profile could not be reapplied")
	elif PlayerProfile.unlocked_cosmetic_ids.size() != (migrated_again.unlocked_cosmetic_ids as Array).size():
		failures.append("Profile migration duplicated cosmetic unlocks")


func _test_progression_and_persistence(failures: Array[String]) -> void:
	PlayerProfile.reset_to_defaults(false)
	PlayerProfile.weapon_mastery_xp["katana"] = 1590
	var mode := load("res://resources/arena/mode_1v1.tres") as ArenaModeDefinition
	var local := ArenaParticipantState.new(&"local", "YOU", 0, 0, null, true)
	local.kills = 5
	local.deaths = 2
	local.damage_dealt = 780.0
	local.headshots = 3
	local.weapon_damage_by_family["katana"] = 280.0
	local.weapon_damage_by_family["pistol"] = 500.0
	local.weapon_hits_by_family["katana"] = 6
	local.weapon_hits_by_family["pistol"] = 14
	local.weapon_kills_by_family["katana"] = 2
	local.weapon_kills_by_family["pistol"] = 3
	var enemy := ArenaParticipantState.new(&"enemy", "BOT", 1, 0, null, false)
	var participants: Array[ArenaParticipantState] = [local, enemy]
	var result := ArenaMatchResult.new().configure(mode, 0, 4, 2, 6, participants, false, "arena:test:progression")
	var first := ArenaProgressionService.grant_once(result)
	var xp_after := PlayerProfile.account_xp
	var tokens_after := PlayerProfile.style_tokens
	var mastery_after := PlayerProfile.weapon_mastery_xp.duplicate(true)
	var second := ArenaProgressionService.grant_once(result)
	if not bool(first.get("granted", false)) or int(first.get("account_xp", 0)) <= 0 or int(first.get("style_tokens", 0)) <= 0:
		failures.append("Completed match did not grant cosmetic progression")
	if not PlayerProfile.unlocked_cosmetic_ids.has("ronin_katana"):
		failures.append("Mastery level 5 did not unlock the family cosmetic")
	if not bool(second.get("duplicate", false)) or PlayerProfile.account_xp != xp_after or PlayerProfile.style_tokens != tokens_after or PlayerProfile.weapon_mastery_xp != mastery_after:
		failures.append("Repeated result granted progression more than once")
	var power_before := PlayerProfile.get_skill_power()
	PlayerProfile.account_xp = 999999
	PlayerProfile.account_level = ArenaProgressionService.level_for_xp(PlayerProfile.account_xp)
	PlayerProfile.style_tokens = 999999
	if PlayerProfile.get_skill_power() != power_before or ArenaEquipmentResolver.gameplay_definition(&"katana").damage != 28.0:
		failures.append("Account progression changed Arena gameplay power")
	if not PlayerProfile.save_profile(TEST_PATH):
		failures.append("Version-7 profile could not be saved atomically")
	elif not PlayerProfile.load_profile(TEST_PATH, false) or not PlayerProfile.arena_progression_result_ids.has("arena:test:progression"):
		failures.append("Arena progression did not persist after reload")


func _test_camera_policy(failures: Array[String]) -> void:
	ArenaSessionRequest.configure(&"1v1", &"NORMAL", &"CASUAL")
	if not ArenaSessionRequest.allows_camera_switch():
		failures.append("Casual camera switching is disabled")
	ArenaSessionRequest.configure(&"1v1", &"NORMAL", &"RANKED")
	if ArenaSessionRequest.allows_camera_switch() or ArenaSessionRequest.can_launch_ranked():
		failures.append("Future Ranked policy is not FPP-only and disabled")
	ArenaSessionRequest.configure(&"1v1", &"NORMAL", &"CASUAL")


func _test_reward_save_failure(failures: Array[String]) -> void:
	PlayerProfile.reset_to_defaults(false)
	var mode := load("res://resources/arena/mode_1v1.tres") as ArenaModeDefinition
	var local := ArenaParticipantState.new(&"local", "YOU", 0, 0, null, true)
	var enemy := ArenaParticipantState.new(&"enemy", "BOT", 1, 0, null, false)
	var participants: Array[ArenaParticipantState] = [local, enemy]
	var result := ArenaMatchResult.new().configure(mode, 1, 0, 4, 4, participants, false, "arena:test:save-failure")
	var idle_grant := ArenaProgressionService.calculate(result)
	if not (idle_grant.mastery as Dictionary).is_empty():
		failures.append("Unused loadout weapons received idle mastery XP")
	local.weapon_damage_by_family["pistol"] = 150.0
	local.weapon_hits_by_family["pistol"] = 6
	local.damage_dealt = 150.0
	result.configure(mode, 1, 0, 4, 4, participants, false, "arena:test:save-failure")
	var before := PlayerProfile.to_save_data()
	var failed := ArenaProgressionService.grant_and_save(result, "user://missing-arena-test-directory/profile.json")
	if not bool(failed.get("save_failed", false)) or bool(failed.get("granted", false)) or PlayerProfile.to_save_data() != before:
		failures.append("Failed reward save did not roll back currency, mastery and grant history")
	var retried := ArenaProgressionService.grant_and_save(result, TEST_PATH)
	if not bool(retried.get("granted", false)) or (retried.mastery as Dictionary).has("katana"):
		failures.append("Reward save retry failed or awarded an unused family")
	if not PlayerProfile.load_profile(TEST_PATH, false):
		failures.append("Retried reward could not be reloaded")
	var duplicate := ArenaProgressionService.grant_and_save(result, TEST_PATH)
	if not bool(duplicate.get("duplicate", false)):
		failures.append("Reload/retry granted the same match twice")
	result.abandoned = true
	if bool(ArenaProgressionService.calculate(result).get("eligible", false)):
		failures.append("Abandoned match was eligible for progression")


func _remove_test_files() -> void:
	for path: String in [TEST_PATH, "%s.backup" % TEST_PATH, "%s.tmp" % TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
