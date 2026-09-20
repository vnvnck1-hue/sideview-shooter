# -*- coding: utf-8 -*-
"""채택된 총격 사운드를 게임에 바로 쓸 형태로 잘라 넣는다.

2026-09-20 프리셋 확정: 플레이어 "두껍게"(p2) · 센트리건 "2연장 교대"(t2).
후보 비교 음원은 Tools/build_gunshot_presets.py 로 다시 만들 수 있다.

원본(48 kHz / 24bit / 스테레오)을 그대로 쓰면 안 되는 이유.

  1. 꼬리가 길다 — 원본에는 0.1~0.6초의 잔향이 붙어 있다. 보디 레이어가 그 길이면
     초당 11발에서 잔향이 계속 겹쳐 먹먹해진다. 앞부분만 잘라 쓰고,
     잘라낸 잔향은 별도의 tail 레이어로 따로 쓴다.
  2. 앞에 무음이 있다 — 파일마다 2~35 ms 씩 다르다. 그대로 두면 발사 입력과
     소리 사이의 지연이 샘플마다 달라진다. 온셋에 맞춰 앞을 깎는다.
  3. 어택 대비가 없다 — 타격감은 절대 음량이 아니라 대비에서 온다. 피크 위치를 찾아
     그 앞을 밀어올린 뒤 다시 정규화하면, 피크는 그대로인데 몸통이 내려앉아 어택이 선다.
  4. 레벨이 제각각이다 — 전부 -1 dBFS 로 맞춰야 audio_manager.gd 의 db 값이 의미를 갖는다.
     믹스는 코드에서 잡고, 파일은 기준 레벨로 통일한다.

버스 로우패스(Weapon 9.5 kHz)·리버브·슬랩백은 여기서 굽지 않는다. 런타임에 버스가 처리한다.
반대로 **파일에 구워야만 하는 것**이 둘 있다 — 레이어 시작 지연(lead)과 좌우 분리(pan).
둘 다 Godot 쪽에 대응하는 기능이 없어서다. 자세한 이유는 CUTS 주석 참고.

출력: 48 kHz / 16bit. 대부분 모노, 센트리건 포신만 스테레오(좌우를 가르므로).
  원본이 48k 라 리샘플링을 하지 않는 편이 깨끗하다. Godot 은 재생 시 알아서 맞춘다.

사용:
    python Tools/stage_gunshot_audio.py
"""

import io
import math
import shutil
import sys
import wave
from pathlib import Path

import numpy as np

if hasattr(sys.stdout, "reconfigure"):   # cp949 콘솔에서 한글·기호가 깨지지 않게
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC = Path(r"C:\Users\vnvnc\Downloads\23279__gokhanbiyik__gun-sounds-01")
DEST = Path("GodotPrototype/assets/audio/sfx/weapon")
LICENSE_DEST = Path("GodotPrototype/assets/audio/_licenses/GokhanBiyik_GunSounds01_CC-BY-4.0.txt")

TARGET_PEAK_DB = -1.0     # 파일은 최대한 채워 내보낸다. 밸런스는 audio_manager 의 db 로 잡는다
FADE_IN_MS = 0.6          # 짧을수록 어택이 선다. 클릭이 안 나는 선까지 줄였다

## 타격감은 절대 음량이 아니라 **대비**에서 나온다.
## 앞 punch_ms 구간만 punch_db 만큼 밀어올린 뒤 전체를 다시 정규화하면,
## 피크는 그대로인데 몸통이 상대적으로 내려앉아 어택이 튀어나온다.
## 그냥 볼륨을 올리는 것과 근본적으로 다르다 — 올리면 다 같이 커져서 타격감은 그대로다.

