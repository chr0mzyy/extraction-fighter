# Extraction Fighter — debug handoff

## MVP 0.6.0 focus

2026-10-22 confirmed defects and resolutions:

- Apparent missing peek fix: the desktop shortcut pointed at the old `project` folder. It now launches `repo-work`; old project contents remain untouched. Upper-body pivot changes are retained.
- Idle mastery: removed fallback to equipped families; only recorded hit/damage families earn mastery.
- Inflated damage/rewards: `HealthComponent` now limits resolved damage to remaining HP. Live acceptance tests expect 400 damage in a clean 4-round 1v1 sweep, not 4000 from test overkill.
- Reward persistence failure: `ArenaProgressionService.grant_and_save()` restores the pre-grant snapshot. Results expose retry and disable rematch until save succeeds.
- Repeated block could restart perfect parry every press: standard melee tuning adds 0.6 s rearm; normal block remains possible.
- 720p CUSTOMIZATION hid BACK: gear slots now have a scroll container; layout regression includes BACK bounds.

Do not use `--script` for the visual suite: early global-class parsing bypasses this project's autoload registration order. Use normal project startup with `-- --arena-visual-test`.

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

Additional checks: `--arena-acceptance-test` and `--arena-mode=2v2 --arena-acceptance-test` must print `ARENA_ACCEPTANCE_OK`. For graphical checks run normally with `-- --arena-visual-test`; captures go to `user://arena_visual_validation`. Always isolate `XDG_DATA_HOME`, including for visual tests.

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
