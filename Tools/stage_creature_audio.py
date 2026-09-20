# 채택한 크리처 보컬만 Godot 프로젝트로 옮긴다.
#
# 2026-09-20 오디션(Downloads/80-CC0-creature-SFX/_player.html)에서 확정된 9개만 다룬다.
# 채택되지 않은 것은 쓰지 않는다 — 후보를 늘리려면 먼저 오디션 페이지에서 고를 것.
#
# 원본: OpenGameArt "80 CC0 creature SFX" (rubberduck) — CC0. 표기 의무 없음.
#       https://opengameart.org/content/80-cc0-creature-sfx
#
# 원본을 그대로 쓰면 안 되는 이유 넷:
#   1) 레벨이 제각각이다 — RMS 가 -17.8 ~ -26.5 dBFS 로 8.7dB 벌어져 있다. 같은 역할의
#      변형끼리 크기가 널뛰면 "변형"이 아니라 "실수"로 들린다.
#   2) 피크가 0 dBFS 를 넘는 것이 셋 있다(bug_04 는 +3.7). 그대로 두면 재생 시 찌그러진다.
#   3) 앞뒤에 무음이 최대 75ms 붙어 있다. 피격음이 늦게 나면 총알이 맞은 것처럼 안 들린다 —
#      원샷 효과음에서 선행 무음은 그냥 지연이다.
#   4) 스테레오지만 실질 듀얼 모노다. AudioStreamPlayer2D 로 위치 패닝을 걸 것이므로
#      파일에 스테레오 이미지가 남아 있으면 패닝이 흐려진다. 모노로 합친다.
#
# 레벨 정책은 gunshot 쪽과 같되 한 겹 더 있다.
#   - 프로젝트 관례: 파일은 피크 -1 dBFS 로 채우고 밸런스는 audio_manager 의 db 로 잡는다.
#   - 다만 피크만 맞추면 위 1) 이 그대로 남는다. 그래서 **먼저 RMS 를 -20 dBFS 로 맞추고**
#     그 결과가 피크 -1 을 넘으면 소프트 리미터로 꼭지만 깎는다.
#   - -20 은 임의값이 아니라 기존 원샷들(footstep -21.3, shell -20.9, fire_body_01 -20.0)이
#     모여 있는 지점이다. 여기 맞춰 두면 creature 의 db 값이 다른 SFX 와 같은 척도가 된다.
#
# 리미터가 필요한 이유 — 그냥 눌러 내리면 안 되는 경우가 있다.
#   hurt_01·hurt_02·death_02 는 crest 가 크다(평균보다 25dB 높은 순간 피크가 한두 방 박혀 있다).
#   피크만 보고 통째로 낮추면 이 셋은 목표보다 5~7dB 아래로 떨어진다. 그러면 death_01 과
#   death_02 가 6dB 차이로 울리는데, 이건 "변형"이 아니라 "한쪽이 고장 난 것"으로 들린다.
#   원본이 이미 0 dBFS 를 넘어 잘려 있던 것들이라 그 꼭지는 보존할 가치도 없다.
#   -7 dBFS 위쪽만 tanh 로 눌러 RMS 를 되찾는다. 크리처 울음에서 이 정도 포화는
#   귀에 왜곡으로 안 들리고 오히려 거친 질감으로 붙는다.
#   (앰비언스 쪽 TEX_TRIM — 재생 게인으로 되돌리는 방식 — 은 여기서는 안 쓴다.
#    루프 베드와 달리 원샷은 파일 자체가 꽉 차 있어야 어택이 산다.)
#
# 음높이는 여기서 내리지 않는다. 외계 생물 톤은 피치를 낮춰 만드는 게 맞지만,
# 파일에 구워 버리면 매번 같은 높이로 울려 4번째 재생부터 반복감이 드러난다.
# audio_manager.SOUNDS 의 pitch 범위(0.7~0.9 대)로 **매 재생마다 다르게** 내린다.
#
# 사용:
#   python Tools/stage_creature_audio.py
#   python Tools/stage_creature_audio.py --dry-run

import argparse
import os
import sys

import numpy as np
import soundfile as sf

try:  # 콘솔이 cp949 여도 한글 로그가 깨지지 않게
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

SRC_DIR = r"C:\Users\vnvnc\Downloads\80-CC0-creature-SFX"
OUT_REL = os.path.join("GodotPrototype", "assets", "audio", "sfx", "creature")
LIC_REL = os.path.join("GodotPrototype", "assets", "audio", "_licenses")

