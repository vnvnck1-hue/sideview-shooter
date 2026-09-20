# -*- coding: utf-8 -*-
"""총격음 프리셋 후보를 게임과 같은 조건으로 합성해 단일 HTML 로 만든다.

파일 하나씩 들어서는 판단할 수 없다. 실제로 귀에 닿는 것은
**여러 레이어가 겹치고 → 방이 울리고 → 리미터를 거친 결과**이기 때문이다.
그래서 여기서는 그 전 과정을 그대로 재현한다.

  레이어 합성(보디·어택·저역) → 방 음향(슬랩백 ×2 + 리버브) → 마스터 리미터

수치는 전부 audio_manager.gd / player.gd / sentry_turret.gd 에서 가져온다.
프리셋을 고르면 그 구성을 그대로 코드에 옮기면 된다.

사용:
    python Tools/build_gunshot_presets.py [출력경로.html]
"""

import base64
import io
import json
import math
import sys
import wave
from pathlib import Path

import numpy as np

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC = Path(r"C:\Users\vnvnc\Downloads\23279__gokhanbiyik__gun-sounds-01")
KENNEY = Path("GodotPrototype/assets/audio/sfx/weapon")   # fire_metal_01/02.ogg (Kenney CC0)
OUT_DEFAULT = Path("Docs/_audition/gunshot_presets.html")

SR = 44100

# --- 게임에서 가져온 값 -------------------------------------------------------
PLAYER_RATE = 0.09       # player.gd FIRE_COOLDOWN (≈11발/초)
TURRET_RATE = 0.055      # sentry_turret.gd FIRE_COOLDOWN (≈18발/초, 포신 2개 교대)
FIRST_BOOST = 2.5        # audio_manager.gd FIRE_FIRST_BOOST
WEAPON_LPF = 9500.0      # LOWPASS[BUS_WEAPON]
LIMIT_CEIL = -1.5        # 마스터 하드리미터 ceiling
LIMIT_REL = 0.035        # 〃 release

# 미리듣기를 어느 방에서 들을 것인가. workshop(1792px = 14m) — 맵의 중앙값 크기.
ROOM_W_PX = 1792.0
PX_PER_M, SOUND_MPS = 128.0, 343.0
ROOM_SLAP = ROOM_W_PX / PX_PER_M / SOUND_MPS      # 40.8ms
ROOM_SLAP2 = ROOM_SLAP * 1.68
ROOM_SLAP_DB = -15.0
ROOM_WET, ROOM_T60 = 0.17, 0.55


# --- 레이어 정의 --------------------------------------------------------------
# src    : 원본 파일 이름 (SRC 폴더 기준) 또는 "kenney:fire_metal_01.ogg"
# trim   : 남길 길이 ms (0 = 전체)
# punch  : 어택 강조 dB / punch_ms: 그 감쇠 길이
# db     : 믹스 레벨 (audio_manager 의 SOUNDS db 에 대응)
# pitch  : 피치 배율
# delay  : 이 레이어만 늦게 시작 (ms) — 겹쳐 쌓을 때 두께를 만든다
def L(src, trim=130, fade=26, punch=0.0, punch_ms=9, db=-6.0, pitch=1.0, delay=0.0, pan=0.0):
    return dict(src=src, trim=trim, fade=fade, punch=punch, punch_ms=punch_ms,
                db=db, pitch=pitch, delay=delay, pan=pan)


G = "413094__gokhanbiyik__gunshort03.wav"     # 밝다, 어택 4ms
G12 = "413115__gokhanbiyik__gunshort12.wav"   # 중간 밝기
G10 = "413101__gokhanbiyik__gunshort10.wav"   # 가장 짧다 0.12s
G08 = "413097__gokhanbiyik__gunshort08.wav"
G06 = "413099__gokhanbiyik__gunshort06.wav"   # 저역 94%, 현재 센트리건
G04 = "413093__gokhanbiyik__gunshort04.wav"   # 어택 53ms, 부풀어 오른다
S03 = "413120__gokhanbiyik__gunsound03.wav"   # 어택 5ms, 고역 12% — 실총 크랙
S16 = "413110__gokhanbiyik__gunsound16.wav"   # 중역 59% — 유일한 중역 중심
S13 = "413111__gokhanbiyik__gunsound13.wav"   # 0.81s, 가장 무겁다
MG4 = "413127__gokhanbiyik__mg04.wav"         # 저역 97%, 현재 서브
MG2 = "413125__gokhanbiyik__mg02.wav"         # 저역 98%, 가장 순수
MG1 = "413126__gokhanbiyik__mg01.wav"         # 저역 96%, 0.50s
KM = "kenney:fire_metal_01.ogg"

