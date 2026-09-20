"""Preview the new yaw frames and auxiliary riser using the game anchors."""

from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "GodotPrototype/assets/props/defense/sentry"
OUT = ROOT / "Assets/Generated/SentryTurret/Lift"
PIVOT = (320, 320)
LIFT_MAX = 176


def sprite(name: str) -> Image.Image:
    return Image.open(GAME / name).convert("RGBA")


def base() -> Image.Image:
    image = Image.new("RGBA", (640, 640))
    image.alpha_composite(sprite("sentry_base.png"), (161, 302))
    return image


def head_at(angle: int) -> Image.Image:
    if angle <= -35:
        name = "sentry_head_elev_p60.png"
        baked = -60
    elif angle >= 15:
        name = "sentry_head_elev_m40.png"
        baked = 40
    else:
        name = "sentry_head.png"
        baked = 0
    if baked == 0:
        image = Image.new("RGBA", (640, 640))
        image.alpha_composite(sprite(name), (231, 123))
    else:
        image = sprite(name)
    return image.rotate(-angle + baked, Image.Resampling.NEAREST,
                        center=PIVOT)


def lift_for(angle: int) -> int:
    t = max(0.0, min(1.0, (angle - 20) / 45.0))
    t = t * t * (3 - 2 * t)
    return round(LIFT_MAX * t)


def render(head: Image.Image, lift: int, riser: Image.Image,
           foundation: Image.Image) -> tuple[Image.Image, int]:
    image = Image.new("RGBA", (640, 640), (24, 24, 28, 255))
    lifted = Image.new("RGBA", (640, 640))
    lifted.alpha_composite(head, (0, -lift))
    image.alpha_composite(lifted)
    if lift > 1:
        image.alpha_composite(riser, (0, LIFT_MAX - lift))
    image.alpha_composite(foundation)
    mask = np.asarray(lifted)[:, :, 3] > 127
    base_mask = np.asarray(foundation)[:, :, 3] > 127
    return image, int(np.count_nonzero(mask & base_mask))


def make_sheet(specs: list[tuple[str, Image.Image, int]],
               riser: Image.Image, foundation: Image.Image,
               filename: str) -> None:
    cell_w, cell_h = 440, 640
    sheet = Image.new("RGBA", (cell_w * len(specs), cell_h),
                      (24, 24, 28, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (label, head, lift) in enumerate(specs):
        frame, overlap = render(head, lift, riser, foundation)
        sheet.alpha_composite(frame.crop((100, 0, 540, 640)),
                              (cell_w * index, 0))
        draw.text((cell_w * index + 10, 8),
                  f"{label}  lift {lift}  overlap {overlap}", fill="white")
        print(label, "lift", lift, "head/base overlap", overlap)
    sheet.save(OUT / filename)


def main() -> None:
    riser = sprite("sentry_aux_riser_extended.png")
    foundation = base()
    angles = [-75, -60, -35, 0, 15, 20, 40, 55, 65]
    make_sheet([(f"{-angle:+d}° elevation", head_at(angle), lift_for(angle))
                for angle in angles], riser, foundation,
               "_elevation_runtime_review.png")
    zero = head_at(0)
    turns = [("right", zero, 0)]
    for angle in (30, 60, 90):
        turns.append((f"yaw {angle}", sprite(f"sentry_head_yaw_{angle}.png"), 0))
    for angle in (60, 30):
        turns.append((f"left yaw {angle}",
                      sprite(f"sentry_head_yaw_{angle}.png").transpose(
                          Image.Transpose.FLIP_LEFT_RIGHT), 0))
    turns.append(("left", zero.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 0))
    make_sheet(turns, riser, foundation, "_yaw_runtime_review.png")


if __name__ == "__main__":
    main()
