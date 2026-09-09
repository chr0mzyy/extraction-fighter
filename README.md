# Extraction Fighter — MVP 0.1.1

A local single-player Godot 4.7.2 combat playground built to test whether fast movement, katana defense, movement sniping, and instant first/third-person switching are fun together.

## Launch

Open this folder in Godot 4.7.2 and run the project (`F6`/`F5`), or run:

```powershell
& 'C:\Users\megap\Desktop\Godot_v4.7.2-stable_win64_console.exe' --path .
```

## Controls

- `WASD`: move
- `Shift`: sprint
- `Ctrl`: crouch / momentum slide
- `Space`: jump / airborne double jump
- `Q`: collision-safe dash
- `V`: instant FPP/TPP toggle
- `1`: katana
- `2`: sniper rifle
- `LMB`: light attack / fire
- `RMB`: block + perfect deflect / ADS
- `F`: katana heavy attack
- `R`: sniper reload
- `Esc`: release/capture mouse
- `F3`: debug overlay

The match is an endless player-versus-bot deathmatch. Falling below the arena kills and respawns the character.

Movement uses momentum-preserving air control, air strafing, coyote time, jump buffering, capped bunny hopping, physical crouching, sliding, and slide jumping. Releasing movement input in the air does not brake horizontal velocity.