PLAYER = [
    {
        "id": "p0", "name": "현재 구성", "tag": "기준",
        "why": "지금 게임에 들어가 있는 것. 나머지를 이것과 비교해서 들어 주면 된다.",
        "bodies": [L(G, punch=5.0, db=-4.0), L(G12, punch=5.0, db=-4.0)],
        "extra": [L(KM, trim=120, punch=0.0, db=-11.0, pitch=0.84),
                  L(MG4, trim=150, fade=34, punch=3.0, punch_ms=18, db=-8.0)],
    },
    {
        "id": "p1", "name": "실총 크랙", "tag": "어택 교체",
        "why": "Kenney 금속 타격 대신 <b>실제 총성의 고역부</b>(gunsound03, 어택 5ms·고역 12%)를 "
               "어택 레이어로 쓴다. 금속음 특유의 '깡'이 빠지고 화약이 터지는 쪽으로 간다.",
        "bodies": [L(G, punch=5.0, db=-4.0), L(G12, punch=5.0, db=-4.0)],
        "extra": [L(S03, trim=45, fade=14, punch=6.0, punch_ms=6, db=-9.0, pitch=1.06),
                  L(MG4, trim=150, fade=34, punch=3.0, punch_ms=18, db=-8.0)],
    },
    {
        "id": "p2", "name": "두껍게", "tag": "보디 2겹",
        "why": "보디를 <b>두 장 겹친다</b> — 두 번째를 7ms 늦춰 깔면 한 발이 두툼해진다. "
               "AAA 무기 사운드가 흔히 쓰는 방식. 대신 연사에서 가장 뭉치기 쉬운 구성이기도 하다.",
        "bodies": [L(G, punch=5.0, db=-5.0), L(G12, punch=5.0, db=-5.0)],
        "extra": [L(G10, trim=110, punch=2.0, db=-9.0, pitch=0.90, delay=7.0),
                  L(KM, trim=120, db=-13.0, pitch=0.84),
                  L(MG4, trim=150, fade=34, punch=3.0, punch_ms=18, db=-7.0)],
    },
    {
        "id": "p3", "name": "묵직하게", "tag": "저역 중심",
        "why": "보디를 반음 내리고 저역을 <b>mg02</b>(저역 98%, 가장 순수)로 바꿔 크게 깐다. "
               "총이 커지고 느려진 느낌. 가슴을 치는 쪽이다.",
        "bodies": [L(G12, punch=4.0, db=-4.5, pitch=0.92), L(G, punch=4.0, db=-4.5, pitch=0.92)],
        "extra": [L(KM, trim=120, db=-13.0, pitch=0.80),
                  L(MG2, trim=190, fade=44, punch=4.0, punch_ms=22, db=-5.5, pitch=0.94)],
    },
    {
        "id": "p4", "name": "날카롭게", "tag": "어택 극대",
        "why": "펀치를 <b>+9dB</b>까지 밀고 저역을 줄였다. 짧고 건조하고 매섭다. "
               "정비공이 든 값싼 총에는 이쪽이 맞을 수도 있다.",
        "bodies": [L(G, trim=110, fade=22, punch=9.0, punch_ms=7, db=-4.0),
                   L(G10, trim=110, fade=22, punch=9.0, punch_ms=7, db=-4.0)],
        "extra": [L(KM, trim=100, punch=4.0, db=-9.0, pitch=0.92),
                  L(MG4, trim=110, fade=28, punch=3.0, punch_ms=14, db=-11.0)],
    },
    {
        "id": "p5", "name": "전부 합쳐", "tag": "최대 임팩트",
        "why": "실총 크랙 + 보디 2겹 + 큰 저역을 모두 넣었다. 가장 강하지만 "
               "<b>연사에서 가장 위험한</b> 구성 — 길게 눌러 보고 뭉개지지 않는지 꼭 확인할 것.",
        "bodies": [L(G, punch=6.0, db=-4.5), L(G12, punch=6.0, db=-4.5)],
        "extra": [L(S03, trim=45, fade=14, punch=6.0, punch_ms=6, db=-9.0, pitch=1.06),
                  L(G10, trim=110, punch=2.0, db=-10.0, pitch=0.90, delay=7.0),
                  L(MG2, trim=170, fade=38, punch=4.0, punch_ms=20, db=-6.0)],
    },
]

