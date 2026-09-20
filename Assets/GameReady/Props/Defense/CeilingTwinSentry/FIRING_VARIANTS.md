# Firing mechanism variants

Both variants use `ceiling_twin_sentry_mount.png` as the fixed upper mount. Each head is a transparent 512 × 224 PNG registered to the same `(0, 0)` origin. Draw the mount behind the selected head and rotate the head about `(160, 82)` for aiming.

- `ceiling_sentry_rotary_head.png`: short motor-driven multi-barrel rotary cluster.
- `ceiling_sentry_accelerator_head.png`: single long electromagnetic launch channel.
- `ceiling_sentry_*_assembled.png`: static placement previews.
- `ceiling_sentry_firing_variants_comparison.png`: side-by-side visual comparison.

Godot scene files for each variant are under `GodotPrototype/assets/props/defense/ceiling_twin_sentry/`. The art is ready for instancing, but firing behavior and animation have not been attached to these new scenes.
