# Wall rotary sentry sprite set

The PNGs in this folder are native size, transparent game sprites. They match the project's pixel prop rendering and nearest texture filtering.

- `wall_rotary_head_game.png`: 320 × 176, upper rotary gun head.
- `wall_rotary_hatch_closed.png`, `wall_rotary_hatch_opening.png`, `wall_rotary_hatch_open.png`: 320 × 384 each, registered to the same left wall origin.
- `wall_rotary_assembled_preview.png`: 440 × 384, placement check only; do not use as the animated in-game sprite.

For a left wall, draw a hatch state at its 320 × 384 origin. When open, draw the head at local position `(8, 110)` in front of the hatch. Its aim pivot is `(147, 140)` inside the head image, equivalent to `(155, 250)` in the hatch image. Keep the hatch fixed and rotate the head around that pivot. For a right wall, mirror the whole assembly and its local offsets. Do not scale the source images independently.

The three hatch poses describe the deployment beats. The middle pose is a key frame, not a continuous mechanical interpolation.