TURRET = [
    {
        "id": "t0", "name": "현재 구성", "tag": "기준",
        "why": "지금 들어가 있는 것 — gunshort06 한 장. 저역뿐이라 거리감은 있는데 "
               "<b>때리는 맛이 없다.</b> 이게 지금 문제로 지적된 부분이다.",
        "bodies": [L(G06, trim=150, fade=30, punch=3.5, punch_ms=12, db=-6.0)],
        "extra": [],
    },
    {
        "id": "t1", "name": "크랙 추가", "tag": "어택 보강",
        "why": "저역은 그대로 두고 <b>고역 크랙</b>(gunsound03)을 얹는다. 거리감을 잃지 않으면서 "
               "'탕' 하는 지점이 생긴다. 가장 적은 변화로 가장 큰 효과.",
        "bodies": [L(G06, trim=150, fade=30, punch=3.5, punch_ms=12, db=-6.0)],
        "extra": [L(S03, trim=40, fade=12, punch=6.0, punch_ms=5, db=-12.0, pitch=1.12)],
    },
    {
        "id": "t2", "name": "2연장 교대", "tag": "포신 2개",
        "why": "센트리건은 <b>포신이 두 개고 번갈아</b> 쏜다(sentry_turret.gd). 그걸 소리로 만든다 — "
               "두 샘플을 좌우로 살짝 갈라 번갈아 재생. 초당 18발이 기계처럼 규칙적으로 들리던 게 "
               "'두 문이 교대로 때린다'로 바뀐다.",
        "bodies": [L(G06, trim=150, fade=30, punch=4.0, punch_ms=12, db=-6.0, pan=0.30),
                   L(G08, trim=150, fade=30, punch=4.0, punch_ms=12, db=-6.0, pitch=0.93, pan=-0.30)],
        "extra": [L(S03, trim=40, fade=12, punch=6.0, punch_ms=5, db=-13.0, pitch=1.12)],
        "alternate": True,
    },
    {
        "id": "t3", "name": "중화기", "tag": "무겁게",
        "why": "가장 무거운 샘플(gunsound13)을 짧게 잘라 쓰고 mg01 저역을 깐다. "
               "플레이어 총보다 확실히 <b>큰 무기</b>로 들린다. 18발/초에서 저역이 버티는지가 관건.",
        "bodies": [L(S13, trim=140, fade=30, punch=5.0, punch_ms=10, db=-5.5, pitch=0.90)],
        "extra": [L(MG1, trim=160, fade=36, punch=3.0, punch_ms=18, db=-9.0, pitch=0.92)],
    },
    {
        "id": "t4", "name": "2연장 + 중화기", "tag": "최대 임팩트",
        "why": "교대 재생에 중화기 톤과 저역까지 전부 얹었다. 센트리건이 가장 위협적으로 들리는 구성.",
        "bodies": [L(S13, trim=140, fade=28, punch=5.0, punch_ms=10, db=-6.0, pitch=0.90, pan=0.30),
                   L(S13, trim=140, fade=28, punch=5.0, punch_ms=10, db=-6.0, pitch=0.84, pan=-0.30)],
        "extra": [L(S03, trim=40, fade=12, punch=6.0, punch_ms=5, db=-13.0, pitch=1.08),
                  L(MG1, trim=160, fade=36, punch=3.0, punch_ms=18, db=-8.5, pitch=0.92)],
        "alternate": True,
    },
]


# --- 오디오 유틸 --------------------------------------------------------------
_cache = {}


def load_mono(name: str) -> np.ndarray:
    """SRC 의 24bit wav 또는 프로젝트의 Kenney ogg 를 SR 모노로."""
    if name in _cache:
        return _cache[name]
    if name.startswith("kenney:"):
        a, sr = _load_ogg_via_wav(KENNEY / name.split(":", 1)[1])
    else:
        a, sr = _load_wav(SRC / name)
    if sr != SR:
        a = np.interp(np.linspace(0, len(a) - 1, int(len(a) * SR / sr)), np.arange(len(a)), a)
    _cache[name] = a - a.mean()
    return _cache[name]


def _load_wav(p: Path):
    with wave.open(str(p), "rb") as w:
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


def _load_ogg_via_wav(p: Path):
    """Kenney 원본은 ogg 다. soundfile 로 읽는다 — 없으면 그 레이어만 빠지고 나머지는 정상 합성된다."""
    try:
        import soundfile as sf
        a, sr = sf.read(str(p), always_2d=True)
        return a.mean(axis=1), sr
    except Exception as e:
        print(f"  ! {p.name} 디코드 실패({e}) — 이 레이어는 빠진다")
        return np.zeros(int(SR * 0.05)), SR


def shape(a, trim_ms, fade_ms, punch_db, punch_ms, pitch):
    env = np.abs(a)
    pk = env.max()
    hits = np.nonzero(env >= pk * 0.05)[0]
    s = a[int(hits[0]):].copy() if len(hits) else a.copy()
    if trim_ms > 0:
        s = s[: int(SR * trim_ms / 1000.0)]
    if len(s) < 8:
        return s
    fi = max(1, int(SR * 0.0006))
    s[:fi] *= np.linspace(0.0, 1.0, fi)
    fo = min(len(s) - 1, int(SR * fade_ms / 1000.0))
    if fo > 1:
        s[-fo:] *= np.linspace(1.0, 0.0, fo) ** 1.5
    if punch_db > 0.0 and punch_ms > 0:            # 피크 기준 트랜지언트 강조
        g = 10 ** (punch_db / 20.0)
        pi = int(np.abs(s).argmax())
        e = np.ones(len(s))
        e[:min(pi + 1, len(s))] = g
        tl = min(int(SR * punch_ms / 1000.0), len(s) - pi - 1)
        if tl > 1:
            e[pi + 1:pi + 1 + tl] = 1.0 + (g - 1.0) * np.exp(-np.linspace(0.0, 4.0, tl))
        s *= e
    pk = np.abs(s).max()
    if pk > 1e-9:
        s *= 10 ** (-1.0 / 20.0) / pk              # 파일 기준 레벨 -1 dBFS
    if abs(pitch - 1.0) > 1e-6:
        n = max(1, int(round(len(s) / pitch)))
        s = np.interp(np.linspace(0, len(s) - 1, n), np.arange(len(s)), s)
    return s


_barrel_gain = {}


def _match_barrels(preset):
    """포신 교대 프리셋은 두 포신이 **같은 크기로** 들려야 한다.
    샘플마다 피크 대비 에너지가 달라서(-1dBFS 로 맞춰도 RMS 는 다르다) 그냥 두면
    좌우가 2dB쯤 어긋나고, 그건 '두 문이 교대'가 아니라 '한쪽이 크다'로 들린다.
    그래서 첫 포신의 RMS 를 기준으로 나머지를 맞춘다."""
    key = preset["id"]
    if key in _barrel_gain:
        return _barrel_gain[key]
    gains = []
    ref = None
    for cfg in preset["bodies"]:
        s = shape(load_mono(cfg["src"]), cfg["trim"], cfg["fade"],
                  cfg["punch"], cfg["punch_ms"], cfg["pitch"])
        rms = math.sqrt((s ** 2).mean()) if len(s) else 1.0
        if ref is None:
            ref = rms
        gains.append(ref / (rms + 1e-9))
    _barrel_gain[key] = gains
    return gains


