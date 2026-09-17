"""Workshop_Modular 프레임의 '안쪽으로 꺾이는' 코너(L-벤드) 4종을 기존 프레임 조각에서 합성한다.

배포된 InnerCorners 시트는 벽 띠가 천장 띠를 지나 그대로 이어지는(T자) 모양이라, 낮은 날개 천장이 높은 벽과
만나는 곳에 놓으면 벽이 천장 아래로 한 칸 튀어나와 보인다. 여기서는 벽 띠 × 천장(바닥) 띠가 겹치는 56×48 사각형만
남기고 나머지는 투명으로 둔 '스텁' 조각을 만든다: 위 셀의 벽 띠가 내려와 천장 띠 높이에서 멈추고 옆 셀의 천장 띠로 꺾인다.
띠 몸통은 벽 조각, 방 안쪽을 향한 가로 모서리(천장 아랫선 / 바닥 윗선)는 천장·바닥 조각에서 덮어 코너가 자연스럽게 닫힌다.

출력: assets/tiles/workshop_modular/workshop_modular_frame_bend_sheet_4x1.png  (128×128 ×4)
  0 bend_top_left     왼쪽 벽 ↓ 가 천장 ← 으로 꺾임  (띠: 왼쪽 위 사각형)   — 왼쪽 날개 천장이 고층부 왼벽과 만나는 셀
  1 bend_top_right    오른쪽 벽 ↓ 가 천장 → 으로 꺾임 (띠: 오른쪽 위 사각형)
  2 bend_bottom_left  왼쪽 벽 ↑ 가 바닥 ← 으로 꺾임  (띠: 왼쪽 아래 사각형) — 바닥이 한 단 낮아지는 곳(미사용, 대칭 완성용)
  3 bend_bottom_right 오른쪽 벽 ↑ 가 바닥 → 으로 꺾임
실행: python tools/make_frame_bend_tiles.py
"""
from PIL import Image
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "assets", "tiles", "workshop_modular")
SRC = os.path.join(TILES, "workshop_modular_frame_terrain_3x3.png")
OUT = os.path.join(TILES, "workshop_modular_frame_bend_sheet_4x1.png")
C = 128
SIDE_W = 56          # 벽 띠 폭 (left: x 0..55, right: x 72..127)
TOP_H = 48           # 천장 띠 높이 (y 0..47)
BOT_H = 48           # 바닥 띠 높이 (y 80..127)
EDGE = 8             # 방 안쪽을 향한 가로 모서리에서 천장/바닥 조각을 덮어쓰는 두께

sheet = Image.open(SRC).convert("RGBA")
def piece(cx, cy):
    return sheet.crop((cx * C, cy * C, cx * C + C, cy * C + C))

LEFT, RIGHT, TOP, BOTTOM = piece(0, 1), piece(1, 1), piece(1, 0), piece(0, 2)

OUTER = 6            # 벽 띠의 바깥쪽(방 밖을 향한) 어두운 테두리 폭 — 이 열도 천장/바닥 조각으로 덮어 옆 셀 띠와 이어지게 한다

def bend(wall, hbar, xr, yr, edge_rows, outer_cols):
    """wall 조각의 (xr × yr) 사각형만 남기고, edge_rows(안쪽 가로 모서리)·outer_cols(바깥 테두리) 는 hbar 조각으로 덮는다."""
    t = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    box = (xr[0], yr[0], xr[1] + 1, yr[1] + 1)
    t.paste(wall.crop(box), box[:2])
    ebox = (xr[0], edge_rows[0], xr[1] + 1, edge_rows[1] + 1)
    t.paste(hbar.crop(ebox), ebox[:2])
    obox = (outer_cols[0], yr[0], outer_cols[1] + 1, yr[1] + 1)
    t.paste(hbar.crop(obox), obox[:2])
    return t

L_X, R_X = (0, SIDE_W - 1), (C - SIDE_W, C - 1)
T_Y, B_Y = (0, TOP_H - 1), (C - BOT_H, C - 1)
T_EDGE, B_EDGE = (TOP_H - EDGE, TOP_H - 1), (C - BOT_H, C - BOT_H + EDGE - 1)
L_OUT, R_OUT = (0, OUTER - 1), (C - OUTER, C - 1)
tiles = [
    bend(LEFT,  TOP,    L_X, T_Y, T_EDGE, L_OUT),
    bend(RIGHT, TOP,    R_X, T_Y, T_EDGE, R_OUT),
    bend(LEFT,  BOTTOM, L_X, B_Y, B_EDGE, L_OUT),
    bend(RIGHT, BOTTOM, R_X, B_Y, B_EDGE, R_OUT),
]
out = Image.new("RGBA", (C * 4, C), (0, 0, 0, 0))
for i, t in enumerate(tiles):
    out.paste(t, (i * C, 0))
out.save(OUT)
print("->", os.path.relpath(OUT, HERE))

# 확인용 목업: 왼쪽 날개 천장(row1: top,top) 이 고층부 왼벽(col2: left) 과 만나는 3×3 셀. 배경은 채움 타일 a.
if __name__ == "__main__":
    bg = Image.open(os.path.join(TILES, "workshop_modular_background_sheet_3x2.png")).convert("RGBA").crop((0, 0, C, C))
    def mock(stub, wall, hbar, wall_col, bar_cols, wall_rows, bar_row, stub_cell, name):
        m = Image.new("RGBA", (C * 3, C * 3), (0, 0, 0, 255))
        for (x, y) in [(x, y) for x in range(3) for y in range(3)]:
            # 방 안: 벽 열의 위쪽 + 천장 행 이하 전체. 밖(검정): 천장 행 위, 벽 열 바깥쪽
            outside = (y < bar_row) and (x in bar_cols)
            if not outside:
                m.paste(bg, (x * C, y * C))
        for y in wall_rows:
            m.alpha_composite(wall, (wall_col * C, y * C))
        for x in bar_cols:
            m.alpha_composite(hbar, (x * C, bar_row * C))
        m.alpha_composite(stub, (stub_cell[0] * C, stub_cell[1] * C))
        p = os.path.join(HERE, "..", "..", "Assets", "GameReady", "Validation", name)
        m.resize((C * 6, C * 6), Image.NEAREST).save(p)
        print("mock ->", os.path.relpath(p, HERE))
    mock(tiles[0], LEFT, TOP, 2, [0, 1], [0], 1, (2, 1), "workshop_modular_bend_top_left_preview.png")
    mock(tiles[1], RIGHT, TOP, 0, [1, 2], [0], 1, (0, 1), "workshop_modular_bend_top_right_preview.png")
