"""Slice the generated researcher pose sheets into aligned Native4 animation clips.

Input sheets are visual source art. Output frames have a shared 80x80 art-pixel
cell, binary alpha, one 16-color palette per character, and a fixed floor pivot.
The output is rebuilt with: python Tools/build_researcher_animation.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build_normal_maps import height_map, normal_from_height
from upscale_native4 import upscale


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Assets/Generated/NPCAnimation"
NATIVE = ROOT / "Assets/GameReady/Native4/character/npc"
PREVIEW = SOURCES / "review"

CELL = 80
ALPHA_CUT = 110
COLORS = 16
CLIPS = ("idle_breathe", "idle_notes", "idle_listen", "walk")
FPS = {"idle_breathe": 3, "idle_notes": 3, "idle_listen": 3, "walk": 8}
PEOPLE = {"researcher_junior": 63, "researcher_male": 65}


def solid_body(mask: np.ndarray) -> np.ndarray:
    """Keep the figure, drop blobs that float free of it.

    Some generated poses carry a faint shadow smear a few pixels below the boots.
    Inside the bounding box it reads as extra height, so the pose gets scaled down
    and its feet end up hanging above the cell floor while every other frame stands
    on it. Anything under a twentieth of the body is not part of the body.
    """
    height, width = mask.shape
    seen = np.zeros_like(mask)
    blobs = []
    for start_y, start_x in zip(*np.nonzero(mask)):
        if seen[start_y, start_x]:
            continue
        pixels = []
        todo = [(int(start_y), int(start_x))]
        seen[start_y, start_x] = True
        while todo:
            y, x = todo.pop()
            pixels.append((y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    todo.append((ny, nx))
        blobs.append(pixels)
    body = max(len(pixels) for pixels in blobs)
    keep = np.zeros_like(mask)
    for pixels in blobs:
        if len(pixels) * 20 >= body:
            ys, xs = np.array(pixels).T
            keep[ys, xs] = True
    return keep


def extract(sheet: Image.Image, col: int, row: int, cols: int, rows: int, height: int) -> Image.Image:
    """Crop one pose by its invisible grid cell and align by the head, not the stride."""
    width, sheet_height = sheet.size
    x0, x1 = round(col * width / cols), round((col + 1) * width / cols)
    y0, y1 = round(row * sheet_height / rows), round((row + 1) * sheet_height / rows)
    region = sheet.crop((x0, y0, x1, y1)).convert("RGBA")
    pixels = np.asarray(region).copy()
    if not (pixels[..., 3] >= ALPHA_CUT).any():
        raise ValueError(f"Empty sheet cell {col}, {row}")
    kept = solid_body(pixels[..., 3] >= ALPHA_CUT)
    pixels[..., 3] = np.where(kept, pixels[..., 3], 0)
    region = Image.fromarray(pixels, "RGBA")
    ys, xs = np.nonzero(kept)
    if len(xs) < 100:
        raise ValueError(f"Empty sheet cell {col}, {row}")
    left, top, right, bottom = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    pose = region.crop((left, top, right, bottom))
    pose = pose.resize((round(pose.width * height / pose.height), height), Image.Resampling.BOX)
    if pose.width > CELL - 4:
        raise ValueError(f"Pose too wide: {pose.width} at {col}, {row}")

    # The front/back shoes change the bounding-box midpoint during a walk.
    # Align the head (top 36%) so the torso stays in place across all frames.
    a = np.asarray(pose)[..., 3]
    hy, hx = np.nonzero(a[: max(1, round(height * .36))] >= ALPHA_CUT)
    head_center = float(np.median(hx)) if len(hx) else pose.width / 2
    paste_x = round(CELL / 2 - head_center)
    paste_y = CELL - 1 - height
    if paste_x < 0 or paste_x + pose.width > CELL:
        raise ValueError(f"Pose outside cell: {paste_x}, {pose.width}")
    canvas = Image.new("RGBA", (CELL, CELL))
    canvas.paste(pose, (paste_x, paste_y))
    return canvas


def quantize_together(frames: list[Image.Image]) -> list[Image.Image]:
    """Use one palette across a character's clips so colors do not flicker."""
    stack = Image.new("RGB", (CELL * len(frames), CELL), (55, 49, 52))
    for i, frame in enumerate(frames):
        stack.paste(frame.convert("RGB"), (i * CELL, 0), frame)
    palette = stack.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    result = []
    for i, frame in enumerate(frames):
        rgb = palette.crop((i * CELL, 0, (i + 1) * CELL, CELL)).convert("RGB")
        rgb_data = np.asarray(rgb)
        alpha = np.asarray(frame)[..., 3] >= ALPHA_CUT
        # Generated walk sheets can leave a detached one-pixel speck below a boot.
        # Preserve all real connected pieces, including small badges, above 2 px.
        seen = np.zeros_like(alpha, dtype=bool)
        for y, x in zip(*np.nonzero(alpha)):
            if seen[y, x]:
                continue
            component = []
            todo = [(int(y), int(x))]
            seen[y, x] = True
            while todo:
                cy, cx = todo.pop()
                component.append((cy, cx))
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < CELL and 0 <= nx < CELL and alpha[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        todo.append((ny, nx))
            if len(component) <= 2:
                for cy, cx in component:
                    alpha[cy, cx] = False
        out = np.dstack((rgb_data, np.where(alpha, 255, 0).astype(np.uint8)))
        out[out[..., 3] == 0] = 0
        result.append(Image.fromarray(out, "RGBA"))
    return result


def sheet_preview(name: str, frames: dict[str, list[Image.Image]]) -> None:
    scale, label_h, gap = 4, 28, 12
    w = 8 * CELL * scale + gap * 9
    h = len(CLIPS) * (CELL * scale + label_h + gap) + gap
    board = Image.new("RGB", (w, h), (37, 39, 47))
    draw = ImageDraw.Draw(board)
    for row, clip in enumerate(CLIPS):
        y = gap + row * (CELL * scale + label_h + gap)
        draw.text((gap, y), f"{name} / {clip} / {FPS[clip]} fps", fill=(226, 223, 205))
        for i, frame in enumerate(frames[clip]):
            x = gap + i * (CELL * scale + gap)
            board.paste(frame.resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST),
                        (x, y + label_h), frame.resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    board.save(PREVIEW / f"{name}_clips_contact.png")


def gif_preview(name: str, clips: dict[str, list[Image.Image]]) -> None:
    """Short review GIF with the two sprite loops at visible scale."""
    scale = 4
    background = Image.new("RGBA", (CELL * scale, CELL * scale), (43, 46, 55, 255))
    display = []
    durations = []
    for clip in CLIPS:
        repetitions = 2 if clip == "walk" else 1
        for frame in clips[clip] * repetitions:
            canvas = background.copy()
            sprite = frame.resize(canvas.size, Image.Resampling.NEAREST)
            canvas.alpha_composite(sprite)
            display.append(canvas.convert("RGB"))
            durations.append(round(1000 / FPS[clip]))
    display[0].save(PREVIEW / f"{name}_clips.gif", save_all=True, append_images=display[1:],
                    duration=durations, loop=0, disposal=2, optimize=False)


def build(name: str, height: int) -> None:
    idle = Image.open(SOURCES / f"{name}_idle_source.png").convert("RGBA")
    walk = Image.open(SOURCES / f"{name}_walk_source.png").convert("RGBA")
    raw = []
    for row in range(3):
        raw.extend(extract(idle, col, row, 4, 3, height) for col in range(4))
    raw.extend(extract(walk, col, row, 4, 2, height) for row in range(2) for col in range(4))
    normalized = quantize_together(raw)
    clips = {clip: normalized[row * 4:(row + 1) * 4] if row < 3 else normalized[12:]
             for row, clip in enumerate(CLIPS)}
    for clip, frames in clips.items():
        output = NATIVE / name / "animations" / clip
        output.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames, 1):
            frame.save(output / f"{clip}_{index:02d}.png", optimize=True)
    sheet_preview(name, clips)
    gif_preview(name, clips)
    print(f"{name}: 3 x 4-frame idle clips + 8-frame walk; 80x80, {COLORS} colors, alpha 0/255")


