from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


COLS = 5
ROWS = 2
FRAME_COUNT = COLS * ROWS


def proportional_edges(length: int, divisions: int) -> list[int]:
    return [round(index * length / divisions) for index in range(divisions + 1)]


def harden_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    return rgba


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--duration-ms", type=int, default=100)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    parser.add_argument(
        "--anchor-mode",
        choices=("body", "ground"),
        default="body",
        help="body removes generator placement jitter; ground preserves intentional body bounce",
    )
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    args.output.mkdir(parents=True, exist_ok=True)
    frames_dir = args.output / "Frames"
    frames_dir.mkdir(parents=True, exist_ok=True)

    x_edges = proportional_edges(source.width, COLS)
    y_edges = proportional_edges(source.height, ROWS)
    frame_width = max(b - a for a, b in zip(x_edges, x_edges[1:]))
    frame_height = max(b - a for a, b in zip(y_edges, y_edges[1:]))

    raw_frames: list[Image.Image] = []
    for row in range(ROWS):
        for col in range(COLS):
            bounds = (x_edges[col], y_edges[row], x_edges[col + 1], y_edges[row + 1])
            cell = harden_alpha(source.crop(bounds), args.alpha_threshold)
            frame = Image.new("RGBA", (frame_width, frame_height), (0, 0, 0, 0))
            frame.paste(cell, (0, 0), cell)
            raw_frames.append(frame)

    # The generator may place each pose a few pixels differently inside its cell.
    # Anchor the stable upper chassis while leaving the feet free to describe the gait.
    body_region_bottom = round(frame_height * 0.58)
    body_boxes = [
        frame.getchannel("A").crop((0, 0, frame_width, body_region_bottom)).getbbox()
        for frame in raw_frames
    ]
    if any(box is None for box in body_boxes):
        raise RuntimeError("Could not find the robot body in every generated frame")
    target_x = body_boxes[0][0]
    target_y = body_boxes[0][1]
    silhouette_boxes = [frame.getchannel("A").getbbox() for frame in raw_frames]
    if any(box is None for box in silhouette_boxes):
        raise RuntimeError("Could not find the robot silhouette in every generated frame")
    ground_line = max(box[3] for box in silhouette_boxes)

    frames: list[Image.Image] = []
    frame_records: list[dict[str, object]] = []
    for index, (raw_frame, body_box, silhouette_box) in enumerate(
        zip(raw_frames, body_boxes, silhouette_boxes)
    ):
        vertical_shift = (
            target_y - body_box[1]
            if args.anchor_mode == "body"
            else ground_line - silhouette_box[3]
        )
        shift = (target_x - body_box[0], vertical_shift)
        frame = Image.new("RGBA", (frame_width, frame_height), (0, 0, 0, 0))
        frame.paste(raw_frame, shift, raw_frame)

        frame_path = frames_dir / f"quadruped_walk_{index + 1:02d}.png"
        frame.save(frame_path, optimize=True)
        frames.append(frame)
        row, col = divmod(index, COLS)
        frame_records.append(
            {
                "frame": index + 1,
                "file": frame_path.name,
                "source_bounds": [
                    x_edges[col],
                    y_edges[row],
                    x_edges[col + 1],
                    y_edges[row + 1],
                ],
                "body_anchor_shift": list(shift),
                "size": [frame_width, frame_height],
            }
        )

    sheet = Image.new(
        "RGBA", (frame_width * COLS, frame_height * ROWS), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        sheet.paste(frame, ((index % COLS) * frame_width, (index // COLS) * frame_height), frame)
    sheet.save(args.output / "quadruped_walk_10f_sheet.png", optimize=True)

    frames[0].save(
        args.output / "quadruped_walk_10f_preview.apng",
        format="PNG",
        save_all=True,
        append_images=frames[1:],
        duration=args.duration_ms,
        loop=0,
        disposal=2,
        blend=0,
    )

    metadata = {
        "source": str(args.source),
        "layout": {"columns": COLS, "rows": ROWS, "frame_count": FRAME_COUNT},
        "frame_size": [frame_width, frame_height],
        "duration_ms": args.duration_ms,
        "loop": True,
        "direction": "left",
        "anchor_mode": args.anchor_mode,
        "alpha": {"mode": "binary", "threshold": args.alpha_threshold},
        "frames": frame_records,
    }
    (args.output / "quadruped_walk_10f.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
