"""
붉은 후드 정비공 — 팔+총 분리 리소스 빌드.

입력 : Assets/GameReady/Characters/HoodedMechanic/Frames/<clip>/<clip>_NN.png (320x320, Bottom Center)
출력 : Assets/GameReady/Characters/HoodedMechanic/Split/
        body/<clip>/<clip>_NN.png   앞팔을 지운 몸통 프레임 (idle/walk/crouch) + aim_01 (shoot_01 몸통)
        arm_gun.png                 어깨 기준 팔+총 (오른쪽 조준, 수평)
        muzzle_flash.png            총구 화염
        split_meta.json             어깨 앵커·총구 좌표 (프레임 로컬 & 바닥 중심 기준)
      GodotPrototype/assets/character/Split/ 에도 동일 복사
실행 : python Tools/build_hooded_mechanic_split.py
"""
import json, os, shutil, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Assets/GameReady/Characters/HoodedMechanic/Frames")
OUT = os.path.join(ROOT, "Assets/GameReady/Characters/HoodedMechanic/Split")
GODOT_OUT = os.path.join(ROOT, "GodotPrototype/assets/character/Split")
CELL = 320
PIVOT = (160, 320)  # Bottom Center

# shoot_01 기준 팔+총 영역과 어깨/총구 (프레임 픽셀 좌표)
ARM_BOX = (199, 138, 286, 210)      # x0,y0,x1,y1 (x1,y1 exclusive)
SHOULDER = (199, 178)
MUZZLE = (282, 160)
FLASH_BOX = (262, 126, 318, 192)
SPLIT_Y = 236            # 상체/하체 분할선 (재킷 밑단 위)
WALK_TORSO_DX = -6       # 걷기 다리 위에 올릴 때 상체 X 보정

# 몸통 프레임별 어깨 앵커 (프레임 픽셀 좌표). 걷기·숙이기는 몸의 상하 움직임에 맞춰 조정.
# 이 값은 hood 상단(bbox top) 변화량으로 자동 보정한다.
BASE_SHOULDER = {
    "idle":   (163, 178),
    "walk":   (163, 178),
    "crouch": (168, 178),   # 1프레임(서 있는 자세) 기준. 이후 프레임은 bbox top 으로 보정
    "aim":    SHOULDER,
}
# 앞팔 인페인트 박스 (idle/walk 만). 박스 안의 '소매 보라' 픽셀을 좌측 재킷 색으로 채운다.
ARM_INPAINT_BOX = {
    "idle": (140, 170, 182, 236),
    "walk": (140, 170, 186, 236),
}


def load(clip, i):
    return Image.open(os.path.join(SRC, clip, f"{clip}_{i:02d}.png")).convert("RGBA")


def is_sleeve(px):
    r, g, b, a = px
    if a == 0:
        return False
    # 어두운 보라/남색 계열(소매·장갑 그림자) + 검정 외곽선
    dark = max(r, g, b) < 60
    purple = b >= r - 5 and b > g and r < 140 and max(r, g, b) < 170
    return dark or purple


def inpaint_arm(im, box):
    """박스 내부의 소매 픽셀을, 같은 행에서 박스 왼쪽 첫 비소매 픽셀(재킷) 색으로 채운다."""
    x0, y0, x1, y1 = box
    px = im.load()
    for y in range(y0, y1):
        # 재킷 샘플: 박스 왼쪽 방향으로 첫 '밝은' 불투명 픽셀
        sample = None
        for x in range(x0 - 1, x0 - 40, -1):
            p = px[x, y]
            if p[3] > 0 and not is_sleeve(p):
                sample = p
                break
        if sample is None:
            continue
        for x in range(x0, x1):
            p = px[x, y]
            if p[3] == 0:
                continue
            if is_sleeve(p):
                px[x, y] = sample
    return im


