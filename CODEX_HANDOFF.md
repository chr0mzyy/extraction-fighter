# Extraction Fighter — development handoff

## Current milestone

MVP 0.6.0 Arena Reborn migrates the active game loop to a fair local Movement Arena Fighter: Lobby → Build → Casual 1v1/2v2 → Results → cosmetic progression. Ranked is a disabled FPP-only extension point. There is no networking.

## Active architecture

- `ArenaEquipmentResolver` owns all ten family gameplay definitions, the 30-skin catalog, default skins and the ten selectable skills. It creates normalized runtime item copies.
- `ArenaWeaponGameplayDefinition` contains combat values; `WeaponCosmeticDefinition` contains only skin identity, family, cosmetic rarity, flavor, preview/model and source ID.
- `WeaponBase` uses the resolver whenever its wielder is under standard Arena rules. The normalized copy has no affixes, Mythic special, item instance or durability.
- `PlayerProfile` schema v7 stores Arena families, selected/unlocked cosmetics, cosmetic gear placeholders, account XP/level, Style Tokens, family mastery, one-shot progression result IDs and statistics while preserving all legacy data.
- `ArenaProgressionService` derives account XP, Style Tokens and family mastery from real match data, grants once per `result_id`, updates persistent statistics and unlocks family skins at mastery 5/15.
- `ArenaMatchManager`/`ArenaParticipantState` collect damage, hits and kills per family. `ArenaMatchUI` presents real score/stats/progression and rematch/lobby actions; the previous item-swap UI is inactive.
- The Lobby exposes PLAY, LOADOUT, CUSTOMIZATION, TRAINING, PROFILE and SETTINGS. All gameplay families/skills are universal; two skills must total at most 200 Power.

## Preserved systems

Advanced movement, FPP/TPP transition, ten skills, ranged/melee/parry combat, bot AI, 1v1/2v2 rounds, HUD, settings/keybinds, pause cursor ownership, audio/feedback and Movement Training remain in use. Legacy Dungeon, inventory, exact item instances, affixes, durability, Gold/Scrap and reward-swap source remain recoverable and their regression tests still run, but they are disconnected from the primary Arena UI/runtime.

Pre-migration state: `19404239cb5414f154892d26bf2443135d4148aa`, reference `backup/pre-arena-reborn`.

## Balance and migration decisions

Standard Arena uses 100 HP. Sniper is 58 body/90 head. Family tuning is documented in `docs/arena_reborn_balance.md`. v6→v7 migration preserves old inventory/economy/settings, maps only verified owned weapons to cosmetic unlocks, grants each default family skin and is idempotent. Old balances are not converted to Style Tokens.

## Validation

Godot 4.7.2 editor import and the Arena migration, rewards, rounds (1v1/2v2), movement/combat, loadout/content, AI soak, HUD, profile, settings, pause, training, scene-flow, legacy effects, Dungeon and durability regressions pass. Runtime UI layout checks pass at 1280×720, 1920×1080 and 2560×1440. Actual GPU captures were inspected at the compositor-constrained 839×1002 window; no claim is made that target-resolution screenshots were captured.

Known shutdown warnings report small ObjectDB leak counts because test runners force-quit scenes; no parser/runtime errors remain. Narrow portrait-like windows can truncate long Arsenal weakness copy, although supported landscape target layouts pass.

## Next safe milestone

Play complete 1v1 and 2v2 matches with normal persistent data, tune TTK from match telemetry, then add mastery 10 banner and mastery 20 prestige/inspect rewards. Networking, matchmaking, Ranked/ELO and paid purchases remain separate future work.
