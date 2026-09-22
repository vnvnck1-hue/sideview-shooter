"""컨셉 원화 한 장(quadruped_side_transparent_v1.png)을 절차적 리그용 조각으로 자른다.

    python Tools/ImageProcessing/cut_quadruped_rig_parts.py

왜 이렇게 자르는가는 GodotPrototype/scripts/walker_rig.gd 의 주석과 짝을 이룬다.
리그는 조각을 **관절 기준**으로 붙이므로, 조각마다 "그림 안에서 관절이 있는 자리"(anchor)가 필요하다.
출력은 **리그 로컬 단위**다 (1px = 리그 1px). 원화를 SCALE 로 줄여 저장하므로 리그는 scale=1 로 쓴다.
본편에서 작게 보이는 것은 walker_unit.gd 가 노드를 줄이기 때문이고, 조각 자체는 랩과 같은 것이다.

## 원화를 **먼저 좌우 반전한다** (2026-09-22)

원화는 왼쪽을 본다 — 총구가 몸통 원점보다 왼쪽(-x)에 있다. 반면 ProcWalker 는 **+x 가 앞**이고
(yaw=0 이 오른쪽), 포신도 요동축에서 +a 로 뻗는 모델이다. 반전 없이 자르면
  · 포신 조각이 앵커 **왼쪽**에 총구를 두게 되어 리그가 180° 돌려 붙인다 (총구가 뒤로, 약실이 앞으로)
  · 몸통도 yaw=0 에서 뒤를 본 채 앞으로 걷는다 — yaw=PI 에서는 거울이 걸려 **양쪽 다** 뒤를 본다
붙여 놓고 나서야 드러난 증상이라 여기 적어 둔다. 아래 상자 좌표는 **전부 반전 후 좌표**다.

반전하면 몸통의 "78" 데칼도 같이 뒤집히므로, 그 자리만 원본에서 떠다 다시 붙인다(DECAL).

조각 (원화에서 실제로 읽히는 구조 그대로):
    hull    몸통. 포신 실루엣을 파내고 그 자리를 **흐린 함몰부**로 메운다
            (포신을 들면 그 안쪽이 보이는데, 원화에는 그 속이 그려져 있지 않다)
    barrel  포가(금색 링) + 포신 관 + 총구 제동기. 링 중심을 요동축으로 삼는다
    sleeve  허벅지 유압 슬리브 = 원화의 초록 장갑판. 고관절에 붙는다
    shin    정강이+발 = 장갑판 아래의 발목·발판. 길이가 변하지 않는 유일한 마디다
    cap     관절 원판 — 뒷다리 고관절에서 딴다. 원형 마스크로 오려
            어느 각도로 돌려도 같아 보이게 한다 (예전엔 사각 상자로 떠서 옆 다리 픽셀이 딸려왔다)
    rod     유압 로드. **원화에 노출된 구간이 없어 새로 만든다** —
            원화 팔레트에서 색을 뽑아 민무늬 원통으로 그린다 (민무늬라 잘라 써도 표가 안 난다)
    *_far   위 다리 마디의 **먼 쪽 벌** — 아래 PARTS 주석 참고

다리는 **두 벌** 자른다: 가까운 쪽(중앙 앞다리)과 먼 쪽(오른쪽 앞다리). 이 둘만 가려지지 않고
발까지 프레임 안에 온전히 들어 있다. 뒤·가까 / 뒤·먼 다리는 각각 같은 벌을 돌려 쓴다.
네 다리를 한 벌로 때우지 않는 이유는 PARTS 주석에 적어 두었다 — 이 원화는 3/4 뷰다.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Assets/Generated/QuadrupedRobotConcept/SideViewCutout/quadruped_side_transparent_v1.png"
OUT = ROOT / "GodotPrototype/assets/quadruped"

# 원화 → 리그 로컬 배율. 원화의 다리 한 벌(약 500px)이 리그의 선 자세 다리 길이(약 170)에 맞는 값.
#
# **조각을 게임 눈금에 맞춰 거칠게 굽지 않는다.** 한때 이 값을 8로 나눠(1조각px = 8로컬px) 본편의
# 4×4 블록에 맞춰 봤는데, 원화가 40px짜리로 뭉개져 랩에서 맞춰 둔 그림과 다른 물건이 됐다.
# 지금은 **랩에서 쓰던 조각 그대로** 본편에 넣고, 크기는 walker_unit.gd 가 노드 배율로만 줄인다.
SCALE = 0.34

# "78" 데칼 — 반전하면 글자가 뒤집히므로 이 상자만 원본에서 떠다 제자리에 다시 붙인다.
# 상자는 **원본(반전 전) 좌표**다. 테두리가 평평한 올리브 면이라 이음매가 보이지 않는다.
DECAL = (815, 285, 940, 375)

# 몸통 원점(리그의 (a,u) = (0,0))이 원화에서 어디인가. **반전 후 좌표**.
# x = 몸통 가로 중앙 · y = 고관절 줄에서 리그의 hip.u(40) 만큼 위
BODY_ORIGIN = (487.0, 482.0)

# 포신 실루엣. **도형으로 직접 그린다.**
#
# 처음엔 원화의 검은 테두리를 경계로 flood fill 을 해 봤다 — 테두리가 파츠 경계라는 발상은 맞지만,
# 이 그림은 파츠 **안쪽**에도 같은 밝기의 홈·띠가 그려져 있어 번짐이 거기서 막혀 조각이 누더기가 됐다.
# 사각형만 쓰면 포가(둥근 금색 링)의 네 귀퉁이가 몸통 장갑을 크게 물어, 몸통에서 파낸 자리가
# 네모난 검은 구멍으로 남았다. 그래서 링만 타원으로 두고 나머지는 사각형으로 감싼다.
#
# 도형은 **넉넉해도 된다** — 원화의 알파와 AND 하므로 배경은 배경으로 남는다.
# 조심할 것은 옆에 붙은 **다른 파츠를 물지 않는 것**뿐이다. 링 왼쪽(약실·급탄부)은 몸통에 남긴다:
# 거기까지 떼면 포신이 부앙할 때 몸통 앞쪽 절반이 통째로 구멍이 된다.
# 관은 **모서리를 둥글린 사각형**이다. 각진 사각형으로 파면 포신을 들었을 때 몸통에 남은
# 함몰부의 위쪽 귀퉁이가 직각으로 드러나 "소켓" 이 아니라 "네모난 구멍" 으로 읽힌다.
GUN_SHAPES = [
    ("ellipse", (672, 168, 804, 482)),     # 포가 (금색 링) — 둥글다. 요동축이 이 안에 있다
    ("round", (745, 185, 1200, 455)),      # 포신 관 + 총구 제동기
]
GUN_PIVOT = (724.0, 320.0)  # 포가 중심 ≒ 포신 축 — 여기를 요동축으로 삼는다

# 조각 상자와 관절 자리 (반전 후 원화 px). axis="down" 은 **원화에서 아래로 뻗은 마디**라는 뜻 —
# 리그가 회전할 때 -90° 를 더해 쓴다. 미리 돌려 저장하면 위에서 오는 빛이 옆으로 눕는다.
#
# 다리 마디는 상자 대신 **관절 두 점**(j0 = 매달리는 쪽 · j1 = 반대쪽)으로 잰다. anchor 는 j0 이고,
# 그 두 점이 이루는 기울기(lean)를 parts.json 에 적어 리그가 회전에서 빼 준다. 원화의 마디가
# 똑바로 서 있는 경우는 드물다 — 특히 **먼 다리는 3/4 로 누워 있어** lean 없이는 관절에서 꺾인다.
#
# ## 가까운 다리 / 먼 다리를 **따로 자른다** (2026-09-22)
# 예전엔 가까운 다리 한 벌만 자르고, 먼 쌍은 리그가 0.82 배로 가늘게·어둡게 그렸다.
# 그런데 이 원화는 정측면이 아니라 **3/4** 이고, 그 안에서 먼 다리는 "작은 가까운 다리" 가 아니라
# **비스듬히 누워 폭이 절반으로 눌린** 다리다 (장갑판 폭 248 → 100px). 한 벌을 줄여 쓰면
# 리그의 사영 위에 원화의 원근이 한 번 더 얹혀 이중으로 보인다.
# 그래서 원화가 이미 그려 둔 먼 다리를 그대로 가져온다 — 원근을 만들지 않고 **받아 쓴다**.
PARTS = {
    # 위쪽 y=12 — 원화 맨 위의 초록 후드까지 넣는다.
    # 아래쪽 y=660 — 예전엔 625(= ProcWalker.BODY_BOT)에서 끊었는데, 그 선이 **배·골반 프레임과
    # 고관절 하우징 한가운데**를 잘라 다리가 허공에 매달렸다. 다리 조각이 시작되는 y≈665 직전까지
    # 내려 배를 살린다 (ProcWalker.BODY_BOT 도 같이 60 으로 내렸다).
    "hull": {"box": (19, 12, 954, 660), "anchor": BODY_ORIGIN, "axis": "none"},
    "barrel": {"box": (668, 164, 1200, 492), "anchor": GUN_PIVOT, "axis": "right", "mask": "gun"},

    # ── 가까운 다리 — 중앙 앞다리. 장갑판은 y 590~992 (거의 수직) · 그 아래가 발목·발판이다.
    # 예전 상자는 두 조각이 25px 겹치고 발이 상자 **밖**이라 다리가 그루터기로 끝났다.
    "sleeve": {"box": (588, 590, 836, 992), "j0": (706.0, 596.0), "j1": (706.0, 986.0), "axis": "down"},
    "shin": {"box": (598, 976, 840, 1128), "j0": (720.0, 980.0), "j1": (720.0, 1122.0), "axis": "down"},
    # 뒷다리 고관절의 **원판**. 원형으로 오려 어느 각도에서나 같아 보이게 한다
    "cap": {"box": (238, 498, 368, 626), "anchor": (303.0, 562.0), "axis": "none", "mask": "circle"},

    # ── 먼 다리 — 오른쪽(앞·먼) 다리. 네 다리 중 가려지지 않고 발까지 온전한 유일한 먼 다리다.
    # 장갑판이 18° 누워 있다 (lean 이 그걸 받는다)
    # 먼 다리는 뒤·먼 다리의 버팀대가 **뒤로 지나가서**, 사각 상자로 뜨면 그 회색 대각선이
    # 딸려 온다 (붙여 보고 알았다 — 장갑판 왼쪽에 정체불명의 회색 막대가 하나 더 생겼다).
    # 그래서 마디의 네 귀퉁이를 찍어 **다각형으로** 오린다.
    "sleeve_far": {"box": (925, 586, 1180, 980), "j0": (985.0, 600.0), "j1": (1098.0, 952.0),
                   "axis": "down", "mask": "poly",
                   "poly": [(964, 612), (1042, 590), (1174, 938), (1068, 972)]},
    "shin_far": {"box": (975, 950, 1160, 1120), "j0": (1063.0, 960.0), "j1": (1050.0, 1098.0),
                 "axis": "down", "mask": "poly",
                 "poly": [(985, 956), (1152, 948), (1142, 1116), (996, 1118)]},
    "cap_far": {"box": (1072, 927, 1134, 989), "anchor": (1103.0, 958.0), "axis": "none", "mask": "circle"},
}

# 로드 치수는 **리그 로컬 px 로 정하고 조각 px 로 환산한다** (PIXEL 로 나눈다).
ROD_LEN = 300   # 로컬 px — ProcWalker.THIGH_MAX 와 같아야 한다 (최대 신장에서 모자라지 않게)
ROD_W = 44      # 로컬 px. 슬리브(원화 판)보다 가늘어야 안쪽으로 들어가 보인다


def harden(img: Image.Image, threshold: int = 128) -> Image.Image:
    rgba = img.convert("RGBA")
    rgba.putalpha(rgba.getchannel("A").point(lambda v: 255 if v >= threshold else 0))
    return rgba


def load_source() -> Image.Image:
    """원화를 읽어 **좌우 반전**하고, 뒤집힌 "78" 데칼만 원본으로 되돌린다."""
    raw = harden(Image.open(SRC))
    art = ImageOps.mirror(raw)
    art.paste(raw.crop(DECAL), (raw.width - DECAL[2], DECAL[1]))
    return art


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
        elif kind == "round":
            d.rounded_rectangle(box, radius=96, fill=255)
        else:
            d.rectangle(box, fill=255)
    _GUN_MASK_CACHE[id(art)] = m
    return m


def to_world(px: float) -> int:
    return int(round(px * SCALE))


def anchor_of(spec: dict) -> tuple[float, float]:
    return spec["anchor"] if "anchor" in spec else spec["j0"]


def lean_of(spec: dict) -> float:
    """마디가 **원화 안에서** 똑바로 아래(또는 오른쪽)에서 얼마나 기울어 있는가 (rad).
    리그가 회전에서 이만큼 되돌려, 그림을 미리 돌리지 않고도 관절이 맞는다."""
    if "j1" not in spec:
        return 0.0
    dx = spec["j1"][0] - spec["j0"][0]
    dy = spec["j1"][1] - spec["j0"][1]
    return math.atan2(dx, dy) if spec["axis"] == "down" else math.atan2(dy, dx)


def cut(art: Image.Image, spec: dict) -> tuple[Image.Image, tuple[float, float]]:
    """상자대로 잘라 월드 단위로 줄인다. anchor 를 조각 안의 좌표로 바꿔 돌려준다."""
    box = spec["box"]
    piece = art.crop(box)
    kind = spec.get("mask")
    m = None
    if kind == "gun":
        m = gun_mask(art).crop(box)
    elif kind == "circle":
        m = Image.new("L", piece.size, 0)
        ImageDraw.Draw(m).ellipse((0, 0, piece.width - 1, piece.height - 1), fill=255)
    elif kind == "poly":
        m = Image.new("L", art.size, 0)
        ImageDraw.Draw(m).polygon(spec["poly"], fill=255)
        m = m.crop(box)
    if m is not None:
        keep = piece.getchannel("A")
        piece.putalpha(Image.composite(keep, Image.new("L", piece.size, 0), m))
    w = max(1, to_world(piece.width))
    h = max(1, to_world(piece.height))
    piece = piece.resize((w, h), Image.LANCZOS)
    a = anchor_of(spec)
    ax = (a[0] - box[0]) * SCALE
    ay = (a[1] - box[1]) * SCALE
    return harden(piece), (round(ax, 1), round(ay, 1))


SOCKET_LIP = 20     # 로컬 px — 남은 몸통 둘레로 함몰부를 이만큼만 남긴다 (소켓의 깊이감)


def carve_gun_out_of_hull(art: Image.Image, hull: Image.Image, hull_box, shade) -> Image.Image:
    """몸통에서 포신 자리를 **진짜로 파내고**, 남은 몸통 둘레에만 얕은 함몰부를 두른다.

    원화는 포신과 몸통이 한 덩어리로 칠해져 있어, 포신을 떼면 그 자리에 구멍이 남는다.
    포신이 부앙하면 그 구멍이 드러나므로 뭔가는 해 줘야 한다. 두 번 헛짚은 자리다.

      1차 — 그 자리의 원화 픽셀을 0.62 배로 **누르기만** 했다. 포신 무늬가 그대로 읽혀
            "움직이지 않는 두 번째 포신" 이 몸통에 박힌 꼴이 됐다.
      2차 — 흐리고 어둡게 눌러 무늬는 지웠는데, 마스크가 **포신 실루엣 전체**라 몸통이 없는
            허공까지 시커멓게 칠했다. 포신을 들면 몸통 오른쪽에 네모난 검은 판이 남았다.

    지금은 마스크를 **알파 0 으로 잘라 내고**, 그중 *남은 몸통에서 SOCKET_LIP 안쪽*만 다시
    채운다. 그래서 몸통 실루엣은 포신이 빠진 진짜 윤곽이 되고, 포가가 박혀 있던 홈 둘레에만
    얕은 그늘이 남아 "포신이 끼워지는 소켓" 으로 읽힌다.
    """
    m = gun_mask(art).crop(hull_box)
    w = max(1, to_world(m.width))
    h = max(1, to_world(m.height))
    m = m.resize((w, h), Image.LANCZOS).point(lambda v: 255 if v >= 128 else 0)
    not_m = m.point(lambda v: 255 - v)

    black = Image.new("L", hull.size, 0)
    body = Image.composite(hull.getchannel("A"), black, not_m)          # 포신을 뺀 진짜 몸통
    near = body.filter(ImageFilter.MaxFilter(SOCKET_LIP * 2 + 1))       # 그 둘레
    socket = Image.composite(m, black, near)                            # 남길 함몰부

    blur = hull.convert("RGB").filter(ImageFilter.GaussianBlur(9))
    recess = Image.blend(blur, Image.new("RGB", hull.size, shade[:3]), 0.45)
    recess = Image.eval(recess, lambda v: int(v * 0.72)).convert("RGBA")
    out = Image.composite(recess, hull, m)

    # 소켓 턱 — 함몰부의 **바깥 테두리** 두어 px 을 한 단 밝게.
    # 이게 없으면 함몰부가 소켓이 아니라 그냥 얼룩으로 보인다.
    lip = Image.composite(socket, black,
                          socket.filter(ImageFilter.MinFilter(9)).point(lambda v: 255 - v))
    edge = Image.eval(out.convert("RGB"), lambda v: min(255, int(v * 1.9) + 18)).convert("RGBA")
    out = Image.composite(edge, out, lip)

    out.putalpha(ImageChops.lighter(body, socket))   # 몸통 + 함몰부만 남고 나머지는 잘려 나간다
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
    art = load_source()
    OUT.mkdir(parents=True, exist_ok=True)
    meta: dict[str, object] = {
        "source": SRC.name,
        "scale": SCALE,
        "mirrored": True,
        "body_origin_art_px": list(BODY_ORIGIN),
        "note": "크기·anchor 는 월드 px (1px = 게임 1px). 원화를 좌우 반전해 자른다 "
                "(원화는 왼쪽을 보는데 리그는 +x 가 앞이다). walker_rig.gd 가 이 파일을 읽는다.",
        "parts": {},
    }

    shade = darkest(art, PARTS["hull"]["box"])
    for name, spec in PARTS.items():
        piece, anchor = cut(art, spec)
        if name == "hull":
            piece = carve_gun_out_of_hull(art, piece, spec["box"], shade)
        piece.save(OUT / f"{name}.png", optimize=True)
        lean = round(lean_of(spec), 4)
        meta["parts"][name] = {
            "size": [piece.width, piece.height],
            "anchor": list(anchor),
            "axis": spec["axis"],
            "lean": lean,
        }
        print(f"  {name:10s} {piece.width:4d}x{piece.height:4d}  anchor {anchor}  "
              f"axis {spec['axis']:5s} lean {math.degrees(lean):5.1f}deg")

    rod = make_rod(palette(art, PARTS["cap"]["box"], 6))
    rod.save(OUT / "rod.png", optimize=True)
    meta["parts"]["rod"] = {
        "size": [rod.width, rod.height],
        "anchor": [rod.width / 2.0, 0.0],
        "axis": "down",
        "lean": 0.0,
        "synthesized": "원화에 노출된 로드가 없어 팔레트에서 새로 그렸다",
    }
    print(f"  rod      {rod.width:4d}x{rod.height:4d}  (새로 그림)")

    (OUT / "parts.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"--- {OUT} 에 저장 ---")


if __name__ == "__main__":
    main()
