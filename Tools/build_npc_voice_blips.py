# -*- coding: utf-8 -*-
"""NPC 말소리 소재를 합성한다 — 대사 음성 방식(DialogueVoice.PRESETS) 전부가 이 파일에서 나온다.

낱말을 읽어 주는 성우가 아니라 **"지금 이 사람이 말하고 있다"는 신호**를 만든다.
소재는 세 갈래이고, 방식(프리셋)이 그중 무엇을 어떻게 쓸지 정한다.

  1) 모음 블립   <말투>_<모음>.wav      글자마다 하나씩 울리는 짧은 조각. 모음 7종
                                        · "모음 블립" 방식은 아무거나 고르고
                                        · "음소 블립" 방식은 **그 글자의 실제 모음**을 고른다
  2) 웅얼거림    <말투>_murmur.wav      말하는 동안 계속 도는 이음 루프. 글자 단위 반복이 아예 없다
  3) 줄머리 한마디 <말투>_open_0N.wav   줄 시작에 한 번만 나는 두세 음절 무의미어

합성 구조는 사람 목소리를 아주 거칠게 흉내 낸 것이다.
  성대(톱니파 = 배음 1/n) → 포먼트 공명 2~3개(모음을 정하는 것은 여기다) → 엔벨로프
말투(dialogue_bubble.gd VOICES)마다 기본 주파수·포먼트 배율·길이가 다르다.
UNIT-7(machine)만 성대 대신 사각파 + 링 모듈레이션 + 샘플 홀드를 쓴다. 합성음이어야 하므로.

루프는 **경계가 들리면 안 된다.** 그래서 파형을 루프 길이의 정수 배 주기로만 만들고
(f0·변조 주파수를 1/L 의 정수 배로 반올림), 공명기는 신호를 세 번 이어 붙여 필터한 뒤
가운데 토막만 잘라 쓴다 — 필터 시작 과도가 루프 안에 남지 않게.

사용:
    python Tools/build_npc_voice_blips.py
출력:
    GodotPrototype/assets/audio/sfx/voice/*.wav   (모노 44.1kHz 16bit)
"""

import math
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "GodotPrototype/assets/audio/sfx/voice"

# 모음 7종. (F1, F2, F3) Hz — 성인 남성 기준값이고 말투별 fscale 로 옮긴다.
# 한글 중성 21자는 dialogue_bubble.gd 가 이 7종으로 접어 넣는다 (ㅑ→a, ㅘ→a, ㅟ→i …).
VOWELS = {
    "a":  (730, 1090, 2440),    # ㅏ
    "eo": (610,  990, 2400),    # ㅓ
    "o":  (450,  820, 2350),    # ㅗ
    "u":  (350,  740, 2300),    # ㅜ
    "eu": (400, 1300, 2400),    # ㅡ
    "i":  (300, 2280, 2900),    # ㅣ
    "e":  (500, 1900, 2600),    # ㅔ
}
VOWEL_ORDER = ["a", "eo", "o", "u", "eu", "i", "e"]

# 말투별 합성 설정.
#   f0      성대 주파수. 낮을수록 나이 들고 큰 몸으로 들린다
#   fscale  포먼트 배율 — 성도 길이. 큰 사람일수록 낮다(<1)
#   dur     블립 하나의 길이(초). 짧을수록 딱딱 끊어 말하는 결
#   glide   블립 안에서 음높이가 내려가는 비율 (말끝을 흐리는 결)
#   breath  숨소리(노이즈) 섞는 양
#   tilt    배음 감쇠 지수. 클수록 어둡고 부드럽다
#   open    줄머리 한마디 세 벌 — (모음, 길이배율) 의 나열. 두세 음절이면 충분하다
VOICES = {
    # 에어록 관리인 아르카디 · 델 박사 — 60대, 낮고 느리고 말끝을 흘린다
    "slow": {
        "f0": 104.0, "fscale": 0.93, "dur": 0.135, "glide": -0.06, "breath": 0.05, "tilt": 1.25,
        "open": [[("eo", 1.6), ("a", 1.9)], [("eu", 1.3), ("o", 2.0)], [("a", 1.5), ("eo", 1.2), ("a", 1.8)]],
    },
    # 수경재배사 미나 — 부드럽다. 고역 배음을 줄여 숨결이 남게
    "soft": {
        "f0": 194.0, "fscale": 1.06, "dur": 0.115, "glide": -0.03, "breath": 0.09, "tilt": 1.45,
        "open": [[("a", 1.4), ("o", 1.8)], [("eu", 1.5), ("a", 1.6)], [("o", 1.2), ("a", 1.3), ("eu", 1.7)]],
    },
    # 방어망 관제원 세린 — 짧게 끊어 붙인다. 감쇠가 빨라 "탁" 하고 멈춘다
    "clipped": {
        "f0": 178.0, "fscale": 1.04, "dur": 0.072, "glide": -0.01, "breath": 0.03, "tilt": 1.0,
        "open": [[("e", 1.3), ("a", 1.4)], [("a", 1.2), ("e", 1.2)], [("eo", 1.1), ("a", 1.3), ("e", 1.1)]],
    },
    # 연구원 유나 — 빠르고 높다. 끝이 살짝 올라간다
    "quick": {
        "f0": 234.0, "fscale": 1.10, "dur": 0.068, "glide": 0.04, "breath": 0.04, "tilt": 1.05,
        "open": [[("a", 1.2), ("i", 1.3), ("a", 1.5)], [("e", 1.1), ("a", 1.4)], [("i", 1.2), ("a", 1.2), ("e", 1.4)]],
    },
    # UNIT-7 — 사람 목소리가 아니다. 사각파 + 링 모듈레이션 + 샘플 홀드
    "machine": {
        "f0": 132.0, "fscale": 1.0, "dur": 0.085, "glide": -0.02, "breath": 0.02, "tilt": 0.9,
        "ring": 74.0, "hold": 7,
        "open": [[("o", 1.2), ("eu", 1.4)], [("eu", 1.1), ("o", 1.1), ("eu", 1.3)], [("o", 1.3), ("o", 1.0)]],
    },
}

