"""Build anatomy-locked ToxicTumorCrawler wall and corner animation frames.

The generated pose studies define timing only. Every delivered frame is a
nearest-neighbor rigid transform of ONE canonical sprite extracted from the
approved monster source. This locks all tumor sacs, torso, face and limb bases.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_base_v2.png"
DEST = ROOT / "Assets/GameReady/Native4/character/ToxicTumorCrawler/WallMotionV2"
PREVIEW = ROOT / "Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_corner_types_anatomy_locked_v2.png"
STRIP_PREVIEW = ROOT / "Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_wall_motion_strips_v2.png"
JUMP_PREVIEW = ROOT / "Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_wall_jump_context_v2.png"
CELL = 80
BODY_SIZE = (52, 27)
ALPHA_CUTOFF = 128

PALETTE = np.array([
    (22, 1, 3), (42, 3, 8), (69, 2, 15), (82, 5, 19),
    (113, 9, 25), (153, 21, 38), (188, 26, 45), (240, 45, 57),
    (252, 47, 57), (64, 48, 26), (103, 83, 41), (114, 96, 46),
    (164, 162, 68), (199, 199, 111), (218, 228, 180), (237, 247, 203),
], dtype=np.uint8)

CLIPS = {
    "wall_jump": {
        "angles": [0, 20, 42, 65, 90],
        "description": "floor takeoff to right-wall attachment",
    },
    "corner_inside": {
        "angles": [90, 112, 135, 158, 180],
        "description": "concave room corner: right wall to underside of ceiling",
    },
    "corner_outside": {
        "angles": [90, 68, 45, 22, 0],
        "description": "convex ledge corner: left vertical face to top surface",
    },
}


def canonical_sprite() -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    alpha = np.asarray(source.getchannel("A")) >= ALPHA_CUTOFF
    ys, xs = np.where(alpha)
    cropped = source.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    resized = np.asarray(cropped.resize(BODY_SIZE, Image.Resampling.BOX), dtype=np.uint8)
    visible = resized[:, :, 3] >= ALPHA_CUTOFF
    rgb = resized[:, :, :3].astype(np.int32)
    dist = ((rgb[:, :, None, :] - PALETTE[None, None, :, :].astype(np.int32)) ** 2).sum(3)
    mapped = PALETTE[dist.argmin(2)]
    native = np.zeros((BODY_SIZE[1], BODY_SIZE[0], 4), dtype=np.uint8)
    native[:, :, :3] = mapped
    native[:, :, 3] = np.where(visible, 255, 0).astype(np.uint8)
    native[~visible] = 0
    canvas = Image.new("RGBA", (CELL, CELL))
    canvas.alpha_composite(Image.fromarray(native, "RGBA"), ((CELL - BODY_SIZE[0]) // 2, (CELL - BODY_SIZE[1]) // 2))
    return canvas


def draw_corner_preview(sheets: dict[str, Image.Image]) -> None:
    panel = 144
    rows = ["corner_inside", "corner_outside"]
    guide = Image.new("RGBA", (panel * 5, panel * 2), (30, 36, 46, 255))
    for row, name in enumerate(rows):
        for index in range(5):
            tile = Image.new("RGBA", (panel, panel), (30, 36, 46, 255))
            draw = ImageDraw.Draw(tile)
            if name == "corner_inside":
                # Solid ceiling above y=20 and right wall beyond x=118.
                draw.rectangle((0, 0, panel - 1, 19), fill=(72, 80, 92, 255))
                draw.rectangle((118, 0, panel - 1, panel - 1), fill=(72, 80, 92, 255))
                draw.line((0, 20, 118, 20), fill=(108, 119, 127, 255), width=2)
                draw.line((117, 20, 117, panel), fill=(108, 119, 127, 255), width=2)
            else:
                # Protruding solid occupies lower-right; its outer lip is 72,72.
                draw.rectangle((72, 72, panel - 1, panel - 1), fill=(72, 80, 92, 255))
                draw.line((72, 72, panel, 72), fill=(108, 119, 127, 255), width=2)
                draw.line((72, 72, 72, panel), fill=(108, 119, 127, 255), width=2)
            frame = sheets[name].crop((index * CELL, 0, (index + 1) * CELL, CELL))
            box = frame.getbbox()
            if name == "corner_inside":
                target_right = [115, 110, 100, 85, 73][index]
                dx = target_right - box[2]
                dy = 23 - box[1]
            elif index <= 1:
                dx = 69 - box[2]
                dy = [78, 67][index] - box[1]
            else:
                dx = [55, 70, 83][index - 2] - box[0]
                dy = 69 - box[3]
            tile.alpha_composite(frame, (dx, dy))
            guide.alpha_composite(tile, (index * panel, row * panel))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    guide.resize((guide.width * 3, guide.height * 3), Image.Resampling.NEAREST).convert("RGB").save(PREVIEW)


def draw_strip_preview(sheets: dict[str, Image.Image]) -> None:
    canvas = Image.new("RGBA", (CELL * 5, CELL * 3), (30, 36, 46, 255))
    for row, name in enumerate(CLIPS):
        canvas.alpha_composite(sheets[name], (0, row * CELL))
    canvas.resize((canvas.width * 4, canvas.height * 4), Image.Resampling.NEAREST).convert("RGB").save(STRIP_PREVIEW)


def draw_wall_jump_preview(sheet: Image.Image) -> None:
    panel = 144
    canvas = Image.new("RGBA", (panel * 5, panel), (30, 36, 46, 255))
    for index in range(5):
        tile = Image.new("RGBA", (panel, panel), (30, 36, 46, 255))
        draw = ImageDraw.Draw(tile)
        draw.rectangle((0, 116, panel - 1, panel - 1), fill=(72, 80, 92, 255))
        draw.rectangle((116, 0, panel - 1, panel - 1), fill=(72, 80, 92, 255))
        draw.line((0, 115, 116, 115), fill=(108, 119, 127, 255), width=2)
        draw.line((115, 0, 115, 116), fill=(108, 119, 127, 255), width=2)
        frame = sheet.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        box = frame.getbbox()
        target_right = [73, 82, 92, 107, 113][index]
        target_bottom = [114, 106, 91, 78, 70][index]
        tile.alpha_composite(frame, (target_right - box[2], target_bottom - box[3]))
        canvas.alpha_composite(tile, (index * panel, 0))
    canvas.resize((canvas.width * 3, canvas.height * 3), Image.Resampling.NEAREST).convert("RGB").save(JUMP_PREVIEW)


def main() -> None:
    base = canonical_sprite()
    DEST.mkdir(parents=True, exist_ok=True)
    base.save(DEST / "canonical_80x80.png", optimize=True)
    base_hash = hashlib.sha256(base.tobytes()).hexdigest()
    sheets: dict[str, Image.Image] = {}
    metadata = {
        "formatVersion": 2,
        "character": "toxic_tumor_crawler",
        "anatomyGuide": "Docs/TOXIC_TUMOR_CRAWLER_ANATOMY.md",
        "source": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "canonicalRgbaSha256": base_hash,
        "artPixelToWorldPixel": 4,
        "cell": [CELL, CELL],
        "commonPivot": {"x": 0.5, "y": 0.0, "description": "bottom center, same convention as the existing crawler sheet"},
        "clips": {},
    }
    for name, spec in CLIPS.items():
        sheet = Image.new("RGBA", (CELL * 5, CELL))
        files = []
        for index, angle in enumerate(spec["angles"], start=1):
            frame = base.rotate(angle, resample=Image.Resampling.NEAREST, expand=False)
            out = DEST / name / f"{name}_{index:02d}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            frame.save(out, optimize=True)
            sheet.alpha_composite(frame, ((index - 1) * CELL, 0))
            files.append(str(out.relative_to(DEST)).replace("\\", "/"))
        sheet_name = f"{name}_5f_v2.png"
        sheet.save(DEST / sheet_name, optimize=True)
        sheets[name] = sheet
        metadata["clips"][name] = {
            "frames": files,
            "sheet": sheet_name,
            "anglesDegCounterclockwise": spec["angles"],
            "fps": 10,
            "loop": False,
            "description": spec["description"],
        }
    (DEST / "wall_motion_v2.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    draw_corner_preview(sheets)
    draw_strip_preview(sheets)
    draw_wall_jump_preview(sheets["wall_jump"])
    print(f"Created 15 anatomy-locked frames, 3 sheets and preview in {DEST}")


if __name__ == "__main__":
    main()
