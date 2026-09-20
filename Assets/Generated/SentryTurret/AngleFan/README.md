# Sentry head boundary poses

The updated request calls for two right-facing poses: `sentry_head_elev_p60.png` (+60°) and `sentry_head_elev_m40.png` (-40°). Both are 640×640 RGBA with binary alpha and a shared pivot at (320, 320). `_contact_sheet.png` shows +60° on the left and -40° on the right.

The current in-game `sentry_head.png` is the identity and palette master. The two `Source` illustrations redraw the receiver from different views: +60° exposes the lower face, while -40° exposes the broad upper face. Both retain the twin barrels, optic, antennas, amber lights, and short rear connector. No mount, hatch, or hose coil is included.

`Tools/build_sentry_head_angle_fan.py` fits those drawings to the 640×640 canvas, aligns the muzzle anchors, quantizes color close to the original sprite, and makes alpha binary. `Tools/review_sentry_angle_fan.py` makes `_mount_sequence_review.png` with the original base and checks the silhouettes at the -15°/+35° pose handoffs. The game now selects these frames at the corresponding pitch ranges.

The two keypose sprites meet the image format, area, palette, and muzzle-position checks. With the original fixed base alone, rotating the -40° sprite to -65° puts both muzzles inside the base/hatch. The separate telescoping auxiliary riser in `../Lift/` now raises the head by up to 176 art pixels. The mounted -65° pose clears the fixed base in `../Lift/_elevation_runtime_review.png`.
