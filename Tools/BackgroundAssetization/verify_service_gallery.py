"""Check source identity, atlas assembly, seams and real Godot light captures.

This validates technical preservation. Visual approval of reconstructed hidden
wall under a removed prop remains a separate human decision.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


WORKSPACE = Path(__file__).resolve().parents[2]
OUTPUT = WORKSPACE / "Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1"
RUNTIME = WORKSPACE / "GodotPrototype/assets/service_gallery"
SOURCE = WORKSPACE / "Assets/Generated/ParallaxConcepts/two-layer-maintenance-v1/A_service_gallery.png"
ATTACHMENT = Path("C:/Users/Loadcomplete/.codex/attachments/df85da84-f809-4db7-8eba-3eea95cf6a81/image-1.png")
SOURCE_HASH = "cab3221c78b9b5169d93663bcaa9ae0dde19dfb626d47cd2235cdedc5f25927e"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def mae(a: Image.Image, b: Image.Image) -> float:
    aa = np.asarray(a.convert("RGB"), dtype=np.int16)
    bb = np.asarray(b.convert("RGB"), dtype=np.int16)
    assert aa.shape == bb.shape
    return float(np.abs(aa - bb).mean())


def run() -> None:
    manifest = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    assert sha(SOURCE) == SOURCE_HASH == manifest["source_sha256"]
    assert ATTACHMENT.exists() and sha(ATTACHMENT) == SOURCE_HASH
    source = rgba(SOURCE)
    assert source.size == (1978, 795)
    rear = rgba(RUNTIME / "rear_diffuse.png")
    front = rgba(RUNTIME / "front_architecture.png")
    for name, plate in (("rear_atlas_128.png", rear), ("front_atlas_128.png", front)):
        atlas = rgba(RUNTIME / name)
        assert atlas.size == (2048, 896)
        tile_rebuilt = Image.new("RGBA", atlas.size)
        for y in range(7):
            for x in range(16):
                cell = atlas.crop((x * 128, y * 128, (x + 1) * 128, (y + 1) * 128))
                tile_rebuilt.paste(cell, (x * 128, y * 128))
        assert np.array_equal(np.asarray(tile_rebuilt.crop((0, 0, 1978, 795))), np.asarray(plate))
    assembled = rear.copy()
    assembled.alpha_composite(front)
    prop_count = fixture_count = 0
    for asset in manifest["assets"]:
        path = WORKSPACE / asset["file"]
        assert sha(path) == asset["sha256"]
        sprite = rgba(path)
        data = np.asarray(sprite)
        assert np.count_nonzero(data[:, :, 3]) > 0, path
        assert np.count_nonzero(data[data[:, :, 3] == 0, :3]) == 0, path
        assembled.alpha_composite(sprite, tuple(asset["position"]))
        if asset["type"] == "prop":
            prop_count += 1
            repair = WORKSPACE / asset["repair_file"]
            assert sha(repair) == asset["repair_sha256"]
            assert rgba(repair).size[0] > 0
        else:
            fixture_count += 1
    assert prop_count == 4 and fixture_count == 5
    assert np.array_equal(np.asarray(assembled), np.asarray(rgba(OUTPUT / "assembled_diffuse_preview.png")))
    repeat_results = []
    for item in manifest["repeat_tiles"]:
        path = WORKSPACE / item["file"]
        assert sha(path) == item["sha256"]
        tile = np.asarray(rgba(path).convert("RGB"), dtype=np.int16)
        edge_x = int(np.abs(tile[:, 0] - tile[:, -1]).max())
        edge_y = int(np.abs(tile[0] - tile[-1]).max())
        if item["wrap_x"]:
            assert edge_x == 0
        if item["wrap_y"]:
            assert edge_y == 0
        repeat_results.append({
            "file": item["file"], "wrap_x": item["wrap_x"], "wrap_y": item["wrap_y"],
            "edge_x": edge_x, "edge_y": edge_y,
        })
    on = rgba(OUTPUT / "godot_lights_on.png")
    off = rgba(OUTPUT / "godot_lights_off.png")
    assert on.size == off.size == source.size
    comparison = Image.new("RGB", (source.width * 2, source.height))
    comparison.paste(source.convert("RGB"), (0, 0))
    comparison.paste(on.convert("RGB"), (source.width, 0))
    comparison.save(OUTPUT / "source_vs_godot.png")
    source_mae = mae(source, assembled)
    on_mae = mae(source, on)
    off_mae = mae(source, off)
    light_delta = mae(on, off)
    assert light_delta > 2.0, "Live PointLight2D should visibly change rendered pixels"
    assert on_mae < off_mae, "Engine lighting should restore the source's painted-light character"
    report = {
        "attachment_matches_source": True,
        "source_sha256": SOURCE_HASH,
        "source_size": list(source.size),
        "architecture_tile_cell_px": 128,
        "rear_cells": 112,
        "front_cells": 112,
        "props": prop_count,
        "live_fixtures": fixture_count,
        "repeat_tiles": repeat_results,
        "reassembled_diffuse_vs_source_mae_8bit": round(source_mae, 3),
        "godot_lights_on_vs_source_mae_8bit": round(on_mae, 3),
        "godot_lights_off_vs_source_mae_8bit": round(off_mae, 3),
        "godot_on_off_mae_8bit": round(light_delta, 3),
        "render_note": "OpenGL Godot 4.7.2 capture with global CRT overlay disabled; baseline lighting in concept was estimated, not mathematically unbaked.",
        "approval_note": "A passed technical check is not a user art approval or proof of invisible-area reconstruction quality.",
    }
    (OUTPUT / "verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run()
