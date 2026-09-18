"""네이티브 4px 규격 자산(1 이미지 px = 1 아트 px)을 게임 자산으로 반입한다.

Assets/GameReady/Native4/<상대경로>.png  →  ×4 Nearest 확대  →  GodotPrototype/assets/<상대경로>.png

ART_GUIDE §10 "네이티브 픽셀 규격 — 4px 블록". 게임은 월드 4px = 아트 1px 이므로 Nearest 로 정확히 4배 키우면
bake_pixel_grid.py 를 거친 자산과 같은 격자(오프셋 0, 단색 4×4 블록)가 된다. 베이크는 필요 없다.

검사(실패하면 그 파일은 건너뛰고 마지막에 목록으로 알린다):
  - 알파는 0 또는 255 만 (반투명·AA 금지)
  - 확대 후 월드 크기가 원래 게임 자산 규격(타일 128 배수 등)과 맞는지는 이 스크립트가 알 수 없으니 §10 크기표를 따른다.

실행: python Tools/upscale_native4.py [상대경로 ...]   (저장소 루트에서. 인자 없으면 Native4 전체)
이후 노멀맵: python Tools/build_normal_maps.py   (확대된 게임 자산에서 만든다. 그룹 이름은 build_normal_maps.GROUPS 참고)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "Assets" / "GameReady" / "Native4"
DST = REPO / "GodotPrototype" / "assets"
SCALE = 4


def upscale(rel: Path) -> str | None:
    src = SRC / rel
    img = Image.open(src).convert("RGBA")
    alpha = np.asarray(img)[..., 3]
    bad = np.count_nonzero((alpha != 0) & (alpha != 255))
    if bad:
        return f"{rel.as_posix()}: 반투명 알파 픽셀 {bad}개 — 0/255 로 정리해야 한다"
    out = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    dst = DST / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, optimize=True)
    print(f"{rel.as_posix()}  {img.width}x{img.height} -> {out.width}x{out.height}")
    return None


def main(argv: list[str]) -> int:
    if not SRC.exists():
        print(f"원본 폴더가 없다: {SRC}")
        return 1
    if argv:
        files = [Path(a) for a in argv]
    else:
        files = sorted(p.relative_to(SRC) for p in SRC.rglob("*.png"))
    if not files:
        print("반입할 PNG 가 없다.")
        return 0
    problems = [msg for rel in files if (msg := upscale(rel))]
    if problems:
        print("\n건너뛴 파일:")
        for m in problems:
            print("  " + m)
        return 2
    print(f"\n{len(files)}장 반입 완료. 다음: python Tools/build_normal_maps.py")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
