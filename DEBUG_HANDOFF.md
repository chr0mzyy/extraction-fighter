# Extraction Fighter — debug handoff

## MVP 0.5.2 focus

Arena reward exchange is implemented and should be debugged through `--arena-reward-test` before manual UI work. The test uses temporary `user://arena_reward_*_test.json` profiles and removes them afterward.

## Runtime commands (Linux)

```bash
/home/pawel/Games/ExtractionFighter/runtime/godot --headless --editor --path . --quit
/home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-reward-test
/home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-round-test
```

Success markers are `ARENA_REWARD_OK` and `ARENA_ROUND_OK`.

## Failure triage

- Ownership, protection, duplicate IDs, limits or rollback: `scripts/arena/arena_reward_service.gd` and `arena_trade_inventory.gd`.
- Save/restart or migration: `scripts/core/player_profile.gd` (save version 6).
- Result gating/abandonment: `scripts/arena/arena_match_result.gd` and `arena_match_manager.gd`.
- Reward layout/cursor/confirmation: `scripts/ui/arena_match_ui.gd` and `scripts/core/game_manager.gd`.
- Synthetic bot contents: `scripts/arena/arena_bot_reward_factory.gd`; these must remain non-persistent and Common–Rare only.

## Important safety boundary

Normal local-bot rewards are simulation only. Do not connect them to `PlayerProfile.save_profile()` or grant bot loot persistently. Full persistence is exercised only through explicit test-profile callbacks until an authoritative PvP/backend owner exists.
