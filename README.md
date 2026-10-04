# Extraction Fighter - MVP 0.4.2

A local single-player Godot 4.7.2 combat prototype with a persistent lobby, data-driven loadouts, and a fast player-versus-bot arena.

## Launch

Open this folder in Godot 4.7.2 and run the project, or run:

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --path .
```

The project starts in the lobby. `PLAY > ARENA` launches endless deathmatch and `PLAY > THE ARMORY` launches a 15-minute extraction run with the selected loadout. Loot occupies a separate 24-slot run pack, is secured only by extraction, and is lost on death or timeout.

## Arena controls

- `WASD`: constant-speed arena movement
- `Shift`, `C`, or `Ctrl`: crouch / momentum slide
- `Space`: jump; hold for auto bunny hop; release and press again in the air for an equipped Double Jump
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
- `Tab`: open/close the simplified Armory run inventory
- `F3`: debug overlay
- `X`: open Armory chests / hold for 5 seconds at an extraction point

Double Jump is the intentional contextual exception to Q/E: it occupies a skill slot but activates with a second airborne `Space` press. Other skills activate from whichever Q/E slot they occupy; contextual skills only activate when their requirements are met.

The development stash contains 30 playable weapon variants: a Common, Rare, and Mythic version for each of the ten weapon families. It also includes ten movement/combat skills and 27 gear foundations. The default build remains Ronin Katana, Huntsman Rifle, Dash, and Double Jump (130/200 Power). Skill combinations above 200 Power are rejected.

Items are stored as persistent instances separate from their reusable definitions. Weapon and gear instances carry current/max durability plus zero to three compatible, non-duplicated affixes with Tier I-III rolls. Durability wear is active in the Armory only; Arena combat never consumes durability. Broken weapons remain equipped but cannot attack until repaired from the Stash.

Armory runs generate exactly six normal extraction sites and two hidden key sites across eligible rooms. A run has a 42% chance to place one Extraction Key in a chest. Hidden extraction consumes it; defeating the Warden drops a boss chest but does not end the run. Successful extraction banks exact item instances and run gold, while death or timeout clears the run pack. F3 shows extraction/key telemetry during development.

Loadout and Stash use reusable rarity-accented item slots with icons, selected/equipped/broken/new states, drag previews, compatible-target highlighting, safe invalid-drop rejection, double-click quick equip and relevant right-click context actions. The 24-slot inventory, loadout and stash exchange exact item instances atomically; a failed move never removes the source item. Stash browsing supports category/subcategory filters, name/type/affix search and identity-safe sorting.

Hover any owned or equipped item in Loadout, Stash, or a populated Main Inventory slot to inspect its reusable rarity-colored tooltip. Tooltips show the exact instance's affix names, tiers, readable effect descriptions, unique Mythic mechanic, and base-to-effective damage/fire-rate/reload values where applicable. Compatible equipped items also produce direction-aware comparisons, including lower-is-better handling for reload, recoil, spread and cooldown.

During an Armory run, `Tab` opens the lighter run inventory. Items can be inspected, compared, consumed or dropped. Dropping creates a world pickup that retains the exact `ItemInstance`, including affixes, variant and durability, and can be recovered if space remains.

The arena remains an endless player-versus-bot deathmatch. Falling below the arena kills and respawns the character. Cameras, bot AI, combat, launch pads, scoring, and respawn behavior remain active.

## Kour-style movement baseline

The previous player locomotion was removed and replaced by an original controller based on Kour.io's public movement characteristics. This is a starting point for playtesting, not extracted Kour.io code or a claim of identical internal values.

- Constant arena run speed with CS-style acceleration, responsive counter-strafing and normalized diagonals. There is no separate sprint mode.
- Hold Space to chain ground jumps without consuming an equipped Double Jump. Release and press again for the airborne skill.
- Airborne `W/S` and unsynchronized `A/D` do nothing, preserving launch momentum. Bhop steering requires held `Space` plus mouse-left+`A` or mouse-right+`D`.
- Ctrl at speed starts a slide; Space carries its momentum into a jump. Dash/launch speed above the normal movement cap survives slide entry and slide jumps.
- Crouch still checks ceiling clearance. Coyote time, jump buffering, loadout skills, movement/jump/air-control buffs, and slide affixes remain integrated.

Tune `Player > MovementController` in the Godot Inspector (`scripts/characters/player_movement_controller.gd`). Defaults: run **10.5 m/s**, ground acceleration **85 m/s²**, jump velocity **7.4 m/s**, gravity **20 m/s²**, air acceleration **24 m/s²**, camera follow **11.5**, bunny-hop cap **22 m/s**. `auto_bunny_hop` can be disabled; jump/landing windows, camera-relative air control, crouch and slide values are exported separately. Bots retain their existing movement profile.

The `--self-test` suite additionally checks diagonal speed, stopping, held-jump chains, skill cooldown ownership, loadouts without Dash/Double Jump, and preservation of above-cap slide momentum.

Profiles are stored as version-4 JSON at `user://player_profile.json`. Version-1/2/3 profiles migrate while preserving valid owned instances, affixes, durability, inventory and equipped slots. Missing, malformed, and unsupported profiles safely fall back to the default build.

Video, graphics, gameplay, and audio preferences are stored independently at `user://game_settings.json`. The lobby and gameplay pause menus apply supported settings live, including FOV, sensitivity, camera effects, damage numbers, crosshair visibility, resolution, rendering scale, and volume buses.

## Combat feel foundation

All ten weapon families use centralized presentation profiles for configurable FPP hip, ADS and sprint poses plus bounded TPP offsets. The same profiles drive procedural idle/movement sway, firing kick, recovery, reload motion, swap motion, muzzle timing, tracer duration and family-specific crosshair behavior, so future Blender models can be retuned without spreading transforms through gameplay scripts.

Combat feedback distinguishes normal, headshot, armor, blocked, parry/deflect, critical/proc, damage-over-time and kill results. Damage numbers use a fixed reusable pool, impacts use a fixed 3D pool, enemy reactions are visual rather than repeated stun, and strong melee connections use a short 42 ms hit-stop. Damage numbers, camera shake, hit-effect intensity and crosshair visibility are persisted in Settings.

## Validation

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --quit
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --ai-soak-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --hud-layout-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --profile-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --inventory-ui-test
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
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --dungeon-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --extraction-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --durability-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --dungeon-soak-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --dungeon-scene-flow-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --settings-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --polish-self-test
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -- --combat-feel-test
```
