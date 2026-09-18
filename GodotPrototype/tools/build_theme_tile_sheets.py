"""방 테마별 모듈러 타일 시트·펜던트 램프·테마 프랍을 게임 자산 폴더(GodotPrototype/assets)에 준비한다.

RoomTiles 는 실행 중에 테마별 TileSet 을 만든다. 그때 필요한 시트는 다음 세 장이다 (모두 128px 셀).
  <theme>_modular_background_sheet_3x2.png   배경 채움 a~f (3×2)
  <theme>_modular_frame_terrain_3x3.png      외곽 프레임 8조각 + 투명 내부 1칸 (3×3)
  <theme>_modular_frame_bend_sheet_4x1.png   오목 코너용 L-벤드 4종 (4×1)
Workshop 은 배포된 시트를 그대로 쓰고, Corridor·Hydroponics·CrewQuarters·PowerRelay 는 낱장 Frame/·Background/ PNG 에서 여기서 합성한다.

L-벤드: 배포된 InnerCorners 는 벽 띠가 천장 띠를 지나 그대로 이어지는(T자) 모양이라 낮은 천장이 높은 벽과 만나는 곳에 놓으면
벽이 한 칸 튀어나와 보인다. 여기서는 벽 띠 × 천장(바닥) 띠가 겹치는 56×48 사각형만 남긴 '스텁' 조각을 만든다:
위 셀의 벽 띠가 내려와 천장 띠 높이에서 멈추고 옆 셀의 천장 띠로 꺾인다. 다섯 테마 모두 띠 규격이 같다
(벽 띠 56px, 천장·바닥 띠 48px — 알파 경계로 확인).
  0 bend_top_left     왼쪽 벽 ↓ 가 천장 ← 으로 꺾임 (띠: 왼쪽 위 사각형)
  1 bend_top_right    오른쪽 벽 ↓ 가 천장 → 으로 꺾임
  2 bend_bottom_left  왼쪽 벽 ↑ 가 바닥 ← 으로 꺾임 (바닥 단차용, 현재 미사용)
  3 bend_bottom_right 오른쪽 벽 ↑ 가 바닥 → 으로 꺾임

펜던트 램프: 옛 스트립 타일 workshop_wall_b 의 천장 램프를 색상(보라 갓·따뜻한 전구·검은 외곽선)으로 잘라
투명 PNG `assets/lights/pendant_lamp.png` 로 만든다. 모든 테마의 깨지는 램프(LampLight) 스프라이트로 쓴다.
전구 픽셀 영역은 `assets/lights/pendant_lamp.json` 에 적는다.

테마 프랍: Assets/GameReady/Props/{Hydroponics,CrewQuarters} 의 투명 PNG 를 assets/props/ 로 복사한다.
복사 뒤 저장소 루트에서 `python Tools/bake_pixel_grid.py` → `python Tools/build_normal_maps.py props` 를 돌린다.

실행: python tools/build_theme_tile_sheets.py   (GodotPrototype 폴더에서. 멱등)
"""
from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJ = HERE.parent
ASSETS = PROJ / "assets"
GAMEREADY = PROJ.parent / "Assets" / "GameReady"
C = 128

# 테마: (타일 폴더, 파일 접두어, 배경 채움 이름 목록)
THEMES = {
    "workshop": (ASSETS / "tiles" / "workshop_modular", "workshop", None),
    "corridor": (ASSETS / "tiles" / "corridor_modular", "corridor", None),
    "hydroponics": (ASSETS / "tiles" / "hydroponics_modular", "hydroponics", None),
    "crewquarters": (ASSETS / "tiles" / "crewquarters_modular", "crewquarters", None),
    # 전력 릴레이실은 배경 채움이 낱장 6종(plain·blocks·channel·vent·repaired·cracked) 이라 3×2 시트도 여기서 만든다
    "power_relay": (ASSETS / "power_relay_room" / "Tiles", "power_relay",
                    ["plain", "blocks", "channel", "vent", "repaired", "cracked"]),
}
FRAME_LAYOUT = {  # 3×3 터레인 시트 배치 (Workshop 배포본과 같다)
    "top_left": (0, 0), "top": (1, 0), "top_right": (2, 0),
    "left": (0, 1), "right": (1, 1), "bottom_left": (2, 1),
    "bottom": (0, 2), "bottom_right": (1, 2),
}
SIDE_W, TOP_H, BOT_H, EDGE, OUTER = 56, 48, 48, 8, 6


