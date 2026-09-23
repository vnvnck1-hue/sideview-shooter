"""Preserve and modularize the selected service-gallery concept image.

All output pixels originate from the source image unless explicitly documented.
This tool keeps the original file unchanged and writes a reviewable staging pack.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


WORKSPACE = Path(__file__).resolve().parents[2]
SOURCE = WORKSPACE / "Assets/Generated/ParallaxConcepts/two-layer-maintenance-v1/A_service_gallery.png"
OUTPUT = WORKSPACE / "Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1"
RUNTIME = WORKSPACE / "GodotPrototype/assets/service_gallery"
CELL = 128

# Each outline follows the source's visible silhouette; the RGB inside is copied
# without resampling or painting. Coordinates are in the 1978 x 795 concept.
PROPS = {
    "workbench": [
        [(207, 529), (214, 521), (552, 521), (558, 529), (558, 642),
         (552, 643), (551, 658), (537, 658), (535, 649), (232, 649),
         (230, 658), (209, 658)],
        [(228, 482), (233, 475), (258, 475), (260, 518), (227, 518)],
        [(276, 485), (281, 480), (304, 480), (311, 516), (275, 516)],
        [(354, 496), (362, 490), (420, 490), (426, 517), (352, 517)],
        [(432, 496), (441, 488), (510, 488), (518, 517), (430, 517)],
    ],
    "motor_cart": [
        [(1305, 577), (1317, 569), (1565, 569), (1592, 577),
         (1596, 616), (1575, 623), (1567, 644), (1555, 658),
         (1516, 658), (1508, 640), (1390, 640), (1384, 659),
         (1340, 659), (1329, 643), (1310, 637), (1302, 617)],
        [(1306, 494), (1316, 481), (1369, 481), (1375, 493),
         (1375, 501), (1325, 501), (1325, 570), (1306, 570)],
        [(1363, 490), (1377, 490), (1377, 572), (1363, 572)],
        [(1395, 536), (1408, 529), (1524, 529), (1552, 536),
         (1552, 578), (1389, 578)],
        [(1584, 480), (1591, 480), (1600, 490), (1600, 506),
         (1589, 506), (1589, 498), (1576, 498), (1572, 506),
         (1572, 572), (1568, 572), (1568, 502), (1575, 492)],
    ],
    "service_cabinet": [
        [(1612, 524), (1624, 516), (1697, 516), (1707, 530),
         (1708, 638), (1723, 639), (1726, 656), (1603, 656),
         (1603, 640), (1612, 639)],
    ],
    "storage_cases": [
        [(1747, 540), (1761, 531), (1902, 531), (1916, 540),
         (1919, 643), (1746, 644)],
        [(1781, 497), (1792, 490), (1903, 490), (1911, 535),
         (1780, 535)],
        [(1908, 556), (1919, 551), (1977, 551), (1977, 645),
         (1905, 645)],
    ],
}

FIXTURES = {
    "wall_lantern": {
        "polygons": [[(134, 168), (143, 162), (159, 162), (170, 174),
                      (171, 225), (162, 237), (139, 237), (131, 226)]],
        "kind": "warm",
        "emitter": [151, 205],
        "radius": 190,
    },
    "ceiling_strip": {
        "polygons": [[(770, 84), (782, 79), (908, 79), (917, 88),
                      (914, 108), (768, 108)]],
        "kind": "warm",
        "emitter": [844, 97],
        "radius": 305,
    },
    "blue_strip_left": {
        "polygons": [[(429, 191), (437, 188), (523, 188), (530, 193),
                      (529, 210), (430, 210)]],
        "kind": "cool",
        "emitter": [480, 199],
        "radius": 235,
    },
    "blue_strip_mid": {
        "polygons": [[(840, 192), (846, 189), (942, 189), (947, 194),
                      (945, 211), (839, 210)]],
        "kind": "cool",
        "emitter": [894, 200],
        "radius": 235,
    },
    "blue_strip_right": {
        "polygons": [[(1788, 192), (1794, 189), (1886, 189), (1893, 194),
                      (1890, 211), (1787, 210)]],
        "kind": "cool",
        "emitter": [1840, 200],
        "radius": 235,
    },
}

# These source-derived patches are dormant at the original layout. They are
# shown only if a detached prop is hidden or moved, covering unavoidable
# painted-in remnants where the original art never exposed the underlying wall.
REPAIRS = {
    "workbench": {"target": (198, 467, 576, 669), "source": (578, 467)},
    "motor_cart": {"target": (1292, 470, 1610, 669), "source": (972, 470)},
    "service_cabinet": {"target": (1597, 508, 1733, 669), "source": (1060, 508)},
    "storage_cases": {"target": (1738, 481, 1978, 669), "source": (1000, 481)},
}


def write_grid() -> Path:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image = Image.open(SOURCE).convert("RGB")
    drawing = ImageDraw.Draw(image)
    for x in range(0, image.width, 128):
        drawing.line((x, 0, x, image.height), fill=(249, 83, 61), width=2)
        drawing.text((x + 5, 7), str(x), fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
    for y in range(0, image.height, 128):
        drawing.line((0, y, image.width, y), fill=(249, 83, 61), width=2)
        drawing.text((5, y + 4), str(y), fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
    out = OUTPUT / "analysis_grid.png"
    image.save(out)
    return out


def write_crops() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image = Image.open(SOURCE).convert("RGB")
    regions = {
        "left_workbench": (180, 450, 590, 675),
        "rolling_cart": (1260, 450, 1620, 680),
        "right_storage": (1580, 440, 1978, 680),
        "left_lamp": (105, 145, 195, 270),
        "top_lamp": (735, 55, 940, 195),
        "rear_blue_lamps": (365, 160, 1010, 260),
        "right_lamp": (1840, 135, 1978, 270),
    }
    for name, bounds in regions.items():
        image.crop(bounds).save(OUTPUT / f"analysis_{name}.png")


def pixel_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mask_for(size: tuple[int, int], polygons: list[list[tuple[int, int]]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    return mask


def extent_of(mask: Image.Image, padding: int = 2) -> tuple[int, int, int, int]:
    box = mask.getbbox()
    assert box is not None
    return (
        max(box[0] - padding, 0),
        max(box[1] - padding, 0),
        min(box[2] + padding, mask.width),
        min(box[3] + padding, mask.height),
    )


def neutralize_lighting(image: Image.Image) -> Image.Image:
    """Remove broad source glow while retaining local material shading.

    The source has lighting painted into it, so this is an estimated diffuse
    recovery, not a mathematical inverse. The original is kept for comparison.
    """
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    y, x = np.mgrid[:image.height, :image.width].astype(np.float32)
    factor = np.ones_like(rgb)
    lights = [
        (151, 205, 160, 190, (0.26, 0.16, 0.06)),
        (844, 97, 280, 215, (0.20, 0.13, 0.05)),
        (480, 199, 220, 130, (0.05, 0.13, 0.24)),
        (894, 200, 210, 130, (0.05, 0.13, 0.23)),
        (1840, 200, 220, 130, (0.05, 0.13, 0.24)),
        (844, 640, 440, 76, (0.12, 0.08, 0.03)),
        (151, 580, 170, 100, (0.09, 0.06, 0.025)),
    ]
    for cx, cy, rx, ry, amount in lights:
        falloff = np.exp(-0.5 * (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2))
        factor += falloff[:, :, None] * np.array(amount, dtype=np.float32)
    albedo = np.clip(rgb / factor, 0, 255).astype(np.uint8)
    return Image.fromarray(albedo, "RGB").convert("RGBA")


def background_fill(albedo: Image.Image, masks: dict[str, Image.Image]) -> Image.Image:
    """Replace pixels concealed by detachable props and fixtures.

    Fill is drawn from adjacent source architecture; it is exposed only when
    props are moved or when a lamp is switched off.
    """
    base = albedo.copy()
    for name, mask in masks.items():
        bounds = extent_of(mask, 0)
        x0, y0, x1, y1 = bounds
        w, h = x1 - x0, y1 - y0
        if name == "workbench":
            source_x = 600
        elif name == "motor_cart":
            source_x = 960
        elif name in ("service_cabinet", "storage_cases"):
            source_x = 900
        elif name == "wall_lantern":
            source_x = 173
        elif name == "ceiling_strip":
            source_x = 970
        elif name.startswith("blue_strip"):
            source_x = max(0, min(x0 - 100, albedo.width - w))
        else:
            raise ValueError(name)
        source_y = y0
        if name == "wall_lantern":
            source_y = 294
        elif name.startswith("blue_strip"):
            source_y = 167
        source_x = min(source_x, albedo.width - w)
        source_y = min(source_y, albedo.height - h)
        patch = albedo.crop((source_x, source_y, source_x + w, source_y + h))
        base.paste(patch, (x0, y0), mask.crop(bounds))
    return base


def repair_patch(albedo: Image.Image, name: str) -> tuple[Image.Image, tuple[int, int]]:
    spec = REPAIRS[name]
    x0, y0, x1, y1 = spec["target"]
    sx, sy = spec["source"]
    w, h = x1 - x0, y1 - y0
    patch = albedo.crop((sx, sy, sx + w, sy + h)).convert("RGBA")
    if name == "motor_cart":
        # The cart occludes the right structural pillar. Continue the same
        # pillar downward using a visible, source-derived upper segment rather
        # than replacing it with blue wall from the generic patch.
        pillar_x0, pillar_x1 = 1415, 1602
        pillar_y0, pillar_y1 = 478, 641
        stem = albedo.crop((pillar_x0, 300, pillar_x1, 300 + pillar_y1 - pillar_y0))
        patch.paste(stem, (pillar_x0 - x0, pillar_y0 - y0))
    elif name == "service_cabinet":
        pillar_x0, pillar_x1 = 1598, 1635
        pillar_y0, pillar_y1 = 515, 641
        stem = albedo.crop((pillar_x0, 320, pillar_x1, 320 + pillar_y1 - pillar_y0))
        patch.paste(stem, (pillar_x0 - x0, pillar_y0 - y0))
    # Feather only the outside 8px boundary where the target was unobstructed;
    # retain full source detail inside and avoid a hard pasted rectangle edge.
    yy, xx = np.mgrid[:h, :w]
    edge = np.minimum.reduce((xx, w - 1 - xx, yy, h - 1 - yy))
    opacity = np.clip(edge / 8.0, 0.0, 1.0)
    patch.putalpha(Image.fromarray(np.rint(opacity * 255).astype(np.uint8), "L"))
    return patch, (x0, y0)


def cyclic_patch(
    image: Image.Image,
    box: tuple[int, int, int, int],
    seam: int = 12,
    wrap_x: bool = True,
    wrap_y: bool = True,
) -> Image.Image:
    """Blend thin boundaries on the axes in which a source crop must wrap."""
    crop = np.asarray(image.crop(box).convert("RGB"), dtype=np.float32).copy()
    h, w, _ = crop.shape
    # Left and right edge converge to the same measured source-color strip.
    if wrap_x:
        original = crop.copy()
        for i in range(seam):
            t = (seam - i) / seam
            avg = (original[:, i] + original[:, w - 1 - i]) * 0.5
            crop[:, i] = original[:, i] * (1 - t) + avg * t
            crop[:, w - 1 - i] = original[:, w - 1 - i] * (1 - t) + avg * t
    if wrap_y:
        original = crop.copy()
        for i in range(seam):
            t = (seam - i) / seam
            avg = (original[i] + original[h - 1 - i]) * 0.5
            crop[i] = original[i] * (1 - t) + avg * t
            crop[h - 1 - i] = original[h - 1 - i] * (1 - t) + avg * t
    tile = np.clip(crop, 0, 255).astype(np.uint8)
    if wrap_y:
        tile[-1, :, :] = tile[0, :, :]
    if wrap_x:
        tile[:, -1, :] = tile[:, 0, :]
    return Image.fromarray(tile, "RGB").convert("RGBA")


def split_architecture(base: Image.Image, wall_repeat: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image]:
    """Split the original architectural masses into the two intended depths."""
    front_polygons = [
        [(0, 0), (1977, 0), (1977, 170), (1646, 170),
         (1646, 158), (1302, 158), (1302, 168),
         (277, 168), (277, 159), (0, 159)],
        [(89, 0), (219, 0), (219, 157), (264, 157),
         (277, 211), (249, 255), (214, 255), (214, 645),
         (93, 645), (93, 255), (0, 255), (0, 76), (89, 76)],
        [(1393, 0), (1636, 0), (1636, 641), (1414, 641),
         (1414, 264), (1347, 180), (1355, 156), (1393, 156)],
        [(0, 641), (1977, 641), (1977, 794), (0, 794)],
    ]
    front_mask = mask_for(base.size, front_polygons)
    front = Image.new("RGBA", base.size, (0, 0, 0, 0))
    front.paste(base, (0, 0), front_mask)
    repeated = Image.new("RGBA", base.size)
    for y in range(0, base.height, wall_repeat.height):
        for x in range(0, base.width, wall_repeat.width):
            repeated.paste(wall_repeat, (x, y))
    rear = Image.composite(repeated, base, front_mask)
    rear.putalpha(255)
    check = rear.copy()
    check.alpha_composite(front)
    if np.any(np.asarray(check.convert("RGB")) != np.asarray(base.convert("RGB"))):
        raise AssertionError("Architectural two-layer split changed source diffuse pixels")
    return rear, front, front_mask


def atlas_of(image: Image.Image) -> Image.Image:
    atlas = Image.new("RGBA", (2048, 896), (0, 0, 0, 0))
    atlas.paste(image, (0, 0))
    return atlas


def build_pack() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    (RUNTIME / "props").mkdir(exist_ok=True)
    (RUNTIME / "fixtures").mkdir(exist_ok=True)
    (RUNTIME / "repair").mkdir(exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    assert source.size == (1978, 795), source.size
    source_hash = pixel_hash(SOURCE)
    if source_hash != "cab3221c78b9b5169d93663bcaa9ae0dde19dfb626d47cd2235cdedc5f25927e":
        raise ValueError("The selected source image changed; do not silently rebuild from a different original")
    albedo = neutralize_lighting(source)
    masks: dict[str, Image.Image] = {}
    placed: list[dict] = []
    for name, polygons in PROPS.items():
        masks[name] = mask_for(source.size, polygons)
    for name, spec in FIXTURES.items():
        masks[name] = mask_for(source.size, spec["polygons"])
    for name, mask in masks.items():
        box = extent_of(mask)
        crop = (source if name in FIXTURES else albedo).crop(box)
        cutout = Image.new("RGBA", crop.size, (0, 0, 0, 0))
        cutout.paste(crop, (0, 0), mask.crop(box))
        folder = "fixtures" if name in FIXTURES else "props"
        path = RUNTIME / folder / f"{name}.png"
        cutout.save(path)
        row = {
            "id": name, "type": "light_fixture" if name in FIXTURES else "prop",
            "file": path.relative_to(WORKSPACE).as_posix(),
            "source_rect": list(box), "position": [box[0], box[1]],
            "sha256": pixel_hash(path),
        }
        if name in FIXTURES:
            row.update({k: FIXTURES[name][k] for k in ("kind", "emitter", "radius")})
        else:
            repair, repair_position = repair_patch(albedo, name)
            repair_path = RUNTIME / "repair" / f"{name}_repair.png"
            repair.save(repair_path)
            row["repair_file"] = repair_path.relative_to(WORKSPACE).as_posix()
            row["repair_position"] = list(repair_position)
            row["repair_sha256"] = pixel_hash(repair_path)
        placed.append(row)
    base = background_fill(albedo, masks)
    base_path = RUNTIME / "architecture_diffuse.png"
    base.save(base_path)
    atlas = atlas_of(base)
    atlas_path = RUNTIME / "architecture_atlas_128.png"
    atlas.save(atlas_path)
    repeats = {
        "wall_repeat_256.png": ((1010, 250, 1266, 506), True, True),
        "ceiling_repeat_256x128.png": ((924, 0, 1180, 128), True, True),
        "floor_repeat_256x128.png": ((768, 658, 1024, 786), True, True),
        "pillar_repeat_128.png": ((96, 310, 224, 438), False, True),
    }
    repeat_meta = []
    repeat_images = {}
    for name, (box, wrap_x, wrap_y) in repeats.items():
        tile = cyclic_patch(base, box, wrap_x=wrap_x, wrap_y=wrap_y)
        repeat_images[name] = tile
        path = RUNTIME / name
        tile.save(path)
        tile_rgb = np.asarray(tile.convert("RGB"), dtype=np.int16)
        repeat_meta.append({
            "file": path.relative_to(WORKSPACE).as_posix(),
            "source_rect": list(box), "size": list(tile.size),
            "wrap_x": wrap_x, "wrap_y": wrap_y,
            "wrap_x_max_channel_difference": int(np.abs(tile_rgb[:, 0] - tile_rgb[:, -1]).max()),
            "wrap_y_max_channel_difference": int(np.abs(tile_rgb[0] - tile_rgb[-1]).max()),
            "sha256": pixel_hash(path),
        })
        preview = Image.new("RGBA", (tile.width * 3, tile.height * 3))
        for yp in range(3):
            for xp in range(3):
                preview.paste(tile, (xp * tile.width, yp * tile.height))
        preview.save(OUTPUT / f"repeat_check_{name}")
    rear, front, front_mask = split_architecture(base, repeat_images["wall_repeat_256.png"])
    rear_path = RUNTIME / "rear_diffuse.png"
    front_path = RUNTIME / "front_architecture.png"
    rear.save(rear_path)
    front.save(front_path)
    rear_atlas_path = RUNTIME / "rear_atlas_128.png"
    front_atlas_path = RUNTIME / "front_atlas_128.png"
    atlas_of(rear).save(rear_atlas_path)
    atlas_of(front).save(front_atlas_path)
    front_mask.save(OUTPUT / "front_architecture_mask.png")
    reconstructed = rear.copy()
    reconstructed.alpha_composite(front)
    empty_preview = reconstructed.copy()
    for row in placed:
        if row["type"] == "prop":
            repair = Image.open(WORKSPACE / row["repair_file"]).convert("RGBA")
            empty_preview.alpha_composite(repair, tuple(row["repair_position"]))
    empty_preview.save(OUTPUT / "props_removed_repaired_preview.png")
    for row in placed:
        sprite = Image.open(WORKSPACE / row["file"]).convert("RGBA")
        reconstructed.alpha_composite(sprite, tuple(row["position"]))
    preview_path = OUTPUT / "assembled_diffuse_preview.png"
    reconstructed.save(preview_path)
    side_by_side = Image.new("RGB", (source.width * 2, source.height), (0, 0, 0))
    side_by_side.paste(source.convert("RGB"), (0, 0))
    side_by_side.paste(reconstructed.convert("RGB"), (source.width, 0))
    side_by_side.save(OUTPUT / "source_vs_diffuse.png")
    manifest = {
        "source": SOURCE.relative_to(WORKSPACE).as_posix(),
        "source_sha256": source_hash,
        "size": list(source.size),
        "cell": CELL,
        "atlas": atlas_path.relative_to(WORKSPACE).as_posix(),
        "rear_atlas": rear_atlas_path.relative_to(WORKSPACE).as_posix(),
        "front_atlas": front_atlas_path.relative_to(WORKSPACE).as_posix(),
        "atlas_grid": [16, 7],
        "actual_grid_coverage": [16, 7],
        "godot_tilesets": [
            "GodotPrototype/assets/service_gallery/service_gallery_rear.tres",
            "GodotPrototype/assets/service_gallery/service_gallery_front.tres",
            "GodotPrototype/assets/service_gallery/service_gallery_repeat.tres",
        ],
        "godot_pack_scene": "GodotPrototype/scenes/ServiceGalleryPack.tscn",
        "godot_preview_scene": "GodotPrototype/scenes/ServiceGalleryPreview.tscn",
        "architecture_diffuse_sha256": pixel_hash(base_path),
        "rear_diffuse_sha256": pixel_hash(rear_path),
        "front_architecture_sha256": pixel_hash(front_path),
        "assets": placed,
        "repeat_tiles": repeat_meta,
        "review_preview": preview_path.relative_to(WORKSPACE).as_posix(),
        "props_removed_preview": "Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1/props_removed_repaired_preview.png",
        "note": "Original pixels are preserved in source. Diffuse is estimated from painted lighting, not pixel-identical to lit source. Prop restoration pixels hidden by the source art are estimated from nearby visible regions.",
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    runtime_placement = []
    for row in placed:
        runtime_row = {
            **{k: v for k, v in row.items() if k not in ("file", "sha256", "source_rect")},
            "texture": "res://assets/service_gallery/" + row["file"].split("service_gallery/", 1)[1],
        }
        if "repair_file" in row:
            runtime_row["repair_texture"] = "res://assets/service_gallery/" + row["repair_file"].split("service_gallery/", 1)[1]
            runtime_row.pop("repair_file")
            runtime_row.pop("repair_sha256")
        runtime_placement.append(runtime_row)
    (RUNTIME / "placements.json").write_text(
        json.dumps(runtime_placement, indent=2), encoding="utf-8"
    )
    print(json.dumps({
        "props": len(PROPS), "fixtures": len(FIXTURES), "tile_cells": 112,
        "source_sha256": source_hash,
        "preview": str(preview_path)
    }, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--grid", action="store_true")
    parser.add_argument("--crops", action="store_true")
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    if args.grid:
        print(write_grid())
    if args.crops:
        write_crops()
    if args.build:
        build_pack()
