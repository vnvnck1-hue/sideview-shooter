# Auxiliary telescoping sentry support

`sentry_aux_riser_extended.png` is a separate 640×640 transparent support sprite. Its lower sleeve is anchored at (320, 320), matching the original head pivot. The top bearing is about 176 source-art pixels above that anchor. The game slides the support and head upward together as downward aim passes 20°, reaching full extension at 65°. At rest, the module is hidden inside the existing base.

`_riser_review.png` shows the support with the original base; `_elevation_runtime_review.png` shows sampled aim angles; `_yaw_runtime_review.png` shows the left/right turn sequence. `Tools/build_sentry_turn_and_lift.py` rebuilds the sprite and the copies used by Godot.
