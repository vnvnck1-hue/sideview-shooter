# Monster Effects Atlas

`monster_fx_atlas_source.png` is the high-resolution generated source for the Toxic Tumor Crawler's dedicated effect art.
The game-ready 256x256 point-sampled atlas is `GodotPrototype/assets/effects/monster_fx_atlas.png`.

Grid layout (4x4, 64px game cells):

1. torn flesh chunks
2. viscous body-fluid droplets
3. impact splashes and puddles
4. saliva, acid strands, and mist clusters

The atlas is used by `MonsterFx`, `Crawler`, `GoreBurst`, `BloodStain`, `AcidGlob`, and monster-mode `SparkBurst`.
Mechanical/electrical sparks still use the procedural SparkBurst drawing path.

## Generation prompt

Built-in image generation, transparent output, with the normal crawler walk frame, normal death frame, and giant walk frame as style references:

> Create a strict 4 by 4 atlas of sixteen isolated monster-effect sprites: torn flesh chunks; asymmetric viscous bodily-fluid droplets; impact splashes and flattened puddles; saliva/acid strands and mist. Match the crawler's coarse retro pixel art, crimson muscle, deep burgundy shadows, muted olive fluid, pale wet highlights, and near-black brown outlines. Use hard pixel clusters, a limited palette, no antialiasing, no gradients, no smooth circles, no text, and genuinely transparent gutters.

