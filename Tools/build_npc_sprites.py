"""NPC 콘셉트 PNG(1254×1254) → Native4 게임 스프라이트(80×80 아트 px)로 반입한다.

Docs/CHARACTER_ART_GUIDE.md §5 "픽셀 제작 규격":
  1 아트 px = 4 월드 px, 셀 80×80 아트 px(= 320×320 월드 px), Bottom Center 피벗,
  알파는 0/255 만, 자산당 8~16색.

콘셉트 그림은 1254px 캔버스에 ~16px 블록으로 그려져 있지만 격자가 정확히 맞지 않고
경계에 반투명 화소가 남아 있다. 여기서 하는 일:
  1. 알파 bbox 로 인물만 잘라낸다
  2. 인물 키(아트 px)를 HEIGHTS 값으로 면적 평균(BOX) 축소 — 플레이어(66 아트 px)와 같은 덩어리감
  3. 알파를 0/255 로 자르고 색을 16색으로 줄인다 (AA·잡색 제거)
  4. 80×80 셀의 바닥 중심에 앉힌다 (발바닥이 셀 맨 아랫줄)

출력: Assets/GameReady/Native4/character/npc/<id>/idle_01.png
이후:  python Tools/upscale_native4.py            (×4 Nearest → GodotPrototype/assets/character/npc/…)
       python Tools/build_normal_maps.py character/npc

실행: python Tools/build_npc_sprites.py   (저장소 루트에서)
"""
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "Assets" / "Generated" / "NPCConcepts"
DST = REPO / "Assets" / "GameReady" / "Native4" / "character" / "npc"

CELL = 80                 # 아트 px. 게임에서 320×320 월드 px
FOOT_PAD = 1              # 발바닥과 셀 아래끝 사이 여유 (아트 px)
ALPHA_CUT = 110           # 이 값 이상이면 불투명 (경계 AA 를 안쪽으로 한 겹 먹는다)
BBOX_CUT = 24             # 콘셉트 PNG 바깥 헐레이션을 무시하고 인물만 잘라 내는 알파 문턱
COLORS = 16

# id → (콘셉트 파일, 키(아트 px))
#   플레이어 서 있는 실루엣이 40×66 아트 px. 인물마다 체형이 다르니 키만 조금씩 달리한다.
#   CHARACTER_ART_GUIDE §2 "NPC 는 플레이어보다 한참 작거나 가늘게 보이지 않아야 한다".
NPCS = {
    "airlock_caretaker":   ("airlock_caretaker_concept_v5.png", 65),
    "security_controller": ("security_controller_concept_v5.png", 68),
    "hydroponics_keeper":  ("hydroponics_keeper_concept_v5.png", 64),
    "researcher_junior":   ("researcher_junior_concept_v2.png", 63),
    "researcher_senior":   ("researcher_senior_concept_v2.png", 65),
    "researcher_male":     ("researcher_male_concept_v1.png", 65),
}


def quantize(rgb: Image.Image, mask: np.ndarray) -> Image.Image:
    """불투명 화소만 보고 COLORS 색 팔레트를 잡는다 (투명 화소가 팔레트를 먹지 않게 평균색으로 덮어 두고 줄인다)."""
    a = np.asarray(rgb).astype(np.uint8).copy()
    if mask.any():
        a[~mask] = a[mask].mean(0).round().astype(np.uint8)
    flat = Image.fromarray(a, "RGB")
    return flat.quantize(colors=COLORS, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")


def build(npc_id: str, src_name: str, height: int) -> None:
    img = Image.open(SRC / src_name).convert("RGBA")
    # 콘셉트 PNG 에는 인물 바깥으로 알파 몇 단계짜리 헐레이션이 남아 있다 — bbox 는 실제 그림만 잡는다
    solid = np.asarray(img)[..., 3] >= BBOX_CUT
    ys, xs = np.nonzero(solid)
    if len(xs) == 0:
        raise SystemExit(f"{src_name}: 빈 이미지")
    fig = img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))

    # 면적 평균으로 아트 해상도까지 내린다 — 16px 블록이 격자에 안 맞아도 덩어리가 살아남는다
    scale = height / fig.height
    small = fig.resize((max(1, round(fig.width * scale)), height), Image.BOX)
    arr = np.asarray(small).astype(np.uint8)
    mask = arr[..., 3] >= ALPHA_CUT

    rgb = quantize(Image.fromarray(arr[..., :3], "RGB"), mask)
    out = np.zeros((height, small.width, 4), np.uint8)
    out[..., :3] = np.asarray(rgb)
    out[..., 3] = np.where(mask, 255, 0)
    out[~mask] = 0                                    # 투명 화소는 색까지 0 (밉맵·필터 번짐 방지)
    sprite = Image.fromarray(out, "RGBA")

    if sprite.width > CELL:
        raise SystemExit(f"{npc_id}: 폭 {sprite.width} 아트 px — 셀 {CELL} 을 넘는다. 키를 줄여라")

    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.paste(sprite, ((CELL - sprite.width) // 2, CELL - FOOT_PAD - height), sprite)

    dst = DST / npc_id / "idle_01.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    cell.save(dst, optimize=True)

    used = len({tuple(p) for p in out[mask]})
    print(f"{npc_id:22s} {fig.width}x{fig.height} -> {sprite.width}x{height} 아트 px, {used}색  {dst.relative_to(REPO).as_posix()}")


def main() -> None:
    for npc_id, (src_name, height) in NPCS.items():
        build(npc_id, src_name, height)
    print("\n다음: python Tools/upscale_native4.py && python Tools/build_normal_maps.py character/npc")


if __name__ == "__main__":
    main()
