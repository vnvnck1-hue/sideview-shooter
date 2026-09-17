"""ToxicTumorCrawler(독성 종양 크롤러) 애니메이션 프레임을 Godot 프로토타입용으로 정리한다.

원본 GameReady 프레임(543×756 셀, Bottom Center 피벗)은 클립마다 발 밑 줄(baseline)이 다르다
(walk 549, attack 519, death ≈582, jump 609~625). 그대로 셀 하단(756)을 발 밑으로 쓰면 클립을 바꿀 때
몬스터가 위아래로 튄다. 이 스크립트가 프레임을 복사하고 프레임마다 실제 발 밑 줄·내용 영역을 재서
crawler_meta.json 에 적는다. 게임(scripts/crawler.gd)은 그 값으로 스프라이트 오프셋과 히트 박스를 잡는다.

실행: python Tools/build_crawler_frames.py   (저장소 루트에서)
출력: GodotPrototype/assets/character/ToxicTumorCrawler/<clip>/<clip>_NN.png + crawler_meta.json
그 뒤 python Tools/build_normal_maps.py 로 노멀맵을 만든다.
"""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Assets" / "GameReady" / "Characters" / "ToxicTumorCrawler"
DST = ROOT / "GodotPrototype" / "assets" / "character" / "ToxicTumorCrawler"
CLIPS = ["walk", "jump", "death", "attack"]
ALPHA_MIN = 8        # 이보다 옅은 픽셀은 잡음으로 본다
ROW_MIN = 6          # 한 줄에 이만큼 이상 불투명 픽셀이 있어야 '내용'


def measure(png: Path) -> dict:
    a = np.asarray(Image.open(png).convert("RGBA"))[..., 3] > ALPHA_MIN
    rows = a.sum(1)
    cols = a.sum(0)
    ys = [i for i in range(len(rows)) if rows[i] >= ROW_MIN]
    xs = [i for i in range(len(cols)) if cols[i] >= ROW_MIN]
    return {
        "feet_y": int(ys[-1]) + 1,                        # 발 밑 줄 (셀 상단 기준, 배타)
        "bbox": [int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1],   # x0, y0, x1, y1
    }


def main() -> None:
    meta = json.loads((SRC / "toxic_tumor_crawler_animation_v1.json").read_text(encoding="utf-8"))
    cell = meta["layout"]
    out = {"cell": [cell["cellWidth"], cell["cellHeight"]], "clips": {}, "frames": {}}
    for clip in meta["clips"]:
        out["clips"][clip["name"]] = {"fps": clip["suggestedFps"], "loop": clip["loop"], "frames": clip["frames"]}
    for fr in meta["frames"]:
        clip = fr["clip"]
        key = f"{clip}_{fr['frame']:02d}"
        src = SRC / fr["file"]
        dst = DST / clip / f"{key}.png"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        out["frames"][key] = measure(src)
        print(f"{key}: feet_y={out['frames'][key]['feet_y']} bbox={out['frames'][key]['bbox']}")
    (DST / "crawler_meta.json").write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print("->", DST / "crawler_meta.json")


if __name__ == "__main__":
    main()
