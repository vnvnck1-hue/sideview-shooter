from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


LEG_NAMES = [
    "front_near_upper",
    "front_near_lower",
    "front_near_foot",
    "rear_near_upper",
    "rear_near_lower",
    "rear_near_foot",
    "front_far_upper",
    "front_far_lower",
    "front_far_foot",
    "rear_far_upper",
    "rear_far_lower",
    "rear_far_foot",
]

JOINT_NAMES = [
    "front_near_hip_cap",
    "rear_near_hip_cap",
    "front_far_hip_cap",
    "rear_far_hip_cap",
    "front_near_knee_cap",
    "rear_near_knee_cap",
    "front_far_knee_cap",
    "rear_far_knee_cap",
]


def edges(length: int, divisions: int) -> list[int]:
    return [round(index * length / divisions) for index in range(divisions + 1)]


def harden_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    rgba.putalpha(rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0))
    return rgba


def tight_crop(image: Image.Image, padding: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError("Generated cell contains no visible pixels")
    left = max(0, bounds[0] - padding)
    top = max(0, bounds[1] - padding)
    right = min(image.width, bounds[2] + padding)
    bottom = min(image.height, bounds[3] + padding)
    return image.crop((left, top, right, bottom)), (left, top, right, bottom)


def save_grid_parts(
    source: Image.Image,
    names: list[str],
    columns: int,
    rows: int,
    output_dir: Path,
    threshold: int,
) -> list[dict[str, object]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    x_edges = edges(source.width, columns)
    y_edges = edges(source.height, rows)
    records: list[dict[str, object]] = []

    for index, name in enumerate(names):
        row, col = divmod(index, columns)
        source_bounds = (
            x_edges[col],
            y_edges[row],
            x_edges[col + 1],
            y_edges[row + 1],
        )
        cell = harden_alpha(source.crop(source_bounds), threshold)
        part, crop_bounds = tight_crop(cell, padding=8)
        path = output_dir / f"{name}.png"
        part.save(path, optimize=True)

        alpha_bounds = part.getchannel("A").getbbox()
        if name.endswith("_cap"):
            pivot = [part.width // 2, part.height // 2]
        else:
            pivot = [
                (alpha_bounds[0] + alpha_bounds[2]) // 2,
                alpha_bounds[1] + max(4, round((alpha_bounds[3] - alpha_bounds[1]) * 0.08)),
            ]
        records.append(
            {
                "name": name,
                "file": path.name,
                "size": [part.width, part.height],
                "suggested_root_pivot_px": pivot,
                "source_cell": [col, row],
                "source_bounds": list(source_bounds),
                "cell_crop_bounds": list(crop_bounds),
            }
        )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("body_source", type=Path)
    parser.add_argument("legs_source", type=Path)
    parser.add_argument("joints_source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    body_raw = Image.open(args.body_source).convert("RGBA")
    legs_raw = Image.open(args.legs_source).convert("RGBA")
    joints_raw = Image.open(args.joints_source).convert("RGBA")

    body_clean = harden_alpha(body_raw, args.alpha_threshold)
    body, body_crop = tight_crop(body_clean, padding=16)
    body_path = args.output / "body_main.png"
    body.save(body_path, optimize=True)
    body_alpha = body.getchannel("A").getbbox()

    legs_atlas = harden_alpha(legs_raw, args.alpha_threshold)
    legs_atlas.save(args.output / "legs_atlas_3x4.png", optimize=True)
    joints_atlas = harden_alpha(joints_raw, args.alpha_threshold)
    joints_atlas.save(args.output / "joint_caps_atlas_4x2.png", optimize=True)

    legs = save_grid_parts(
        legs_raw, LEG_NAMES, 3, 4, args.output / "LegSegments", args.alpha_threshold
    )
    joints = save_grid_parts(
        joints_raw, JOINT_NAMES, 4, 2, args.output / "JointCaps", args.alpha_threshold
    )

    metadata = {
        "view": "strict left-facing side view",
        "alpha": {"mode": "binary", "threshold": args.alpha_threshold},
        "body": {
            "name": "body_main",
            "file": body_path.name,
            "size": [body.width, body.height],
            "suggested_root_pivot_px": [
                (body_alpha[0] + body_alpha[2]) // 2,
                (body_alpha[1] + body_alpha[3]) // 2,
            ],
            "source_crop_bounds": list(body_crop),
        },
        "layer_order_back_to_front": [
            "front_far",
            "rear_far",
            "body_main",
            "rear_near",
            "front_near",
            "joint_caps",
        ],
        "legs": legs,
        "joint_caps": joints,
        "rig_note": "Place each segment pivot on its parent joint center; overlap circular pads beneath the matching cap to hide rotation seams.",
    }
    (args.output / "rig_parts.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