def cut_box(im, box, extra_predicate=None):
    x0, y0, x1, y1 = box
    px = im.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if extra_predicate is None or extra_predicate(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    return im


def crop_box(im, box):
    return im.crop(box)


def main():
    for d in [OUT, GODOT_OUT]:
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(os.path.join(d, "body"), exist_ok=True)

    meta = {"cell": CELL, "pivot": {"x": PIVOT[0], "y": PIVOT[1]}, "frames": {}}

    # 1) 팔+총
    shoot1 = load("shoot", 1)
    arm = crop_box(shoot1, ARM_BOX)
    arm.save(os.path.join(OUT, "arm_gun.png"))
    meta["arm_gun"] = {
        "size": [arm.width, arm.height],
        "shoulder_local": [SHOULDER[0] - ARM_BOX[0], SHOULDER[1] - ARM_BOX[1]],
        "muzzle_local": [MUZZLE[0] - ARM_BOX[0], MUZZLE[1] - ARM_BOX[1]],
    }

    # 2) 총구 화염 (shoot_03, 노랑/주황/흰색만)
    shoot3 = load("shoot", 3)
    flash = crop_box(shoot3, FLASH_BOX)
    fp = flash.load()
    for y in range(flash.height):
        for x in range(flash.width):
            r, g, b, a = fp[x, y]
            hot = a > 0 and r > 170 and g > 90 and (b < 140 or (r > 230 and g > 230))
            if not hot:
                fp[x, y] = (0, 0, 0, 0)
    flash = flash.crop(flash.getbbox())
    flash.save(os.path.join(OUT, "muzzle_flash.png"))
    meta["muzzle_flash"] = {"size": [flash.width, flash.height]}

    # 3) 몸통: aim (shoot_01 에서 팔 제거)
    aim = cut_box(shoot1.copy(), ARM_BOX)
    os.makedirs(os.path.join(OUT, "body", "aim"), exist_ok=True)
    aim.save(os.path.join(OUT, "body", "aim", "aim_01.png"))
    meta["frames"]["aim_01"] = {"shoulder": list(SHOULDER),
                                 "shoulder_from_pivot": [SHOULDER[0] - PIVOT[0], SHOULDER[1] - PIVOT[1]]}

    # 4) 몸통: 상체(aim 몸통, 고정) + 하체(walk 프레임 다리) 합성. idle 은 aim_01 그대로.
    #    Metal Slug 식: 팔·총이 실시간으로 회전하므로 상체는 한 포즈로 고정하고 다리만 애니메이션.
    torso = aim.crop((0, 0, CELL, SPLIT_Y))
    os.makedirs(os.path.join(OUT, "body", "idle"), exist_ok=True)
    aim.save(os.path.join(OUT, "body", "idle", "idle_01.png"))
    meta["frames"]["idle_01"] = meta["frames"]["aim_01"]

    os.makedirs(os.path.join(OUT, "body", "walk"), exist_ok=True)
    top0 = load("walk", 1).getbbox()[1]
    for i in range(1, 5):
        src = load("walk", i)
        bob = src.getbbox()[1] - top0          # 걷기 상하 흔들림 (px)
        out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        legs = src.crop((0, SPLIT_Y + bob, CELL, CELL))
        # 분할선 바로 아래로 내려온 앞팔(장갑) 잔여 픽셀 제거: 밝은 색(살색/탄색)만 지운다
        lp = legs.load()
        for y in range(0, min(20, legs.height)):
            for x in range(185, 232):
                r, g, b, a = lp[x, y]
                if a > 0 and r > 150 and g > 100:
                    lp[x, y] = (0, 0, 0, 0)
        out.alpha_composite(legs, (0, SPLIT_Y + bob))
        out.alpha_composite(torso, (WALK_TORSO_DX, bob))
        out.save(os.path.join(OUT, "body", "walk", f"walk_{i:02d}.png"))
        sx, sy = SHOULDER[0] + WALK_TORSO_DX, SHOULDER[1] + bob
        meta["frames"][f"walk_{i:02d}"] = {"shoulder": [sx, sy],
                                            "shoulder_from_pivot": [sx - PIVOT[0], sy - PIVOT[1]]}

    # crouch: 원본 유지 (팔은 오버레이). 어깨는 hood 상단 변화량으로 보정
    os.makedirs(os.path.join(OUT, "body", "crouch"), exist_ok=True)
    top0 = load("crouch", 1).getbbox()[1]
    for i in range(1, 5):
        im = load("crouch", i)
        im.save(os.path.join(OUT, "body", "crouch", f"crouch_{i:02d}.png"))
        sx, sy = BASE_SHOULDER["crouch"]
        sy = sy + (im.getbbox()[1] - top0)
        meta["frames"][f"crouch_{i:02d}"] = {"shoulder": [sx, sy],
                                              "shoulder_from_pivot": [sx - PIVOT[0], sy - PIVOT[1]]}

    with open(os.path.join(OUT, "split_meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)

    # Godot 프로젝트로 복사
    shutil.rmtree(GODOT_OUT)
    shutil.copytree(OUT, GODOT_OUT)
    print("OK ->", OUT)
    print(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