MURMUR_LEN = 1.6        # 웅얼거림 루프 길이(초)
MURMUR_WANDER = 2       # 루프 한 바퀴 동안 모음이 오가는 횟수
MURMUR_SYLL = 7         # 루프 한 바퀴 동안의 음절 수 (약 4.4Hz — 사람이 말하는 속도)


# -- 소재 --------------------------------------------------------------------

def glottal(f0: float, n: int, glide: float, square: bool, tilt: float, breath: float,
            seed: int = 7) -> np.ndarray:
    """성대 파형. 음높이가 블립 안에서 조금 미끄러진다(위상 적분)."""
    t = np.arange(n) / SR
    f = f0 * (1.0 + glide * (t / max(t[-1], 1e-6)))
    ph = 2.0 * math.pi * np.cumsum(f) / SR
    if square:
        out = np.sign(np.sin(ph)) * 0.6
    else:
        out = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
    h = 1
    while f0 * h < SR * 0.45:
        out += 0.5 * np.sin(ph * h) / (h ** tilt)
        h += 1
    return out + np.random.default_rng(seed).normal(0.0, 1.0, n) * breath


def formant(x: np.ndarray, freq: float, bw: float, gain: float) -> np.ndarray:
    """2극 공명기 하나. 포먼트가 곧 모음이고, 모음이 곧 "사람 소리" 다."""
    r = math.exp(-math.pi * bw / SR)
    theta = 2.0 * math.pi * freq / SR
    b1, b2 = 2.0 * r * math.cos(theta), -r * r
    a0 = (1.0 - r) * math.sqrt(1.0 - 2.0 * r * math.cos(2.0 * theta) + r * r)
    y = np.zeros(len(x))
    y1 = y2 = 0.0
    for i, s in enumerate(x):
        v = a0 * s + b1 * y1 + b2 * y2
        y[i] = v
        y2, y1 = y1, v
    return y * gain


def vocal_tract(x: np.ndarray, vowel: str, fscale: float) -> np.ndarray:
    f1, f2, f3 = VOWELS[vowel]
    return (formant(x, f1 * fscale, 90.0, 1.0)
            + formant(x, f2 * fscale, 120.0, 0.55)
            + formant(x, f3 * fscale, 180.0, 0.22))


def machine_color(x: np.ndarray, cfg: dict) -> np.ndarray:
    """기계 인물 전용 — 링 모듈레이션 + 샘플 홀드(거친 해상도)."""
    if "ring" not in cfg:
        return x
    t = np.arange(len(x)) / SR
    y = x * (0.65 + 0.35 * np.sin(2.0 * math.pi * cfg["ring"] * t))
    hold = cfg["hold"]
    return np.repeat(y[::hold], hold)[:len(x)]


def envelope(n: int, attack: float, decay: float) -> np.ndarray:
    a = max(int(SR * attack), 2)
    env = np.ones(n)
    env[:a] = np.linspace(0.0, 1.0, a) ** 0.6
    t = np.arange(n - a) / SR
    env[a:] = np.exp(-t / decay)
    env[-64:] *= np.linspace(1.0, 0.0, 64)      # 끝을 0 으로 — 클릭 방지
    return env


def norm(x: np.ndarray, peak: float = 0.72) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    return x / m * peak if m > 0 else x


