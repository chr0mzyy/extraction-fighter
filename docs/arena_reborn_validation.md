# Arena Reborn 0.6.0 — verification, 2026-10-22

## Baseline and scope

Original pre-migration commit: `19404239cb5414f154892d26bf2443135d4148aa` (`backup/pre-arena-reborn`). This audit started at `f3e14ef2e8d36e2291a3dc63b9d61d7b6383f100` and created `backup/pre-arena-reborn-audit-20261022`. The existing `project.godot` edit was preserved and excluded from the commit. The separate old `project` directory was not edited.

The initial migration already provided the Arena loop, universal gameplay access, family normalization, cosmetic selection, v7 profile migration, progression and camera policy. This pass closes observed defects, integrates the pending upper-body peek fix, and verifies the intended local vertical slice.

## Defects fixed

- Unused equipped families received fallback mastery. Mastery now requires recorded hits or actual damage for a recognized family.
- Overkill damage was counted in statistics and rewards. Credited damage is now capped to HP actually removed.
- Reward save failure was ignored. The grant now rolls back and results allow retry; a retry after successful reload is deduplicated.
- Repeated block presses could perpetually refresh perfect parry. Standard Katana/Sword tuning has a 0.6 s rearm; blocking still works while rearming.
- Arsenal omitted icons and clipped role/weakness copy. Original SVG family silhouettes and separate description lines were added, with full hover details.
- At 720p, the character slot panel pushed CUSTOMIZATION's BACK offscreen. It now scrolls, and the layout regression includes BACK bounds.
- Catalog resolution repeatedly rebuilt a 30-item index. Immutable source definitions are now cached once.

## Automated results — PASS

Installed engine: Godot `4.7.2.stable.official.ed1daf0bf`. Tests ran directly against `repo-work`, with separate `XDG_DATA_HOME` values and bounded execution time.

| Check | Evidence |
| --- | --- |
| Editor import | No parser errors |
| `--arena-reborn-test` | 10 families, universal skills, 200 Power, all skin definition fingerprints, v6→v7 migration, mastery unlock, no idle mastery, save failure/rollback/retry, reload deduplication, camera policy |
| `--arena-acceptance-test` | Live 1v1 countdown, health/death, round resets, 4-round victory, correct damage, results, persisted rewards, no duplication and rematch |
| `--arena-mode=2v2 --arena-acceptance-test` | Same live flow with four actors and 3-round victory |
| `--arena-round-test` and 2v2 variant | Teams, elimination, spectate, timers, sudden death, reset, score and friendly fire |
| `--arena-reward-test` | Item swap inactive, real stats, results/retry layout at all target sizes, free cursor |
| `--combat-feel-test` | All 30 skin scenes instantiated in-tree; exported runtime combat properties match within each family; no legacy instance/affix/Mythic leakage; repeated block does not refresh parry; firing, ADS, reload, melee and feedback |
| `--self-test` | Ground movement, momentum, air steering, slide, bhop, peek, camera, combat, parry, skills and respawn |
| `--loadout-integration-test` | Exact selected weapons/skills, absent unequipped abilities, Grapple/Blink, reset |
| `--content-arena-test` | Expanded arsenal, skill Power and ability execution |
| `--profile-self-test` | Atomic profile saves, valid backup recovery, inventory identity and compatibility |
| `--settings-self-test` | Video/gameplay/audio/keybind persistence and fallback |
| `--training-self-test` | Checkpoints, temporary build, timer/PB and progression isolation |
| `--pause-flow-test` | Settings, resume and cursor ownership |
| `--scene-flow-test` | Lobby → Arena → Lobby keeps the selected build |
| `--ai-soak-test` | Bot perception, movement, decisions, recovery and combat |
| `--hud-layout-test` | Anchored HUD and feedback states |
| `--lobby-layout-test` | Main, arsenal, cosmetics/BACK, profile, settings and playlists at all target sizes |
| `--polish-self-test` | Character details, live settings, audio and visual feedback |
| `--effect-self-test` | Preserved effects work only in its explicit legacy test context |
| `--dungeon-self-test` | Legacy Dungeon stays recoverable and buildable |
| `--durability-self-test` | Legacy durability and repair/save compatibility |

There are 22 gameplay test configurations including the two mode variants; editor import and graphical checks are additional. Some runners report ObjectDB instances at forced exit. This remains technical debt; passing assertions do not prove leak-free long sessions.

## GPU evidence — PASS for captured layouts

`--arena-visual-test` ran with OpenGL Compatibility on an NVIDIA GeForce RTX 5070. Exact-size SubViewports generated 27 PNGs: nine screens/states at each of 1280×720, 1920×1080 and 2560×1440. States: main menu, arsenal, customization, profile, FPP, TPP, pause, normal results and save retry.

Images are written outside Git at `user://arena_visual_validation`. Representative images were inspected, including 720p arsenal/customization/results, 1080p pause/results and 1440p TPP. These are automated rendering checks, not a human mouse/keyboard playtest. Match results in the captures are driven by health/death events in an isolated test profile.

## Focused desktop UI review

Resolved priorities: P0 hidden BACK in CUSTOMIZATION; P1 clipped weapon weakness copy. Current readability is 8/10 and navigation UX 7/10 for supported landscape targets, based on runtime bounds plus rendered evidence. Accessibility remains 5/10: small secondary text and narrow-window behavior need a later pass. Retention, commercial performance and Google Play risk are unverified/not applicable to this local desktop build. Mobile portrait sizes, touch safe areas and CJK localization were not tested or claimed.

## Limits and next safe task

- This remains local player-versus-bots. Multiplayer, matchmaking, ELO and Ranked are not implemented.
- Character cosmetic slots are foundation placeholders; mastery 10 banners and mastery 20 prestige/inspect rewards are future content. Existing mastery 5/15 skin rewards and Style Token purchases work.
- TTK values are a starting balance target. No claim of final 1.5–2.5 s real-engagement TTK or long-session performance is made without player telemetry/profiling.
- Failed rewards can be retried while results remain open. Leaving after a failed save forfeits that match's reward, clearly stated in UI.
- Next: human 1v1/2v2 play sessions with several weapon/skill builds, then tune only centralized balance values from observations.

## Reproduce

```bash
cd /home/pawel/Games/ExtractionFighter/repo-work
XDG_DATA_HOME=/tmp/arena-reborn-tests /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-acceptance-test
XDG_DATA_HOME=/tmp/arena-reborn-tests-2v2 /home/pawel/Games/ExtractionFighter/runtime/godot --headless --path . -- --arena-mode=2v2 --arena-acceptance-test
XDG_DATA_HOME=/tmp/arena-reborn-visual /home/pawel/Games/ExtractionFighter/runtime/godot --path . --rendering-method gl_compatibility -- --arena-visual-test
```

Skills used in this pass: `$gamestudio`, `$godot-gdscript`, `$godot-gdscript-headless-testing`, `$handoff`.
