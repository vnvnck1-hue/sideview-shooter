"""원본 외곽 프레임과 L-벤드 4종을 한 장의 검증 목업으로 조합한다."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / "assets" / "tiles" / "workshop_modular"
OUT = ROOT.parent / "Assets" / "GameReady" / "Validation" / "workshop_modular_corner_composition_exact_v1.png"
CELL = 128
SCALE = 2
GRID_W, GRID_H = 12, 9


def load_tile(path: Path, x: int = 0, y: int = 0) -> Image.Image:
    sheet = Image.open(path).convert("RGBA")
    return sheet.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL))


def main() -> None:
    bg = load_tile(TILES / "workshop_modular_background_sheet_3x2.png")
    frame_sheet = TILES / "workshop_modular_frame_terrain_3x3.png"
    bend_sheet = TILES / "workshop_modular_frame_bend_sheet_4x1.png"

    # 12×9 방에서 위·아래 중앙을 파내 네 종류의 L-벤드를 모두 드러낸다.
    cells = {(x, y) for y in range(GRID_H) for x in range(GRID_W)}
    for x in range(4, 8):
        cells.remove((x, 0))
        cells.remove((x, GRID_H - 1))

    out = Image.new("RGBA", (GRID_W * CELL, GRID_H * CELL), (7, 9, 20, 255))
    for x, y in sorted(cells, key=lambda p: (p[1], p[0])):
        out.alpha_composite(bg, (x * CELL, y * CELL))

    # 프레임 시트 좌표: TL, T, TR / L, R, BL / B, BR, 내부.
    frame_coords = {
        "top_left": (0, 0), "top": (1, 0), "top_right": (2, 0),
        "left": (0, 1), "right": (1, 1),
        "bottom_left": (2, 1), "bottom": (0, 2), "bottom_right": (1, 2),
        "inner": (2, 2),
    }
    frame = {name: load_tile(frame_sheet, *coord) for name, coord in frame_coords.items()}
    bends = {
        "bend_top_left": load_tile(bend_sheet, 0, 0),
        "bend_top_right": load_tile(bend_sheet, 1, 0),
        "bend_bottom_left": load_tile(bend_sheet, 2, 0),
        "bend_bottom_right": load_tile(bend_sheet, 3, 0),
    }

    # 실제 L-벤드가 들어가는 네 셀. 위·아래 중앙의 파인 홈 양 끝이다.
    special = {
        (4, 1): "bend_top_left", (7, 1): "bend_top_right",
        (4, 7): "bend_bottom_left", (7, 7): "bend_bottom_right",
    }

    def inside(x: int, y: int) -> bool:
        return (x, y) in cells

    for x, y in sorted(cells, key=lambda p: (p[1], p[0])):
        if (x, y) in special:
            out.alpha_composite(bends[special[(x, y)]], (x * CELL, y * CELL))
            continue
        top = not inside(x, y - 1)
        bottom = not inside(x, y + 1)
        left = not inside(x - 1, y)
        right = not inside(x + 1, y)
        if top and left:
            piece = frame["top_left"]
        elif top and right:
            piece = frame["top_right"]
        elif bottom and left:
            piece = frame["bottom_left"]
        elif bottom and right:
            piece = frame["bottom_right"]
        elif top:
            piece = frame["top"]
        elif bottom:
            piece = frame["bottom"]
        elif left:
            piece = frame["left"]
        elif right:
            piece = frame["right"]
        else:
            continue
        out.alpha_composite(piece, (x * CELL, y * CELL))

    out = out.resize((out.width * SCALE, out.height * SCALE), Image.Resampling.NEAREST)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
