# Extraction Fighter - MVP 0.2.2

A local single-player Godot 4.7.2 combat prototype with a persistent lobby, data-driven loadouts, and a fast player-versus-bot arena.

## Launch

Open this folder in Godot 4.7.2 and run the project, or run:

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --path .
```

The project starts in the lobby. `PLAY > ARENA` deploys the currently selected two weapons and two skills. `LOADOUT` changes the build, `STASH` shows all permanently owned items and the 24-slot main inventory, and arena `Esc` opens Resume / Return to Lobby / Quit.

## Arena controls

- `WASD`: move
- `Shift`: sprint
- `Ctrl`: crouch / momentum slide
- `Space`: jump; airborne double jump only when Double Jump is equipped
- `Q`: skill slot 1
- `E`: skill slot 2
- `V`: instant FPP/TPP toggle
- `1`: weapon slot 1
- `2`: weapon slot 2
- `LMB`: light attack / fire
- `RMB`: block / ADS
- `F`: melee heavy attack
- `R`: firearm reload / activate a ready Mythic weapon action
- `Esc`: pause menu
- `F3`: debug overlay

Double Jump is the intentional contextual exception to Q/E: it occupies a skill slot but activates with a second airborne `Space` press. Other skills activate from whichever Q/E slot they occupy; contextual skills only activate when their requirements are met.

The development stash contains 30 playable weapon variants: a Common, Rare, and Mythic version for each of the ten weapon families. It also includes ten movement/combat skills and 27 gear foundations. The default build remains Ronin Katana, Huntsman Rifle, Dash, and Double Jump (130/200 Power). Skill combinations above 200 Power are rejected.

Items are stored as persistent instances separate from their reusable definitions. Instances carry durability plus zero to three compatible, non-duplicated affixes with Tier I-III rolls. The 50-affix catalog covers combat, movement, skills, elements, risk/reward, melee, firearms, and ultra-rare effects. Common items roll 0-1 affixes, Rare items 1-2, and Mythic items 2-3 plus a fixed identity mechanic.

Hover any owned or equipped item in Loadout, Stash, or a populated Main Inventory slot to inspect its reusable rarity-colored tooltip. Tooltips show the exact instance's affix names, tiers, readable effect descriptions, unique Mythic mechanic, and base-to-effective damage/fire-rate/reload values where applicable.

The arena remains an endless player-versus-bot deathmatch. Falling below the arena kills and respawns the character. Existing momentum-preserving air control, bunny hopping, crouching, sliding, slide jumping, cameras, bot AI, combat, launch pads, scoring, and respawn behavior remain active.

Profiles are stored as version-2 JSON at `user://player_profile.json`. Version-1 profiles migrate to persistent item instances while preserving valid owned items and equipped slots. Missing, malformed, and unsupported profiles safely fall back to the default build.

## Validation

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --quit
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --ai-soak-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --hud-layout-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --content-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --tooltip-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --affix-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --effect-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --content-arena-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --loadout-integration-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --lobby-layout-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --pause-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --scene-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-restart-write-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-restart-read-test
```
