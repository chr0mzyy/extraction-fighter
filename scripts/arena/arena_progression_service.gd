class_name ArenaProgressionService
extends RefCounted

const MAX_RESULT_HISTORY := 128
const MAX_ACCOUNT_XP := 1000000000
const MAX_STYLE_TOKENS := 1000000000


static func calculate(result: ArenaMatchResult) -> Dictionary:
	if result == null or result.abandoned or result.result_id.is_empty():
		return {"eligible": false, "reason": "Match was not completed"}
	var stats := result.local_player_stats()
	if stats.is_empty():
		return {"eligible": false, "reason": "Local participant is missing"}
	var won := result.local_player_won()
	var kills := maxi(0, int(stats.get("kills", 0)))
	var damage := maxf(0.0, float(stats.get("damage_dealt", 0.0)))
	var headshots := maxi(0, int(stats.get("headshots", 0)))
	var account_xp := 90 + (50 if won else 0) + mini(120, kills * 15) + mini(180, floori(damage / 18.0)) + mini(50, headshots * 5)
	var style_tokens := 12 + (8 if won else 0) + mini(20, kills * 2)
	var mastery: Dictionary = {}
	var family_damage: Dictionary = stats.get("weapon_damage_by_family", {}) as Dictionary
	var family_hits: Dictionary = stats.get("weapon_hits_by_family", {}) as Dictionary
	var family_kills: Dictionary = stats.get("weapon_kills_by_family", {}) as Dictionary
	var used_families: Array[String] = []
	for raw_family: Variant in family_damage.keys():
		var family := String(raw_family)
		if StringName(family) in ArenaEquipmentResolver.FAMILY_ORDER and float(family_damage.get(raw_family, 0.0)) > 0.0 and not used_families.has(family):
			used_families.append(family)
	for raw_family: Variant in family_hits.keys():
		var family := String(raw_family)
		if StringName(family) in ArenaEquipmentResolver.FAMILY_ORDER and int(family_hits.get(raw_family, 0)) > 0 and not used_families.has(family):
			used_families.append(family)
	for family: String in used_families:
		var mastery_xp := 20
		mastery_xp += mini(120, floori(float(family_damage.get(family, 0.0)) / 20.0))
		mastery_xp += mini(60, int(family_hits.get(family, 0)) * 2)
		mastery_xp += mini(60, int(family_kills.get(family, 0)) * 12)
		mastery[family] = mastery_xp
	return {
		"eligible": true,
		"result_id": result.result_id,
		"won": won,
		"account_xp": account_xp,
		"style_tokens": style_tokens,
		"mastery": mastery,
	}


static func grant_and_save(result: ArenaMatchResult, path: String = PlayerProfile.SAVE_PATH) -> Dictionary:
	var snapshot := PlayerProfile.to_save_data()
	var grant := grant_once(result)
	if not bool(grant.get("granted", false)):
		return grant
	if PlayerProfile.save_profile(path):
		return grant
	var save_error := PlayerProfile.last_error
	PlayerProfile.apply_save_data(snapshot)
	return {"granted": false, "save_failed": true, "reason": save_error,
		"account_xp": 0, "style_tokens": 0, "mastery": {}}


static func grant_once(result: ArenaMatchResult) -> Dictionary:
	var calculated := calculate(result)
	if not bool(calculated.get("eligible", false)):
		calculated["granted"] = false
		return calculated
	var result_id := String(calculated.result_id)
	if PlayerProfile.arena_progression_result_ids.has(result_id):
		return {
			"eligible": true,
			"granted": false,
			"duplicate": true,
			"result_id": result_id,
			"account_xp": 0,
			"style_tokens": 0,
			"mastery": {},
		}
	PlayerProfile.account_xp = mini(MAX_ACCOUNT_XP, PlayerProfile.account_xp + int(calculated.account_xp))
	PlayerProfile.account_level = level_for_xp(PlayerProfile.account_xp)
	PlayerProfile.style_tokens = mini(MAX_STYLE_TOKENS, PlayerProfile.style_tokens + int(calculated.style_tokens))
	var unlocked_cosmetics: Array[String] = []
	for family: Variant in (calculated.mastery as Dictionary).keys():
		var family_id := String(family)
		var before := maxi(0, int(PlayerProfile.weapon_mastery_xp.get(family_id, 0)))
		PlayerProfile.weapon_mastery_xp[family_id] = mini(MAX_ACCOUNT_XP, before + int(calculated.mastery[family]))
		_unlock_mastery_cosmetics(StringName(family_id), unlocked_cosmetics)
	PlayerProfile.record_arena_progression_result(result_id)
	PlayerProfile.statistics["matches_completed"] = int(PlayerProfile.statistics.get("matches_completed", 0)) + 1
	PlayerProfile.statistics["matches_won"] = int(PlayerProfile.statistics.get("matches_won", 0)) + (1 if bool(calculated.won) else 0)
	var stats := result.local_player_stats()
	PlayerProfile.statistics["kills"] = int(PlayerProfile.statistics.get("kills", 0)) + maxi(0, int(stats.get("kills", 0)))
	PlayerProfile.statistics["deaths"] = int(PlayerProfile.statistics.get("deaths", 0)) + maxi(0, int(stats.get("deaths", 0)))
	PlayerProfile.statistics["damage"] = float(PlayerProfile.statistics.get("damage", 0.0)) + maxf(0.0, float(stats.get("damage_dealt", 0.0)))
	PlayerProfile.profile_changed.emit()
	calculated["granted"] = true
	calculated["account_level"] = PlayerProfile.account_level
	calculated["unlocked_cosmetics"] = unlocked_cosmetics
	return calculated


static func level_for_xp(xp: int) -> int:
	var level := 1
	var threshold := xp_required_for_level(2)
	while xp >= threshold and level < 100:
		level += 1
		threshold = xp_required_for_level(level + 1)
	return level


static func xp_required_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return roundi(250.0 * pow(float(level - 1), 1.45))


static func mastery_level_for_xp(xp: int) -> int:
	return clampi(1 + xp / 400, 1, 20)


static func mastery_xp_in_level(xp: int) -> int:
	return maxi(0, xp % 400)


static func _unlock_mastery_cosmetics(family: StringName, unlocked: Array[String]) -> void:
	var level := mastery_level_for_xp(int(PlayerProfile.weapon_mastery_xp.get(String(family), 0)))
	var cosmetics := ArenaEquipmentResolver.cosmetics_for_family(family)
	var unlock_indexes: Array[int] = []
	if level >= 5:
		unlock_indexes.append(1)
	if level >= 15:
		unlock_indexes.append(2)
	for index: int in unlock_indexes:
		if index >= cosmetics.size():
			continue
		var skin_id := String(cosmetics[index].skin_id)
		if not PlayerProfile.unlocked_cosmetic_ids.has(skin_id):
			PlayerProfile.unlocked_cosmetic_ids.append(skin_id)
			unlocked.append(skin_id)