def render_shot(preset, body_index=0):
    """한 발을 스테레오로 합성한다. (L, R)

    보디가 여럿이면 한 발에 하나만 나간다 — 배리에이션(반복감 제거)이거나 포신 교대다."""
    bodies = preset["bodies"]
    bi = body_index % len(bodies)
    layers = [bodies[bi]]
    body_gain = _match_barrels(preset)[bi] if preset.get("alternate") else 1.0
    layers += preset["extra"]

    n = 0
    built = []
    for cfg in layers:
        s = shape(load_mono(cfg["src"]), cfg["trim"], cfg["fade"],
                  cfg["punch"], cfg["punch_ms"], cfg["pitch"])
        s = s * 10 ** (cfg["db"] / 20.0)
        if cfg is layers[0]:
            s = s * body_gain           # 포신 교대일 때만 1.0 이 아니다
        off = int(SR * cfg["delay"] / 1000.0)
        built.append((s, off, cfg["pan"]))
        n = max(n, off + len(s))
    l = np.zeros(n)
    r = np.zeros(n)
    for s, off, pan in built:
        # 등출력 패닝: pan -1(좌) ~ 0(중앙) ~ +1(우). 가운데에서 이득이 1.0 이 되게 √2 를 곱한다.
        ang = (max(-1.0, min(1.0, pan)) + 1.0) * 0.25 * math.pi
        gl = math.cos(ang) * math.sqrt(2.0)
        gr = math.sin(ang) * math.sqrt(2.0)
        l[off:off + len(s)] += s * gl
        r[off:off + len(s)] += s * gr
    return l, r


def lowpass(a, hz, poles=2):
    alpha = (1.0 / SR) / (1.0 / (2 * math.pi * hz) + 1.0 / SR)
    out = a
    for _ in range(poles):
        y = np.empty_like(out)
        acc = 0.0
        for i, v in enumerate(out):
            acc += alpha * (v - acc)
            y[i] = acc
        out = y
    return out


def _room_ir(t60, seed=3):
    """지수 감쇠 노이즈 임펄스. 저역은 덜어낸다(SPACE_HIPASS 에 해당)."""
    rng = np.random.default_rng(seed)
    n = int(SR * t60)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-6.9 * t / t60)
    ir -= lowpass(ir, 180.0, 1)          # 저역 제거
    ir[: int(SR * 0.004)] = 0.0
    return ir / (np.abs(ir).max() + 1e-9)


_IR = None


def space(l, r):
    """슬랩백 2탭 + 리버브. audio_manager 의 Weapon 버스 구성과 같은 순서."""
    global _IR
    if _IR is None:
        _IR = (_room_ir(ROOM_T60, 3), _room_ir(ROOM_T60, 9))
    pad = int(SR * (ROOM_T60 + 0.35))
    l = np.concatenate([l, np.zeros(pad)])
    r = np.concatenate([r, np.zeros(pad)])
    l, r = lowpass(l, WEAPON_LPF), lowpass(r, WEAPON_LPF)

    g = 10 ** (ROOM_SLAP_DB / 20.0)
    d1, d2 = int(SR * ROOM_SLAP), int(SR * ROOM_SLAP2)
    dry_l, dry_r = l.copy(), r.copy()
    l[d1:] += dry_l[:-d1] * g * 0.45            # 탭1 은 오른쪽으로 치우친다
    r[d1:] += dry_r[:-d1] * g * 1.00
    l[d2:] += dry_l[:-d2] * g * 0.56 * 0.85     # 탭2 는 왼쪽
    r[d2:] += dry_r[:-d2] * g * 0.25 * 0.85

    def conv(x, ir):
        n = 1 << (len(x) + len(ir) - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x)]
        return y
    l = l + conv(l, _IR[0]) * ROOM_WET * 0.35
    r = r + conv(r, _IR[1]) * ROOM_WET * 0.35
    return l, r


def limiter(l, r):
    """마스터 하드리미터 흉내 — release 가 발사 간격보다 짧아 사이사이 회복한다."""
    ceil = 10 ** (LIMIT_CEIL / 20.0)
    env = np.maximum(np.abs(l), np.abs(r))
    gain = np.ones(len(env))
    g = 1.0
    coef = math.exp(-1.0 / (SR * LIMIT_REL))
    for i, v in enumerate(env):
        target = min(1.0, ceil / v) if v > ceil else 1.0
        g = target if target < g else target + (g - target) * coef
        gain[i] = g
    return l * gain, r * gain


