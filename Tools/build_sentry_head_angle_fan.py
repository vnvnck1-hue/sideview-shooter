"""Prepare the two redrawn sentry perspectives as pivot-aligned game sprites."""

from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Assets/Generated/SentryTurret/AngleFan"
SOURCE = OUTPUT / "Source"
MASTER = ROOT / "GodotPrototype/assets/props/defense/sentry/sentry_head.png"

# The -40-degree redraw is mapped through both muzzles and its underside socket.
# The +60-degree redraw uses uniform scaling to keep the two long barrels round
# and parallel; both resulting muzzles are within the requested 8 px tolerance.
DOWN = ("new_m40_redraw.png", (1048, 874), (994, 941),
        (608, 636), (552, 389), (527, 413))

def build_pose(source: Image.Image, muzzle1: tuple[int, int],
               muzzle2: tuple[int, int], source_pivot: tuple[int, int],
               target1: tuple[int, int], target2: tuple[int, int],
               palette: Image.Image) -> Image.Image:
    target_pivot = np.array((320.0, 320.0))
    source_basis = np.column_stack((np.subtract(muzzle1, source_pivot),
                                    np.subtract(muzzle2, source_pivot))).astype(float)
    target_basis = np.column_stack((np.subtract(target1, target_pivot),
                                    np.subtract(target2, target_pivot))).astype(float)
    forward = target_basis @ np.linalg.inv(source_basis)
    inverse_linear = np.linalg.inv(forward)
    offset = np.asarray(source_pivot) - inverse_linear @ target_pivot
    inverse = (inverse_linear[0, 0], inverse_linear[0, 1], offset[0],
               inverse_linear[1, 0], inverse_linear[1, 1], offset[1])
    sprite = source.transform((640, 640), Image.Transform.AFFINE, inverse,
                              resample=Image.Resampling.NEAREST)
    alpha = sprite.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = sprite.convert("RGB").quantize(palette=palette).convert("RGB")
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def build_up(palette: Image.Image) -> Image.Image:
    source = Image.open(SOURCE / "new_p60_redraw.png").convert("RGBA")
    scale = 0.32
    source_muzzle = (805, 159)
    target_muzzle = (348, 80)
    source_origin = (source_muzzle[0] - target_muzzle[0] / scale,
                     source_muzzle[1] - target_muzzle[1] / scale)
    sprite = source.transform(
        (640, 640), Image.Transform.AFFINE,
        (1 / scale, 0, source_origin[0], 0, 1 / scale, source_origin[1]),
        resample=Image.Resampling.NEAREST,
    )
    alpha = sprite.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = sprite.convert("RGB").quantize(palette=palette).convert("RGB")
    sprite = rgb.convert("RGBA")
    sprite.putalpha(alpha)

    # The fixed base occludes this part of the receiver. Its socket has to
    # reach the pivot at (320, 320), or the raised head looks detached.
    underside = Image.new("RGBA", (640, 640))
    draw = ImageDraw.Draw(underside)
    draw.polygon([(278, 244), (309, 251), (333, 284), (335, 316),
                  (321, 337), (305, 333), (284, 310), (271, 281)],
                 fill="#06070E")
    inner = [(283, 251), (307, 260), (325, 287), (329, 314),
             (317, 327), (308, 324), (291, 305), (278, 280)]
    draw.polygon(inner, fill="#383841")
    draw.line(inner[:4], fill="#635C5B", width=2)
    draw.polygon([(301, 298), (315, 290), (324, 302),
                  (320, 318), (312, 323), (299, 310)], fill="#242228")
    for x, y in ((310, 299), (315, 315)):
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill="#917D67")
    underside.alpha_composite(sprite)
    return underside


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    master = Image.open(MASTER).convert("RGBA")
    palette = master.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    sheet = Image.new("RGBA", (1280, 640))
    original_area = int(np.count_nonzero(np.asarray(master)[:, :, 3] == 255))
    for index, label in enumerate(("p60", "m40")):
        if label == "p60":
            pose = build_up(palette)
        else:
            filename, muzzle1, muzzle2, source_pivot, target1, target2 = DOWN
            source = Image.open(SOURCE / filename).convert("RGBA")
            pose = build_pose(source, muzzle1, muzzle2, source_pivot,
                              target1, target2, palette)
        area = int(np.count_nonzero(np.asarray(pose)[:, :, 3] == 255))
        if not 0.85 <= area / original_area <= 1.15:
            raise ValueError(f"{label}: opaque area {area} differs from {original_area}")
        pose.save(OUTPUT / f"sentry_head_elev_{label}.png")
        sheet.alpha_composite(pose, (index * 640, 0))
    sheet.save(OUTPUT / "_contact_sheet.png")


if __name__ == "__main__":
    main()
