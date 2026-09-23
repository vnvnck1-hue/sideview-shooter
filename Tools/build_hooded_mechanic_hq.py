"""
붉은 후드 정비공 — 고화질 원화(v1, 2026-09-23) 한 장에서 플레이어 리소스 전체를 다시 만든다.

입력 : Assets/Generated/PlayerConcepts/hooded_mechanic_hq_source_v1.webp
        1254² · 약 9.8px 격자로 업스케일된 128² 네이티브 픽셀아트 (조준 자세 한 장)
처리 : 1) 128² 네이티브 격자로 복원 (블록 중앙부 중앙값 · 알파 다수결)
       2) 파츠 분리 — 머리(후드+마스크) / 팔+총 / 몸통(배낭·재킷·골반) / 앞다리·뒷다리(허벅지·정강이·부츠)
       3) 파츠 리그로 포즈를 만든다. 다리는 2관절 IK, 회전은 EPX 8× 확대 후 최근접 샘플(RotSprite 약식)이라
          원화 색만 쓰고 안티앨리어싱이 생기지 않는다. 회전 0 인 파츠는 원화 픽셀 그대로 붙인다.
       4) 네이티브 → 월드 ×4 최근접 확대 (ART_GUIDE §10: 1 art px = 월드 4px, 런타임 축소 금지)
출력 : GodotPrototype/assets/character/
          Split/body/<clip>/<clip>_NN.png   몸통(머리·팔 제외)  idle·aim·walk·run·crouch
          Split/head/<clip>/<clip>_NN.png   머리 (셀 크기 그대로, neck 이 회전축)
          Split/arm_gun.png                 팔+총 (어깨가 회전축, 오른쪽 수평 조준)
          Split/muzzle_flash.png            총구 화염 (기존 이펙트 유지)
          Split/split_meta.json             셀·어깨·목·총구·배출구 좌표
          Action/roll|reload/*_NN.png       전신 액션 6프레임
          Frames/<clip>/*_NN.png            전신 합성 (idle·walk·run·shoot·crouch, 검수·참조용)
       Assets/GameReady/Characters/HoodedMechanic/HQ/   네이티브 파츠·시트·검수 이미지
실행 : python Tools/build_hooded_mechanic_hq.py [--native-scale 1.0]
        --native-scale 는 네이티브 격자 자체를 다시 뽑는 배율(1.0 = 원화 그대로 93px 키).
        월드 배율 ×4 는 고정 — 키를 줄이고 싶으면 이 값을 낮춰 **네이티브에서** 줄인다.
이후 : python Tools/build_normal_maps.py character/Split
"""
import argparse
import json
import math
import os
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Assets/Generated/PlayerConcepts/hooded_mechanic_hq_source_v1.webp"
GODOT = ROOT / "GodotPrototype/assets/character"
REVIEW = ROOT / "Assets/GameReady/Characters/HoodedMechanic/HQ"
NATIVE = 128            # 원화 네이티브 격자
ART = 4                 # 월드 px / art px
CELL_N = 128            # 네이티브 셀 (월드 512)
PIVOT_N = (CELL_N // 2, CELL_N)   # 바닥 중심

# ---------------------------------------------------------------- 1) 네이티브 복원

def to_native(path: Path) -> np.ndarray:
    a = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
    p = a.shape[0] / NATIVE
    out = np.zeros((NATIVE, NATIVE, 4), np.uint8)
    for j in range(NATIVE):
        y0, y1 = int(round(j * p + p * 0.25)), int(round(j * p + p * 0.75))
        for i in range(NATIVE):
            x0, x1 = int(round(i * p + p * 0.25)), int(round(i * p + p * 0.75))
            b = a[y0:y1, x0:x1].reshape(-1, 4)
            op = b[:, 3] > 128
            if op.sum() * 2 >= len(b):
                out[j, i, :3] = np.median(b[op, :3], axis=0)
                out[j, i, 3] = 255
    # 고립 픽셀 제거
    al = out[..., 3] > 0
    nb = sum(np.roll(np.roll(al, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)) - al
    out[al & (nb == 0)] = 0
    return out


# ---------------------------------------------------------------- 2) 파츠 분리 (원화 네이티브 좌표)
# 좌표는 원화 128² 격자 기준. 아래 값은 native_grid 검수 이미지로 잡았다.
HEAD_NECK = (63, 59)        # 머리 회전축 (마스크 턱 아래 목)
SHOULDER = (62, 70)         # 팔 회전축 (어깨 패드 앞쪽)
MUZZLE = (99, 69)           # 총구 끝
EJECT = (80, 64)            # 탄피 배출구 (총 윗면)
HIP_BACK = (53, 88)         # 뒷다리 고관절
HIP_FRONT = (68, 88)        # 앞다리 고관절
KNEE_BACK = (49, 99)
KNEE_FRONT = (73, 100)
ANKLE_BACK = (47, 108)
ANKLE_FRONT = (72, 109)
LEG_TOP = 85                # 다리 조각이 시작하는 줄 (몸통 골반 밑으로 숨는 겹침 포함)
TORSO_BOTTOM = 89           # 몸통이 끝나는 줄 (이 아래는 다리)
LEG_SPLIT_X = 61            # 뒷다리 | 앞다리 경계


def masks(img: np.ndarray) -> dict:
    h, w = img.shape[:2]
    Y, X = np.mgrid[0:h, 0:w]
    op = img[..., 3] > 0
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    red = (r > g + 40) & (r > b + 30)

    head = op & (Y < 60) & ~((X < 47) & (Y >= 54))
    head |= op & (Y >= 60) & (Y <= 61) & (X >= 70) & (X <= 80) & red

    arm = op & (X >= 65) & (Y >= 63) & (Y <= 81) & ~((X <= 70) & (Y >= 75)) & ~head
    arm &= ~((X <= 69) & (Y <= 65))          # 목 아래 스카프 매듭은 몸통

    legs = op & (Y >= LEG_TOP) & ~(red & (Y < TORSO_BOTTOM))   # 스카프 끝자락은 몸통
    leg_back = legs & (X <= LEG_SPLIT_X - 1)
    leg_front = legs & (X >= LEG_SPLIT_X)
    torso = op & ~head & ~arm & (Y < TORSO_BOTTOM)
    return {"head": head, "arm": arm, "torso": torso, "leg_back": leg_back, "leg_front": leg_front}


def cut(img, m):
    out = np.zeros_like(img)
    out[m] = img[m]
    return out


def split_leg(leg: np.ndarray, knee_y: int, ankle_y: int):
    """다리 → 허벅지 / 정강이 / 부츠. 관절 부근은 1~2줄 겹쳐 회전 시 틈이 안 생기게 한다."""
    h = leg.shape[0]
    Y = np.mgrid[0:h, 0:leg.shape[1]][0]
    al = leg[..., 3] > 0
    thigh = cut(leg, al & (Y <= knee_y + 1))
    shin = cut(leg, al & (Y >= knee_y - 1) & (Y <= ankle_y + 1))
    boot = cut(leg, al & (Y >= ankle_y - 1))
    return thigh, shin, boot


def inpaint_arm_hole(torso: np.ndarray, arm_m: np.ndarray) -> np.ndarray:
    """팔을 떼어낸 자리 중 몸통 실루엣 안쪽(x ≤ 어깨+8)을 같은 줄 왼쪽 재킷 색으로 메우고 외곽선을 다시 긋는다."""
    t = torso.copy()
    h, w = arm_m.shape
    outline = np.array([22, 14, 20, 255], np.uint8)
    for y in range(h):
        xs = [x for x in range(w) if arm_m[y, x] and x <= SHOULDER[0] + 7]
        if not xs:
            continue
        src = None
        for x in range(min(xs) - 1, min(xs) - 8, -1):
            if t[y, x, 3] > 0 and int(t[y, x, :3].max()) > 50:
                src = t[y, x].copy()
                break
        if src is None:
            continue
        for x in xs:
            t[y, x] = src
        t[y, max(xs) + 1 if max(xs) + 1 < w else max(xs)] = outline
    return t


# ---------------------------------------------------------------- 3) 회전 (EPX 8× → 최근접)

def epx(a: np.ndarray) -> np.ndarray:
    h, w = a.shape[:2]
    P = a
    pad = np.pad(P, ((1, 1), (1, 1), (0, 0)), mode="edge")
    A = pad[:-2, 1:-1]; B = pad[1:-1, 2:]; C = pad[1:-1, :-2]; D = pad[2:, 1:-1]
    eq = lambda u, v: np.all(u == v, axis=-1)
    o1 = np.where((eq(C, A) & ~eq(C, D) & ~eq(A, B))[..., None], A, P)
    o2 = np.where((eq(A, B) & ~eq(A, C) & ~eq(B, D))[..., None], B, P)
    o3 = np.where((eq(D, C) & ~eq(D, B) & ~eq(C, A))[..., None], C, P)
    o4 = np.where((eq(B, D) & ~eq(B, A) & ~eq(D, C))[..., None], D, P)
    out = np.zeros((h * 2, w * 2, a.shape[2]), a.dtype)
    out[0::2, 0::2] = o1; out[0::2, 1::2] = o2; out[1::2, 0::2] = o3; out[1::2, 1::2] = o4
    return out


_EPX_CACHE = {}


def epx8(part: np.ndarray) -> np.ndarray:
    key = part.tobytes().__hash__()
    if key not in _EPX_CACHE:
        _EPX_CACHE[key] = epx(epx(epx(part)))
    return _EPX_CACHE[key]


def place(canvas: np.ndarray, part: np.ndarray, pivot, angle: float, dest, flip_x=False) -> None:
    """part(원화 좌표계, 전체 128² 크기)의 pivot 을 dest 로 옮기며 angle(rad, 화면 시계방향 +) 회전해 canvas 에 그린다."""
    H, W = canvas.shape[:2]
    if abs(angle) < 1e-4 and not flip_x:
        dx, dy = int(round(dest[0] - pivot[0])), int(round(dest[1] - pivot[1]))
        al = part[..., 3] > 0
        ys, xs = np.nonzero(al)
        ty, tx = ys + dy, xs + dx
        ok = (ty >= 0) & (ty < H) & (tx >= 0) & (tx < W)
        canvas[ty[ok], tx[ok]] = part[ys[ok], xs[ok]]
        return
    big = epx8(part)
    s = 8
    ca, sa = math.cos(angle), math.sin(angle)
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    u = X + 0.5 - dest[0]
    v = Y + 0.5 - dest[1]
    if flip_x:
        u = -u
    # 역회전
    sx = (ca * u + sa * v) + pivot[0]
    sy = (-sa * u + ca * v) + pivot[1]
    bx = np.floor(sx * s).astype(int)
    by = np.floor(sy * s).astype(int)
    ok = (bx >= 0) & (by >= 0) & (bx < big.shape[1]) & (by < big.shape[0])
    samp = np.zeros((H, W, 4), np.uint8)
    samp[ok] = big[by[ok], bx[ok]]
    m = samp[..., 3] > 0
    canvas[m] = samp[m]


# ---------------------------------------------------------------- 리그
OUTLINE = np.array([24, 14, 22, 255], np.uint8)


def dilate(m: np.ndarray) -> np.ndarray:
    o = m.copy()
    o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]
    return o


def despeckle(lay: np.ndarray, passes: int = 2) -> None:
    """회전으로 생긴 가시·외톨이 픽셀 제거 (4-이웃 불투명이 1개 이하)."""
    for _ in range(passes):
        m = lay[..., 3] > 0
        n = np.zeros(m.shape, int)
        n[1:] += m[:-1]; n[:-1] += m[1:]; n[:, 1:] += m[:, :-1]; n[:, :-1] += m[:, 1:]
        lay[m & (n <= 1)] = 0


def ang(a, b):
    return math.atan2(b[1] - a[1], b[0] - a[0])


def ik(hip, ankle, l1, l2, bend=1.0):
    """2관절 IK. bend=+1 이면 무릎이 앞(+x)으로 나온다."""
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = max(1e-3, min(math.hypot(dx, dy), l1 + l2 - 1e-3))
    base = math.atan2(dy, dx)
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    c = max(-1.0, min(1.0, c))
    a = math.acos(c)
    th = base - a * bend       # 화면 좌표(y 아래)에서 앞으로 굽히려면 base 에서 반시계(-)
    knee = (hip[0] + l1 * math.cos(th), hip[1] + l1 * math.sin(th))
    return knee


class Rig:
    def __init__(self, img):
        self.img = img
        m = masks(img)
        self.m = m
        self.head = cut(img, m["head"])
        self.arm = cut(img, m["arm"])
        torso = cut(img, m["torso"])
        self.torso = inpaint_arm_hole(torso, m["arm"])
        # 몸통 쪽에 목 아래 겹침(머리가 돌아도 빈틈이 안 보이게): 후드 아래 3줄을 몸통에도 남긴다
        Y = np.mgrid[0:NATIVE, 0:NATIVE][0]
        under = m["head"] & (Y >= 55)
        self.torso[under] = img[under]
        self.legs = {}
        for side, hip, knee, ankle in (("back", HIP_BACK, KNEE_BACK, ANKLE_BACK),
                                       ("front", HIP_FRONT, KNEE_FRONT, ANKLE_FRONT)):
            leg = cut(img, m["leg_" + side])
            th, sh, bo = split_leg(leg, knee[1], ankle[1])
            self.legs[side] = {
                "hip": hip, "knee": knee, "ankle": ankle,
                "thigh": th, "shin": sh, "boot": bo,
                "l1": math.dist(hip, knee), "l2": math.dist(knee, ankle),
                "a1": ang(hip, knee), "a2": ang(knee, ankle),
            }

    # 원화(조준 자세) 기준 → 셀 좌표 변환: 발바닥이 셀 바닥, 두 발 중심이 셀 중심
    @staticmethod
    def cell_offset():
        return (PIVOT_N[0] - 61, (CELL_N - 1) - 116)

    def pose(self, hip_dy=0.0, hip_dx=0.0, lean=0.0, feet=None, bend=(1.0, 1.0), boot_rot=(0.0, 0.0),
             with_head=False, with_arm=False, arm_angle=0.0, head_angle=0.0, rest_legs=False):
        """한 프레임 합성. feet: {"back": (x,y), "front": (x,y)} 원화 좌표계 발목 목표. 반환: (canvas, anchors)"""
        ox, oy = self.cell_offset()
        cv = np.zeros((CELL_N, CELL_N, 4), np.uint8)
        # 골반(몸통) 변환: 허리 중심 기준 회전 + 이동
        waist = ((HIP_BACK[0] + HIP_FRONT[0]) / 2, TORSO_BOTTOM - 2)
        wdst = (waist[0] + ox + hip_dx, waist[1] + oy + hip_dy)

        def tf(p):   # 원화 몸통 좌표 → 셀 좌표
            dx, dy = p[0] - waist[0], p[1] - waist[1]
            c, s = math.cos(lean), math.sin(lean)
            return (wdst[0] + c * dx - s * dy, wdst[1] + s * dx + c * dy)

        layers = {}
        for side, b, br in zip(("back", "front"), bend, boot_rot):
            L = self.legs[side]
            lay = np.zeros_like(cv)
            layers[side] = lay
            hip = tf(L["hip"])
            if rest_legs or feet is None or feet.get(side) is None:
                ankle = (L["ankle"][0] + ox, L["ankle"][1] + oy)
            else:
                f = feet[side]
                ankle = (f[0] + ox, f[1] + oy)
            if rest_legs and abs(hip_dy) < 1e-3 and abs(lean) < 1e-4 and abs(hip_dx) < 1e-3:
                for k in ("thigh", "shin", "boot"):
                    place(lay, L[k], (0, 0), 0.0, (ox, oy))
                continue
            knee = ik(hip, ankle, L["l1"], L["l2"], b)
            reach = (knee[0] + L["l2"] * math.cos(ang(knee, ankle)), knee[1] + L["l2"] * math.sin(ang(knee, ankle)))
            a1 = ang(hip, knee) - L["a1"]
            a2 = ang(knee, ankle) - L["a2"]
            place(lay, L["thigh"], L["hip"], a1, hip)
            place(lay, L["shin"], L["knee"], a2, knee)
            place(lay, L["boot"], L["ankle"], br, reach)
            despeckle(lay)
        # 뒷다리 → 앞다리. 앞다리가 뒷다리 위에 겹치는 곳에만 1px 외곽선 (겹치지 않는 원화 자세는 그대로)
        back, front = layers["back"], layers["front"]
        m = back[..., 3] > 0
        cv[m] = back[m]
        fm = front[..., 3] > 0
        ring = dilate(fm) & ~fm & m
        cv[ring] = OUTLINE
        cv[fm] = front[fm]
        place(cv, self.torso, waist, lean, wdst)
        neck = tf(HEAD_NECK)
        shoulder = tf(SHOULDER)
        if with_head:
            place(cv, self.head, HEAD_NECK, lean + head_angle, neck)
        if with_arm:
            place(cv, self.arm, SHOULDER, arm_angle, shoulder)
        return cv, {"neck": neck, "shoulder": shoulder}


def up4(a: np.ndarray) -> Image.Image:
    return Image.fromarray(a).resize((a.shape[1] * ART, a.shape[0] * ART), Image.NEAREST)


# ---------------------------------------------------------------- 4) 포즈 표
# 발목 목표는 원화 좌표계. 원화 발목: 뒷발 (47,108) · 앞발 (72,109). 합성 뒤 발바닥을 셀 바닥에 붙인다.
GB, GF = ANKLE_BACK[1], ANKLE_FRONT[1]
WALK = [
    dict(hip_dy=1, feet={"back": (47, GB), "front": (74, GF)}, boot_rot=(0.18, -0.12)),
    dict(hip_dy=-1, feet={"back": (58, GB - 5), "front": (64, GF)}, boot_rot=(0.30, 0.0)),
    dict(hip_dy=1, feet={"back": (72, GB), "front": (49, GF)}, boot_rot=(-0.12, 0.18)),
    dict(hip_dy=-1, feet={"back": (61, GB), "front": (56, GF - 5)}, boot_rot=(0.0, 0.30)),
]
RUN_LEAN = 0.09
RUN = [
    dict(hip_dy=2, hip_dx=2, lean=RUN_LEAN, feet={"back": (41, GB - 4), "front": (80, GF)}, boot_rot=(0.55, -0.20)),
    dict(hip_dy=-1, hip_dx=2, lean=RUN_LEAN, feet={"back": (61, GB - 11), "front": (64, GF)}, boot_rot=(0.35, 0.0)),
    dict(hip_dy=2, hip_dx=2, lean=RUN_LEAN, feet={"back": (78, GB), "front": (43, GF - 4)}, boot_rot=(-0.20, 0.55)),
    dict(hip_dy=-1, hip_dx=2, lean=RUN_LEAN, feet={"back": (60, GB), "front": (63, GF - 11)}, boot_rot=(0.0, 0.35)),
]
CROUCH = [dict(hip_dy=d, lean=l, feet={"back": (46, GB), "front": (73, GF)}) for d, l in
          ((2, 0.02), (6, 0.05), (10, 0.08), (12, 0.10))]
REST = dict(rest_legs=True)
PLANTED = dict(feet={"back": ANKLE_BACK, "front": ANKLE_FRONT})


def ground_align(cv: np.ndarray) -> int:
    rows = np.nonzero(cv[..., 3].any(1))[0]
    return (CELL_N - 1) - int(rows.max())


def shift(cv, dy):
    out = np.zeros_like(cv)
    if dy > 0:
        out[dy:] = cv[:CELL_N - dy]
    elif dy < 0:
        out[:dy] = cv[-dy:]
    else:
        out[:] = cv
    return out


def world_anchor(p, dy):
    return [int(round(p[0] * ART)), int(round((p[1] + dy) * ART))]


def body_frame(rig, spec):
    """몸통 셀 + 머리 셀 + 앵커(월드 px, 셀 좌표). 발이 셀 바닥에 닿도록 정렬."""
    body, anc = rig.pose(**spec)
    dy = ground_align(body)
    body = shift(body, dy)
    head = np.zeros_like(body)
    place(head, rig.head, HEAD_NECK, spec.get("lean", 0.0), (anc["neck"][0], anc["neck"][1] + dy))
    return body, head, {"neck": world_anchor(anc["neck"], dy), "shoulder": world_anchor(anc["shoulder"], dy)}


def full_frame(rig, spec, arm_angle=0.0, head_angle=0.0, arm_back=0.0):
    """전신 합성 (몸통 + 머리 + 팔). 바닥 정렬 전."""
    body, anc = rig.pose(**spec)
    lean = spec.get("lean", 0.0)
    place(body, rig.head, HEAD_NECK, lean + head_angle, anc["neck"])
    sh = anc["shoulder"]
    sh = (sh[0] - arm_back * math.cos(arm_angle), sh[1] - arm_back * math.sin(arm_angle))
    place(body, rig.arm, SHOULDER, arm_angle, sh)
    return body, {"neck": anc["neck"], "shoulder": sh}


def grounded(cv):
    return shift(cv, ground_align(cv))


def spin(cv: np.ndarray, angle: float) -> np.ndarray:
    """전신 합성을 실루엣 중심 기준으로 회전하고 바닥에 붙인다 (구르기)."""
    ys, xs = np.nonzero(cv[..., 3])
    c = (float(xs.mean()), float(ys.mean()))
    out = np.zeros_like(cv)
    place(out, cv, c, angle, (PIVOT_N[0] + 2, CELL_N * 0.72))
    return grounded(out)


def save(a: np.ndarray, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    up4(a).save(path)


def build(native_scale: float):
    if abs(native_scale - 1.0) > 1e-3:
        raise SystemExit("--native-scale ≠ 1 은 아직 지원하지 않는다 (원화 좌표표를 그 배율로 다시 잡아야 함)")
    img = to_native(SRC)
    rig = Rig(img)
    split = GODOT / "Split"
    action = GODOT / "Action"
    frames_dir = GODOT / "Frames"
    flash_keep = (split / "muzzle_flash.png").read_bytes()     # 총구 화염은 기존 이펙트를 그대로 쓴다
    for d in (split / "body", split / "head", action, frames_dir):
        if d.exists():
            shutil.rmtree(d)
    REVIEW.mkdir(parents=True, exist_ok=True)

    meta = {"cell": CELL_N * ART, "art_px": ART, "native_cell": CELL_N,
            "pivot": {"x": PIVOT_N[0] * ART, "y": PIVOT_N[1] * ART},
            "source": "Assets/Generated/PlayerConcepts/hooded_mechanic_hq_source_v1.webp", "frames": {}}
    px, py = meta["pivot"]["x"], meta["pivot"]["y"]
    review_rows = []

    clips = {"idle": [REST], "aim": [REST], "walk": WALK, "run": RUN, "crouch": CROUCH}
    for clip, specs in clips.items():
        row = []
        for i, spec in enumerate(specs, 1):
            body, head, anc = body_frame(rig, spec)
            key = f"{clip}_{i:02d}"
            save(body, split / "body" / clip / f"{key}.png")
            save(head, split / "head" / clip / f"{key}.png")
            meta["frames"][key] = {
                "shoulder": anc["shoulder"], "shoulder_from_pivot": [anc["shoulder"][0] - px, anc["shoulder"][1] - py],
                "neck": anc["neck"], "neck_from_pivot": [anc["neck"][0] - px, anc["neck"][1] - py],
            }
            comp = body.copy()
            m = head[..., 3] > 0
            comp[m] = head[m]
            s = anc["shoulder"]
            place(comp, rig.arm, SHOULDER, 0.0, (s[0] / ART, s[1] / ART))
            row.append(comp)
        review_rows.append(row)

    # 팔+총 (어깨 회전축 기준으로 잘라낸다)
    ys, xs = np.nonzero(rig.arm[..., 3])
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    x0 = min(x0, SHOULDER[0])
    save(rig.arm[y0:y1, x0:x1], split / "arm_gun.png")
    meta["arm_gun"] = {
        "size": [(x1 - x0) * ART, (y1 - y0) * ART],
        "shoulder_local": [(SHOULDER[0] - x0) * ART, (SHOULDER[1] - y0) * ART],
        "muzzle_local": [(MUZZLE[0] - x0) * ART, (MUZZLE[1] - y0) * ART],
        "eject_from_shoulder": [(EJECT[0] - SHOULDER[0]) * ART, (EJECT[1] - SHOULDER[1]) * ART],
    }
    (split / "muzzle_flash.png").write_bytes(flash_keep)
    meta["muzzle_flash"] = {"size": list(Image.open(split / "muzzle_flash.png").size)}
    meta["head"] = {"note": "head/<clip>/<clip>_NN.png 은 셀 크기 그대로, neck 이 회전축. 몸통에도 후드 아래 5줄이 겹쳐 있다"}

    # 전신 높이 · 몸 중심 · 구르기 중심 (발 밑 기준, 오른쪽 방향, 월드 px)
    idle = np.array(up4(review_rows[0][0]))
    ys, xs = np.nonzero(idle[..., 3])
    meta["height"] = int(py - ys.min())
    meta["body_center_y"] = int(round(meta["height"] * 0.57))
    c4 = np.array(up4(review_rows[4][3]))
    ys, xs = np.nonzero(c4[..., 3])
    meta["roll_center"] = [int(round(xs.mean() - px)), int(round(py - ys.mean()))]

    # 액션: 구르기 — 숙임 → 앞으로 기울며 말림 → 공 → 공 → 착지 숙임 → 일어서 조준
    deep = dict(hip_dy=13, lean=0.30, feet={"back": (56, GB - 4), "front": (67, GF - 4)})
    roll = []
    f, _ = full_frame(rig, CROUCH[1], arm_angle=0.35, head_angle=0.08); roll.append(grounded(f))
    f, _ = full_frame(rig, dict(CROUCH[3], lean=0.22), arm_angle=0.9, head_angle=0.05); roll.append(spin(f, 0.45))
    ball, _ = full_frame(rig, deep, arm_angle=1.45, head_angle=-0.15)   # 고개를 숙여 후드가 몸에 붙는다
    roll.append(spin(ball, 1.9))
    roll.append(spin(ball, 3.9))
    f, _ = full_frame(rig, CROUCH[3], arm_angle=0.7, head_angle=0.15); roll.append(spin(f, -0.35 + 2 * math.pi))
    f, _ = full_frame(rig, CROUCH[0], arm_angle=0.12); roll.append(grounded(f))
    for i, f in enumerate(roll, 1):
        save(f, action / "roll" / f"roll_{i:02d}.png")

    # 액션: 재장전 — 팔이 내려가 총을 흔들고, 고개가 총을 내려다본다
    reload = []
    for i, (a, h, dy) in enumerate(((0.25, 0.05, 0), (0.70, 0.12, 1), (1.05, 0.20, 1),
                                    (0.95, 0.20, 1), (0.55, 0.10, 0), (0.15, 0.03, 0)), 1):
        spec = REST if dy == 0 else dict(PLANTED, hip_dy=dy)
        f, _ = full_frame(rig, spec, arm_angle=a, head_angle=h)
        f = grounded(f)
        reload.append(f)
        save(f, action / "reload" / f"reload_{i:02d}.png")

    # 전신 합성 Frames (검수·참조용; 게임은 Split + Action 을 쓴다)
    full = {"idle": [REST, REST, dict(PLANTED, hip_dy=1), REST], "walk": WALK, "run": RUN, "crouch": CROUCH}
    for clip, specs in full.items():
        for i, spec in enumerate(specs, 1):
            f, _ = full_frame(rig, spec)
            save(grounded(f), frames_dir / clip / f"{clip}_{i:02d}.png")
    fl = Image.open(split / "muzzle_flash.png").convert("RGBA")
    flash_n = np.array(fl.resize((max(1, fl.width // ART), max(1, fl.height // ART)), Image.NEAREST))
    for i, back in enumerate((0.0, 3.0, 2.0, 0.5), 1):
        f, anc = full_frame(rig, REST, arm_back=back)
        if i == 3:
            mx = anc["shoulder"][0] + MUZZLE[0] - SHOULDER[0]
            my = anc["shoulder"][1] + MUZZLE[1] - SHOULDER[1]
            fy0, fx0 = int(round(my - flash_n.shape[0] / 2)), int(round(mx))
            for y, x in zip(*np.nonzero(flash_n[..., 3])):
                if 0 <= fy0 + y < CELL_N and 0 <= fx0 + x < CELL_N:
                    f[fy0 + y, fx0 + x] = flash_n[y, x]
        save(grounded(f), frames_dir / "shoot" / f"shoot_{i:02d}.png")

    with open(split / "split_meta.json", "w", encoding="utf-8") as fp:
        json.dump(meta, fp, indent=2, ensure_ascii=False)

    # 검수 시트 (행: idle · aim · walk · run · crouch · roll · reload)
    rows = review_rows + [roll, reload]
    W = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (W * CELL_N * ART, len(rows) * CELL_N * ART), (58, 58, 68, 255))
    for r, row in enumerate(rows):
        for c, f in enumerate(row):
            sheet.alpha_composite(up4(f), (c * CELL_N * ART, r * CELL_N * ART))
    sheet.save(REVIEW / "hooded_mechanic_hq_review_sheet.png")
    Image.fromarray(img).save(REVIEW / "hooded_mechanic_hq_native128.png")
    for k in ("head", "arm", "torso"):
        Image.fromarray(getattr(rig, k)).save(REVIEW / f"part_{k}.png")
    for side in ("back", "front"):
        for k in ("thigh", "shin", "boot"):
            Image.fromarray(rig.legs[side][k]).save(REVIEW / f"part_leg_{side}_{k}.png")
    print(json.dumps({k: meta[k] for k in ("cell", "height", "body_center_y", "roll_center", "arm_gun")}, ensure_ascii=False))
    print(json.dumps({k: meta["frames"][k] for k in ("idle_01", "walk_02", "crouch_04")}))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--native-scale", type=float, default=1.0)
    build(ap.parse_args().native_scale)
