"""GodotPrototype/assets 의 PNG 를 '진짜 픽셀아트' 격자로 굽는다 (크기는 그대로).

원본 그림은 4px 정도의 픽셀 덩어리로 그려졌지만 경계가 안티앨리어싱되어 있고 잡티가 있다.
게임은 카메라 zoom 0.25 로 534×300 뷰포트에 그리므로(×3 확대) 원본 4×4 블록이 화면의 픽셀 하나(3 화면 px)가 된다.
(2026-09-18 에 8px 블록·×6 "방식 B" 를 수식 축소로 시험했다가 롤백. B 는 네이티브로 직접 그려 반입한다 — ART_GUIDE §10)
이 스크립트는 각 블록을 **단색 하나**(불투명 픽셀 평균에 가장 가까운 실제 픽셀색)로 채우고
알파는 다수결(불투명 픽셀이 절반 이상이면 불투명)로 잘라 AA 를 없앤다.
결과 PNG 는 원본과 같은 크기라 타일셋·좌표·스크립트를 하나도 건드리지 않는다.

블록 크기는 게임 안 표시 배율에 맞춘다: 스프라이트 스케일 s, 카메라 zoom z 면 block = 1/(s·z).
  기본 4        (scale 1 × zoom 0.25)
  크롤러 10     (scale 0.4 × zoom 0.25)

격자 정렬: 원본의 픽셀 덩어리는 (0,0) 기준 격자에 맞지 않을 수 있어, 프랍·캐릭터는 블록 안 색 분산이 최소가 되는
오프셋(0..b-1)² 을 찾아 그 격자로 굽는다. 타일은 128px 이음새를 지켜야 하므로 오프셋 0 고정.

멱등: 이미 구운 파일을 다시 구워도 결과가 같다 (블록이 단색이면 그대로).
실행: python Tools/bake_pixel_grid.py [상대경로 ...]  (저장소 루트에서. 인자 없으면 assets 전체, normals 제외)
이후 노멀맵 재생성: python Tools/build_normal_maps.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "GodotPrototype" / "assets"
BLOCK_BY_PREFIX = {
    "character/ToxicTumorCrawler": 10,
}
DEFAULT_BLOCK = 4
SKIP_DIRS = {"normals"}
SKIP_PREFIXES = ("character/GiantToxicTumorCrawler/",)  # 상세 원본 기반 거대종 프레임 보존
NO_ALIGN_PREFIX = ("tiles",)          # 타일: 이음새 때문에 격자 오프셋 탐색 안 함
ALPHA_CUT = 128


def block_size_for(rel: Path) -> int:
    p = rel.as_posix()
    for prefix, b in BLOCK_BY_PREFIX.items():
        if p.startswith(prefix):
            return b
    return DEFAULT_BLOCK


def block_variance(rgba: np.ndarray, b: int, oy: int, ox: int) -> float:
    """오프셋 (oy, ox) 격자로 나눴을 때 불투명 픽셀의 블록 안 색 분산 합 (작을수록 격자가 잘 맞음)."""
    h, w, _ = rgba.shape
    sub = rgba[oy:oy + ((h - oy) // b) * b, ox:ox + ((w - ox) // b) * b]
    H, W = sub.shape[0] // b, sub.shape[1] // b
    blocks = sub.reshape(H, b, W, b, 4).transpose(0, 2, 1, 3, 4).reshape(H, W, b * b, 4).astype(np.float32)
    op = blocks[..., 3] >= ALPHA_CUT
    n = np.maximum(op.sum(-1), 1)[..., None]
    mean = (blocks[..., :3] * op[..., None]).sum(2) / n
    var = (((blocks[..., :3] - mean[:, :, None, :]) ** 2).sum(-1) * op).sum()
    return float(var)


def best_offset(rgba: np.ndarray, b: int) -> tuple[int, int]:
    best = (0, 0)
    best_v = None
    for oy in range(b):
        for ox in range(b):
            v = block_variance(rgba, b, oy, ox)
            if best_v is None or v < best_v:
                best, best_v = (oy, ox), v
    return best


def bake(img: Image.Image, b: int, align: bool = True) -> Image.Image:
    rgba = np.asarray(img.convert("RGBA")).astype(np.int32)
    h, w, _ = rgba.shape
    oy, ox = best_offset(rgba, b) if align else (0, 0)
    # 격자 오프셋: 앞쪽에 (b-o) 만큼 투명 여백을 붙여 블록 경계를 맞추고, 끝에는 부분 블록을 edge 복제로 채운다
    fy, fx = (b - oy) % b, (b - ox) % b
    ph, pw = (-(h + fy)) % b, (-(w + fx)) % b
    pad = np.pad(rgba, ((fy, ph), (fx, pw), (0, 0)), mode="edge")
    if fy or ph:
        pad[:fy, :, 3] = 0
        pad[fy + h:, :, 3] = 0
    if fx or pw:
        pad[:, :fx, 3] = 0
        pad[:, fx + w:, 3] = 0
    H, W = pad.shape[0] // b, pad.shape[1] // b
    blocks = pad.reshape(H, b, W, b, 4).transpose(0, 2, 1, 3, 4).reshape(H, W, b * b, 4)
    rgb = blocks[..., :3].astype(np.float32)
    opaque = blocks[..., 3] >= ALPHA_CUT                      # (H, W, n)
    n_op = opaque.sum(-1)                                     # (H, W)
    # 유효 픽셀 수: 이미지 안쪽 픽셀 수 (가장자리 블록은 적다)
    inside = np.ones_like(opaque)
    if fy or fx or ph or pw:
        mask = np.zeros(pad.shape[:2], dtype=bool)
        mask[fy:fy + h, fx:fx + w] = True
        inside = mask.reshape(H, b, W, b).transpose(0, 2, 1, 3).reshape(H, W, b * b)
    n_in = inside.sum(-1)
    keep = n_op * 2 >= n_in                                   # 절반 이상 불투명 → 불투명

    wts = opaque.astype(np.float32)
    mean = (rgb * wts[..., None]).sum(2) / np.maximum(n_op, 1)[..., None]   # (H, W, 3)
    dist = ((rgb - mean[:, :, None, :]) ** 2).sum(-1)         # (H, W, n)
    dist = np.where(opaque, dist, np.inf)
    pick = dist.argmin(-1)                                    # 평균에 가장 가까운 실제 픽셀
    chosen = np.take_along_axis(blocks[..., :3], pick[..., None, None], axis=2)[:, :, 0, :]

    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[..., :3] = np.where(keep[..., None], chosen, 0)
    out[..., 3] = np.where(keep, 255, 0)
    big = out.repeat(b, axis=0).repeat(b, axis=1)[fy:fy + h, fx:fx + w]
    return Image.fromarray(big, "RGBA")


def main() -> None:
    args = [Path(a) for a in sys.argv[1:]]
    if args:
        files = []
        for a in args:
            p = ROOT / a
            files += sorted(p.rglob("*.png")) if p.is_dir() else [p]
    else:
        files = [f for f in sorted(ROOT.rglob("*.png")) if not (set(f.relative_to(ROOT).parts) & SKIP_DIRS)]
    files = [f for f in files if not f.relative_to(ROOT).as_posix().startswith(SKIP_PREFIXES)]
    for f in files:
        rel = f.relative_to(ROOT)
        b = block_size_for(rel)
        align = not rel.as_posix().startswith(NO_ALIGN_PREFIX)
        img = Image.open(f)
        baked = bake(img, b, align)
        baked.save(f, optimize=True)
        print(f"baked block={b:>2} align={int(align)} {rel.as_posix()} {img.size[0]}x{img.size[1]}")
    print(f"{len(files)} files")


if __name__ == "__main__":
    main()
