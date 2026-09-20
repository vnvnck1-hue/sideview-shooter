"""Turn the two approved crawler pose strips into Native4 animation assets.

The source strips were drawn against the existing ToxicTumorCrawler sheet. This
step keeps their silhouettes, reduces them to the ART_GUIDE Native4 palette and
writes ten independent 80x80 RGBA frames plus two five-column sheets.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Generated/CharacterAnimation/ToxicTumorCrawler"
DEST = ROOT / "Assets/GameReady/Native4/character/ToxicTumorCrawler"
CELL = 80
SCALE = 0.14
ALPHA_CUTOFF = 128

# Sampled from the approved crawler's outline, flesh and tumor clusters. The
# highlight is reserved explicitly because automatic quantization loses it.
PALETTE = np.array([
    (22, 1, 3), (42, 3, 8), (69, 2, 15), (82, 5, 19),
    (113, 9, 25), (153, 21, 38), (188, 26, 45), (240, 45, 57),
    (252, 47, 57), (64, 48, 26), (103, 83, 41), (114, 96, 46),
    (164, 162, 68), (199, 199, 111), (218, 228, 180), (237, 247, 203),
], dtype=np.uint8)

CLIPS = {
    "wall_jump": {
        "source": "toxic_tumor_crawler_wall_jump_5f_source_v1.png",
        "ranges": [(61, 373), (456, 876), (906, 1371), (1400, 1724), (1825, 2060)],
        "fps": 10,
        "description": "floor takeoff to right-wall grip",
    },
    "corner_turn": {
        "source": "toxic_tumor_crawler_corner_turn_5f_source_v1.png",
        "ranges": [(59, 366), (463, 773), (878, 1174), (1268, 1626), (1701, 2085)],
        "fps": 10,
        "description": "concave inside corner: right wall to ceiling, body stays within the room",
    },
}


def crop_pose(sheet: Image.Image, x0: int, x1: int) -> Image.Image:
    pose = sheet.crop((x0, 0, x1, sheet.height))
    mask = np.asarray(pose.getchannel("A")) >= ALPHA_CUTOFF
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError(f"Empty source range {x0}:{x1}")
    return pose.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def native_pose(pose: Image.Image, palette: np.ndarray, flip: bool = False) -> Image.Image:
    width = round(pose.width * SCALE)
    height = round(pose.height * SCALE)
    if width > CELL - 4 or height > CELL - 4:
        raise ValueError(f"Pose {pose.size} too large for {CELL}x{CELL} cell")
    pose = pose.resize((width, height), Image.Resampling.BOX)
    if flip:
        pose = pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    rgba = np.asarray(pose, dtype=np.uint8)
    visible = rgba[:, :, 3] >= ALPHA_CUTOFF
    rgb = rgba[:, :, :3].astype(np.int32)
    distances = ((rgb[:, :, None, :] - palette[None, None, :, :].astype(np.int32)) ** 2).sum(3)
    mapped = palette[distances.argmin(2)]
    result = np.zeros((height, width, 4), dtype=np.uint8)
    result[:, :, :3] = mapped
    result[:, :, 3] = np.where(visible, 255, 0).astype(np.uint8)
    result[~visible] = 0
    canvas = Image.new("RGBA", (CELL, CELL))
    canvas.alpha_composite(Image.fromarray(result, "RGBA"), ((CELL - width) // 2, (CELL - height) // 2))
    return canvas


def inside_corner_preview(sheet: Image.Image) -> None:
    """Show the sprites against a concave right-wall/ceiling guide for review."""
    panel_size = 96
    preview = Image.new("RGBA", (panel_size * 5, panel_size), (31, 36, 46, 255))
    # The room is the lower-left area; the solid ceiling and wall are above/right.
    offsets = [(20, 14), (15, 13), (16, 3), (-2, 2), (-12, 2)]
    for index, (dx, dy) in enumerate(offsets):
        panel = Image.new("RGBA", (panel_size, panel_size), (31, 36, 46, 255))
        pixels = np.asarray(panel).copy()
        pixels[:20, :, :3] = (72, 80, 92)
        pixels[:, 78:, :3] = (72, 80, 92)
        pixels[19:21, :78, :3] = (108, 119, 127)
        pixels[20:, 77:79, :3] = (108, 119, 127)
        panel = Image.fromarray(pixels, "RGBA")
        frame = sheet.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        panel.alpha_composite(frame, (dx, dy))
        preview.alpha_composite(panel, (index * panel_size, 0))
    preview.resize((preview.width * 4, preview.height * 4), Image.Resampling.NEAREST).convert("RGB").save(
        SOURCE / "toxic_tumor_crawler_inside_corner_preview_v1.png"
    )


def main() -> None:
    palette = PALETTE
    sheets: dict[str, Image.Image] = {}
    metadata = {
        "formatVersion": 1,
        "character": "toxic_tumor_crawler",
        "artPixelToWorldPixel": 4,
        "cell": [CELL, CELL],
        "commonPivot": {"x": 0.5, "y": 0.0, "description": "bottom center of each cell, matching existing crawler metadata"},
        "orientation": "right-wall jump, then right-wall-to-ceiling inside corner; mirror or rotate for other surfaces",
        "clips": {},
    }
    for name, config in CLIPS.items():
        source = Image.open(SOURCE / config["source"]).convert("RGBA")
        sheet = Image.new("RGBA", (CELL * 5, CELL))
        frames = []
        for index, (x0, x1) in enumerate(config["ranges"], start=1):
            pose = crop_pose(source, x0, x1)
            frame = native_pose(pose, palette)
            if name == "corner_turn" and index == 1:
                # An exact handoff removes the one-frame snap between clips.
                frame = sheets["wall_jump"].crop((CELL * 4, 0, CELL * 5, CELL))
            frame_path = DEST / name / f"{name}_{index:02d}.png"
            frame_path.parent.mkdir(parents=True, exist_ok=True)
            frame.save(frame_path, optimize=True)
            sheet.alpha_composite(frame, ((index - 1) * CELL, 0))
            frames.append(str(frame_path.relative_to(DEST)).replace("\\", "/"))
        sheet_path = DEST / f"{name}_5f_v1.png"
        sheet.save(sheet_path, optimize=True)
        sheets[name] = sheet
        metadata["clips"][name] = {
            "frames": frames,
            "sheet": sheet_path.name,
            "fps": config["fps"],
            "loop": False,
            "description": config["description"],
        }
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "wall_motion_v1.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    inside_corner_preview(sheets["corner_turn"])
    print(f"Created 10 frames, 2 sheets and metadata in {DEST}")
    print("Palette:", ["#" + "".join(f"{v:02x}" for v in color) for color in palette])


if __name__ == "__main__":
    main()