def burst(preset, rate, shots):
    rng = np.random.default_rng(11)
    span = int(SR * (rate * (shots - 1) + ROOM_T60 + 1.0))
    l = np.zeros(span)
    r = np.zeros(span)
    for i in range(shots):
        sl, sr_ = render_shot(preset, body_index=i)
        jit = 10 ** (float(rng.uniform(-1.5, 1.5)) / 20.0)
        if i == 0:
            jit *= 10 ** (FIRST_BOOST / 20.0)
        p = float(rng.uniform(0.96, 1.04))
        if abs(p - 1.0) > 1e-6:
            n = max(1, int(round(len(sl) / p)))
            x = np.linspace(0, len(sl) - 1, n)
            sl = np.interp(x, np.arange(len(sl)), sl)
            sr_ = np.interp(x, np.arange(len(sr_)), sr_)
        at = int(i * rate * SR)
        k = min(len(sl), span - at)
        l[at:at + k] += sl[:k] * jit
        r[at:at + k] += sr_[:k] * jit
    return limiter(*space(l, r))


def wav_uri(l, r):
    n = min(len(l), len(r))
    inter = np.empty(n * 2)
    inter[0::2] = np.clip(l[:n], -1, 1)
    inter[1::2] = np.clip(r[:n], -1, 1)
    pcm = (inter * 32767.0).astype("<i2").tobytes()
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    return "data:audio/wav;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def env_path(l, r, width=320, height=42):
    a = np.maximum(np.abs(l), np.abs(r))
    pk = a.max() or 1.0
    bk = np.array_split(a, min(width, max(1, len(a))))
    top, bot = [], []
    for i, b in enumerate(bk):
        x = i * width / len(bk)
        v = (b.max() / pk) * (height / 2 - 1)
        top.append(f"{x:.1f},{height/2-v:.1f}")
        bot.append(f"{x:.1f},{height/2+v:.1f}")
    return "M" + " L".join(top + list(reversed(bot))) + " Z"


def peak_db(l, r):
    return 20 * math.log10(max(np.abs(l).max(), np.abs(r).max()) + 1e-9)


def rms_db(l, r):
    x = np.concatenate([l, r])
    return 20 * math.log10(math.sqrt((x ** 2).mean()) + 1e-9)


def build(out_path: Path):
    groups = []
    for title, presets, rate, shots, note in [
        ("플레이어 소총", PLAYER, PLAYER_RATE, 8,
         "초당 11발 · <code>player.gd FIRE_COOLDOWN 0.09</code>"),
        ("센트리건", TURRET, TURRET_RATE, 12,
         "초당 18발 · <code>sentry_turret.gd FIRE_COOLDOWN 0.055</code> · 포신 2개 교대"),
    ]:
        items = []
        for p in presets:
            print(f"  합성 중: {title} / {p['name']}")
            sl, sr_ = render_shot(p, 0)
            one = limiter(*space(sl, sr_))
            bl, br = burst(p, rate, shots)
            rows = []
            multi = len(p["bodies"]) > 1
            for cfg in p["bodies"] + p["extra"]:
                is_body = cfg in p["bodies"]
                nm = cfg["src"].split("__")[-1].replace(".wav", "").replace("kenney:", "")
                if cfg["src"].startswith("kenney"):
                    nm = "Kenney " + nm
                # 보디는 한 발에 하나만 나간다 — 여럿이면 배리에이션(또는 포신 교대)이다.
                role = "동시"
                if is_body and multi:
                    role = "포신 교대" if p.get("alternate") else "배리에이션"
                elif is_body:
                    role = "보디"
                rows.append({
                    "name": nm, "role": role,
                    "trim": cfg["trim"], "punch": cfg["punch"], "db": cfg["db"],
                    "pitch": cfg["pitch"], "delay": cfg["delay"], "pan": cfg["pan"],
                })
            items.append({
                "id": p["id"], "name": p["name"], "tag": p["tag"], "why": p["why"],
                "alt": bool(p.get("alternate")),
                "layers": rows,
                "one": wav_uri(*one), "burst": wav_uri(bl, br),
                "wave": env_path(bl, br),
                "peak": round(peak_db(bl, br), 1), "rms": round(rms_db(bl, br), 1),
            })
        groups.append({"title": title, "note": note, "items": items})

    payload = {"groups": groups, "room": {
        "w": int(ROOM_W_PX), "m": round(ROOM_W_PX / PX_PER_M, 1),
        "slap1": round(ROOM_SLAP * 1000, 1), "slap2": round(ROOM_SLAP2 * 1000, 1),
        "lpf": int(WEAPON_LPF)}}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(HTML.replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False)),
                        encoding="utf-8")
    print(f"\n완료: {out_path}  ({out_path.stat().st_size/1024/1024:.1f} MB)")


HTML = r"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>총격음 프리셋 비교</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Gothic+A1:wght@400;700;800&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+KR:wght@400;500&display=swap" rel="stylesheet">
<style>
:root{color-scheme:dark;--ground:#101319;--surface:#171B23;--surface-2:#1E232D;
--line:#2A303C;--line-soft:#222836;--ink:#DCE0E8;--ink-dim:#8B93A3;--ink-faint:#5E6675;
--amber:#E8A33D;--rust:#C4523E;--steel:#6E8BA8;--ok:#7FA663;
--display:'Gothic A1','Malgun Gothic',sans-serif;--body:'IBM Plex Sans KR','Malgun Gothic',sans-serif;
--mono:'IBM Plex Mono',ui-monospace,monospace;}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);font-family:var(--body);font-size:14px;line-height:1.65;padding-bottom:84px}
.wrap{max-width:1000px;margin:0 auto;padding:36px 20px 20px}
code{font-family:var(--mono);font-size:.92em;color:var(--amber)}
h1{font-family:var(--display);font-weight:800;font-size:25px;margin:0 0 6px}
.sub{color:var(--ink-dim);font-size:13px;margin:0 0 20px}
.sub b{color:var(--ink)}
.brief{border:1px solid var(--line);background:var(--surface);padding:14px 16px;border-radius:3px;margin:0 0 28px}
.brief h3{font-family:var(--display);font-weight:800;font-size:14px;margin:0 0 8px}
.brief p{margin:0 0 8px;font-size:13px;color:var(--ink-dim)}
.brief p:last-child{margin:0}
.brief b{color:var(--ink)}
.chain{font-family:var(--mono);font-size:11.5px;color:var(--ink-dim);background:var(--ground);
  border:1px solid var(--line-soft);border-radius:2px;padding:9px 12px;margin:10px 0 0;overflow-x:auto;white-space:nowrap}
