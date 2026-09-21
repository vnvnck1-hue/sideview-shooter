"""컨셉 원화 한 장(quadruped_side_transparent_v1.png)을 절차적 리그용 조각으로 자른다.

    python Tools/ImageProcessing/cut_quadruped_rig_parts.py

왜 이렇게 자르는가는 GodotPrototype/scripts/walker_rig.gd 의 주석과 짝을 이룬다.
리그는 조각을 **관절 기준**으로 붙이므로, 조각마다 "그림 안에서 관절이 있는 자리"(anchor)가 필요하다.
출력은 **월드 단위**다 (1px = 게임 1px). 원화를 SCALE 로 줄여 저장하므로 리그는 scale=1 로 쓴다.

조각 (원화에서 실제로 읽히는 구조 그대로):
    hull    몸통. 포신 실루엣을 빼고 그 구멍을 어두운 함몰부로 메운다
            (포신을 들면 그 안쪽이 보이는데, 원화에는 그 속이 그려져 있지 않다)
    barrel  총구~약실. 포가(gold ring) 중심을 요동축으로 삼는다
    sleeve  허벅지 유압 슬리브 = 원화의 초록 장갑판. 고관절에 붙는다
    shin    정강이+발 = 장갑판 아래의 짧은 발목·발판. 길이가 변하지 않는 유일한 마디다
    cap     관절 원통 — 고관절·무릎의 이음매를 덮는다 (원화의 큰 실린더에서 딴다)
    rod     유압 로드. **원화에 노출된 구간이 없어 새로 만든다** —
            원화 팔레트에서 색을 뽑아 민무늬 원통으로 그린다 (민무늬라 잘라 써도 표가 안 난다)

다리는 한 벌만 자른다. 네 다리가 같은 조각을 쓰고, 먼 쌍은 리그가 어둡게·조금 작게 그린다.
원화의 네 다리는 서로 다른 각도로 그려져 있어 그대로는 재사용할 수 없다 — 가장 온전한
가까·앞 다리(중앙의 큰 초록 판)를 표준으로 삼는다.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Assets/Generated/QuadrupedRobotConcept/SideViewCutout/quadruped_side_transparent_v1.png"
OUT = ROOT / "GodotPrototype/assets/quadruped"

# 원화 → 월드 배율. 원화의 다리 한 벌(약 500px)이 리그의 선 자세 다리 길이(약 170)에 맞는 값.
SCALE = 0.34

# 몸통 원점(리그의 (a,u) = (0,0))이 원화에서 어디인가.
# x = 몸통 가로 중앙 · y = 고관절 줄에서 리그의 hip.u(40) 만큼 위
BODY_ORIGIN = (717.0, 482.0)

# 포신 실루엣. **도형으로 직접 그린다.**
#
# 처음엔 원화의 검은 테두리를 경계로 flood fill 을 해 봤다 — 테두리가 파츠 경계라는 발상은 맞지만,
# 이 그림은 파츠 **안쪽**에도 같은 밝기의 홈·띠가 그려져 있어 번짐이 거기서 막혀 조각이 누더기가 됐다.
# 사각형만 쓰면 포가(둥근 금색 링)의 네 귀퉁이가 몸통 장갑을 크게 물어, 몸통에서 파낸 자리가
# 네모난 검은 구멍으로 남았다. 그래서 링만 타원으로 두고 나머지는 사각형으로 감싼다.
GUN_SHAPES = [
    ("rect", (0, 168, 392, 432)),          # 총구 제동기 + 포신 관
    ("ellipse", (380, 110, 570, 600)),     # 포가 (금색 링) — 둥글다
    ("rect", (556, 150, 706, 560)),        # 약실 덩어리
]
GUN_PIVOT = (480.0, 320.0)  # 포가 중심 ≒ 포신 축 — 여기를 요동축으로 삼는다

# 조각 상자와 관절 자리 (원화 px). axis="down" 은 **원화에서 아래로 뻗은 마디**라는 뜻 —
# 리그가 회전할 때 +90° 를 더해 쓴다. 미리 돌려 저장하면 위에서 오는 빛이 옆으로 눕는다.
PARTS = {
    # 위쪽 상자 경계는 y=12 — 원화 맨 위의 초록 후드까지 넣는다.
    # 95 로 잘랐다가 후드가 사라져 몸통이 납작해졌다 (원화와 나란히 놓고 보니 바로 드러났다)
    "hull": {"box": (250, 12, 1185, 625), "anchor": BODY_ORIGIN, "axis": "none"},
    "barrel": {"box": (0, 60, 706, 610), "anchor": GUN_PIVOT, "axis": "right", "mask": "gun"},
    "sleeve": {"box": (378, 592, 596, 975), "anchor": (487.0, 600.0), "axis": "down"},
    "shin": {"box": (380, 950, 592, 1108), "anchor": (486.0, 956.0), "axis": "down"},
    "cap": {"box": (185, 725, 332, 902), "anchor": (258.0, 813.0), "axis": "none"},
}

ROD_LEN = 300   # 월드 px — ProcWalker.THIGH_MAX 와 같아야 한다 (최대 신장에서 모자라지 않게)
ROD_W = 44      # 월드 px. 슬리브(원화 판)보다 가늘어야 안쪽으로 들어가 보인다


def harden(img: Image.Image, threshold: int = 128) -> Image.Image:
    rgba = img.convert("RGBA")
    rgba.putalpha(rgba.getchannel("A").point(lambda v: 255 if v >= threshold else 0))
    return rgba


_GUN_MASK_CACHE: dict[int, Image.Image] = {}


def gun_mask(art: Image.Image) -> Image.Image:
    """포신 실루엣 마스크 (GUN_SHAPES 의 합집합)"""
    if id(art) in _GUN_MASK_CACHE:
        return _GUN_MASK_CACHE[id(art)]
    m = Image.new("L", art.size, 0)
    d = ImageDraw.Draw(m)
    for kind, box in GUN_SHAPES:
        if kind == "ellipse":
            d.ellipse(box, fill=255)
        else:
            d.rectangle(box, fill=255)
    _GUN_MASK_CACHE[id(art)] = m
    return m


def to_world(px: float) -> int:
    return int(round(px * SCALE))


def cut(art: Image.Image, spec: dict) -> tuple[Image.Image, tuple[float, float]]:
    """상자대로 잘라 월드 단위로 줄인다. anchor 를 조각 안의 좌표로 바꿔 돌려준다."""
    box = spec["box"]
    piece = art.crop(box)
    if spec.get("mask") == "gun":
        m = gun_mask(art).crop(box)
        a = piece.getchannel("A").point(lambda v: v)
        piece.putalpha(Image.composite(a, Image.new("L", piece.size, 0), m))
    w = max(1, to_world(piece.width))
    h = max(1, to_world(piece.height))
    piece = piece.resize((w, h), Image.LANCZOS)
    ax = (spec["anchor"][0] - box[0]) * SCALE
    ay = (spec["anchor"][1] - box[1]) * SCALE
    return harden(piece), (round(ax, 1), round(ay, 1))


def carve_gun_out_of_hull(art: Image.Image, hull: Image.Image, hull_box, shade) -> Image.Image:
    """몸통에서 포신 자리를 파내고 **어두운 함몰부**로 메운다.

    원화는 포신과 몸통이 한 덩어리로 칠해져 있어, 포신을 떼면 그 자리에 구멍이 남는다.
    포신이 부앙하면 그 구멍이 드러나므로 뭔가는 채워야 한다. 원화에 없는 속을 상상해 그리는 대신
    **그 자리의 원화 픽셀을 그대로 어둡게 눌러** 함몰부로 만든다. 평평한 검정으로 덮으면 마스크
    도형이 그대로 드러나 네모난 구멍처럼 보이는데(처음에 그렇게 나왔다), 눌러 두면 밑에 있던
    기계 디테일이 어둠 속에 희미하게 남아 "포신이 함몰부에 얹혀 있다" 로 읽힌다.
    """
    m = gun_mask(art).crop(hull_box)
    w = max(1, to_world(m.width))
    h = max(1, to_world(m.height))
    m = m.resize((w, h), Image.LANCZOS).point(lambda v: 255 if v >= 128 else 0)
    alpha = hull.getchannel("A")
    dark = Image.blend(hull.convert("RGB"), Image.new("RGB", hull.size, shade[:3]), 0.72)
    dark = Image.eval(dark, lambda v: int(v * 0.62))
    out = Image.composite(dark.convert("RGBA"), hull, m)
    out.putalpha(alpha)                      # 몸통 실루엣은 그대로 — 안쪽만 어둡게
    return out


def darkest(art: Image.Image, box) -> tuple[int, int, int, int]:
    """그 구역에서 가장 어두운 불투명 색 (함몰부·그림자 색으로 쓴다)"""
    region = art.crop(box).convert("RGBA")
    best = None
    best_lum = 1e9
    for r, g, b, a in region.getdata():
        if a < 200:
            continue
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum < best_lum:
            best_lum = lum
            best = (r, g, b, 255)
    return best or (20, 20, 28, 255)


def palette(art: Image.Image, box, count: int) -> list[tuple[int, int, int]]:
    """그 구역의 대표색을 어두운 순으로 count 개 (로드를 원화 색으로 그리기 위해)"""
    region = art.crop(box).convert("RGB").quantize(colors=count, method=Image.MEDIANCUT)
    pal = region.getpalette()[: count * 3]
    cols = [tuple(pal[i * 3 : i * 3 + 3]) for i in range(count)]
    cols.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    return cols


def make_rod(cols: list[tuple[int, int, int]]) -> Image.Image:
    """유압 로드 — 원화에 없어 새로 그린다. **위에서 아래로 뻗은** 민무늬 원통.
    윗면 하이라이트 · 가운데 본색 · 아랫면 그림자 3단. 길이 방향으로 무늬가 없어야
    리그가 region 으로 잘라 써도 표가 나지 않는다."""
    img = Image.new("RGBA", (ROD_W, ROD_LEN), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark, mid, lit = cols[0], cols[len(cols) // 2], cols[-1]
    d.rectangle((0, 0, ROD_W - 1, ROD_LEN - 1), fill=mid + (255,))
    d.rectangle((0, 0, 2, ROD_LEN - 1), fill=dark + (255,))                    # 왼쪽 테두리
    d.rectangle((ROD_W - 3, 0, ROD_W - 1, ROD_LEN - 1), fill=dark + (255,))    # 오른쪽 테두리
    d.rectangle((6, 0, 12, ROD_LEN - 1), fill=lit + (255,))                    # 원통 하이라이트
    d.rectangle((ROD_W - 12, 0, ROD_W - 7, ROD_LEN - 1), fill=dark + (255,))   # 반대쪽 음영
    return img


def main() -> None:
    art = harden(Image.open(SRC))
    OUT.mkdir(parents=True, exist_ok=True)
    meta: dict[str, object] = {
        "source": SRC.name,
        "scale": SCALE,
        "body_origin_art_px": list(BODY_ORIGIN),
        "note": "크기·anchor 는 월드 px (1px = 게임 1px). walker_rig.gd 가 이 파일을 읽는다.",
        "parts": {},
    }

    shade = darkest(art, (250, 95, 1185, 625))
    for name, spec in PARTS.items():
        piece, anchor = cut(art, spec)
        if name == "hull":
            piece = carve_gun_out_of_hull(art, piece, spec["box"], shade)
        piece.save(OUT / f"{name}.png", optimize=True)
        meta["parts"][name] = {
            "size": [piece.width, piece.height],
            "anchor": list(anchor),
            "axis": spec["axis"],
        }
        print(f"  {name:8s} {piece.width:4d}x{piece.height:4d}  anchor {anchor}  axis {spec['axis']}")

    rod = make_rod(palette(art, (185, 725, 332, 902), 6))
    rod.save(OUT / "rod.png", optimize=True)
    meta["parts"]["rod"] = {
        "size": [rod.width, rod.height],
        "anchor": [rod.width / 2.0, 0.0],
        "axis": "down",
        "synthesized": "원화에 노출된 로드가 없어 팔레트에서 새로 그렸다",
    }
    print(f"  rod      {rod.width:4d}x{rod.height:4d}  (새로 그림)")

    (OUT / "parts.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"--- {OUT} 에 저장 ---")


if __name__ == "__main__":
    main()
