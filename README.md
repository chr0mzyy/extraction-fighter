# Extraction Fighter - MVP 0.2.1

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
- `R`: firearm reload
- `Esc`: pause menu
- `F3`: debug overlay

Double Jump is the intentional contextual exception to Q/E: it occupies a skill slot but activates with a second airborne `Space` press. Other skills activate from whichever Q/E slot they occupy; contextual skills only activate when their requirements are met.

The development stash contains ten playable weapons (three melee, six firearms, and one projectile wand), ten movement/combat skills, and 27 gear foundations spanning Common, Rare, and Mythic progression. The default build remains Ronin Katana, Huntsman Rifle, Dash, and Double Jump (130/200 Power). Skill combinations above 200 Power are rejected.

Hover any owned or equipped item in Loadout, Stash, or a populated Main Inventory slot to inspect its reusable rarity-colored tooltip. Tooltips show a generated placeholder preview and only the stats relevant to that item type.

The arena remains an endless player-versus-bot deathmatch. Falling below the arena kills and respawns the character. Existing momentum-preserving air control, bunny hopping, crouching, sliding, slide jumping, cameras, bot AI, combat, launch pads, scoring, and respawn behavior remain active.

Profiles are stored as versioned JSON at `user://player_profile.json`. Missing, malformed, and unsupported profiles safely fall back to the default build.

## Validation

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --quit
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --ai-soak-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --hud-layout-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --content-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --tooltip-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --content-arena-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --loadout-integration-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --lobby-layout-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --pause-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --scene-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-restart-write-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-restart-read-test
```
