"""Bake the generated jump and ladder-climb poses to the current 80x80 art grid.

The output uses four 320x320 cells per clip, matching the game's v1 player
resource. Source images are retained in Assets/Generated/PlayerMovement.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Generated/PlayerMovement"
GAME = ROOT / "Assets/GameReady/Characters/HoodedMechanic"
GODOT = ROOT / "GodotPrototype/assets/character"
ART_CELL = 80
GAME_CELL = 320


def opaque_crop(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    image.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("Generated pose contains no visible pixels")
    return image.crop(bounds)


def jump_sources() -> list[Image.Image]:
    sheet = Image.open(SOURCE / "jump_source.png").convert("RGBA")
    return [
        opaque_crop(sheet.crop((round(i * sheet.width / 4), 0,
                                round((i + 1) * sheet.width / 4), sheet.height)))
        for i in range(4)
    ]


def climb_sources() -> list[Image.Image]:
    # The fourth pose returns to the low-grip pose to close the loop.
    names = ["climb_low_source.png", "climb_reach_a_source.png",
             "climb_reach_b_source.png", "climb_low_source.png"]
    return [opaque_crop(Image.open(SOURCE / name)) for name in names]


def climb_back_sources() -> list[Image.Image]:
    sheet = Image.open(SOURCE / "climb_back_source.png").convert("RGBA")
    poses = [
        opaque_crop(sheet.crop((round(i * sheet.width / 4), 0,
                                round((i + 1) * sheet.width / 4), sheet.height)))
        for i in (0, 1)
    ]
    # The generated rear view is nearly symmetrical. Mirror the first two
    # poses so the reaching hand and raised boot truly alternate in the loop.
    return poses + [poses[0].transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                    poses[1].transpose(Image.Transpose.FLIP_LEFT_RIGHT)]


def art_frames(clip: str, sources: list[Image.Image]) -> list[Image.Image]:
    if clip == "jump":
        scale = min(65 / max(p.height for p in sources),
                    72 / max(p.width for p in sources))
        foot_lines = [79, 75, 72, 79]
    else:
        scale = min(72 / max(p.height for p in sources),
                    72 / max(p.width for p in sources))
        foot_lines = [78, 76, 74, 76]

    sampled = []
    for source in sources:
        size = (round(source.width * scale), round(source.height * scale))
        pose = source.resize(size, Image.Resampling.BOX)
        alpha = pose.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        pose.putalpha(alpha)
        sampled.append(pose)

    # One palette for every pose in a clip prevents color flicker on playback.
    palette_source = Image.new("RGB", (sum(p.width for p in sampled),
                                       max(p.height for p in sampled)), (0, 0, 0))
    x = 0
    for pose in sampled:
        palette_source.paste(pose.convert("RGB"), (x, 0), pose.getchannel("A"))
        x += pose.width
    palette = palette_source.quantize(colors=32, method=Image.Quantize.MEDIANCUT)

    frames = []
    x = 0
    for index, pose in enumerate(sampled):
        rgb = Image.new("RGB", pose.size)
        rgb.paste(pose.convert("RGB"), mask=pose.getchannel("A"))
        colored = rgb.quantize(palette=palette).convert("RGBA")
        colored.putalpha(pose.getchannel("A"))
        canvas = Image.new("RGBA", (ART_CELL, ART_CELL))
        left = (ART_CELL - pose.width) // 2
        top = foot_lines[index] - pose.height + 1
        canvas.alpha_composite(colored, (left, top))
        frames.append(canvas.resize((GAME_CELL, GAME_CELL), Image.Resampling.NEAREST))
        x += pose.width
    return frames


def save_clip(clip: str, frames: list[Image.Image]) -> None:
    sheet = Image.new("RGBA", (GAME_CELL * 4, GAME_CELL))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * GAME_CELL, 0))
        name = f"{clip}_{index + 1:02d}.png"
        for base in (GAME, GODOT):
            path = base / "Frames" / clip / name
            path.parent.mkdir(parents=True, exist_ok=True)
            frame.save(path)
    sheet_name = f"hooded_mechanic_{clip}_4f_v1.png"
    for base in (GAME, GODOT):
        path = base / "Sheets" / sheet_name
        path.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(path)


def main() -> None:
    for clip, sources in (("jump", jump_sources()), ("climb", climb_sources()),
                          ("climb_back", climb_back_sources())):
        save_clip(clip, art_frames(clip, sources))
        print(f"{clip}: 4 frames, 320x320 per frame, 1280x320 sheet")


if __name__ == "__main__":
    main()