def scene_review() -> None:
    """Preview both new clips beside the ORIGINAL player in an existing room capture."""
    background = Image.open(ROOT / "Assets/GameReady/Validation/corridor_long_tile_prop_validation.png").convert("RGBA")
    people = ("researcher_junior", "researcher_male")
    x_centers = (745, 1515)
    scale = 2.8  # Native4 4x world pixels viewed at ~0.7: original player is ~185 px tall.
    size = round(CELL * scale)
    floor = 655
    frames = []
    durations = []
    for clip in CLIPS:
        length = 8 if clip == "walk" else 4
        for index in range(1, length + 1):
            scene = background.copy()
            for name, center_x in zip(people, x_centers):
                art = Image.open(NATIVE / name / "animations" / clip / f"{clip}_{index:02d}.png").convert("RGBA")
                scaled = art.resize((size, size), Image.Resampling.NEAREST)
                scene.alpha_composite(scaled, (center_x - size // 2, floor - size + round(scale)))
            frames.append(scene.crop((380, 345, 1920, 700)).convert("RGB"))
            durations.append(round(1000 / FPS[clip]))
        if clip == "idle_breathe":
            scene.convert("RGB").save(PREVIEW / "researchers_with_player_corridor.png", optimize=True)
    frames[0].save(PREVIEW / "researchers_with_player_corridor.gif", save_all=True,
                   append_images=frames[1:], duration=durations, loop=0, disposal=2, optimize=False)


def install_game_frames() -> None:
    """Make the 4x world textures and matching character normals for new frames."""
    files = [NATIVE / "researcher_male/idle_01.png"]
    files += [p for name in PEOPLE for p in sorted((NATIVE / name / "animations").rglob("*.png"))]
    world_root = ROOT / "GodotPrototype/assets"
    for art in files:
        rel = art.relative_to(ROOT / "Assets/GameReady/Native4")
        problem = upscale(rel)
        if problem:
            raise ValueError(problem)
        world = world_root / rel
        h, alpha = height_map(Image.open(world), bevel=4, blur=0.6)
        normal = normal_from_height(h, strength=2.8)
        rgb = ((normal * 0.5 + 0.5) * 255).round().clip(0, 255).astype(np.uint8)
        rgb[alpha < 0.03] = (128, 128, 255)
        out = np.dstack((rgb, np.full(rgb.shape[:2], 255, dtype=np.uint8)))
        target = world_root / "normals" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out, "RGBA").save(target, optimize=True)


if __name__ == "__main__":
    for npc, art_height in PEOPLE.items():
        build(npc, art_height)
    install_game_frames()
    scene_review()