## 2026-09-20 프리셋 확정 — 플레이어 "두껍게"(p2), 센트리건 "2연장 교대"(t2).
## 근거와 비교 음원은 Tools/build_gunshot_presets.py 로 다시 만들 수 있다.
##
## lead : 파일 앞에 붙이는 무음(ms). Godot 의 AudioStreamPlayer 에는 시작 지연이 없어서,
##        "보디보다 7ms 늦게 깔리는 층" 같은 건 파일에 구워 넣는 수밖에 없다.
## pan  : 스테레오로 내보내며 좌우를 가른다(-1 좌 ~ +1 우). 센트리건 포신 2개를
##        갈라 놓는 용도. AudioStreamPlayer2D 의 위치 패닝은 두 포신 간격(몇백 px)으로는
##        화면 비율상 거의 효과가 없어서, 파일 단계에서 가른다.
CUTS = [
    # --- 플레이어 소총: 보디 2겹 + 어택 + 저역 ---
    ("413094__gokhanbiyik__gunshort03.wav", "fire_body_01.wav", 130, 26, 5.0, 9, 0.0, 0.0,
     "보디 배리에이션 1 — 이 팩에서 가장 밝아 어택이 산다"),
    ("413115__gokhanbiyik__gunshort12.wav", "fire_body_02.wav", 130, 26, 5.0, 9, 0.0, 0.0,
     "보디 배리에이션 2 — 01 과 밝기가 겹치지 않는다"),
    ("413101__gokhanbiyik__gunshort10.wav", "fire_body2_01.wav", 110, 26, 2.0, 9, 7.0, 0.0,
     "두께 층 — 보디보다 7ms 늦게, 피치를 내려 깐다. 한 발이 두툼해지는 이유"),
    ("413127__gokhanbiyik__mg04.wav", "fire_sub_01.wav", 150, 34, 3.0, 18, 0.0, 0.0,
     "발사 저역 — 150ms 로 짧게. 때리고 빠져야 연사에 안 쌓인다"),
    ("413119__gokhanbiyik__gunsound04.wav", "fire_tail_01.wav", 0, 60, 0.0, 0, 0.0, 0.0,
     "사격 종료 잔향 — 자르지 않는다. 꼬리가 이 소리의 전부다"),

    # --- 센트리건: 포신 2개 교대 + 크랙 ---
    ("413099__gokhanbiyik__gunshort06.wav", "turret_fire_01.wav", 150, 30, 4.0, 12, 0.0, 0.30,
     "포신 A — 오른쪽. 저역 중심(중심 142 Hz)이라 거리감이 산다"),
    ("413097__gokhanbiyik__gunshort08.wav", "turret_fire_02.wav", 150, 30, 4.0, 12, 0.0, -0.30,
     "포신 B — 왼쪽. A 와 다른 샘플이어야 '교대'로 들린다"),
    ("413120__gokhanbiyik__gunsound03.wav", "turret_crack_01.wav", 40, 12, 6.0, 5, 0.0, 0.0,
     "센트리건 크랙 — 실총 고역부만 잘라 매 발 얹는다. '탕' 하는 지점"),
]

## 포신 A/B 의 RMS 를 맞추기 위한 보정(dB)을 자동으로 계산해 찍어 준다.
## 둘 다 -1 dBFS 로 정규화해도 샘플마다 피크 대비 에너지가 달라 좌우가 어긋난다.
## 그러면 '두 문이 교대'가 아니라 '한쪽이 크다'로 들린다.
BARREL_MATCH = ("turret_fire_01.wav", "turret_fire_02.wav")


def load_mono(path: Path):
    with wave.open(str(path), "rb") as w:
        n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    if sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        a = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        a = np.where(a & 0x800000, a - 0x1000000, a).astype(np.float64) / 8388608.0
    else:
        dt = {1: np.uint8, 2: np.int16, 4: np.int32}[sw]
        a = np.frombuffer(raw, dtype=dt).astype(np.float64)
        a = (a - 128.0) / 128.0 if sw == 1 else a / float(2 ** (8 * sw - 1))
    if ch > 1:
        a = a.reshape(-1, ch).mean(axis=1)
    return a, sr


def cut(a: np.ndarray, sr: int, keep_ms: int, fade_out_ms: int,
        punch_db: float = 0.0, punch_ms: int = 0, lead_ms: float = 0.0) -> np.ndarray:
    a = a - a.mean()                                    # DC 오프셋 제거 (저역이 많아 무시 못 한다)

    env = np.abs(a)
    pk = env.max()
    hits = np.nonzero(env >= pk * 0.05)[0]              # 온셋 = 피크의 5% 를 처음 넘는 지점
    s = a[int(hits[0]):] if len(hits) else a.copy()

    if keep_ms > 0:
        s = s[: int(sr * keep_ms / 1000.0)]
    s = s.copy()

    fi = max(1, int(sr * FADE_IN_MS / 1000.0))          # 자른 단면에서 클릭이 나지 않게
    s[:fi] *= np.linspace(0.0, 1.0, fi)
    fo = min(len(s) - 1, int(sr * fade_out_ms / 1000.0))
    if fo > 1:
        s[-fo:] *= np.linspace(1.0, 0.0, fo) ** 1.5     # 살짝 볼록하게 — 꼬리가 갑자기 죽지 않는다

    # 트랜지언트 강조 — 어택 구간만 밀어올린다.
    #
    # 창을 파일 맨 앞에 고정하면 안 된다. 샘플마다 피크가 오는 시점이 달라서
    # (gunshort03 은 4ms, gunshort12 는 21ms) 고정 창은 피크가 늦은 쪽에서
    # 정작 어택 앞의 조용한 부분만 키우고 끝난다 — 대비가 오히려 뒤집힌다.
    # 그래서 **피크까지는 그대로 밀고, 피크 이후로 지수 감쇠**시킨다.
    # 정규화가 뒤따르므로 최종 피크는 그대로고, 몸통만 상대적으로 내려앉는다.
    if punch_db > 0.0 and punch_ms > 0:
        g = 10 ** (punch_db / 20.0)
        pi = int(np.abs(s).argmax())
        n = int(sr * punch_ms / 1000.0)
        env = np.ones(len(s))
        env[:min(pi + 1, len(s))] = g
        tail = min(n, len(s) - pi - 1)
        if tail > 1:
            env[pi + 1:pi + 1 + tail] = 1.0 + (g - 1.0) * np.exp(-np.linspace(0.0, 4.0, tail))
        s *= env

    pk = np.abs(s).max()
    if pk > 1e-9:
        s *= 10 ** (TARGET_PEAK_DB / 20.0) / pk
    if lead_ms > 0.0:
        s = np.concatenate([np.zeros(int(sr * lead_ms / 1000.0)), s])
    return s


