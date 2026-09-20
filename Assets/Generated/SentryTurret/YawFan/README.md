# Sentry head yaw views

`sentry_head_yaw_30.png`, `sentry_head_yaw_60.png`, and `sentry_head_yaw_90.png` turn the original right-facing side view toward the camera. They share a 640×640 transparent canvas and the original head pivot at (320, 320). The game mirrors these three frames after the front view to complete a left/right turn. `_turn_contact_sheet.png` compares the original and all three new views.

All three keep one receiver, two vertically stacked barrels, the top optical pod and two antennas. Barrel projection shortens across 30° → 60° → 90°. They are generated from the editable images in `Source/` by `Tools/build_sentry_turn_and_lift.py`.