TARGET_RMS_DB = -20.0     # 같은 역할의 변형끼리 크기를 맞춘다
TARGET_PEAK_DB = -1.0     # 최종 피크 상한
SAMPLE_RATE = 48000       # 원본 전부 48k — 리샘플하지 않는다

KNEE_DB = -7.0            # 이 위쪽만 tanh 로 눌린다. 아래는 손대지 않는다
LIMIT_PASSES = 4          # 누르고 → RMS 되맞추고 를 반복하는 횟수 (보통 2회면 수렴한다)

TRIM_DB = -50.0           # 이보다 작으면 무음으로 본다
PAD_HEAD = 0.004          # 어택 앞에 남기는 여유 (초). 0 이면 첫 샘플이 뚝 끊긴 듯 들린다
PAD_TAIL = 0.030          # 꼬리 뒤에 남기는 여유
FADE_IN = 0.003           # 클릭 방지
FADE_OUT = 0.020

# (원본, 대상, 용도) — 대상 이름은 audio_manager.gd 가 참조할 이름이다.
FILES = [
    # 위협 — 플레이어를 발견하고 달려들기 시작할 때. 짧고 날이 서 있어야 한다.
    ("alien_02.ogg", "aggro_01.ogg", "크롤러 위협 (포효·공격 개시)"),
    ("alien_03.ogg", "aggro_02.ogg", "크롤러 위협 (포효·공격 개시)"),
    ("bug_04.ogg",   "aggro_03.ogg", "크롤러 위협 — 벌레질감. 셋 중 가장 건조하다"),
    # 피격 — 초당 여러 번 울린다. 짧고 작아야 한다.
    ("alien_01.ogg", "hurt_01.ogg",  "크롤러 피격"),
    ("alien_04.ogg", "hurt_02.ogg",  "크롤러 피격"),
    # 죽음 — 한 개체당 정확히 한 번. 가장 길고 크게 가도 되는 자리.
    ("misc_01.ogg",  "death_01.ogg", "크롤러 죽음"),
    ("spit_01.ogg",  "death_02.ogg", "크롤러 죽음 — 젖은 계열"),
    ("spit_02.ogg",  "death_03.ogg", "크롤러 죽음 — 젖은 계열"),
    # 배회 — 걷는 중 이따금. 존재를 알리되 주의를 끌면 안 되므로 가장 작게 깐다.
    ("alien_06.ogg", "idle_01.ogg",  "크롤러 배회 중 웅얼거림"),
]

LICENSE_TEXT = """80 CC0 creature SFX — rubberduck (OpenGameArt)
https://opengameart.org/content/80-cc0-creature-sfx

License: CC0 1.0 Universal (Public Domain Dedication)
https://creativecommons.org/publicdomain/zero/1.0/

저작자 표기 의무 없음. 상업적 사용·개작·재배포 모두 허용.

이 프로젝트에서 쓰는 파일 (전부 개작본 — 모노 합성 · 무음 제거 · RMS -20dBFS 정규화):
  sfx/creature/aggro_01.ogg  <- alien_02.ogg
  sfx/creature/aggro_02.ogg  <- alien_03.ogg
  sfx/creature/aggro_03.ogg  <- bug_04.ogg
  sfx/creature/hurt_01.ogg   <- alien_01.ogg
  sfx/creature/hurt_02.ogg   <- alien_04.ogg
  sfx/creature/death_01.ogg  <- misc_01.ogg
  sfx/creature/death_02.ogg  <- spit_01.ogg
  sfx/creature/death_03.ogg  <- spit_02.ogg
  sfx/creature/idle_01.ogg   <- alien_06.ogg

가공 규칙은 Tools/stage_creature_audio.py 에 전부 적혀 있다.
"""


def db_to_lin(db: float) -> float:
    return 10.0 ** (db / 20.0)


def rms_db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def peak_db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.max(np.abs(x)) + 1e-12)


def trim(x: np.ndarray, sr: int) -> np.ndarray:
    """앞뒤 무음을 잘라낸다. 어택 앞과 꼬리 뒤에는 약간 남긴다."""
    thr = db_to_lin(TRIM_DB) * np.max(np.abs(x))
    idx = np.where(np.abs(x) > thr)[0]
    if idx.size == 0:
        return x
    a = max(0, idx[0] - int(PAD_HEAD * sr))
    b = min(len(x), idx[-1] + int(PAD_TAIL * sr))
    return x[a:b]