def piece(sheet: Image.Image, cx: int, cy: int) -> Image.Image:
    return sheet.crop((cx * C, cy * C, cx * C + C, cy * C + C))


def bend(wall: Image.Image, hbar: Image.Image, xr, yr, edge_rows, outer_cols) -> Image.Image:
    """wall 조각의 (xr × yr) 사각형만 남기고, 안쪽 가로 모서리(edge_rows)·바깥 테두리(outer_cols)는 hbar 조각으로 덮는다."""
    t = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    box = (xr[0], yr[0], xr[1] + 1, yr[1] + 1)
    t.paste(wall.crop(box), box[:2])
    ebox = (xr[0], edge_rows[0], xr[1] + 1, edge_rows[1] + 1)
    t.paste(hbar.crop(ebox), ebox[:2])
    obox = (outer_cols[0], yr[0], outer_cols[1] + 1, yr[1] + 1)
    t.paste(hbar.crop(obox), obox[:2])
    return t


def check_bands(frame_dir: Path, prefix: str) -> None:
    """벽 띠 56 / 천장·바닥 띠 48 규격 확인 (알파 경계)."""
    def bbox(name):
        a = np.asarray(Image.open(frame_dir / f"{prefix}_frame_{name}.png").convert("RGBA"))[..., 3] > 0
        rows, cols = np.where(a.any(1))[0], np.where(a.any(0))[0]
        return rows.min(), rows.max(), cols.min(), cols.max()
    assert bbox("top")[1] == TOP_H - 1, f"{prefix}: top band"
    assert bbox("bottom")[0] == C - BOT_H, f"{prefix}: bottom band"
    assert bbox("left")[3] == SIDE_W - 1, f"{prefix}: left band"
    assert bbox("right")[2] == C - SIDE_W, f"{prefix}: right band"


