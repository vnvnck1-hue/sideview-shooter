"""
붉은 후드 정비공 — 머리(후드+마스크) 분리 리소스 빌드.

build_hooded_mechanic_split.py 가 만든 Split/body 프레임(머리 포함)을 읽어
  head/<clip>/<clip>_NN.png   목 위(후드·마스크)만 남긴 320x320 프레임 (+ 목선 아래 후드 자락 OVERLAP px 포함)
  body/<clip>/<clip>_NN.png   목선 위를 지운 몸통 프레임 (목선 아래는 원본 그대로 — 후드 자락은 양쪽에 중복되어 회전 틈을 가린다)
  split_meta.json             frames[*].neck / neck_from_pivot 추가
를 GameReady Split 과 GodotPrototype Split 양쪽에 쓴다.

목선 위치는 idle 프레임 기준값을 각 프레임의 후드 상단(붉은 픽셀 bbox) 이동량으로 보정한다.
실행 순서 : build_hooded_mechanic_split.py → 이 스크립트 → build_normal_maps.py
"""
import json, os, shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Assets/GameReady/Characters/HoodedMechanic/Split")
OUTS = [SRC, os.path.join(ROOT, "GodotPrototype/assets/character/Split")]
CELL = 320
PIVOT = (160, 320)

NECK_IDLE = (175, 172)   # idle_01 프레임 픽셀 좌표: 마스크 아래·재킷 위 목선, 머리 회전축
OVERLAP = 28             # 목선 아래로 머리 스프라이트에 함께 담을 후드 자락 높이
HEAD_BACK_W = 85         # 목선 아래 자락을 담을 범위: 목 X 기준 뒤쪽(왼쪽) 폭
HEAD_FRONT_W = 95        # 앞쪽(오른쪽) 폭
CLIPS = {"idle": 1, "aim": 1, "walk": 4, "crouch": 4}


def is_hood_red(p):
    r, g, b, a = p
    return a > 0 and r > 70 and r > g * 1.6 and r > b * 1.5 and r - g > 35


def is_outline(p):
    r, g, b, a = p
    return a > 0 and max(r, g, b) < 70


def is_pack(p):
    """배낭·가죽 갈색 (목선 위로 튀어나온 배낭 윗부분은 몸통에 남긴다)."""
    r, g, b, a = p
    return a > 0 and r > 90 and r >= g > b and g > r * 0.55 and r - b > 40 and not (r > 200 and g > 150)


def hood_top(im):
    """후드(붉은 픽셀) 최상단 y 와 그 행의 x 중심."""
    px = im.load()
    for y in range(CELL):
        xs = [x for x in range(CELL) if is_hood_red(px[x, y])]
        if len(xs) >= 3:
            return y, (min(xs) + max(xs)) * 0.5
    raise RuntimeError("hood not found")


def split_frame(im, neck):
    nx, ny = neck
    head = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    body = im.copy()
    hp, bp, sp = head.load(), body.load(), im.load()
    # 1) 목선 위: 머리로. 단, 목 왼쪽(뒤쪽) 구역은 후드(붉은색)와 그 외곽선(2px)만 머리이고
    #    나머지(배낭 윗부분·끈)는 몸통에 남긴다. 얼굴은 목 오른콽에 있으므로 그쪽은 전부 머리.
    back_x = nx - 30
    # 몸통에 남길 픽셀 = 배낭 갈색 + 거기서 10px 안에 이어진 비(非)붉은 픽셀(배낭 외곽선·끈). 후드 외곽선이 일부 몸통에 남아도 각도 0 에선 동일하게 보인다. 그 외 뒤쪽 구역은 모두 머리(후드·외곽선).
    keep = set()
    for y in range(ny):
        for x in range(back_x):
            if is_pack(sp[x, y]):
                keep.add((x, y))
    for _ in range(10):
        grow = set()
        for (x, y) in keep:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < back_x and 0 <= yy < ny and (xx, yy) not in keep:
                        p = sp[xx, yy]
                        if p[3] > 0 and not is_hood_red(p):
                            grow.add((xx, yy))
        keep |= grow
    for y in range(ny):
        for x in range(CELL):
            p = sp[x, y]
            if p[3] == 0 or (x, y) in keep:
                continue
            hp[x, y] = p
            bp[x, y] = (0, 0, 0, 0)
    # 2) 목선 아래 OVERLAP 띠: 목선 바로 위 머리 픽셀과 이어진 붉은 후드 자락(+외곽선)만 머리에도 복사.
    #    (스카프처럼 떨어져 있는 붉은 조각은 제외) 몸통은 그대로 둔다.
    seeds = [(x, ny - 1) for x in range(CELL) if hp[x, ny - 1][3] > 0 and (is_hood_red(sp[x, ny - 1]) or is_outline(sp[x, ny - 1]))]
    seen = set(seeds)
    stack = list(seeds)
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if (xx, yy) in seen or not (0 <= xx < CELL) or not (ny <= yy < ny + OVERLAP) or xx < nx - HEAD_BACK_W or xx > nx + HEAD_FRONT_W:
                continue
            p = sp[xx, yy]
            if is_hood_red(p) or is_outline(p):
                seen.add((xx, yy))
                hp[xx, yy] = p
                stack.append((xx, yy))
    return head, body


def _touches_red(px, x, y):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if 0 <= xx < CELL and 0 <= yy < CELL and is_hood_red(px[xx, yy]):
            return True
    return False


def main():
    with open(os.path.join(SRC, "split_meta.json"), encoding="utf-8") as f:
        meta = json.load(f)
    if any("neck" in v for v in meta["frames"].values()):
        raise SystemExit("이미 머리가 분리된 Split 입니다. build_hooded_mechanic_split.py 를 먼저 다시 실행하세요.")

    idle = Image.open(os.path.join(SRC, "body/idle/idle_01.png")).convert("RGBA")
    top0, cx0 = hood_top(idle)

    results = {}   # rel path -> image
    for clip, n in CLIPS.items():
        for i in range(1, n + 1):
            name = f"{clip}_{i:02d}"
            im = Image.open(os.path.join(SRC, "body", clip, name + ".png")).convert("RGBA")
            top, cx = hood_top(im)
            neck = (int(round(NECK_IDLE[0] + (cx - cx0))), NECK_IDLE[1] + (top - top0))
            head, body = split_frame(im, neck)
            results[f"head/{clip}/{name}.png"] = head
            results[f"body/{clip}/{name}.png"] = body
            meta["frames"][name]["neck"] = [neck[0], neck[1]]
            meta["frames"][name]["neck_from_pivot"] = [neck[0] - PIVOT[0], neck[1] - PIVOT[1]]
            print(f"{name}: neck={neck}")
    meta["head"] = {"overlap": OVERLAP, "note": "head/<clip>/<clip>_NN.png 은 320 셀 그대로, neck 이 회전축"}

    for out in OUTS:
        for rel, im in results.items():
            dst = os.path.join(out, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            im.save(dst)
        with open(os.path.join(out, "split_meta.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2, ensure_ascii=False)
        print("OK ->", out)


if __name__ == "__main__":
    main()