def fade(x: np.ndarray, sr: int) -> np.ndarray:
    """양 끝에 짧은 페이드. 잘라낸 자리에서 나는 딸깍 소리를 없앤다."""
    n_in = min(int(FADE_IN * sr), len(x) // 4)
    n_out = min(int(FADE_OUT * sr), len(x) // 4)
    y = x.copy()
    if n_in > 0:
        y[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out > 0:
        y[-n_out:] *= np.linspace(1.0, 0.0, n_out)
    return y


def soft_limit(x: np.ndarray) -> tuple:
    """KNEE_DB 위쪽만 tanh 로 눌러 목표 RMS 를 되찾는다.

    누르면 RMS 도 같이 내려가므로 다시 올리고, 올리면 또 넘으므로 다시 누른다.
    두어 번이면 수렴한다. 반환: (결과, 눌린 샘플 비율 %)
    """
    knee = db_to_lin(KNEE_DB)
    ceil = db_to_lin(TARGET_PEAK_DB)
    target = db_to_lin(TARGET_RMS_DB)
    y = x
    touched = 0.0
    for _ in range(LIMIT_PASSES):
        if peak_db(y) <= TARGET_PEAK_DB:
            break
        over = np.abs(y) > knee
        touched = max(touched, 100.0 * over.mean())
        # 무릎 위 초과분을 tanh 로 접어 넣는다 — 무릎 지점에서 기울기가 이어져 계단이 안 생긴다
        room = ceil - knee
        excess = (np.abs(y) - knee) / room
        y = np.where(over, np.sign(y) * (knee + room * np.tanh(excess)), y)
        y = y * target / (10.0 ** (rms_db(y) / 20.0))
    pk = peak_db(y)
    if pk > TARGET_PEAK_DB:                       # 마지막 안전망
        y = y * db_to_lin(TARGET_PEAK_DB - pk)
    return y, touched


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="쓰지 않고 측정만 한다")
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, OUT_REL)
    lic_dir = os.path.join(root, LIC_REL)
    if not args.dry_run:
        os.makedirs(out_dir, exist_ok=True)
        os.makedirs(lic_dir, exist_ok=True)

    print(f"원본 : {SRC_DIR}")
    print(f"대상 : {out_dir}")
    print(f"목표 : RMS {TARGET_RMS_DB:+.1f} dBFS · 피크 상한 {TARGET_PEAK_DB:+.1f} dBFS\n")
    print(f"{'대상':<16}{'길이':>8}{'RMS':>8}{'피크':>8}   비고")
    print("-" * 78)

    trims = []
    missing = 0
    for src_name, dst_name, note in FILES:
        src = os.path.join(SRC_DIR, src_name)
        if not os.path.exists(src):
            print(f"{dst_name:<16}{'':>8}{'':>8}{'':>8}   ✗ 원본 없음: {src_name}")
            missing += 1
            continue

        data, sr = sf.read(src, always_2d=True, dtype="float64")
        x = data.mean(axis=1)                      # 듀얼 모노 → 모노
        x = fade(trim(x, sr), sr)

        x *= db_to_lin(TARGET_RMS_DB) / (10.0 ** (rms_db(x) / 20.0))
        x, touched = soft_limit(x)

        miss = TARGET_RMS_DB - rms_db(x)
        if miss > 0.5:
            trims.append((dst_name, miss))
        flag = ""
        if touched > 0.0:
            flag = f"  리미터 {touched:.2f}%"
        if miss > 0.5:
            flag += f"  ← 목표보다 {miss:.1f} dB 낮음"
        print(f"{dst_name:<16}{len(x)/sr:7.3f}s{rms_db(x):8.1f}{peak_db(x):8.1f}   {note}{flag}")

        if not args.dry_run:
            sf.write(os.path.join(out_dir, dst_name), x.astype(np.float32), SAMPLE_RATE,
                     format="OGG", subtype="VORBIS")

    print("-" * 78)
    if missing:
        print(f"⚠ 원본 {missing}개를 찾지 못했다. SRC_DIR 을 확인할 것.")

    if trims:
        print("\n리미터로도 목표 RMS 에 못 닿은 파일 — audio_manager 의 db 로 되돌릴 값:")
        for name, d in trims:
            print(f"    {name}: +{d:.1f} dB")
        print("  (KNEE_DB 를 더 낮추면 닿지만 그만큼 포화가 들린다. 여기서는 db 로 메우는 편이 낫다)")

    if not args.dry_run:
        with open(os.path.join(lic_dir, "OGA_80_CC0_creature_SFX.txt"), "w", encoding="utf-8") as f:
            f.write(LICENSE_TEXT)
        print(f"\n✓ {len(FILES) - missing}개 내보냄 → {OUT_REL}")
        print(f"✓ 라이선스 증빙 → {LIC_REL}/OGA_80_CC0_creature_SFX.txt")
    else:
        print("\n(dry-run — 아무것도 쓰지 않았다)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
