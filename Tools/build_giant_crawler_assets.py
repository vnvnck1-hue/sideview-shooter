"""Build the giant's 2x, full-detail animation frames from the archived masters.

The normal crawler keeps its 10px-grid art. Giant frames use the detailed
pre-bake masters, enlarged to 1086x1512 so Godot can render them at 0.7 scale
(70% of the former 2.0 world scale) without sharing the low-detail textures.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "GodotPrototype"
NORMAL_MASTERS = GODOT / "assets_original/character/ToxicTumorCrawler"
ROAR_MASTERS = ROOT / "Assets/GameReady/Characters/ToxicTumorCrawler/Frames/roar"
DEST = GODOT / "assets/character/GiantToxicTumorCrawler"
CLIPS = ("walk", "jump", "death", "attack", "roar")
FACTOR = 2


def source(clip: str, index: int) -> Path:
    if clip == "roar":
        return ROAR_MASTERS / f"toxic_tumor_crawler_roar_{index:02d}.png"
    return NORMAL_MASTERS / clip / f"{clip}_{index:02d}.png"


def measure(image: Image.Image) -> dict:
    opaque = np.asarray(image.getchannel("A")) > 8
    rows = np.flatnonzero(opaque.sum(axis=1) >= 6 * FACTOR)
    cols = np.flatnonzero(opaque.sum(axis=0) >= 6 * FACTOR)
    if len(rows) == 0 or len(cols) == 0:
        raise ValueError("empty frame")
    return {
        "feet_y": int(rows[-1]) + 1,
        "bbox": [int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1],
    }


def main() -> None:
    base = json.loads((GODOT / "assets/character/ToxicTumorCrawler/crawler_meta.json").read_text(encoding="utf-8"))
    output = {
        "cell": [543 * FACTOR, 756 * FACTOR],
        "sourceScale": FACTOR,
        "clips": base["clips"],
        "frames": {},
    }
    for clip in CLIPS:
        for index in range(1, int(base["clips"][clip]["frames"]) + 1):
            key = f"{clip}_{index:02d}"
            src = source(clip, index)
            with Image.open(src) as input_image:
                original = input_image.convert("RGBA")
                # Point enlargement keeps every hand-authored edge and palette color.
                enlarged = original.resize((original.width * FACTOR, original.height * FACTOR), Image.Resampling.NEAREST)
            target = DEST / clip / f"{key}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            enlarged.save(target, optimize=True)
            output["frames"][key] = measure(enlarged)
            print(f"{key}: {target.relative_to(ROOT)}")
    (DEST / "crawler_meta.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
