"""센트리건 전개 스프라이트 시트(sentry_turret_deploy_direct_v1_sheet)를 게임용 자산으로 가공한다.

하는 일
  1. 8 프레임(4×2, 416×468)을 잘라 **접지선·받침 중심**을 프레임마다 맞춘다.
     원본은 프레임마다 받침 중심이 218 → 190 px 로 흘러 그대로 쓰면 전개 중 좌우로 떨린다.
  2. 마지막 프레임(fully_deployed_ready)을 **상단 머리(포신 어셈블리 + 급탄 호스)** 와
     **하단 받침(요동 실린더 + 기둥 + 해치 꽃잎)** 으로 분리한다 — 조준 회전축은 요동 실린더 중심.
     머리는 받침 **뒤**에 그려서 잘린 단면이 실린더·기둥에 가린다.
  3. 총구·탄피 배출구 등 런타임이 쓰는 앵커를 JSON 으로 남긴다.

실행: python Tools/build_sentry_turret_parts.py   (저장소 루트에서)
출력: Assets/Generated/SentryTurret/Parts/ (원본 보관) · GodotPrototype/assets/props/defense/sentry/ (게임)
      노멀맵은 이어서 python Tools/build_normal_maps.py props 로 만든다.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "Assets/Generated/SentryTurret/Animation/sentry_turret_deploy_direct_v1_sheet.png"
OUT_ASSET = ROOT / "Assets/Generated/SentryTurret/Parts"
OUT_GAME = ROOT / "GodotPrototype/assets/props/defense/sentry"

FRAME = (416, 468)
COLS, ROWS, COUNT = 4, 2, 8
ANCHOR = (208, 440)          # 정규화 프레임 안에서 (받침 중심 x, 접지선 y)
BAND = 24                    # 받침 중심을 재는 하단 띠 높이 (px)

# ── 머리/받침 분리 (정규화 프레임 좌표) ────────────────────────────────────────
# 포신 어셈블리는 y < CUT_Y, 급탄 호스의 아래쪽 고리는 요동 실린더 왼쪽(x < HOSE_X)으로 흘러
# HOSE_Y 까지 내려온다. 호스를 자르지 않고 통째로 머리에 붙여야 회전할 때 끊겨 보이지 않는다.
CUT_Y = 196
HOSE_X = 128
HOSE_Y = 264
PIVOT = (178, 214)           # 요동 실린더 중심 = 부앙(조준) 회전축
MUZZLES = [(222, -96), (218, -62)]   # 위·아래 포구 (회전축 기준, 정지 자세)
EJECT = (86, -20)                    # 탄피 배출구 (회전축 기준, 정지 자세)


def load_frames() -> list[Image.Image]:
    sheet = Image.open(SHEET).convert("RGBA")
    w, h = FRAME
    if sheet.size != (w * COLS, h * ROWS):
        raise SystemExit(f"시트 크기가 다르다: {sheet.size}, 기대값 {(w * COLS, h * ROWS)}")
    out = []
    for i in range(COUNT):
        c, r = i % COLS, i // COLS
        out.append(sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)))
    return out


def align(frame: Image.Image) -> Image.Image:
    """접지선(불투명 최하단)과 받침 중심(하단 띠의 불투명 픽셀 무게중심)을 ANCHOR 로 옮긴다."""
    a = np.asarray(frame)[..., 3] > 127
    ys = np.where(a.any(1))[0]
    bottom = int(ys.max())
    band = a[max(bottom - BAND + 1, 0): bottom + 1]
    cols = band.sum(0)
    cx = float((cols * np.arange(frame.width)).sum() / cols.sum())
    dx = int(round(ANCHOR[0] - cx))
    dy = int(round(ANCHOR[1] - (bottom + 1)))
    moved = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    moved.alpha_composite(frame, (dx, dy))
    return moved


def head_mask(frame: Image.Image) -> np.ndarray:
    """머리(포신 + 호스) 픽셀 마스크."""
    a = np.asarray(frame)[..., 3] > 0
    yy, xx = np.mgrid[0:frame.height, 0:frame.width]
    upper = yy < CUT_Y
    hose = (yy >= CUT_Y) & (yy < HOSE_Y) & (xx < HOSE_X)
    return a & (upper | hose)


def cut(frame: Image.Image, mask: np.ndarray) -> tuple[Image.Image, tuple[int, int]]:
    """마스크 부분만 남긴 뒤 여백을 잘라 (이미지, 프레임 안 좌상단) 으로 돌려준다."""
    rgba = np.asarray(frame).copy()
    rgba[~mask] = 0
    img = Image.fromarray(rgba, "RGBA")
    box = img.getbbox()
    return img.crop(box), (box[0], box[1])


def save(img: Image.Image, rel: str) -> None:
    for base in (OUT_ASSET, OUT_GAME):
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)


def main() -> None:
    frames = [align(f) for f in load_frames()]
    for i, f in enumerate(frames):
        save(f, f"deploy/sentry_deploy_{i + 1:02d}.png")

    last = frames[-1]
    hm = head_mask(last)
    head, head_tl = cut(last, hm)
    base, base_tl = cut(last, (np.asarray(last)[..., 3] > 0) & ~hm)
    save(head, "sentry_head.png")
    save(base, "sentry_base.png")

    meta = {
        "source": SHEET.name,
        "frame_size": list(FRAME),
        "frame_count": COUNT,
        "fps": 10,
        # 정규화 프레임 안에서 받침 중심 x · 접지선 y. 런타임은 이 점을 바닥의 설치 지점에 맞춘다.
        "anchor": list(ANCHOR),
        # 조준 회전축 (앵커 기준). 머리 스프라이트는 이 점을 원점으로 회전한다.
        "pivot": [PIVOT[0] - ANCHOR[0], PIVOT[1] - ANCHOR[1]],
        # 각 스프라이트의 좌상단 (앵커 기준)
        "base_offset": [base_tl[0] - ANCHOR[0], base_tl[1] - ANCHOR[1]],
        # 머리는 회전축 기준 (회전축을 원점으로 두고 그린다)
        "head_offset": [head_tl[0] - PIVOT[0], head_tl[1] - PIVOT[1]],
        "head_size": list(head.size),
        "base_size": list(base.size),
        "muzzles": [list(m) for m in MUZZLES],
        "eject": list(EJECT),
        "cut": {"y": CUT_Y, "hose_x": HOSE_X, "hose_y": HOSE_Y},
    }
    for base_dir in (OUT_ASSET, OUT_GAME):
        (base_dir / "sentry_turret.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"프레임 {COUNT}개 정렬 · 머리 {head.size} · 받침 {base.size}")
    print(f"→ {OUT_GAME}")


if __name__ == "__main__":
    main()