.gh{border-bottom:1px solid var(--line);padding-bottom:10px;margin:36px 0 4px;display:flex;
  flex-wrap:wrap;gap:10px;align-items:baseline;justify-content:space-between}
.gh h2{font-family:var(--display);font-weight:800;font-size:18px;margin:0}
.gh .n{font-family:var(--mono);font-size:11px;color:var(--ink-faint)}
.card{border:1px solid var(--line-soft);background:var(--surface);border-radius:3px;padding:14px 16px;margin-top:12px}
.card.done{border-color:color-mix(in srgb,var(--ok) 45%,transparent)}
.card.no{opacity:.45}
.ct{display:flex;flex-wrap:wrap;gap:10px;align-items:baseline;justify-content:space-between}
.nm{font-family:var(--display);font-weight:800;font-size:15.5px}
.tag{font-family:var(--mono);font-size:10px;color:var(--amber);border:1px solid color-mix(in srgb,var(--amber) 45%,transparent);
  padding:2px 8px;border-radius:2px;margin-left:8px;vertical-align:middle}
.met{font-family:var(--mono);font-size:10.5px;color:var(--ink-faint)}
.why{font-size:13px;color:var(--ink-dim);margin:8px 0 0;max-width:76ch}
.why b{color:var(--ink)}
table.lay{width:100%;border-collapse:collapse;margin:11px 0 0;font-family:var(--mono);font-size:11px}
table.lay th{text-align:left;color:var(--ink-faint);font-weight:400;border-bottom:1px solid var(--line-soft);padding:4px 8px 4px 0}
table.lay td{color:var(--ink-dim);padding:3px 8px 3px 0;border-bottom:1px solid var(--line-soft)}
table.lay td:first-child{color:var(--ink)}
svg.w{display:block;width:100%;height:42px;margin:11px 0 0}
svg.w path{fill:color-mix(in srgb,var(--steel) 50%,transparent)}
.card.done svg.w path{fill:color-mix(in srgb,var(--ok) 45%,transparent)}
svg.w rect.ph{fill:var(--amber);width:1.5px}
.plays{display:flex;flex-wrap:wrap;gap:7px;margin:10px 0 0}
.pl{font-family:var(--mono);font-size:11.5px;background:var(--surface-2);border:1px solid var(--line);
  color:var(--ink-dim);padding:6px 13px;border-radius:2px;cursor:pointer;display:flex;gap:7px;align-items:center}
.pl:hover{border-color:var(--steel);color:var(--ink)}
.pl.on{border-color:var(--amber);color:var(--amber)}
.pl.key{background:color-mix(in srgb,var(--amber) 12%,var(--surface-2));border-color:color-mix(in srgb,var(--amber) 40%,transparent);color:var(--ink)}
.pl .t{width:0;height:0;border-left:6px solid currentColor;border-top:4px solid transparent;border-bottom:4px solid transparent}
.pl.on .t{border:none;width:7px;height:8px;background:currentColor}
.verd{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:12px 0 0;border-top:1px solid var(--line-soft);padding-top:11px}
.vl{font-family:var(--mono);font-size:10.5px;color:var(--ink-faint)}
.v{font-family:var(--mono);font-size:11.5px;background:none;border:1px solid var(--line);color:var(--ink-faint);
  padding:5px 14px;border-radius:2px;cursor:pointer}
.v:hover{border-color:var(--steel);color:var(--ink-dim)}
.v[aria-pressed="true"][data-v="pick"]{background:color-mix(in srgb,var(--ok) 20%,transparent);border-color:var(--ok);color:var(--ok)}
.v[aria-pressed="true"][data-v="no"]{background:color-mix(in srgb,var(--rust) 18%,transparent);border-color:var(--rust);color:var(--rust)}
.memo{flex:1 1 220px;min-width:170px;background:var(--surface-2);border:1px solid var(--line);color:var(--ink);
  font-family:var(--body);font-size:12.5px;padding:6px 10px;border-radius:2px}
.memo:focus{outline:none;border-color:var(--steel)}
.dock{position:fixed;left:0;right:0;bottom:0;z-index:10;background:color-mix(in srgb,var(--surface) 95%,transparent);
  backdrop-filter:blur(8px);border-top:1px solid var(--line);padding:11px 20px;
  padding-bottom:calc(11px + env(safe-area-inset-bottom,0px));display:flex;flex-wrap:wrap;gap:12px;
  align-items:center;justify-content:space-between}
