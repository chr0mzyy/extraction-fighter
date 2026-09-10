class_name AffixDatabase
extends RefCounted

const WEAPON := ItemDefinition.ItemType.WEAPON
const GEAR := ItemDefinition.ItemType.GEAR
const MELEE: Array[StringName] = [&"katana", &"nodachi", &"sword"]
const GUNS: Array[StringName] = [&"sniper", &"assault_rifle", &"burst_rifle", &"battle_rifle", &"pistol", &"akimbo_pistols"]

static var _definitions: Array[AffixDefinition] = []
static var _index: Dictionary = {}


static func all() -> Array[AffixDefinition]:
	_ensure_built()
	return _definitions


static func get_definition(affix_id: StringName) -> AffixDefinition:
	_ensure_built()
	return _index.get(String(affix_id)) as AffixDefinition


static func _ensure_built() -> void:
	if not _definitions.is_empty():
		return
	# Combat
	_add(&"heavy", "Heavy", "+{value}% damage, -{secondary}% attack/fire rate.", &"combat", [WEAPON], [], [6, 9, 12], [3, 4.5, 6])
	_add(&"rapid", "Rapid", "+{value}% attack/fire rate, -{secondary}% damage.", &"combat", [WEAPON], [], [5, 7.5, 10], [3, 4.5, 6])
	_add(&"deadeye", "Deadeye", "+{value}% headshot damage.", &"combat", [WEAPON], GUNS, [8, 13, 18])
	_add(&"stable", "Stable", "-{value}% recoil and spread.", &"combat", [WEAPON], GUNS, [10, 15, 20])
	_add(&"quickdraw", "Quickdraw", "+{value}% ready speed after swapping.", &"combat", [WEAPON, GEAR], [], [12, 18, 25])
	_add(&"fast_reload", "Fast Reload", "+{value}% reload speed.", &"combat", [WEAPON], GUNS, [10, 15, 20], [], true)
	_add(&"executioner", "Executioner", "+{value}% damage against targets below 30% HP.", &"combat", [WEAPON], [], [7, 11, 15])
	_add(&"first_strike", "First Strike", "First hit after four seconds deals +{value}% damage.", &"combat", [WEAPON], [], [10, 15, 20])
	_add(&"relentless", "Relentless", "Consecutive hits gain damage, capped at +{value}%.", &"combat", [WEAPON], [], [6, 9, 12])
	# Movement
	_add(&"lightweight", "Lightweight", "+{value}% movement speed while active.", &"movement", [WEAPON, GEAR], [], [3, 5, 7])
	_add(&"airborne", "Airborne", "+{value}% air control.", &"movement", [WEAPON, GEAR], [], [7, 11, 15])
	_add(&"springloaded", "Springloaded", "Kills grant +{value}% jump height for two seconds.", &"movement", [WEAPON, GEAR], [], [10, 15, 20])
	_add(&"momentum", "Momentum", "Fast-moving hits grant +{value}% speed briefly.", &"movement", [WEAPON, GEAR], [], [4, 6, 8])
	_add(&"slider", "Slider", "+{value}% slide duration and retention.", &"movement", [WEAPON, GEAR], [], [8, 13, 18])
	_add(&"parkour", "Parkour", "Traversal makes the next attack recover {value}% faster.", &"movement", [WEAPON, GEAR], [], [8, 12, 16])
	_add(&"chaser", "Chaser", "Hits on retreating enemies grant +{value}% speed.", &"movement", [WEAPON, GEAR], [], [5, 8, 11])
	# Skill / cooldown
	_add(&"charged", "Charged", "Kills reduce equipped skill cooldowns by {value}%.", &"skill", [WEAPON, GEAR], [], [4, 6, 8])
	_add(&"flow", "Flow", "Post-skill hits refund {value}% of that skill's cooldown.", &"skill", [WEAPON, GEAR], [], [5, 8, 11])
	_add(&"overclocked", "Overclocked", "Skill use grants +{value}% weapon speed for 1.5 seconds.", &"skill", [WEAPON, GEAR], [], [8, 12, 16])
	_add(&"linked", "Linked", "Swap after a hit for +{value}% damage briefly.", &"skill", [WEAPON, GEAR], [], [6, 9, 12])
	# Elemental
	_add(&"burning", "Burning", "{value}% chance to ignite for short fire damage.", &"elemental", [WEAPON], [], [10, 15, 20])
	_add(&"frost", "Frost", "Hits reduce enemy movement handling by {value}% briefly.", &"elemental", [WEAPON], [], [8, 12, 16])
	_add(&"poisoned", "Poisoned", "{value}% chance to apply a lingering poison.", &"elemental", [WEAPON], [], [12, 18, 24])
	_add(&"bleeding", "Bleeding", "{value}% chance to bleed; moving victims take more damage.", &"elemental", [WEAPON], [], [12, 18, 24])
	_add(&"shock", "Shock", "Repeated hits build toward a brief {value}% disruption.", &"elemental", [WEAPON], [], [10, 15, 20])
	_add(&"void", "Void", "Hits reduce healing received by {value}% temporarily.", &"elemental", [WEAPON], [], [12, 18, 24])
	# Risk / reward
	_add(&"glass_cannon", "Glass Cannon", "+{value}% outgoing damage; receive +{secondary}% damage.", &"risk", [WEAPON, GEAR], [], [10, 15, 20], [5, 7.5, 10])
	_add(&"berserker", "Berserker", "Damage rises with missing HP, capped at +{value}%.", &"risk", [WEAPON, GEAR], [], [12, 18, 25])
	_add(&"gambler", "Gambler", "{value}% chance for a powerful critical; base damage is reduced.", &"risk", [WEAPON], [], [5, 7, 10])
	_add(&"reckless", "Reckless", "+{value}% airborne damage, with worse grounded handling.", &"risk", [WEAPON], [], [8, 12, 16])
	_add(&"bloodlust", "Bloodlust", "Kills grant {value}% lifesteal for three seconds.", &"risk", [WEAPON, GEAR], [], [3, 4, 5])
	_add(&"last_stand", "Last Stand", "Below 20% HP, attacks and reloads are {value}% faster.", &"risk", [WEAPON, GEAR], [], [12, 18, 25])
	# Melee
	_add(&"vampiric", "Vampiric", "Melee hits restore {value}% of damage dealt.", &"melee", [WEAPON], MELEE, [2, 3.5, 5])
	_add(&"crusher", "Crusher", "Heavy attacks cause +{value}% stagger and knockback.", &"melee", [WEAPON], MELEE, [12, 20, 30])
	_add(&"duelist", "Duelist", "Perfect parry empowers the next hit by +{value}%.", &"melee", [WEAPON, GEAR], MELEE, [12, 18, 25])
	_add(&"reach", "Reach", "+{value}% melee range.", &"melee", [WEAPON], MELEE, [5, 8, 12])
	_add(&"counterweight", "Counterweight", "Blocking makes the next swing {value}% faster.", &"melee", [WEAPON, GEAR], MELEE, [8, 12, 16])
	_add(&"predator", "Predator", "Back attacks deal +{value}% damage.", &"melee", [WEAPON], MELEE, [10, 16, 22])
	# Gun
	_add(&"ricochet", "Ricochet", "Bullets have a {value}% chance to bounce once.", &"gun", [WEAPON], GUNS, [25, 50, 100])
	_add(&"hollow_point", "Hollow Point", "+{value}% against low armor, weaker against heavy armor.", &"gun", [WEAPON], GUNS, [7, 11, 15])
	_add(&"armor_piercing", "Armor Piercing", "Ignores {value}% armor, slightly weaker unarmored.", &"gun", [WEAPON], GUNS, [15, 25, 35])
	_add(&"hipfire", "Hipfire", "Improves hipfire accuracy by {value}%.", &"gun", [WEAPON], GUNS, [18, 28, 40])
	_add(&"aerial_accuracy", "Aerial Accuracy", "Reduces airborne spread by {value}%.", &"gun", [WEAPON], GUNS, [15, 25, 35])
	_add(&"mag_dump", "Mag Dump", "Final magazine rounds fire {value}% faster.", &"gun", [WEAPON], GUNS, [10, 16, 22], [], true)
	_add(&"fresh_mag", "Fresh Mag", "First three rounds after reload deal +{value}% damage.", &"gun", [WEAPON], GUNS, [5, 8, 12], [], true)
	# Ultra rare
	_add(&"echo", "Echo", "{value}% chance to repeat part of hit damage after 0.4 seconds.", &"ultra", [WEAPON], [], [6, 10, 15])
	_add(&"adrenaline", "Adrenaline", "Kills reduce movement-skill recovery by {value}%.", &"ultra", [WEAPON, GEAR], [], [8, 12, 18])
	_add(&"phase", "Phase", "A clean dash avoidance makes the next hit ignore {value}% armor.", &"ultra", [WEAPON, GEAR], [], [15, 25, 35])
	_add(&"reversal", "Reversal", "+{value}% damage briefly against the enemy who struck first.", &"ultra", [WEAPON, GEAR], [], [8, 12, 18])
	_add(&"chain_reaction", "Chain Reaction", "Elemental kills transfer status at {value}% strength nearby.", &"ultra", [WEAPON], [], [40, 60, 80])


static func _add(
		affix_id: StringName, title: String, text: String, category: StringName,
		item_types: Array[int], families: Array[StringName] = [], values: Array = [0.0, 0.0, 0.0],
		secondary: Array = [0.0, 0.0, 0.0], magazine_required: bool = false
) -> void:
	var definition := AffixDefinition.new()
	definition.id = affix_id
	definition.display_name = title
	definition.description = text
	definition.category = category
	definition.allowed_item_types = item_types.duplicate()
	definition.allowed_weapon_families = families.duplicate()
	definition.tier_values = _float_array(values)
	definition.secondary_values = _float_array(secondary)
	definition.effect_key = affix_id
	definition.requires_magazine = magazine_required
	_definitions.append(definition)
	_index[String(affix_id)] = definition


static func _float_array(values: Array) -> Array[float]:
	var result: Array[float] = []
	for value: Variant in values:
		result.append(float(value))
	while result.size() < 3:
		result.append(0.0)
	return result
