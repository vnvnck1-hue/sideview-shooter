"""캐릭터 규격 기준표 측정기 — SCALE_STANDARDIZATION_PLAN 1단계.

게임에 실제로 반입된 플레이어·NPC 이미지와 split_meta.json, player.gd 상수를 읽어
외형(불투명 영역)·어깨/목/총구·이동 수치를 월드 px 로 출력한다. 값을 손으로 옮겨 적지 않고
리소스를 바꾼 뒤 다시 돌려 기준표(Docs/SCALE_CHARACTER_BASELINE.md)를 갱신하기 위한 도구다.

- 외형 = 알파 128 이상 픽셀의 경계 상자. 피벗(셀 하단 중앙) 기준, 오른쪽을 볼 때의 좌/우 범위.
- 이미지 캔버스(셀) 크기와 실제 그림 영역을 구분해 둘 다 적는다.
- 판정 크기(독액 명중 상자·벽 여유)는 이미지가 아니라 코드 상수라서 별도로 읽는다.

실행 (저장소 루트):
  python Tools/measure_character_scale.py            # 표 출력
  python Tools/measure_character_scale.py --sheet    # + 같은 바닥선 비교 이미지
      → Assets/Generated/ScaleBaseline/character_lineup.png
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "GodotPrototype"
CHAR = GAME / "assets" / "character"
SCRIPTS = GAME / "scripts"
OUT_SHEET = ROOT / "Assets" / "Generated" / "ScaleBaseline" / "character_lineup.png"


def bbox(path: Path):
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
    return im, box


def consts(script: str, names):
    text = (SCRIPTS / script).read_text(encoding="utf-8")
    out = {}
    for n in names:
        m = re.search(rf"^const {n}\s*:?=\s*([-\d.]+)", text, re.M)
        out[n] = float(m.group(1)) if m else None
    return out


def frame_row(path: Path, cell: int, pivot_x: int):
    _, b = bbox(path)
    x0, y0, x1, y1 = b
    return {"left": x0 - pivot_x, "right": x1 - pivot_x, "w": x1 - x0,
            "top": cell - y0, "floor_gap": cell - y1}


def main():
    meta = json.loads((CHAR / "Split" / "split_meta.json").read_text(encoding="utf-8"))
    cell = int(meta["cell"])
    px = int(meta["pivot"]["x"])

    art = int(meta.get("art_px", 4))
    print(f"# 플레이어 셀 {cell}² 월드 px (네이티브 {meta.get('native_cell', cell // art)}² × {art}), 피벗 ({px}, {meta['pivot']['y']})")
    pc = consts("player.gd", ["BODY_CENTER_Y"])
    print(f"# 몸 중심 높이 BODY_CENTER_Y={pc['BODY_CENTER_Y']}")

    print("\n## 자세별 외형 (피벗 기준, 오른쪽 방향)")
    print("| 프레임 | 왼쪽 | 오른쪽 | 폭 | 높이 | 바닥 틈 |")
    print("|---|---|---|---|---|---|")
    groups = [("Frames", "idle"), ("Frames", "walk"), ("Frames", "run"), ("Frames", "crouch"),
              ("Frames", "shoot"), ("Action", "roll"), ("Action", "reload")]
    for base, clip in groups:
        for p in sorted((CHAR / base / clip).glob("*.png")):
            r = frame_row(p, cell, px)
            print(f"| {clip}/{p.stem} | {r['left']:+d} | {r['right']:+d} | {r['w']} | {r['top']} | {r['floor_gap']} |")

    body = frame_row(CHAR / "Split" / "body" / "idle" / "idle_01.png", cell, px)
    head = frame_row(CHAR / "Split" / "head" / "idle" / "idle_01.png", cell, px)
    print(f"\n총 제외 몸통+머리 (idle): 왼쪽 {min(body['left'], head['left']):+d} ~ 오른쪽 "
          f"{max(body['right'], head['right']):+d}, 높이 {max(body['top'], head['top'])}")

    arm = meta["arm_gun"]
    mz = (arm["muzzle_local"][0] - arm["shoulder_local"][0], arm["muzzle_local"][1] - arm["shoulder_local"][1])
    print(f"\n## 어깨·목·총구 (피벗 기준, 총구 = 수평 조준 시, 어깨→총구 {mz})")
    print("| 프레임 | 어깨 | 목 | 총구 |")
    print("|---|---|---|---|")
    for k, v in meta["frames"].items():
        s = v["shoulder_from_pivot"]
        print(f"| {k} | {tuple(s)} | {tuple(v['neck_from_pivot'])} | ({s[0] + mz[0]}, {s[1] + mz[1]}) |")

    mv = consts("player.gd", ["WALK_SPEED", "RUN_SPEED", "ACCEL", "DECEL", "ROLL_TIME", "ROLL_DISTANCE",
                              "ROLL_EXIT_SPEED", "ROLL_SLIDE_TIME", "ROLL_SLIDE_DECEL"])
    hit = consts("acid_glob.gd", ["PLAYER_HALF_W", "PLAYER_HEIGHT"])
    wall = consts("main.gd", ["WALL_MARGIN", "DOOR_PASS_MARGIN", "ART_CELL"])
    exit_v = mv["RUN_SPEED"] * mv["ROLL_EXIT_SPEED"]
    t_stop = exit_v / mv["ROLL_SLIDE_DECEL"]          # 미끄러짐 시간 안에 멈추면 그 지점까지만
    t = min(t_stop, mv["ROLL_SLIDE_TIME"])
    slide = exit_v * t - 0.5 * mv["ROLL_SLIDE_DECEL"] * t ** 2
    print("\n## 코드 상수")
    for d in (mv, hit, wall):
        for k, v in d.items():
            print(f"- {k} = {v}")
    print(f"- (계산) 구르기 후 미끄러짐 ≈ {slide:.0f}, 구르기 총 이동 ≈ {mv['ROLL_DISTANCE'] + slide:.0f}")

    print("\n## NPC (idle_01, 셀 320 = 80 art px × 4)")
    print("| NPC | 폭 | 높이 | 바닥 틈 |")
    print("|---|---|---|---|")
    npcs = []
    for p in sorted((CHAR / "npc").glob("*/idle_01.png")):
        im, b = bbox(p)
        r = frame_row(p, im.size[1], im.size[0] // 2)
        npcs.append((p.parent.name, p))
        print(f"| {p.parent.name} | {r['w']} | {r['top'] - r['floor_gap']} | {r['floor_gap']} |")

    if "--sheet" in sys.argv:
        def lowest(folder):   # 가장 낮은 프레임 (통로 높이 판단용)
            return min(sorted(folder.glob("*.png")), key=lambda q: frame_row(q, cell, px)["top"])
        lineup = [("player idle", CHAR / "Frames" / "idle" / "idle_01.png"),
                  ("player crouch(min)", lowest(CHAR / "Frames" / "crouch")),
                  ("player roll(min)", lowest(CHAR / "Action" / "roll"))] + npcs
        make_sheet(lineup)


def make_sheet(items):
    """같은 바닥선·같은 배율(월드 1px = 이미지 1px)로 나란히 세운다. 32 월드 px 마다 가는 선, 128 마다 굵은 선."""
    crops = []
    for name, p in items:
        im, b = bbox(p)
        x0, _, x1, _ = b
        crops.append((name, im.crop((x0, 0, x1, im.size[1])), im.size[1] - b[3]))
    top_h = 440
    gap = 40
    width = sum(c.size[0] for _, c, _ in crops) + gap * (len(crops) + 1) + 60
    height = top_h + 60
    floor = top_h
    sheet = Image.new("RGBA", (width, height), (28, 30, 34, 255))
    d = ImageDraw.Draw(sheet)
    for y in range(0, top_h + 1, 32):
        c = (90, 96, 106, 255) if y % 128 == 0 else (46, 50, 56, 255)
        d.line([(0, floor - y), (width, floor - y)], fill=c)
        if y % 64 == 0:
            d.text((4, floor - y - 12), str(y), fill=(160, 166, 176, 255))
    d.line([(0, floor), (width, floor)], fill=(200, 120, 60, 255), width=2)
    x = 60
    for name, c, floor_gap in crops:
        sheet.alpha_composite(c, (x, floor - c.size[1] + floor_gap))
        d.text((x, floor + 8), name, fill=(220, 224, 230, 255))
        x += c.size[0] + gap
    OUT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_SHEET)
    print(f"\n비교 이미지: {OUT_SHEET.relative_to(ROOT)}  ({width}×{height}, 월드 1px = 이미지 1px)")


if __name__ == "__main__":
    main()
