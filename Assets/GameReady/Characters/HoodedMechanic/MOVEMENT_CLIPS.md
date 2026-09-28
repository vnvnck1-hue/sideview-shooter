# Hooded Mechanic movement clips v1

The jump and ladder-climb sheets extend the current 320×320-cell player art.
Each sheet is 1280×320 RGBA with four frames in one horizontal row.
The corresponding individual frames are under `Frames/jump/`, `Frames/climb/`,
and `Frames/climb_back/`.
Copies are also available under `GodotPrototype/assets/character/`.

| Clip | Sheet | Playback | Order |
| --- | --- | --- | --- |
| Jump | `Sheets/hooded_mechanic_jump_4f_v1.png` | 8 FPS, no loop | anticipation, rise, apex, landing |
| Ladder climb, side | `Sheets/hooded_mechanic_climb_4f_v1.png` | 8 FPS, loop | low grip, high reach, alternate reach, low grip |
| Ladder climb, rear | `Sheets/hooded_mechanic_climb_back_4f_v1.png` | 8 FPS, loop | right reach, passing rung, left reach, passing rung |

Use nearest-neighbor filtering and a bottom-center cell pivot. Jump and side
climb face right; flip horizontally for left-facing movement. Rear climb faces
directly away from the camera and already alternates left/right limbs. The
ladder itself is intentionally absent from the frames so it can be placed in
the level. The sheets are artwork only; movement and animation switching still
need to be connected to the player controller.

Connected in the Godot prototype (2026-09-25): `scripts/player.gd` plays Jump and
side Ladder climb through its full-body `ActionVisual` (frames picked by vertical
speed / climbed distance, not by timer). Rear climb is not used yet.

Source images are in `Assets/Generated/PlayerMovement/`. Rebuild the sheets and
frames with `Tools/build_hooded_mechanic_movement_sheets.py` using Pillow.