def build_theme(theme: str, tiles_dir: Path, prefix: str, bg_names) -> None:
    frame_dir = tiles_dir / "Frame"
    check_bands(frame_dir, prefix)
    # 3×3 프레임 시트
    sheet = Image.new("RGBA", (3 * C, 3 * C), (0, 0, 0, 0))
    for name, (cx, cy) in FRAME_LAYOUT.items():
        sheet.paste(Image.open(frame_dir / f"{prefix}_frame_{name}.png").convert("RGBA"), (cx * C, cy * C))
    sheet.save(tiles_dir / f"{prefix}_modular_frame_terrain_3x3.png")
    # L-벤드 4종
    left, right, top, bottom = piece(sheet, 0, 1), piece(sheet, 1, 1), piece(sheet, 1, 0), piece(sheet, 0, 2)
    lx, rx = (0, SIDE_W - 1), (C - SIDE_W, C - 1)
    ty, by = (0, TOP_H - 1), (C - BOT_H, C - 1)
    t_edge, b_edge = (TOP_H - EDGE, TOP_H - 1), (C - BOT_H, C - BOT_H + EDGE - 1)
    l_out, r_out = (0, OUTER - 1), (C - OUTER, C - 1)
    bends = [
        bend(left, top, lx, ty, t_edge, l_out),
        bend(right, top, rx, ty, t_edge, r_out),
        bend(left, bottom, lx, by, b_edge, l_out),
        bend(right, bottom, rx, by, b_edge, r_out),
    ]
    out = Image.new("RGBA", (4 * C, C), (0, 0, 0, 0))
    for i, t in enumerate(bends):
        out.paste(t, (i * C, 0))
    out.save(tiles_dir / f"{prefix}_modular_frame_bend_sheet_4x1.png")
    # 배경 3×2 시트 (낱장만 있는 테마)
    if bg_names:
        bg = Image.new("RGBA", (3 * C, 2 * C), (0, 0, 0, 0))
        for i, n in enumerate(bg_names):
            bg.paste(Image.open(tiles_dir / "Background" / f"{prefix}_bg_{n}.png").convert("RGBA"), ((i % 3) * C, (i // 3) * C))
        bg.save(tiles_dir / f"{prefix}_modular_background_sheet_3x2.png")
    print(f"[{theme}] frame 3x3 + bend 4x1{' + bg 3x2' if bg_names else ''} -> {tiles_dir.relative_to(PROJ)}")


def build_pendant_lamp() -> None:
    """workshop_wall_b 의 천장 램프(타일 로컬 140,60 ~ 252,170)를 색으로 잘라 투명 PNG 로."""
    tile = Image.open(ASSETS / "tiles" / "workshop_wall_b.png").convert("RGBA")
    x0, y0, x1, y1 = 132, 56, 260, 176
    reg = tile.crop((x0, y0, x1, y1))
    rgb = np.asarray(reg).astype(int)
    hsv = np.asarray(reg.convert("HSV")).astype(int)
    h, s, v = hsv[..., 0] * 360 // 255, hsv[..., 1], hsv[..., 2]
    purple = (h >= 250) & (h <= 335) & (s > 40)                 # 갓·기둥
    bulb = (h >= 10) & (h <= 70) & (v > 110)                     # 따뜻한 전구
    white = (v > 200) & (s < 60)
    dark = v < 45                                                # 외곽선
    mask = purple | bulb | white | dark
    H, W = mask.shape
    seen = np.zeros_like(mask)
    q = deque()
    for y in range(H):                                           # 씨앗: 중앙 기둥·갓
        for x in range(W):
            if mask[y, x] and 52 <= x <= 76 and 20 <= y <= 100:
                seen[y, x] = 1
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = 1
                q.append((ny, nx))
    # 천장 띠에 붙은 가로 파이프 조각(램프 윗부분 옆으로 뻗는 것)은 기둥 폭 밖 y<24 를 지운다
    seen[:24, :44] = 0
    seen[:24, 84:] = 0
    rows, cols = np.where(seen.any(1))[0], np.where(seen.any(0))[0]
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = rgb[..., :3]
    out[..., 3] = np.where(seen, 255, 0)
    img = Image.fromarray(out).crop((cols.min(), rows.min(), cols.max() + 1, rows.max() + 1))
    a = np.asarray(img)
    bh = np.asarray(img.convert("HSV")).astype(int)
    bmask = (a[..., 3] > 0) & (((bh[..., 0] * 360 // 255 >= 10) & (bh[..., 0] * 360 // 255 <= 70) & (bh[..., 2] > 110)) | ((bh[..., 2] > 200) & (bh[..., 1] < 60)))
    br, bc = np.where(bmask.any(1))[0], np.where(bmask.any(0))[0]
    bulb_rect = [int(bc.min()), int(br.min()), int(bc.max() - bc.min() + 1), int(br.max() - br.min() + 1)]
    lights = ASSETS / "lights"
    lights.mkdir(exist_ok=True)
    img.save(lights / "pendant_lamp.png")
    meta = {"size": [img.size[0], img.size[1]], "bulb": bulb_rect, "source": "tiles/workshop_wall_b.png",
            "note": "bulb = 전구 픽셀 영역 (x, y, w, h). 스프라이트 원점은 좌상단, 천장 띠 아랫선에 윗변을 맞춘다."}
    (lights / "pendant_lamp.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[lamp] pendant_lamp.png {img.size} bulb {bulb_rect}")


def copy_theme_props() -> None:
    dst = ASSETS / "props"
    n = 0
    for sub in ("Hydroponics", "CrewQuarters"):
        for src in sorted((GAMEREADY / "Props" / sub).glob("*.png")):
            shutil.copyfile(src, dst / src.name)
            n += 1
    print(f"[props] {n} theme props -> assets/props/  (다음: python Tools/bake_pixel_grid.py && python Tools/build_normal_maps.py props)")


if __name__ == "__main__":
    for theme, (tiles_dir, prefix, bg_names) in THEMES.items():
        build_theme(theme, tiles_dir, prefix, bg_names)
    build_pendant_lamp()
    copy_theme_props()