def blip(cfg: dict, vowel: str, dur_mul: float = 1.0, pitch_mul: float = 1.0) -> np.ndarray:
    n = int(SR * cfg["dur"] * dur_mul)
    src = glottal(cfg["f0"] * pitch_mul, n, cfg["glide"], "ring" in cfg, cfg["tilt"], cfg["breath"])
    out = machine_color(vocal_tract(src, vowel, cfg["fscale"]), cfg)
    return out * envelope(n, 0.006, cfg["dur"] * dur_mul * 0.42)


def opener(cfg: dict, syllables: list) -> np.ndarray:
    """줄머리 한마디 — 음절 두셋을 이어 붙이고 전체 음높이를 끝으로 갈수록 떨어뜨린다.

    사람은 말을 시작할 때 목을 한 번 고른다. 그 한 번만 소리로 내고 나머지 줄은
    조용히 두는 방식(프리셋 "줄머리 한마디")이 이 파일을 쓴다.
    """
    parts = []
    for i, (vowel, dur_mul) in enumerate(syllables):
        drop = 1.0 - 0.07 * i                            # 음절마다 조금씩 낮아진다
        parts.append(blip(cfg, vowel, dur_mul, drop))
        if i < len(syllables) - 1:
            parts.append(np.zeros(int(SR * 0.035)))      # 음절 사이 짧은 틈
    return norm(np.concatenate(parts))


def murmur(cfg: dict) -> np.ndarray:
    """말하는 동안 계속 도는 웅얼거림 루프.

    이음매가 들리지 않아야 하므로 **모든 주기 성분을 루프 길이의 정수 배**로 맞추고,
    공명기는 신호를 세 번 이어 붙여 통과시킨 뒤 가운데 토막만 쓴다.
    """
    n = int(SR * MURMUR_LEN)
    cycles = max(round(cfg["f0"] * MURMUR_LEN), 1)
    f0 = cycles / MURMUR_LEN                             # 루프 안에 정확히 정수 주기
    t3 = np.arange(n * 3) / SR
    ph = 2.0 * math.pi * f0 * t3
    if "ring" in cfg:
        src = np.sign(np.sin(ph)) * 0.6
    else:
        src = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
    h = 1
    while f0 * h < SR * 0.45:
        src += 0.5 * np.sin(ph * h) / (h ** cfg["tilt"])
        h += 1
    src += np.random.default_rng(11).normal(0.0, 1.0, n * 3) * cfg["breath"]

    # 기계 인물의 링 주파수도 루프 길이의 정수 배로 맞춘다 — 안 맞추면 이음매에서 틱 소리가 난다
    # (샘플 홀드는 n 이 hold 로 나누어떨어지므로 그대로 둬도 이어진다)
    if "ring" in cfg:
        cfg = dict(cfg)
        cfg["ring"] = max(round(cfg["ring"] * MURMUR_LEN), 1) / MURMUR_LEN

    # 모음 둘 사이를 천천히 오간다 — 한 모음으로 고정하면 "삐-" 하는 톤이 된다
    a = machine_color(vocal_tract(src, "eo", cfg["fscale"]), cfg)[n:n * 2]
    b = machine_color(vocal_tract(src, "o" if "ring" in cfg else "a", cfg["fscale"]), cfg)[n:n * 2]
    t = np.arange(n) / SR
    mix = 0.5 + 0.5 * np.sin(2.0 * math.pi * MURMUR_WANDER / MURMUR_LEN * t)
    out = a * mix + b * (1.0 - mix)

    # 음절 리듬 — 진폭이 4~5Hz 로 드나든다. 이게 없으면 사이렌이지 말이 아니다
    syll = 0.5 + 0.5 * np.sin(2.0 * math.pi * MURMUR_SYLL / MURMUR_LEN * t - math.pi * 0.5)
    out *= 0.35 + 0.65 * syll ** 1.6
    return norm(out, 0.62)


# -- 출력 --------------------------------------------------------------------

def write_wav(path: Path, data: np.ndarray) -> None:
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made = 0
    for name, cfg in VOICES.items():
        for vowel in VOWEL_ORDER:
            write_wav(OUT / ("%s_%s.wav" % (name, vowel)), norm(blip(cfg, vowel)))
            made += 1
        for i, syllables in enumerate(cfg["open"], start=1):
            write_wav(OUT / ("%s_open_%02d.wav" % (name, i)), opener(cfg, syllables))
            made += 1
        write_wav(OUT / ("%s_murmur.wav" % name), murmur(cfg))
        made += 1
        print("%-9s  모음 %d · 줄머리 %d · 웅얼 1" % (name, len(VOWEL_ORDER), len(cfg["open"])))
    print("총 %d 개 -> %s" % (made, OUT))


if __name__ == "__main__":
    main()
