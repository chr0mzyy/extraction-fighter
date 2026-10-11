# Extraction Fighter — debug handoff

## MVP 0.6.0 focus

The competitive boundary is `ArenaEquipmentResolver` plus `PlayerController.standard_arena_ruleset`. If an Arena skin changes combat, first inspect `ArenaWeaponGameplayDefinition.apply_to()` and `WeaponBase.configure_from_item()`. Do not restore affix/Mythic behavior to standard Arena to make a legacy test pass; `--effect-self-test` explicitly switches only its test player to the preserved non-competitive runtime.

## Runtime commands (Linux)

Use a separate `XDG_DATA_HOME` when testing so the live profile is never touched:

```bash
XDG_DATA_HOME=/tmp/extraction-fighter-test /home/pawel/Games/ExtractionFighter/runtime/godot --headless --editor --path . --quit
XDG_DATA_HOME=/tmp/extraction-fighter-test /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-reborn-test
XDG_DATA_HOME=/tmp/extraction-fighter-test /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-reward-test
XDG_DATA_HOME=/tmp/extraction-fighter-test /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-round-test
XDG_DATA_HOME=/tmp/extraction-fighter-test /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-mode=2v2 --arena-round-test
```

Success markers: `ARENA_REBORN_OK`, `ARENA_REWARD_OK`, and `ARENA_ROUND_OK`.

## Failure triage

- Skin/gameplay mismatch or affix leak: `scripts/arena/arena_equipment_resolver.gd`, `arena_weapon_gameplay_definition.gd`, `scripts/weapons/weapon_base.gd`.
- Loadout/universal access/200 Power: `scripts/core/player_profile.gd`, `scripts/ui/lobby.gd`.
- Account XP/mastery/Style duplication: `scripts/arena/arena_progression_service.gd`; verify the match `result_id` and `arena_progression_result_ids`.
- Missing real statistics: `arena_match_manager.gd`, `arena_participant_state.gd`, and `DamageInfo.weapon_family`.
- Results/rematch/cursor: `scripts/ui/arena_match_ui.gd`, `scripts/core/game_manager.gd`.
- v6→v7 migration or backup recovery: `scripts/core/player_profile.gd`; never discard legacy fields to repair a malformed profile.
- FPP/TPP policy: `scripts/arena/arena_session_request.gd` and `PlayerController.configure_arena()`.

## Safety boundaries

- Repository before migration: `backup/pre-arena-reborn` at `19404239cb5414f154892d26bf2443135d4148aa`.
- Dungeon and item-swap files are archival/legacy. Keep them buildable, but do not add their menu entry or rewards to the Arena flow.
- Normal local play has no authoritative remote owner, matchmaking or Ranked. Do not present local bots as network players.
- Test leak warnings at forced process exit are known; treat parser errors, `SCRIPT ERROR`, failed success markers, or increasing live-session objects as real regressions.
