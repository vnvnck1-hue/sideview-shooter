"""Prepare the sentry's yaw keyposes and telescoping support sprites."""

from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageDraw
from build_normal_maps import height_map, normal_from_height


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HEAD = ROOT / "GodotPrototype/assets/props/defense/sentry/sentry_head.png"
SOURCE_BASE = ROOT / "GodotPrototype/assets/props/defense/sentry/sentry_base.png"
YAW = ROOT / "Assets/Generated/SentryTurret/YawFan"
LIFT = ROOT / "Assets/Generated/SentryTurret/Lift"
GAME = ROOT / "GodotPrototype/assets/props/defense/sentry"
NORMALS = ROOT / "GodotPrototype/assets/normals/props/defense/sentry"

# Source socket centers were measured on the illustrated underside coupling.
# X scale follows the change in projected barrel length; Y scale keeps the
# receiver, optic and muzzle spacing consistent with the original 0-degree art.
YAW_POSES = (
    (30, (830, 865), (0.35, 0.23)),
    (60, (680, 1005), (0.34, 0.20)),
    (90, (680, 1030), (0.28, 0.20)),
)


def normalize(source: Image.Image, anchor: tuple[int, int],
              scale: tuple[float, float], target: tuple[int, int],
              palette: Image.Image) -> Image.Image:
    sx, sy = scale
    ax, ay = anchor
    tx, ty = target
    image = source.convert("RGBA").transform(
        (640, 640), Image.Transform.AFFINE,
        (1 / sx, 0, ax - tx / sx, 0, 1 / sy, ay - ty / sy),
        resample=Image.Resampling.NEAREST,
    )
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = image.convert("RGB").quantize(palette=palette).convert("RGB")
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def build() -> None:
    master = Image.open(SOURCE_HEAD).convert("RGBA")
    palette = master.convert("RGB").quantize(
        colors=256, method=Image.Quantize.MEDIANCUT)
    yaw_sheet = Image.new("RGBA", (640 * 4, 640))
    zero = Image.new("RGBA", (640, 640))
    zero.alpha_composite(master, (231, 123))
    yaw_sheet.alpha_composite(zero)

    for index, (angle, anchor, scale) in enumerate(YAW_POSES, 1):
        source = Image.open(YAW / "Source" / f"sentry_head_yaw{angle}_source.png")
        # The original receiver ends about 18 px above the true gimbal pivot.
        pose = normalize(source, anchor, scale, (320, 302), palette)
        if pose.getbbox() is None:
            raise ValueError(f"empty yaw {angle} pose")
        pose.save(YAW / f"sentry_head_yaw_{angle}.png")
        yaw_sheet.alpha_composite(pose, (index * 640, 0))
    yaw_sheet.save(YAW / "_turn_contact_sheet.png")

    riser_source = Image.open(LIFT / "Source/sentry_aux_riser_source.png")
    # At full extension the lower sleeve nests in the existing base bearing
    # at (320, 320), and the upper trunnion carries the raised head pivot.
    riser = normalize(riser_source, (510, 1420), (0.24, 0.15),
                      (320, 320), palette)
    riser.save(LIFT / "sentry_aux_riser_extended.png")

    base = Image.new("RGBA", (640, 640))
    base.alpha_composite(Image.open(SOURCE_BASE).convert("RGBA"), (161, 302))
    preview = Image.new("RGBA", (640 * 3, 640), (24, 24, 28, 255))
    draw = ImageDraw.Draw(preview)
    down = Image.open(ROOT / "Assets/Generated/SentryTurret/AngleFan/"
                      "sentry_head_elev_m40.png").convert("RGBA")
    down = down.rotate(-25, Image.Resampling.NEAREST, center=(320, 320))
    raised = Image.new("RGBA", (640, 640))
    raised.alpha_composite(down, (0, -176))
    raised.alpha_composite(riser)
    raised.alpha_composite(base)
    preview.alpha_composite(raised)
    draw.text((12, 12), "-65° + 176 px lift", fill="white")
    collapsed = Image.new("RGBA", (640, 640))
    collapsed.alpha_composite(zero)
    collapsed.alpha_composite(riser, (0, 176))
    collapsed.alpha_composite(base)
    preview.alpha_composite(collapsed, (640, 0))
    draw.text((652, 12), "0° collapsed", fill="white")
    front = Image.new("RGBA", (640, 640))
    front.alpha_composite(Image.open(YAW / "sentry_head_yaw_90.png"),
                          (0, -176))
    front.alpha_composite(riser)
    front.alpha_composite(base)
    preview.alpha_composite(front, (1280, 0))
    draw.text((1292, 12), "front view + 176 px lift", fill="white")
    preview.save(LIFT / "_riser_review.png")

    for file in (*YAW.glob("sentry_head_yaw_*.png"),
                 LIFT / "sentry_aux_riser_extended.png"):
        image = Image.open(file).convert("RGBA")
        alpha = np.asarray(image)[:, :, 3]
        if image.size != (640, 640) or not np.all(np.isin(alpha, (0, 255))):
            raise ValueError(f"invalid sprite format: {file}")

    # Runtime sprites use the same lighting path as the original head/base.
    GAME.mkdir(parents=True, exist_ok=True)
    NORMALS.mkdir(parents=True, exist_ok=True)
    game_sources = [
        *(YAW / f"sentry_head_yaw_{angle}.png" for angle in (30, 60, 90)),
        LIFT / "sentry_aux_riser_extended.png",
        ROOT / "Assets/Generated/SentryTurret/AngleFan/sentry_head_elev_p60.png",
        ROOT / "Assets/Generated/SentryTurret/AngleFan/sentry_head_elev_m40.png",
    ]
    for file in game_sources:
        dst = GAME / file.name
        shutil.copy2(file, dst)
        h, _ = height_map(Image.open(dst), bevel=6, blur=0.8)
        normal = normal_from_height(h, strength=3.2)
        rgb = ((normal * 0.5 + 0.5) * 255).round().clip(0, 255).astype(np.uint8)
        alpha = np.full(rgb.shape[:2] + (1,), 255, dtype=np.uint8)
        Image.fromarray(np.concatenate((rgb, alpha), axis=2), "RGBA").save(
            NORMALS / file.name)


if __name__ == "__main__":
    build()