.dock .l{font-family:var(--mono);font-size:11.5px;color:var(--ink-dim)}
.dock .l b{color:var(--amber);font-weight:500}
.dock button{font-family:var(--mono);font-size:11.5px;background:var(--surface-2);border:1px solid var(--line);
  color:var(--ink-dim);padding:7px 14px;border-radius:2px;cursor:pointer;margin-left:9px}
.dock button:hover{border-color:var(--steel);color:var(--ink)}
.dock button.primary{background:color-mix(in srgb,var(--amber) 16%,var(--surface-2));
  border-color:color-mix(in srgb,var(--amber) 50%,transparent);color:var(--amber)}
.out{position:fixed;inset:0;z-index:20;background:color-mix(in srgb,var(--ground) 93%,transparent);display:none;padding:34px 20px;overflow:auto}
.out.open{display:block}
.out .box{max-width:820px;margin:0 auto;background:var(--surface);border:1px solid var(--line);border-radius:3px;padding:18px}
.out h3{font-family:var(--display);font-weight:800;font-size:16px;margin:0 0 4px}
.out p{font-size:13px;color:var(--ink-dim);margin:0 0 12px}
.out textarea{width:100%;height:46vh;background:var(--ground);border:1px solid var(--line);color:var(--ink);
  font-family:var(--mono);font-size:12px;padding:12px;border-radius:2px}
</style></head><body><div class="wrap">

<h1>총격음 프리셋 비교</h1>
<p class="sub">플레이어 6개 · 센트리건 5개. <b>연사로 들어 보고 하나씩 골라 주면 된다.</b><br>
전부 지금 게임과 같은 조건으로 합성했다 — 레이어 겹침 · 방 울림 · 마스터 리미터까지.</p>

<div class="brief">
  <h3>어떻게 만들었나</h3>
  <p>파일 하나씩 들어서는 판단이 안 된다. 실제로 귀에 닿는 건 <b>레이어가 겹치고 → 방이 울리고 →
     리미터를 거친 결과</b>라서, 그 과정을 그대로 재현했다. 수치는 전부 코드에서 가져왔다.</p>
  <div class="chain" id="chain"></div>
  <p style="margin-top:10px"><b>역할</b> 열의 "배리에이션"·"포신 교대"는 <b>한 발에 하나만</b> 나간다는 뜻이다
     (반복감을 지우는 용도). "동시"는 매 발 같이 겹친다.</p>
  <p><b>단발보다 연사를 먼저 들어 달라.</b> 단발로는 다 그럴듯하게 들린다.
     차이가 갈리는 건 초당 11발(센트리건은 18발)로 쏟아질 때 <b>뭉개지느냐 버티느냐</b>다.</p>
  <p>미리듣기는 <b>작업실</b>(폭 1792px = 14m) 기준이다. 좁은 통로나 격납고에서는 울림이 더 짧거나 길어진다.</p>
</div>

<div id="groups"></div>
</div>

<div class="dock">
  <div class="l">플레이어 <b id="p1">—</b> · 센트리건 <b id="p2">—</b></div>
  <div><button id="stop">재생 정지</button><button id="exp" class="primary">결과 복사</button></div>
</div>

<div class="out" id="out"><div class="box">
  <h3>선택 결과</h3><p>복사해서 붙여넣어 주면 그대로 적용하겠다.</p>
  <textarea id="txt" spellcheck="false"></textarea>
  <div style="display:flex;gap:9px;margin-top:12px">
    <button id="cp" class="primary" style="font-family:var(--mono);font-size:12px;background:color-mix(in srgb,var(--amber) 16%,var(--surface-2));border:1px solid color-mix(in srgb,var(--amber) 50%,transparent);color:var(--amber);padding:8px 16px;border-radius:2px;cursor:pointer">클립보드로 복사</button>
    <button id="cl" style="font-family:var(--mono);font-size:12px;background:var(--surface-2);border:1px solid var(--line);color:var(--ink-dim);padding:8px 16px;border-radius:2px;cursor:pointer">닫기</button>
  </div>
</div></div>

<script>
const DATA=/*__DATA__*/null;
const KEY="gunshot-presets-v1";
const st=JSON.parse(localStorage.getItem(KEY)||"{}");
const esc=s=>String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
let au=null,cur=null,raf=0;
function stop(){if(au){au.pause();au=null}if(cur){cur.classList.remove("on");cur=null}
  cancelAnimationFrame(raf);document.querySelectorAll("rect.ph").forEach(r=>r.setAttribute("x",-5));}
function play(b,src,svg){const again=cur===b;stop();if(again)return;
  au=new Audio(src);cur=b;b.classList.add("on");au.play().catch(()=>{});au.onended=stop;
  if(svg){const ph=svg.querySelector("rect.ph");const tk=()=>{if(!au)return;
    ph.setAttribute("x",(au.currentTime/(au.duration||1))*320);raf=requestAnimationFrame(tk)};raf=requestAnimationFrame(tk)}}

const R=DATA.room;
document.getElementById("chain").textContent=
 `레이어 합성 → LowPass ${R.lpf}Hz → 슬랩백 ${R.slap1}ms / ${R.slap2}ms → 리버브 → 하드리미터 -1.5dB (release 35ms)   ·   방: ${R.w}px = ${R.m}m`;