def to_stereo(s: np.ndarray, pan: float) -> np.ndarray:
    """등출력 패닝으로 스테레오 인터리브 (-1 좌 ~ +1 우).

    √2 를 곱해 가운데 이득을 1.0 으로 맞추면 한쪽으로 치우쳤을 때 그 채널이
    원본보다 커진다 — -1 dBFS 로 정규화해 뒀어도 0 dBFS 에 붙어 버린다.
    그래서 패닝 **뒤에** 한 번 더 정규화한다. 좌우 비율은 그대로 유지된다."""
    ang = (max(-1.0, min(1.0, pan)) + 1.0) * 0.25 * math.pi
    out = np.empty(len(s) * 2)
    out[0::2] = s * math.cos(ang) * math.sqrt(2.0)
    out[1::2] = s * math.sin(ang) * math.sqrt(2.0)
    pk = np.abs(out).max()
    if pk > 1e-9:
        out *= 10 ** (TARGET_PEAK_DB / 20.0) / pk
    return out


def write_wav16(path: Path, a: np.ndarray, sr: int, channels: int = 1) -> None:
    pcm = (np.clip(a, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm)


def main() -> None:
    if not SRC.is_dir():
        sys.exit(f"원본 폴더가 없다: {SRC}")
    DEST.mkdir(parents=True, exist_ok=True)
    LICENSE_DEST.parent.mkdir(parents=True, exist_ok=True)

    print(f"{'출력':<20}{'원본':<22}{'길이':>9}{'용도'}")
    print("-" * 96)
    rms = {}
    for src_name, out_name, keep_ms, fade_ms, punch_db, punch_ms, lead_ms, pan, note in CUTS:
        src = SRC / src_name
        if not src.is_file():
            sys.exit(f"원본 파일 없음: {src}")
        a, sr = load_mono(src)
        s = cut(a, sr, keep_ms, fade_ms, punch_db, punch_ms, lead_ms)
        rms[out_name] = float(np.sqrt((s ** 2).mean()))   # 패닝 전 모노 기준
        ch = 1
        if abs(pan) > 1e-6:
            s, ch = to_stereo(s, pan), 2
        write_wav16(DEST / out_name, s, sr, ch)
        tag = f" · {'좌' if pan < 0 else '우'} {abs(pan):.2f}" if ch == 2 else ""
        tag += f" · 앞 무음 {lead_ms:.0f}ms" if lead_ms else ""
        print(f"{out_name:<21}{src_name.split('__')[-1]:<22}"
              f"{len(a)/sr:>5.2f}s→{len(s)/sr/ch if ch==1 else len(s)/sr/2:.2f}s{tag}")
        print(f"{'':21}{note}")

    a_name, b_name = BARREL_MATCH
    if a_name in rms and b_name in rms:
        comp = 20 * math.log10(rms[a_name] / max(rms[b_name], 1e-9))
        print("")
        print(f"포신 RMS 보정: {b_name} 를 {comp:+.1f} dB 하면 {a_name} 와 같은 크기로 들린다.")
        print("  → audio_manager.gd 의 turret_fire_b 의 db 에 이 값이 반영돼 있어야 한다.")

    lic = SRC / "_readme_and_license.txt"
    if lic.is_file():
        header = (
            "이 프로젝트에서 사용 중인 파일 (Tools/stage_gunshot_audio.py 로 잘라낸 것):\n"
            + "".join(f"  {o:<20} ← {s}\n" for s, o, *_ in CUTS)
            + "\n라이선스: CC BY 4.0 — 크레딧 표기 의무. Docs/CREDITS.md 참고.\n"
            + "표기 문구: Gun Sounds 01 by GokhanBiyik (freesound.org), CC BY 4.0\n"
            + "\n" + "=" * 70 + "\n원본 팩에 동봉된 라이선스 원문\n" + "=" * 70 + "\n\n"
        )
        LICENSE_DEST.write_text(header + lic.read_text(encoding="utf-8", errors="replace"),
                                encoding="utf-8")
        print(f"\n라이선스 사본: {LICENSE_DEST}")

    print("\n다음: Godot 을 한 번 띄워 임포트시킨 뒤 연사를 길게 눌러 확인할 것.")


if __name__ == "__main__":
    main()
