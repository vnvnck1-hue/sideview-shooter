"""Render the head choices against the existing base at the handoff angles."""

from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Assets/Generated/SentryTurret/AngleFan"
HEAD = ROOT / "GodotPrototype/assets/props/defense/sentry/sentry_head.png"
BASE = ROOT / "GodotPrototype/assets/props/defense/sentry/sentry_base.png"


def main() -> None:
    zero = Image.new("RGBA", (640, 640))
    zero.alpha_composite(Image.open(HEAD).convert("RGBA"), (231, 123))
    up = Image.open(ART / "sentry_head_elev_p60.png").convert("RGBA")
    down = Image.open(ART / "sentry_head_elev_m40.png").convert("RGBA")
    base = Image.new("RGBA", (640, 640))
    base.alpha_composite(Image.open(BASE).convert("RGBA"), (161, 302))
    specs = [(-65, down, -25), (-40, down, 0), (-15, zero, -15),
             (0, zero, 0), (35, zero, 35), (60, up, 0), (90, up, 30)]
    sheet = Image.new("RGBA", (420 * len(specs), 520), (24, 24, 28, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (angle, head, local_rotation) in enumerate(specs):
        frame = Image.new("RGBA", (640, 640))
        frame.alpha_composite(head.rotate(local_rotation, Image.Resampling.NEAREST,
                                          center=(320, 320)))
        frame.alpha_composite(base)
        sheet.alpha_composite(frame.crop((110, 40, 530, 560)), (420 * index, 0))
        draw.text((420 * index + 10, 8), f"{angle:+d} degrees", fill="white")
    sheet.save(ART / "_mount_sequence_review.png")
    # Switching masks at the exact handoff angles reveals position jumps.
    for angle, variant, variant_rotation in ((-15, down, 25), (35, up, -25)):
        a = np.asarray(zero.rotate(angle, Image.Resampling.NEAREST,
                                   center=(320, 320)))[:, :, 3] > 127
        b = np.asarray(variant.rotate(variant_rotation, Image.Resampling.NEAREST,
                                      center=(320, 320)))[:, :, 3] > 127
        print(f"{angle:+d} handoff silhouette IoU: {np.count_nonzero(a & b) / np.count_nonzero(a | b):.3f}")


if __name__ == "__main__":
    main()
