"""Bake the generated four-pose run sheet into the player's Native4 split format.

Input: Assets/Generated/PlayerRun/hooded_mechanic_run_sheet_v1.png
Output: matching 320px frames in GameReady and Godot, split head/body,
        per-frame anchors in split_meta.json, and Godot normal maps.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_hooded_mechanic_head_split import hood_top, split_frame
from build_normal_maps import height_map, normal_from_height
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "Assets/Generated/PlayerRun/hooded_mechanic_run_sheet_v1.png"
GAME = ROOT / "Assets/GameReady/Characters/HoodedMechanic"
GODOT = ROOT / "GodotPrototype/assets/character"
CELL = 320
ART_CELL = 80
ART_HEIGHT = 66


def bake_pose(source: Image.Image) -> Image.Image:
    # The generated sheet has transparent gutters; threshold its soft edge before
    # sampling to the game's 1 art px = 4 world px grid.
    alpha = source.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    box = alpha.getbbox()
    if box is None:
        raise ValueError("Empty run pose")
    source.putalpha(alpha)
    cut = source.crop(box)
    width = round(cut.width * ART_HEIGHT / cut.height)
    if width > ART_CELL - 4:
        raise ValueError("Run pose exceeds player cell")
    art = cut.resize((width, ART_HEIGHT), Image.Resampling.BOX)
    a = art.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    art.putalpha(a)
    # Keep the established limited palette and hard alpha of the Native4 assets.
    rgb = Image.new("RGB", art.size, (0, 0, 0))
    rgb.paste(art, mask=a)
    palette = rgb.quantize(colors=24, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    palette.putalpha(a)
    canvas = Image.new("RGBA", (ART_CELL, ART_CELL))
    canvas.alpha_composite(palette, ((ART_CELL - width) // 2, ART_CELL - ART_HEIGHT))
    return canvas.resize((CELL, CELL), Image.Resampling.NEAREST)


def normal_map(image: Image.Image) -> Image.Image:
    h, alpha = height_map(image, 4, 0.6)
    n = normal_from_height(h, 2.8)
    rgb = ((n * 0.5 + 0.5) * 255).round().clip(0, 255).astype(np.uint8)
    rgb[alpha < 8 / 255] = (128, 128, 255)
    return Image.fromarray(np.dstack([rgb, np.full(alpha.shape, 255, dtype=np.uint8)]), "RGBA")


def save_both(relative: str, image: Image.Image) -> None:
    for root in (GAME, GODOT):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    if sheet.width % 4:
        raise ValueError("Expected four equal run cells")
    span = sheet.width // 4
    for index in range(4):
        pose = bake_pose(sheet.crop((index * span, 0, (index + 1) * span, sheet.height)))
        name = f"run_{index + 1:02d}.png"
        save_both(f"Frames/run/{name}", pose)
        # The run pose's head remains independent so mouse aiming and recoil work.
        top, hood_x = hood_top(pose)
        neck = (round(hood_x + 10), top + 110)
        head, body = split_frame(pose, neck)
        for part, frame in (("head", head), ("body", body)):
            save_both(f"Split/{part}/run/{name}", frame)
            normal_path = GODOT / f"../normals/character/Split/{part}/run/{name}"
            normal_path.parent.mkdir(parents=True, exist_ok=True)
            normal_map(frame).save(normal_path)
        shoulder = (neck[0] + 24, neck[1] + 6)
        for root in (GAME / "Split", GODOT / "Split"):
            meta_path = root / "split_meta.json"
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta["frames"][name[:-4]] = {
                "shoulder": list(shoulder),
                "shoulder_from_pivot": [shoulder[0] - 160, shoulder[1] - 320],
                "neck": list(neck),
                "neck_from_pivot": [neck[0] - 160, neck[1] - 320],
            }
            meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"{name}: hood={top}, neck={neck}, shoulder={shoulder}")


if __name__ == "__main__":
    main()
