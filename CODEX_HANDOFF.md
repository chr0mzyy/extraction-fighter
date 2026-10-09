# Extraction Fighter development handoff

## Current milestone

MVP 0.5.1 Arena Round System is implemented for local play. Arena now supports configurable 1v1 and 2v2 bot matches, round countdowns, team elimination, timers and sudden death, side-swapped resets, results, rematch, abandonment, and lobby return.

## Architecture

- `ArenaModeDefinition` resources describe mode size, first-to score, maximum rounds, and time limit.
- `ArenaMatchManager` owns the match state machine and rules; actors only expose team/combat/reset hooks.
- `ArenaParticipantState` and `ArenaMatchResult` keep reliable match statistics and future inventory/reward identities without mutating profile inventory.
- `ArenaMatchUI` presents countdown, round outcome, spectator state, and results separately from the shared gameplay HUD.
- `GameManager` coordinates scene actors, deterministic spawn markers, bot targets, transient cleanup, and lobby/rematch flows.

## Validation

Headless Arena tests cover both modes, elimination, spectator activation, friendly fire, timer HP tiebreak, sudden death, first-to win conditions, reset state, results, and rematch. Existing profile, inventory, loadout, movement/combat, HUD, pause, scene-flow, Training, Dungeon, and extraction tests pass with Godot 4.5.1 compatibility validation.

## Known limitations

- 2v2 is explicitly local player plus bots; there is no networking or human matchmaking.
- Spectator cycling is architected for multiple living teammates but the current 2v2 roster can expose only one allied bot after local death.
- Arena reward/item exchange is represented only by result/inventory identity hooks; no items are transferred.
- Final smoke testing should also be repeated with the project's installed Godot 4.7.2 runtime on the host checkout.

## Next recommended milestone

Run a short manual balance and visual pass in Godot 4.7.2, then build the Arena reward-selection contract on top of `ArenaMatchResult` without adding networking yet.
