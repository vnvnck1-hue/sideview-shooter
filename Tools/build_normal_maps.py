"""GameReady 타일·프랍·문 PNG 에서 2D 라이팅용 노멀맵을 자동 생성한다.

높이 = 밝기(블러) + 알파 실루엣 베벨(프랍·문). Sobel 기울기 → 노멀.

**손으로 면을 나눈 자산은 건너뛴다.** GodotPrototype/assets/faces/<같은 상대경로>.png 가 있으면
그 자산의 노멀은 tools/bake_face_normals.gd 가 면 맵에서 굽는다 — 여기서 덮어쓰면 그 작업이 날아간다.
(면을 나누는 곳: 로비 → "면 라이팅 랩". 규약: GodotPrototype/scripts/face_normal.gd)
Godot 는 OpenGL(Y+ 위) 규약이므로 화면 위쪽을 향한 면이 G>0.5 가 된다.

실행: python Tools/build_normal_maps.py [그룹 ...]  (저장소 루트에서. 그룹을 주면 그 그룹만)
출력: GodotPrototype/assets/normals/<종류>/<이름>.png  (원본과 같은 크기)
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "GodotPrototype" / "assets"
GROUPS = {
    # 종류: (강도, 베벨 폭 px, 밝기 블러)  — 하위 폴더까지 재귀 탐색 (character/Split/body/<clip>/*.png)
    "tiles": (2.4, 0, 1.0),
    "props": (3.2, 6, 0.8),
    "connectors": (3.0, 5, 0.8),
    # 방식 B 전력 릴레이실 — 기존 지하 시설물의 노멀 반응을 유지하되,
    # 게임 런타임이 참조하는 전용 폴더 구조를 그대로 보존한다.
    "power_relay_room/Props": (3.2, 6, 0.8),
    "power_relay_room/Destruction": (3.2, 5, 0.7),
    "power_relay_room/Lighting": (2.6, 4, 0.7),
    "power_relay_room/Tiles/Background": (2.4, 0, 1.0),
    "power_relay_room/Tiles/Frame": (2.4, 0, 1.0),
    "character/Split": (2.8, 4, 0.6),     # 게임이 쓰는 분리 프레임(몸통·팔)만
    "character/ToxicTumorCrawler": (2.6, 5, 0.7),   # 몬스터: 종양 덩어리가 둥글게 굴러 보이도록 베벨을 조금 넓게
    "character/GiantToxicTumorCrawler": (2.6, 10, 1.4),  # 2배 상세 프레임의 대응 노멀
    "character/npc": (2.8, 4, 0.6),       # NPC 한 장짜리 idle — 플레이어 Split 과 같은 반응
    # 사족보행 기체(버그봇)의 원화 파츠. 금속 각파이프·실린더라 프랍과 같은 세기를 쓰되,
    # 조각이 가늘고 길어(포신 181×112, 로드 230×38) 베벨을 좁게 잡는다 — 넓으면 조각 전체가
    # 한 덩어리 원통으로 뭉개져 표면의 볼트·패널 선이 사라진다.
    "quadruped": (3.0, 4, 0.7),
}
EXCLUDE = {"muzzle_flash.png"}            # 발광 스프라이트는 노멀 불필요
FACES = ROOT / "faces"                    # 손으로 나눈 면 맵 — 있으면 이 스크립트는 그 자산을 건드리지 않는다


def height_map(img: Image.Image, bevel: int, blur: float) -> np.ndarray:
    rgba = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    lum = rgba[..., 0] * 0.299 + rgba[..., 1] * 0.587 + rgba[..., 2] * 0.114
    alpha = rgba[..., 3]
    if blur > 0:
        lum = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(blur))).astype(np.float32) / 255.0
    h = lum * alpha
    if bevel > 0:
        # 실루엣 안쪽으로 들어갈수록 높아지는 둥근 베벨 (알파 침식 누적)
        mask = (alpha > 0.5).astype(np.float32)
        acc = np.zeros_like(mask)
        cur = mask.copy()
        for _ in range(bevel):
            er = cur.copy()
            er[1:, :] *= cur[:-1, :]
            er[:-1, :] *= cur[1:, :]
            er[:, 1:] *= cur[:, :-1]
            er[:, :-1] *= cur[:, 1:]
            acc += er
            cur = er
        bev = acc / bevel
        bev = np.sqrt(np.clip(bev, 0, 1))          # 둥글게
        h = 0.55 * h + 0.45 * bev * mask
    return h, alpha


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
    p = np.pad(h, 1, mode="edge")
    # Sobel
    dx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    dy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    dx *= strength / 8.0
    dy *= strength / 8.0
    nx = -dx
    ny = dy          # 이미지 y-아래 → OpenGL y-위 변환
    nz = np.ones_like(h)
    n = np.stack([nx, ny, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def main() -> None:
    import sys
    only = set(sys.argv[1:])          # 인자로 그룹 이름을 주면 그 그룹만 (예: character/ToxicTumorCrawler)
    for group, (strength, bevel, blur) in GROUPS.items():
        if only and group not in only:
            continue
        src_dir = ROOT / group
        out_dir = ROOT / "normals" / group
        out_dir.mkdir(parents=True, exist_ok=True)
        for png in sorted(src_dir.rglob("*.png")):
            if png.name in EXCLUDE:
                continue
            rel = png.relative_to(src_dir)
            if (FACES / group / rel).exists():
                print(f"{group}/{rel} — 면 맵 있음, 건너뜀 (tools/bake_face_normals.gd 가 굽는다)")
                continue
            img = Image.open(png)
            h, alpha = height_map(img, bevel, blur)
            n = normal_from_height(h, strength)
            rgb = ((n * 0.5 + 0.5) * 255.0).round().clip(0, 255).astype(np.uint8)
            a = (np.clip(alpha, 0, 1) * 255).round().astype(np.uint8)
            # 투명 픽셀은 평평한 노멀 (0.5,0.5,1)
            flat = a < 8
            rgb[flat] = (128, 128, 255)
            out = np.dstack([rgb, np.full_like(a, 255)])
            dst = out_dir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(out, "RGBA").save(dst)
            print(f"{group}/{rel} -> {dst.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()