function lay(L){
  const c=[];
  if(L.pitch!==1) c.push(`피치 ${L.pitch}`);
  if(L.delay) c.push(`+${L.delay}ms`);
  if(L.pan) c.push(L.pan>0?"우":"좌");
  return `<tr><td>${esc(L.name)}</td><td>${esc(L.role)}</td><td>${L.trim||"전체"}ms</td>
  <td>${L.punch?"+"+L.punch+"dB":"—"}</td><td>${L.db}dB</td><td>${c.join(" · ")||"—"}</td></tr>`;
}
function card(it){
  const v=st[it.id];
  return `<div class="card ${v==="pick"?"done":""} ${v==="no"?"no":""}" data-id="${it.id}">
   <div class="ct"><div><span class="nm">${esc(it.name)}</span><span class="tag">${esc(it.tag)}</span></div>
   <span class="met">피크 ${it.peak}dB · RMS ${it.rms}dB${it.alt?" · 교대 재생":""}</span></div>
   <p class="why">${it.why}</p>
   <table class="lay"><tr><th>레이어</th><th>역할</th><th>길이</th><th>펀치</th><th>레벨</th><th>기타</th></tr>
   ${it.layers.map(lay).join("")}</table>
   <svg class="w" viewBox="0 0 320 42" preserveAspectRatio="none"><path d="${it.wave}"></path><rect class="ph" x="-5" y="0" height="42"></rect></svg>
   <div class="plays"><button class="pl" data-k="one"><span class="t"></span>단발</button>
   <button class="pl key" data-k="burst"><span class="t"></span>연사</button></div>
   <div class="verd"><span class="vl">판정</span>
   <button class="v" data-id="${it.id}" data-v="pick" aria-pressed="${v==="pick"}">이걸로</button>
   <button class="v" data-id="${it.id}" data-v="no" aria-pressed="${v==="no"}">아니다</button>
   <input class="memo" data-id="${it.id}" placeholder="한 줄 메모 (선택)" value="${esc((st[it.id+"_n"])||"")}"></div>
  </div>`;
}
document.getElementById("groups").innerHTML=DATA.groups.map(g=>`
 <div class="gh"><h2>${esc(g.title)}</h2><span class="n">${g.note}</span></div>
 ${g.items.map(card).join("")}`).join("");

const byId={};DATA.groups.forEach(g=>g.items.forEach(i=>byId[i.id]=i));
document.addEventListener("click",e=>{
 const p=e.target.closest(".pl");
 if(p){const h=p.closest("[data-id]");play(p,byId[h.dataset.id][p.dataset.k],h.querySelector("svg"));return}
 const v=e.target.closest(".v");
 if(v){const id=v.dataset.id,val=v.dataset.v;
  if(val==="pick"){ // 그룹 안에서 하나만
    const grp=DATA.groups.find(g=>g.items.some(i=>i.id===id));
    if(st[id]!=="pick") grp.items.forEach(i=>{if(st[i.id]==="pick")delete st[i.id]});
  }
  st[id]=st[id]===val?undefined:val;if(!st[id])delete st[id];
  save();render();}
});
document.addEventListener("input",e=>{if(e.target.classList.contains("memo")){
  st[e.target.dataset.id+"_n"]=e.target.value;save()}});
function save(){localStorage.setItem(KEY,JSON.stringify(st))}
function render(){
 document.querySelectorAll(".v").forEach(b=>b.setAttribute("aria-pressed",st[b.dataset.id]===b.dataset.v));
 document.querySelectorAll(".card").forEach(c=>{c.classList.toggle("done",st[c.dataset.id]==="pick");
  c.classList.toggle("no",st[c.dataset.id]==="no")});
 DATA.groups.forEach((g,i)=>{const p=g.items.find(it=>st[it.id]==="pick");
  document.getElementById("p"+(i+1)).textContent=p?p.name:"—"});
}
render();
document.getElementById("stop").onclick=stop;
document.getElementById("exp").onclick=()=>{stop();
 const L=["## 총격음 프리셋 선택 결과",""];
 DATA.groups.forEach(g=>{L.push(`### ${g.title}`);
  const p=g.items.find(i=>st[i.id]==="pick");
  L.push(p?`- **선택: ${p.name}** (\`${p.id}\`)${st[p.id+"_n"]?" — "+st[p.id+"_n"]:""}`:"- _선택 없음_");
  g.items.filter(i=>st[i.id]==="no").forEach(i=>L.push(`- 제외: ${i.name} (\`${i.id}\`)${st[i.id+"_n"]?" — "+st[i.id+"_n"]:""}`));
  L.push("")});
 document.getElementById("txt").value=L.join("\n");
 document.getElementById("out").classList.add("open")};
document.getElementById("cl").onclick=()=>document.getElementById("out").classList.remove("open");
document.getElementById("cp").onclick=async()=>{const t=document.getElementById("txt");t.select();
 try{await navigator.clipboard.writeText(t.value)}catch(e){document.execCommand("copy")}
 const b=document.getElementById("cp");b.textContent="복사됨";setTimeout(()=>b.textContent="클립보드로 복사",1400)};
document.addEventListener("keydown",e=>{if(e.key==="Escape"){stop();document.getElementById("out").classList.remove("open")}});
</script></body></html>
"""

if __name__ == "__main__":
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else OUT_DEFAULT)
