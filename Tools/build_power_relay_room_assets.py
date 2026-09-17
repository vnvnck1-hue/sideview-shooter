"""Build the Power Relay Room art pack from the generated source sheets.

The source sheets are intentionally kept in Assets/Generated/PowerRelayRoom/Source.
This script turns them into the ART_GUIDE §10 deliverables:

* Native8: 1 art pixel = 1 pixel, 16x16 modular cells, binary alpha.
* GameReady: the same assets enlarged 8x with nearest-neighbour sampling.
* GodotPrototype/assets/power_relay_room: a game-facing copy of GameReady.

The generated images are treated as visual source material only. Cropping, alpha
cleanup, palette reduction, and the part manifest are deterministic here so the
room can be rebuilt without hand-editing a large atlas.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets" / "Generated" / "PowerRelayRoom" / "Source"
NATIVE = ROOT / "Assets" / "GameReady" / "Native8" / "PowerRelayRoom"
GAME = ROOT / "Assets" / "GameReady" / "PowerRelayRoom"
GODOT = ROOT / "GodotPrototype" / "assets" / "power_relay_room"


def mkdirs() -> None:
    for root in (NATIVE, GAME, GODOT):
        for folder in ("Tiles/Background", "Tiles/Frame", "Tiles/Frame/InnerCorners", "Props", "Lighting", "Cables", "Destruction", "Validation"):
            (root / folder).mkdir(parents=True, exist_ok=True)


def binary_alpha(img: Image.Image, threshold: int = 128) -> Image.Image:
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    return rgba


def quantize_rgba(img: Image.Image, colors: int) -> Image.Image:
    rgba = binary_alpha(img)
    quantized = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    quantized.putalpha(rgba.getchannel("A"))
    return quantized


def trim(img: Image.Image) -> Image.Image:
    rgba = binary_alpha(img)
    box = rgba.getchannel("A").getbbox()
    if not box:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return rgba.crop(box)


def fit_sprite(img: Image.Image, box: tuple[int, int], colors: int = 16) -> Image.Image:
    source = trim(img)
    target_w, target_h = box
    scale = min(target_w / source.width, target_h / source.height)
    size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    source = source.resize(size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", box, (0, 0, 0, 0))
    out.paste(source, ((target_w - size[0]) // 2, (target_h - size[1]) // 2), source)
    return quantize_rgba(out, colors)


def save_pair(native_img: Image.Image, relative: str) -> None:
    native_path = NATIVE / relative
    game_path = GAME / relative.replace(".png", "_game_scale.png")
    godot_path = GODOT / relative
    for path in (native_path, game_path, godot_path):
        path.parent.mkdir(parents=True, exist_ok=True)
    native_img.save(native_path, optimize=True)
    game = native_img.resize((native_img.width * 8, native_img.height * 8), Image.Resampling.NEAREST)
    game.save(game_path, optimize=True)
    shutil.copy2(game_path, godot_path)


def save_native_only(img: Image.Image, relative: str) -> None:
    path = NATIVE / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def cell_crop(img: Image.Image, columns: int, rows: int, index: int) -> Image.Image:
    cell_w = img.width // columns
    cell_h = img.height // rows
    x = (index % columns) * cell_w
    y = (index // columns) * cell_h
    return img.crop((x, y, x + cell_w, y + cell_h))


def make_tiles() -> None:
    source = Image.open(SOURCE / "power_relay_background_sheet_v1.png").convert("RGBA")
    names = [
        "power_relay_bg_plain",
        "power_relay_bg_blocks",
        "power_relay_bg_channel",
        "power_relay_bg_vent",
        "power_relay_bg_repaired",
        "power_relay_bg_cracked",
    ]
    for index, name in enumerate(names):
        tile = cell_crop(source, 3, 2, index).convert("RGB").resize((16, 16), Image.Resampling.NEAREST).convert("RGBA")
        tile.putalpha(Image.new("L", tile.size, 255))
        save_pair(quantize_rgba(tile, 12), f"Tiles/Background/{name}.png")

    # The room architecture uses the existing modular frame grammar, but the
    # native version is included with this theme so it is self-contained.
    frame_names = [
        "workshop_frame_top_left.png", "workshop_frame_top.png", "workshop_frame_top_right.png",
        "workshop_frame_left.png", "workshop_frame_right.png", "workshop_frame_bottom_left.png",
        "workshop_frame_bottom.png", "workshop_frame_bottom_right.png",
    ]
    for name in frame_names:
        source_path = ROOT / "Assets" / "GameReady" / "Tiles" / "Workshop_Modular" / "Frame" / name
        frame = Image.open(source_path).convert("RGBA").resize((16, 16), Image.Resampling.NEAREST)
        save_pair(quantize_rgba(frame, 12), f"Tiles/Frame/{name.replace('workshop_frame_', 'power_relay_frame_')}")
    inner_names = [
        "workshop_frame_inner_top_left.png", "workshop_frame_inner_top_right.png",
        "workshop_frame_inner_bottom_left.png", "workshop_frame_inner_bottom_right.png",
    ]
    for name in inner_names:
        source_path = ROOT / "Assets" / "GameReady" / "Tiles" / "Workshop_Modular" / "Frame" / "InnerCorners" / name
        frame = Image.open(source_path).convert("RGBA").resize((16, 16), Image.Resampling.NEAREST)
        save_pair(quantize_rgba(frame, 12), f"Tiles/Frame/InnerCorners/{name.replace('workshop_frame_', 'power_relay_frame_')}")


def make_props() -> dict:
    source = Image.open(SOURCE / "power_relay_props_sheet_v1.png").convert("RGBA")
    definitions = [
        ("power_relay_cabinet_assembled.png", 0, (46, 40), 16),
        ("power_relay_capacitor_bank.png", 1, (48, 32), 16),
        ("power_relay_breaker_box.png", 2, (24, 24), 12),
        ("power_relay_maintenance_cart.png", 3, (40, 24), 16),
        ("power_relay_work_lamp_fixture.png", 4, (20, 20), 12),
        ("power_relay_conduit_junction.png", 5, (28, 24), 12),
    ]
    out = {}
    for name, index, size, colors in definitions:
        rel = f"Props/{name}"
        save_pair(fit_sprite(cell_crop(source, 3, 2, index), size, colors), rel)
        out[name] = {"path": f"Props/{name}", "sizeArtPx": list(size), "pivot": "bottom_center", "layer": "floor_prop"}
    return out


def make_sheet_sprites(source_name: str, folder: str, names: list[str], sizes: list[tuple[int, int]], colors: int) -> list[dict]:
    source = Image.open(SOURCE / source_name).convert("RGBA")
    result = []
    for index, (name, size) in enumerate(zip(names, sizes)):
        relative = f"{folder}/{name}.png"
        save_pair(fit_sprite(cell_crop(source, 3, 2, index), size, colors), relative)
        result.append({"path": relative, "sizeArtPx": list(size), "pivot": "center", "sourceCell": index})
    return result


def make_cabinet_parts() -> list[dict]:
    source = Image.open(SOURCE / "power_relay_cabinet_parts_sheet_v1.png").convert("RGBA")
    # Boxes are intentionally generous. trim() removes the transparent margin
    # while preserving each part's hard pixel silhouette.
    boxes = {
        "power_relay_cabinet_assembled.png": (20, 60, 770, 750),
        "power_relay_cabinet_left_door.png": (780, 170, 1030, 610),
        "power_relay_cabinet_inner_core.png": (1030, 170, 1280, 610),
        "power_relay_cabinet_right_door.png": (1260, 170, 1555, 610),
        "power_relay_cabinet_top_cap.png": (850, 30, 1405, 175),
        "power_relay_cabinet_lower_base.png": (930, 575, 1435, 735),
        "power_relay_cabinet_hinge_a.png": (790, 680, 950, 820),
        "power_relay_cabinet_hinge_b.png": (790, 800, 950, 955),
        "power_relay_cabinet_cable_chunk_a.png": (960, 680, 1160, 830),
        "power_relay_cabinet_cable_chunk_b.png": (1160, 680, 1370, 830),
        "power_relay_cabinet_debris_a.png": (950, 805, 1085, 960),
        "power_relay_cabinet_debris_b.png": (1060, 805, 1210, 960),
        "power_relay_cabinet_debris_c.png": (1190, 805, 1370, 960),
        "power_relay_cabinet_debris_d.png": (1360, 805, 1555, 960),
    }
    targets = {
        "power_relay_cabinet_assembled.png": (46, 40),
        "power_relay_cabinet_left_door.png": (18, 28),
        "power_relay_cabinet_inner_core.png": (18, 28),
        "power_relay_cabinet_right_door.png": (18, 28),
        "power_relay_cabinet_top_cap.png": (32, 10),
        "power_relay_cabinet_lower_base.png": (32, 10),
        "power_relay_cabinet_hinge_a.png": (8, 8),
        "power_relay_cabinet_hinge_b.png": (8, 8),
        "power_relay_cabinet_cable_chunk_a.png": (12, 8),
        "power_relay_cabinet_cable_chunk_b.png": (12, 8),
        "power_relay_cabinet_debris_a.png": (8, 8),
        "power_relay_cabinet_debris_b.png": (8, 8),
        "power_relay_cabinet_debris_c.png": (8, 8),
        "power_relay_cabinet_debris_d.png": (8, 8),
    }
    result = []
    for name, box in boxes.items():
        rel = f"Destruction/{name}"
        save_pair(fit_sprite(source.crop(box), targets[name], 16), rel)
        result.append({"path": rel, "sizeArtPx": list(targets[name]), "pivot": "center", "partRole": "assembled" if "assembled" in name else "detachable"})
    return result


def make_validation(props: dict, cables: list[dict], lights: list[dict]) -> None:
    tile_dir = GAME / "Tiles" / "Background"
    frame_dir = GAME / "Tiles" / "Frame"
    bg_names = ["power_relay_bg_plain", "power_relay_bg_blocks", "power_relay_bg_channel", "power_relay_bg_vent", "power_relay_bg_repaired", "power_relay_bg_cracked"]
    frame_names = {p.stem: p for p in frame_dir.glob("*.png") if "inner" not in p.stem}
    cell = 128
    cols, rows = 14, 8
    preview = Image.new("RGBA", (cols * cell, rows * cell), (7, 9, 20, 255))
    for y in range(rows):
        for x in range(cols):
            tile_name = bg_names[(x + y * 2) % len(bg_names)] + "_game_scale.png"
            tile = Image.open(tile_dir / tile_name).convert("RGBA")
            preview.alpha_composite(tile, (x * cell, y * cell))
    # Perimeter frame, using the existing modular grammar copied into this theme.
    def put(name: str, x: int, y: int) -> None:
        path = frame_dir / (name + "_game_scale.png")
        if path.exists():
            preview.alpha_composite(Image.open(path).convert("RGBA"), (x * cell, y * cell))
    put("power_relay_frame_top_left", 0, 0)
    put("power_relay_frame_top_right", cols - 1, 0)
    put("power_relay_frame_bottom_left", 0, rows - 1)
    put("power_relay_frame_bottom_right", cols - 1, rows - 1)
    for x in range(1, cols - 1):
        put("power_relay_frame_top", x, 0)
        put("power_relay_frame_bottom", x, rows - 1)
    for y in range(1, rows - 1):
        put("power_relay_frame_left", 0, y)
        put("power_relay_frame_right", cols - 1, y)

    def paste_bottom_center(path: Path, x: int, floor_y: int) -> None:
        sprite = Image.open(path).convert("RGBA")
        preview.alpha_composite(sprite, (x - sprite.width // 2, floor_y - sprite.height))

    floor_y = 7 * cell + 96
    paste_bottom_center(GAME / "Props" / "power_relay_cabinet_assembled_game_scale.png", 3 * cell, floor_y)
    paste_bottom_center(GAME / "Props" / "power_relay_capacitor_bank_game_scale.png", 7 * cell, floor_y)
    paste_bottom_center(GAME / "Props" / "power_relay_maintenance_cart_game_scale.png", 10 * cell, floor_y)
    preview.save(GAME / "Validation" / "power_relay_room_modular_preview.png", optimize=True)
    preview.save(GODOT / "Validation" / "power_relay_room_modular_preview.png", optimize=True)


def main() -> None:
    mkdirs()
    make_tiles()
    props = make_props()
    cables = make_sheet_sprites(
        "power_relay_cables_sheet_v1.png", "Cables",
        ["power_relay_cable_straight", "power_relay_cable_hanging", "power_relay_cable_shallow_sag", "power_relay_cable_vertical_drop", "power_relay_cable_elbow", "power_relay_cable_loose_end"],
        [(32, 8), (24, 16), (24, 12), (8, 24), (24, 24), (16, 24)], 12,
    )
    lights = make_sheet_sprites(
        "power_relay_lighting_sheet_v1.png", "Lighting",
        ["power_relay_ceiling_lamp", "power_relay_wall_lamp", "power_relay_indicator_beacon", "power_relay_fluorescent_lamp", "power_relay_dangling_lamp", "power_relay_floor_work_light"],
        [(24, 16), (16, 16), (16, 16), (32, 8), (16, 24), (24, 16)], 12,
    )
    parts = make_cabinet_parts()
    make_validation(props, cables, lights)

    manifest = {
        "formatVersion": 1,
        "theme": "PowerRelay",
        "concept": "지하 전력 릴레이·축전실",
        "artGuide": "Docs/ART_GUIDE.md §10 방식 B",
        "native": {"root": "Assets/GameReady/Native8/PowerRelayRoom", "artPixelToWorldPx": 8, "gameScale": 8, "cellArtPx": [16, 16], "cellWorldPx": [128, 128], "alpha": "binary 0/255", "filter": "nearest/point"},
        "backgroundTiles": {"folder": "Tiles/Background", "repeatAxes": ["x", "y"], "files": ["power_relay_bg_plain.png", "power_relay_bg_blocks.png", "power_relay_bg_channel.png", "power_relay_bg_vent.png", "power_relay_bg_repaired.png", "power_relay_bg_cracked.png"]},
        "frameTiles": {"folder": "Tiles/Frame", "architecture": "Workshop_Modular perimeter grammar, restyled through native 8px export", "files": sorted(str(p.relative_to(NATIVE)).replace("\\", "/") for p in (NATIVE / "Tiles" / "Frame").rglob("*.png"))},
        "props": props,
        "lightingProps": lights,
        "physicsCables": [{**cable, "physics": {"attachmentMode": "two_point", "runtimeScript": "GodotPrototype/scripts/power_relay_cable.gd", "simulation": "Verlet chain with fixed ceiling anchor and free tip", "detachOnImpact": False, "impactResponse": "elastic shot/body impulse"}} for cable in cables],
        "destructionParts": {"intact": "Destruction/power_relay_cabinet_assembled.png", "parts": parts, "assembly": ["lower_base", "inner_core", "left_door", "right_door", "top_cap", "hinges", "cable_chunks"], "impactOrder": ["door_panels", "top_cap", "inner_core", "lower_base", "debris"]},
        "validation": "Assets/GameReady/PowerRelayRoom/Validation/power_relay_room_modular_preview.png",
        "layerOrder": ["Background Tiles", "Back-wall Doors", "Floor Props", "Lighting Props", "Physics Cables", "Character", "Front Effects"],
    }
    for path in (GAME / "power_relay_room_manifest_v1.json", GODOT / "power_relay_room_manifest_v1.json"):
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Power Relay Room assets built")
    print(f"Native: {NATIVE}")
    print(f"GameReady: {GAME}")
    print(f"Godot: {GODOT}")


if __name__ == "__main__":
    main()
