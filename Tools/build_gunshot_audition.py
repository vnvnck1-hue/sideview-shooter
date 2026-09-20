# -*- coding: utf-8 -*-
"""GokhanBiyik "Gun Sounds 01" 팩(Freesound 23279)을 귀로 판정하기 위한 단일 HTML을 만든다.

원본 재생만으로는 게임에서 어떻게 들릴지 알 수 없다. 그래서 세 가지를 같이 들려준다.

  1. 원본        — 받은 파일 그대로 (모노 48k 16bit 로만 변환)
  2. 가공본      — 용도에 맞게 자르고 Weapon 버스 로우패스(6.5 kHz)를 먹인 것
  3. 연사        — 초당 11발(FIRE_COOLDOWN 0.09)로 실제 난사했을 때

판정 결과는 브라우저에 저장되고, 하단 [결과 복사] 로 마크다운을 뽑아낼 수 있다.

사용:
    python Tools/build_gunshot_audition.py [출력경로.html]
"""

import base64
import html
import io
import json
import math
import struct
import sys
import wave
from pathlib import Path

import numpy as np

SRC = Path(r"C:\Users\vnvnc\Downloads\23279__gokhanbiyik__gun-sounds-01")
PACK_URL = "https://freesound.org/people/GokhanBiyik/packs/23279/"
AUTHOR_URL = "https://freesound.org/people/GokhanBiyik/"
OUT_DEFAULT = Path("Docs/_audition/gunshot_audition.html")

PREVIEW_SR = 44100
WEAPON_LPF_HZ = 6500.0      # audio_manager.gd LOWPASS[BUS_WEAPON]
FIRE_COOLDOWN = 0.09        # player.gd FIRE_COOLDOWN — 초당 약 11발
SUB_GAP = 0.16              # audio_manager.gd SOUNDS["fire_low"]["gap"]
TURRET_COOLDOWN = 0.055     # sentry_turret.gd FIRE_COOLDOWN — 초당 약 18발 (포신 2개 교대)

# ---------------------------------------------------------------- 그룹 정의
# role  : 이 자리에 들어갈 사운드가 무슨 일을 하는가
# need  : 몇 개를 뽑아야 하는가
# proc  : 가공본 미리듣기 규칙 (trim_ms=자를 길이, gain=목표 피크 dBFS)
GROUPS = [
    {
        "id": "fire_body",
        "title": "발사 · 보디",
        "slot": 'audio_manager.gd  SOUNDS["fire_body"]',
        "code": "player.gd:_fire()",
        "need": "3종 이상",
        "role": (
            "총이 총으로 들리게 하는 본체. <b>매 발</b> 울린다. 초당 11번 반복되므로 "
            "길이가 150 ms 를 넘으면 연사에서 꼬리가 겹쳐 진창이 된다. "
            "현재는 Kenney 금속 타격음(<code>fire_metal</code>)으로 흉내 내는 중이라, 이 자리가 이 팩의 <b>1순위 용도</b>다."
        ),
        "proc": {"trim_ms": 130, "fade_ms": 28, "peak_db": -6.0},
        "burst": "body",
        "files": [
            ("413094__gokhanbiyik__gunshort03.wav", "★ 이 팩에서 가장 밝다. 어택 4.3 ms 로 즉발이고 중·고역이 살아 있어 '크랙'이 들리는 유일한 짧은 샘플."),
            ("413101__gokhanbiyik__gunshort10.wav", "★ 가장 짧다(0.12초). 꼬리 93 ms 라 연사에 가장 안전하다. 밝기는 중간."),
            ("413115__gokhanbiyik__gunshort12.wav", "★ 위 둘과 밝기가 겹치지 않는다. 3종 배리에이션의 세 번째로 적합."),
            ("413102__gokhanbiyik__gunshort09.wav", "예비. gunshort10 과 성격이 거의 같다 — 둘 중 하나만."),
            ("413098__gokhanbiyik__gunshort07.wav", "예비. 어택이 32 ms 로 다소 느리다(=덜 즉발적)."),
            ("413097__gokhanbiyik__gunshort08.wav", "예비. 어택 46 ms. 위와 같은 이유로 후순위."),
            ("413099__gokhanbiyik__gunshort06.wav", "거의 순수 저역(중심 142 Hz). 보디보다 저역 레이어 쪽에 가깝다."),
        ],
    },
    {
        "id": "fire_sub",
        "title": "발사 · 저역",
        "slot": 'audio_manager.gd  SOUNDS["fire_sub"]  (기존 fire_low 교체)',
        "code": "player.gd:_fire()",
        "need": "1종",
        "role": (
            "명치를 치는 무게. <b>두 발에 한 번만</b> 깔린다(<code>gap 0.16</code>) — 저역은 누적이 가장 빨라서 "
            "매 발 깔면 연사가 먹먹해진다. 지금은 Kenney 폭발음을 쓰고 있다. "
            "이 팩의 <code>mg</code> 4종은 측정상 에너지의 96~98%가 150 Hz 아래라 이 자리에 거의 맞춤이다."
        ),
        "proc": {"trim_ms": 220, "fade_ms": 40, "peak_db": -10.0},
        "burst": "sub",
        "files": [
            ("413127__gokhanbiyik__mg04.wav", "★ 저역 비중 97%, 0.23초로 가장 짧다. gap 0.16 규칙에 가장 잘 맞는다."),
            ("413128__gokhanbiyik__mg03.wav", "mg04 와 거의 같은 길이·대역. 둘 중 귀에 맞는 쪽."),
            ("413125__gokhanbiyik__mg02.wav", "저역 비중 98% 로 가장 순수하지만 0.31초로 조금 길다."),
            ("413126__gokhanbiyik__mg01.wav", "0.50초. 이 자리엔 너무 길다 — 잘라야 쓴다."),
        ],
    },
    {
        "id": "fire_tail",
        "title": "사격 종료 · 잔향",
        "slot": 'audio_manager.gd  SOUNDS["fire_tail"]  (신규)',
        "code": "player.gd:_fire() — 마지막 발 이후 0.12초",
        "need": "1종",
        "role": (
            "지하 콘크리트 방이 울리는 소리. <b>연사 중에는 절대 재생하지 않고</b>, 사격이 끊긴 뒤 한 번만 울린다. "
            "이게 지금 통째로 없어서 총이 '방 안에서' 쏘는 느낌이 안 난다. "
            "짧게 자르지 말고 꼬리를 길게 남긴 파일이 필요하다."
        ),
        "proc": {"trim_ms": 0, "fade_ms": 60, "peak_db": -13.0},
        "burst": None,
        "files": [
            ("413111__gokhanbiyik__gunsound13.wav", "★ 가장 길다(0.81초, 잔향 626 ms). 잔향 레이어로 쓰기 가장 좋다."),
            ("413119__gokhanbiyik__gunsound04.wav", "잔향 586 ms. gunsound13 보다 어둡다."),
            ("413118__gokhanbiyik__gunsound05.wav", "잔향 585 ms. 위와 거의 동급 — 취향 선택."),
            ("413122__gokhanbiyik__gunsound07.wav", "0.69초지만 잔향은 391 ms 로 짧은 편. 더 마른 울림을 원하면."),
        ],
    },
    {
        "id": "turret",
        "title": "센트리건 (원거리)",
        "slot": 'audio_manager.gd  SOUNDS["turret_fire"]  (신규)',
        "code": "main.gd:_on_turret_shoot()",
        "need": "1종",
        "role": (
            "지금은 플레이어와 <b>똑같은 샘플에 -3 dB 만</b> 걸려 있다. 그래서 '멀리서 작게 쏜다'로만 들리고 "
            "'저쪽에서 <b>다른 총</b>이 쏜다'로는 안 들린다. 플레이어 총과 대역이 겹치지 않는 샘플이 필요하다."
        ),
        "proc": {"trim_ms": 200, "fade_ms": 35, "peak_db": -9.0},
        "burst": "turret",
        "files": [
            ("413110__gokhanbiyik__gunsound16.wav", "★ 이 팩에서 유일하게 중역 중심(에너지 59%가 800 Hz~4 kHz). 플레이어 총과 확실히 구분된다."),
            ("413109__gokhanbiyik__gunsound15.wav", "16번과 같은 소재의 어두운 버전. 16이 과하면 이쪽."),
            ("413120__gokhanbiyik__gunsound03.wav", "고역이 12% 있어 원거리 특유의 '탁' 이 살아 있다."),
            ("413124__gokhanbiyik__gunsound19.wav", "중간 밝기. 무난하지만 플레이어 총과 겹칠 위험."),
        ],
    },
    {
        "id": "boom",
        "title": "대형 파괴 · 폭발 소재",
        "slot": "미구현 — 필요해지면",
        "code": "—",
        "need": "0~1종 (급하지 않음)",
        "role": (
            "지금 당장 쓸 자리는 없다. 다만 어택이 느리고 묵직한 샘플 몇 개가 있어서, "
            "나중에 폭발·구조물 붕괴가 생기면 소재로 쓸 만하다. <b>급하지 않으니 '보류'로 넘겨도 된다.</b>"
        ),
        "proc": {"trim_ms": 0, "fade_ms": 50, "peak_db": -8.0},
        "burst": None,
        "files": [
            ("413093__gokhanbiyik__gunshort04.wav", "어택 53 ms 로 느리게 부풀어 오른다. 짧은 폭발에 가깝다."),
            ("413104__gokhanbiyik__gunsound18.wav", "0.61초, 저역 92%. 묵직한 붕괴음 소재."),
            ("413103__gokhanbiyik__gunsound17.wav", "0.53초. 위보다 조금 가볍다."),
            ("413100__gokhanbiyik__gunshort05.wav", "어택 66 ms 로 가장 느리다. 피크가 -7.6 dB 라 원본이 작다."),
        ],
    },
]


# ---------------------------------------------------------------- 오디오 유틸
def load_wav(path: Path):
    """24bit 스테레오를 포함해 읽고 모노 float64 로 돌려준다."""
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
    return a, sr, ch, sw * 8


def resample(a: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr:
        return a
    n = int(round(len(a) * dst_sr / float(src_sr)))
    return np.interp(np.linspace(0, len(a) - 1, n), np.arange(len(a)), a)


def lowpass(a: np.ndarray, sr: int, hz: float, poles: int = 2) -> np.ndarray:
    """버스 로우패스 흉내. 1극 IIR 을 겹쳐 쓴다 — 정확한 필터가 아니라 체감용."""
    dt = 1.0 / sr
    rc = 1.0 / (2 * math.pi * hz)
    alpha = dt / (rc + dt)
    out = a
    for _ in range(poles):
        y = np.empty_like(out)
        acc = 0.0
        for i, v in enumerate(out):
            acc += alpha * (v - acc)
            y[i] = acc
        out = y
    return out


def normalize(a: np.ndarray, peak_db: float) -> np.ndarray:
    pk = np.abs(a).max()
    if pk < 1e-9:
        return a
    return a * (10 ** (peak_db / 20.0) / pk)


def encode_wav16(a: np.ndarray, sr: int) -> bytes:
    clipped = np.clip(a, -1.0, 1.0)
    pcm = (clipped * 32767.0).astype("<i2").tobytes()
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm)
    return buf.getvalue()


def data_uri(a: np.ndarray, sr: int) -> str:
    return "data:audio/wav;base64," + base64.b64encode(encode_wav16(a, sr)).decode("ascii")


def onset_index(a: np.ndarray) -> int:
    env = np.abs(a)
    pk = env.max()
    if pk < 1e-9:
        return 0
    hits = np.nonzero(env >= pk * 0.05)[0]
    return int(hits[0]) if len(hits) else 0


def shape(a: np.ndarray, sr: int, trim_ms: int, fade_ms: int, peak_db: float) -> np.ndarray:
    """온셋부터 자르고, 페이드를 걸고, 버스 로우패스를 먹인 뒤 레벨을 맞춘다."""
    s = a[onset_index(a):]
    if trim_ms > 0:
        s = s[: int(sr * trim_ms / 1000.0)]
    s = s.copy()
    fi = max(1, int(sr * 0.001))
    s[:fi] *= np.linspace(0.0, 1.0, fi)
    fo = min(len(s) - 1, int(sr * fade_ms / 1000.0))
    if fo > 1:
        s[-fo:] *= np.linspace(1.0, 0.0, fo)
    s = lowpass(s, sr, WEAPON_LPF_HZ)
    return normalize(s, peak_db)


def pitched(a: np.ndarray, ratio: float) -> np.ndarray:
    if abs(ratio - 1.0) < 1e-6:
        return a
    n = max(1, int(round(len(a) / ratio)))
    return np.interp(np.linspace(0, len(a) - 1, n), np.arange(len(a)), a)


def make_burst(body, sub, sr, shots=10, rng=None, cooldown=FIRE_COOLDOWN):
    """초당 11발 난사를 실제로 합성한다. 피치·음량 흔들기와 gap 규칙까지 그대로 적용."""
    rng = rng or np.random.default_rng(7)
    span = int(sr * (cooldown * (shots - 1) + 1.2))
    out = np.zeros(span)
    last_sub = -99.0
    for i in range(shots):
        t = i * cooldown
        at = int(t * sr)
        if body is not None:
            v = pitched(body, float(rng.uniform(0.94, 1.06)))
            g = 10 ** (float(rng.uniform(-1.5, 1.5)) / 20.0)
            g *= 1.2 if i == 0 else 1.0            # 첫 발만 조금 크게
            seg = v * g
            out[at:at + len(seg)] += seg[: max(0, span - at)]
        if sub is not None and t - last_sub >= SUB_GAP:
            v = pitched(sub, float(rng.uniform(0.94, 1.02)))
            out[at:at + len(v)] += v[: max(0, span - at)]
            last_sub = t
    pk = np.abs(out).max()
    if pk > 0.89:                                   # Master 하드 리미터 자리
        out = out * (0.89 / pk)
    return out


def envelope_path(a: np.ndarray, width=300, height=40) -> str:
    """파형 미니어처를 SVG path 로."""
    env = np.abs(a)
    pk = env.max() or 1.0
    n = len(env)
    buckets = np.array_split(env, min(width, n)) if n else []
    tops, bots = [], []
    for i, b in enumerate(buckets):
        x = i * width / max(1, len(buckets))
        v = (b.max() / pk) * (height / 2 - 1)
        tops.append(f"{x:.1f},{height/2 - v:.1f}")
        bots.append(f"{x:.1f},{height/2 + v:.1f}")
    return "M" + " L".join(tops + list(reversed(bots))) + " Z"


def measure(a: np.ndarray, sr: int) -> dict:
    env = np.abs(a)
    pk = float(env.max()) or 1e-9
    pi = int(env.argmax())
    start = onset_index(a)
    t40 = pk * 10 ** (-40 / 20.0)
    idx = np.nonzero(env >= t40)[0]
    tail_ms = (int(idx[-1]) - pi) / sr * 1000.0 if len(idx) else 0.0
    w = a[start:start + int(sr * 0.2)]
    if len(w) < 256:
        w = a[:max(256, len(a))]
    spec = np.abs(np.fft.rfft(w * np.hanning(len(w)))) ** 2
    fr = np.fft.rfftfreq(len(w), 1.0 / sr)
    tot = spec.sum() + 1e-12
    return {
        "dur": len(a) / sr,
        "peak_db": 20 * math.log10(pk),
        "attack_ms": (pi - start) / sr * 1000.0,
        "tail_ms": max(0.0, tail_ms),
        "centroid": float((fr * spec).sum() / tot),
        "low": float(spec[fr < 150].sum() / tot),
        "mid": float(spec[(fr >= 800) & (fr < 4000)].sum() / tot),
        "high": float(spec[fr >= 4000].sum() / tot),
    }


# ---------------------------------------------------------------- 빌드
def build(out_path: Path) -> None:
    if not SRC.is_dir():
        sys.exit(f"원본 폴더가 없다: {SRC}")

    all_files = sorted(p.name for p in SRC.glob("*.wav"))
    picked_names = {f for g in GROUPS for f, _ in g["files"]}

    cache = {}

    def get(name):
        if name not in cache:
            a, sr, ch, bits = load_wav(SRC / name)
            cache[name] = (a, sr, ch, bits)
        return cache[name]

    # 저역 레이어 기준본 — 보디 후보의 "연사 + 저역" 합성에 쓴다
    sub_raw, sub_sr, _, _ = get("413127__gokhanbiyik__mg04.wav")
    sub_ref = shape(resample(sub_raw, sub_sr, PREVIEW_SR), PREVIEW_SR, 220, 40, -13.0)

    groups_out = []
    for g in GROUPS:
        items = []
        for name, why in g["files"]:
            a, sr, ch, bits = get(name)
            m = measure(a, sr)
            mono = resample(a, sr, PREVIEW_SR)
            p = g["proc"]
            proc = shape(mono, PREVIEW_SR, p["trim_ms"], p["fade_ms"], p["peak_db"])

            clips = {
                "orig": data_uri(mono, PREVIEW_SR),   # 레벨 보정 없음 — 원본 크기 그대로 비교
                "proc": data_uri(proc, PREVIEW_SR),
            }
            if g["burst"] == "body":
                clips["burst"] = data_uri(make_burst(proc, None, PREVIEW_SR), PREVIEW_SR)
                clips["mix"] = data_uri(make_burst(proc, sub_ref, PREVIEW_SR), PREVIEW_SR)
            elif g["burst"] == "sub":
                clips["burst"] = data_uri(make_burst(None, proc, PREVIEW_SR, shots=10), PREVIEW_SR)
            elif g["burst"] == "turret":
                clips["burst"] = data_uri(
                    make_burst(proc, None, PREVIEW_SR, shots=14, cooldown=TURRET_COOLDOWN), PREVIEW_SR)

            items.append({
                "id": name.split("__")[0],
                "file": name,
                "short": name.split("__")[-1].replace(".wav", ""),
                "url": f"https://freesound.org/s/{name.split('__')[0]}/",
                "why": why,
                "star": why.startswith("★"),
                "kb": round((SRC / name).stat().st_size / 1024),
                "fmt": f"{sr//1000} kHz · {bits}bit · {'스테레오' if ch>1 else '모노'}",
                "m": {k: round(v, 3) for k, v in m.items()},
                "wave": envelope_path(mono),
                "clips": clips,
            })
        groups_out.append({
            "id": g["id"], "title": g["title"], "slot": g["slot"], "code": g["code"],
            "need": g["need"], "role": g["role"], "items": items,
            "proc_label": (f'앞 {g["proc"]["trim_ms"]} ms 만 남기고 컷' if g["proc"]["trim_ms"]
                           else "전체 길이 유지"),
            "rate": ("18발/초" if g["burst"] == "turret" else "11발/초"),
        })

    rest = []
    for name in all_files:
        if name in picked_names:
            continue
        a, sr, ch, bits = get(name)
        m = measure(a, sr)
        mono = resample(a, sr, PREVIEW_SR)
        rest.append({
            "id": name.split("__")[0],
            "file": name,
            "short": name.split("__")[-1].replace(".wav", ""),
            "url": f"https://freesound.org/s/{name.split('__')[0]}/",
            "m": {k: round(v, 3) for k, v in m.items()},
            "wave": envelope_path(mono),
            "clips": {"orig": data_uri(mono, PREVIEW_SR)},
        })

    payload = {
        "groups": groups_out,
        "rest": rest,
        "total": len(all_files),
        "pack_url": PACK_URL,
        "author_url": AUTHOR_URL,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        HTML.replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False)),
        encoding="utf-8",
    )
    mb = out_path.stat().st_size / 1024 / 1024
    print(f"완료: {out_path}  ({mb:.1f} MB, 원본 {len(all_files)}개 중 후보 {len(picked_names)}개)")


# ---------------------------------------------------------------- HTML
HTML = r"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>총격 사운드 오디션 — Gun Sounds 01</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Gothic+A1:wght@400;700;800&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+KR:wght@400;500&display=swap" rel="stylesheet">
<style>
:root{
  color-scheme: dark;
  --ground:#101319; --surface:#171B23; --surface-2:#1E232D;
  --line:#2A303C; --line-soft:#222836;
  --ink:#DCE0E8; --ink-dim:#8B93A3; --ink-faint:#5E6675;
  --amber:#E8A33D; --rust:#C4523E; --steel:#6E8BA8; --ok:#7FA663;
  --display:'Gothic A1','Malgun Gothic',sans-serif;
  --body:'IBM Plex Sans KR','Malgun Gothic',sans-serif;
  --mono:'IBM Plex Mono',ui-monospace,monospace;
}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);font-family:var(--body);
     font-size:14px;line-height:1.65;padding-bottom:86px}
.wrap{max-width:1000px;margin:0 auto;padding:36px 20px 20px}
a{color:var(--steel)}
code{font-family:var(--mono);font-size:.92em;color:var(--amber)}
h1{font-family:var(--display);font-weight:800;font-size:25px;margin:0 0 6px;letter-spacing:-.01em}
.sub{color:var(--ink-dim);font-size:13px;margin:0 0 22px}
.sub b{color:var(--ink)}

.banner{border:1px solid var(--rust);border-left-width:3px;background:color-mix(in srgb,var(--rust) 9%,transparent);
        padding:14px 16px;border-radius:3px;margin:0 0 16px}
.banner h3{font-family:var(--display);font-weight:800;font-size:14px;margin:0 0 6px;color:var(--rust)}
.banner p{margin:0 0 6px;font-size:13px;color:var(--ink-dim)}
.banner p:last-child{margin-bottom:0}
.banner b{color:var(--ink)}

.brief{border:1px solid var(--line);background:var(--surface);padding:14px 16px;border-radius:3px;margin:0 0 26px}
.brief h3{font-family:var(--display);font-weight:800;font-size:14px;margin:0 0 8px}
.brief p{margin:0 0 8px;font-size:13px;color:var(--ink-dim)}
.brief p:last-child{margin-bottom:0}
.brief b{color:var(--ink)}
.legend{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}
.lg{font-family:var(--mono);font-size:10.5px;color:var(--ink-faint);border:1px solid var(--line);
    padding:3px 8px;border-radius:2px}
.lg b{color:var(--ink-dim);font-weight:500}

.group{margin:0 0 40px;scroll-margin-top:14px}
.ghead{border-bottom:1px solid var(--line);padding-bottom:11px;margin-bottom:6px}
.gtop{display:flex;flex-wrap:wrap;gap:10px;align-items:baseline;justify-content:space-between}
.ghead h2{font-family:var(--display);font-weight:800;font-size:18px;margin:0}
.gneed{font-family:var(--mono);font-size:10.5px;color:var(--amber);border:1px solid color-mix(in srgb,var(--amber) 45%,transparent);
       padding:3px 8px;border-radius:2px;white-space:nowrap}
.gslot{font-family:var(--mono);font-size:11px;color:var(--ink-faint);margin-top:5px}
.grole{font-size:13px;color:var(--ink-dim);margin:10px 0 0;max-width:74ch}
.grole b{color:var(--ink)}

.card{border:1px solid var(--line-soft);border-radius:3px;background:var(--surface);
      padding:13px 15px;margin-top:11px}
.card.star{border-color:color-mix(in srgb,var(--amber) 40%,transparent)}
.card.done{border-color:color-mix(in srgb,var(--ok) 40%,transparent)}
.card.no{opacity:.5}
.ctop{display:flex;flex-wrap:wrap;gap:10px;align-items:baseline;justify-content:space-between}
.cname{font-family:var(--mono);font-size:13px;color:var(--ink)}
.cname .st{color:var(--amber)}
.cmeta{font-family:var(--mono);font-size:10.5px;color:var(--ink-faint)}
.why{font-size:13px;color:var(--ink-dim);margin:7px 0 0;max-width:74ch}

.wave{display:block;width:100%;height:40px;margin:10px 0 2px}
.wave path{fill:color-mix(in srgb,var(--steel) 55%,transparent)}
.card.star .wave path{fill:color-mix(in srgb,var(--amber) 50%,transparent)}
.wave rect.ph{fill:color-mix(in srgb,var(--amber) 90%,transparent);width:1.5px}

.badges{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0 0}
.bd{font-family:var(--mono);font-size:10px;color:var(--ink-faint);border:1px solid var(--line);
    padding:2px 7px;border-radius:2px;font-variant-numeric:tabular-nums}
.bd b{color:var(--ink-dim);font-weight:500}
.bd.warn{color:var(--rust);border-color:color-mix(in srgb,var(--rust) 40%,transparent)}
.bd.good{color:var(--ok);border-color:color-mix(in srgb,var(--ok) 35%,transparent)}

.plays{display:flex;flex-wrap:wrap;gap:7px;margin:11px 0 0}
.pl{font-family:var(--mono);font-size:11.5px;background:var(--surface-2);border:1px solid var(--line);
    color:var(--ink-dim);padding:6px 12px;border-radius:2px;cursor:pointer;display:flex;gap:7px;align-items:center}
.pl:hover{border-color:var(--steel);color:var(--ink)}
.pl.on{border-color:var(--amber);color:var(--amber)}
.pl .t{width:0;height:0;border-left:6px solid currentColor;border-top:4px solid transparent;border-bottom:4px solid transparent}
.pl.on .t{border:none;width:7px;height:8px;background:currentColor}
.pl.key{background:color-mix(in srgb,var(--amber) 12%,var(--surface-2));border-color:color-mix(in srgb,var(--amber) 40%,transparent);color:var(--ink)}

.verdict{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:12px 0 0;
         border-top:1px solid var(--line-soft);padding-top:11px}
.vlabel{font-family:var(--mono);font-size:10.5px;color:var(--ink-faint);margin-right:2px}
.v{font-family:var(--mono);font-size:11.5px;background:none;border:1px solid var(--line);
   color:var(--ink-faint);padding:5px 14px;border-radius:2px;cursor:pointer}
.v:hover{border-color:var(--steel);color:var(--ink-dim)}
.v[aria-pressed="true"][data-v="ok"]{background:color-mix(in srgb,var(--ok) 20%,transparent);border-color:var(--ok);color:var(--ok)}
.v[aria-pressed="true"][data-v="hold"]{background:color-mix(in srgb,var(--amber) 18%,transparent);border-color:var(--amber);color:var(--amber)}
.v[aria-pressed="true"][data-v="no"]{background:color-mix(in srgb,var(--rust) 18%,transparent);border-color:var(--rust);color:var(--rust)}
.memo{flex:1 1 220px;min-width:180px;background:var(--surface-2);border:1px solid var(--line);
      color:var(--ink);font-family:var(--body);font-size:12.5px;padding:6px 10px;border-radius:2px}
.memo::placeholder{color:var(--ink-faint)}
.memo:focus{outline:none;border-color:var(--steel)}

details.rest{margin:30px 0 0;border-top:1px solid var(--line);padding-top:18px}
details.rest summary{font-family:var(--display);font-weight:800;font-size:16px;cursor:pointer;list-style:none}
details.rest summary::-webkit-details-marker{display:none}
details.rest summary::before{content:"▸ ";color:var(--ink-faint)}
details.rest[open] summary::before{content:"▾ "}
.restnote{font-size:13px;color:var(--ink-dim);margin:9px 0 4px;max-width:74ch}
.rrow{display:grid;grid-template-columns:34px minmax(0,1.1fr) minmax(0,1.4fr) auto;gap:12px;align-items:center;
      padding:8px 0;border-bottom:1px solid var(--line-soft)}
@media(max-width:700px){.rrow{grid-template-columns:34px minmax(0,1fr);row-gap:7px}
  .rrow .rw{grid-column:1/3}.rrow .verdict{grid-column:1/3;margin-top:2px;border-top:none;padding-top:0}}
.rp{width:30px;height:30px;border-radius:50%;border:1px solid var(--line);background:var(--surface-2);
    display:grid;place-items:center;cursor:pointer;padding:0}
.rp:hover{border-color:var(--amber)}
.rp .t{width:0;height:0;border-left:7px solid var(--ink-dim);border-top:5px solid transparent;border-bottom:5px solid transparent;margin-left:2px}
.rp.on .t{border-left-color:var(--amber)}
.rname{font-family:var(--mono);font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.rname small{color:var(--ink-faint);font-size:10px;display:block}
.rw{height:26px;width:100%}
.rw path{fill:color-mix(in srgb,var(--steel) 40%,transparent)}
.rrow .verdict{margin:0;border:none;padding:0;gap:5px}
.rrow .v{padding:4px 9px;font-size:10.5px}
.rrow .memo{display:none}

.dock{position:fixed;left:0;right:0;bottom:0;z-index:10;
      background:color-mix(in srgb,var(--surface) 95%,transparent);backdrop-filter:blur(8px);
      border-top:1px solid var(--line);padding:11px 20px;
      padding-bottom:calc(11px + env(safe-area-inset-bottom,0px));
      display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between}
.dock .l{font-family:var(--mono);font-size:11.5px;color:var(--ink-dim);min-width:0;
         overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.dock .l b{color:var(--amber);font-weight:500}
.dock .r{display:flex;gap:9px;align-items:center}
.dock button{font-family:var(--mono);font-size:11.5px;background:var(--surface-2);border:1px solid var(--line);
             color:var(--ink-dim);padding:7px 14px;border-radius:2px;cursor:pointer}
.dock button:hover{border-color:var(--steel);color:var(--ink)}
.dock button.primary{background:color-mix(in srgb,var(--amber) 16%,var(--surface-2));
                     border-color:color-mix(in srgb,var(--amber) 50%,transparent);color:var(--amber)}
.out{position:fixed;inset:0;z-index:20;background:color-mix(in srgb,var(--ground) 92%,transparent);
     display:none;padding:34px 20px;overflow:auto}
.out.open{display:block}
.out .box{max-width:840px;margin:0 auto;background:var(--surface);border:1px solid var(--line);
          border-radius:3px;padding:18px}
.out h3{font-family:var(--display);font-weight:800;font-size:16px;margin:0 0 4px}
.out p{font-size:13px;color:var(--ink-dim);margin:0 0 12px}
.out textarea{width:100%;height:56vh;background:var(--ground);border:1px solid var(--line);color:var(--ink);
              font-family:var(--mono);font-size:12px;line-height:1.6;padding:12px;border-radius:2px;resize:vertical}
.out .row{display:flex;gap:9px;margin-top:12px}
</style>
</head>
<body>
<div class="wrap">

<h1>총격 사운드 오디션</h1>
<p class="sub">Freesound 팩 <b>“Gun Sounds 01”</b> · GokhanBiyik · 원본 36개 · 48 kHz / 24bit / 스테레오<br>
후보 <b id="ncand">—</b>개를 용도별로 묶었다. <b>듣고 채택 / 보류 / 기각만 눌러 주면 된다.</b>
다 누르고 맨 아래 <b>[결과 복사]</b> 를 누르면 그대로 붙여넣을 수 있는 요약이 나온다.</p>

<div class="banner">
  <h3>⚠ 이 팩은 CC0 가 아니다 — CC-BY 4.0 이다</h3>
  <p><code>_readme_and_license.txt</code> 확인 결과 36개 <b>전부 Attribution 4.0</b>. 즉 <b>크레딧 표기가 의무</b>다.
     지금까지 프로젝트는 Kenney CC0 만 써서 크레딧 파일이 없었는데, 이 팩을 하나라도 채택하는 순간
     <code>Docs/CREDITS.md</code> 를 만들어야 한다.</p>
  <p>표기 문구 예시 — <code>Gun Sounds 01 by GokhanBiyik (freesound.org), CC BY 4.0</code>,
     그리고 게임 내 크레딧 화면에도 같은 내용이 들어가야 한다.</p>
  <p><b>그러니 먼저 정해 줘야 할 게 하나 있다:</b> 크레딧 관리를 감수할 것인가?
     아니라면 이 팩은 전부 기각하고, 리서치 문서에 정리해 둔 <b>michorvath 의 CC0 9종</b>으로 가면 된다
     (<a href="https://freesound.org/people/michorvath/sounds/" target="_blank" rel="noopener">링크</a>).
     내 권고는 <b>“이 팩을 써도 좋다”</b> — 크레딧 한 줄이 아까울 만큼 내용이 나쁘지 않고, 어차피 CC-BY 음원은 언젠가 쓰게 된다.</p>
</div>

<div class="brief">
  <h3>먼저 알아야 할 것 — 이 팩의 성격</h3>
  <p>36개를 전부 측정해 보니 <b>극단적으로 저역에 치우쳐 있다.</b> 대부분 에너지의 <b>70~98%가 150 Hz 아래</b>고,
     스펙트럼 중심이 100~600 Hz 에 몰려 있다. 쉽게 말해 <b>“쿵”은 있는데 “탁”이 거의 없다.</b></p>
  <p>그래서 결론이 갈린다. <b>저역·잔향·원거리 자리에는 아주 잘 맞고, 날카로운 어택은 이 팩으로 못 채운다.</b>
     현재 쓰고 있는 Kenney 금속 타격음(<code>fire_metal</code>)이 오히려 그 어택을 담당하고 있으므로,
     <b>둘을 버리고 고르는 게 아니라 겹쳐 쓰는 쪽</b>이 맞을 가능성이 높다. 그 판단을 위해 “연사 + 저역 레이어” 미리듣기를 넣었다.</p>
  <p><b>나는 이 소리들을 듣지 못한다.</b> 여기 적힌 평가는 전부 파형·스펙트럼 <b>측정값에서 나온 추론</b>이지 청취 결과가 아니다.
     측정으로는 "밝다/짧다/저역이 많다"까지만 말할 수 있고, <b>“좋은 총소리인가”는 네가 판단해야 한다.</b>
     ★ 는 내 1순위 추천이지만 그냥 무시해도 된다.</p>
  <div class="legend">
    <span class="lg"><b>원본</b> 받은 파일 그대로 (모노 변환만)</span>
    <span class="lg"><b>가공본</b> 용도에 맞게 자르고 Weapon 버스 로우패스 6.5 kHz 적용</span>
    <span class="lg"><b>연사</b> 초당 11발 — 실제 <code>FIRE_COOLDOWN 0.09</code> 로 합성</span>
    <span class="lg"><b>+저역</b> 거기에 mg04 를 <code>gap 0.16</code> 규칙대로 겹친 것</span>
  </div>
</div>

<div id="groups"></div>

<details class="rest">
  <summary>나머지 전체 (후보로 안 뽑은 것들)</summary>
  <p class="restnote">위 후보에 안 넣은 파일들이다. 측정상 후보들과 성격이 겹치거나 용도에 안 맞아서 뺐는데,
     <b>귀로 들으면 판단이 다를 수 있으니</b> 전부 들어볼 수 있게 남겨 뒀다. 여기서 건진 게 있으면 채택을 누르고 메모는 생략해도 된다.</p>
  <div id="rest"></div>
</details>

</div>

<div class="dock">
  <div class="l">판정 <b id="prog">0</b> / <span id="tot">0</span> · 채택 <b id="nok">0</b> · 보류 <b id="nhold">0</b> · 기각 <b id="nno">0</b></div>
  <div class="r">
    <button id="stop">재생 정지</button>
    <button id="reset">초기화</button>
    <button id="export" class="primary">결과 복사</button>
  </div>
</div>

<div class="out" id="out">
  <div class="box">
    <h3>판정 결과</h3>
    <p>아래 내용을 그대로 복사해서 대화창에 붙여넣으면 된다. 그대로 적용하겠다.</p>
    <textarea id="outtext" spellcheck="false"></textarea>
    <div class="row">
      <button id="copy" class="primary" style="font-family:var(--mono);font-size:12px;background:color-mix(in srgb,var(--amber) 16%,var(--surface-2));border:1px solid color-mix(in srgb,var(--amber) 50%,transparent);color:var(--amber);padding:8px 16px;border-radius:2px;cursor:pointer">클립보드로 복사</button>
      <button id="close" style="font-family:var(--mono);font-size:12px;background:var(--surface-2);border:1px solid var(--line);color:var(--ink-dim);padding:8px 16px;border-radius:2px;cursor:pointer">닫기</button>
    </div>
  </div>
</div>

<script>
const DATA = /*__DATA__*/null;
const KEY = "gunshot-audition-v1";
const state = JSON.parse(localStorage.getItem(KEY) || "{}");

let audio = null, curBtn = null, raf = 0;
function stopAll(){
  if(audio){ audio.pause(); audio = null; }
  if(curBtn){ curBtn.classList.remove("on"); curBtn = null; }
  cancelAnimationFrame(raf);
  document.querySelectorAll("rect.ph").forEach(r => r.setAttribute("x", -5));
}
function play(btn, src, svg){
  const again = (curBtn === btn);
  stopAll();
  if(again) return;
  audio = new Audio(src); curBtn = btn; btn.classList.add("on");
  audio.play().catch(()=>{});
  audio.onended = () => stopAll();
  if(svg){
    const ph = svg.querySelector("rect.ph");
    const tick = () => {
      if(!audio) return;
      const d = audio.duration || 1;
      ph.setAttribute("x", (audio.currentTime / d) * 300);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  }
}

const esc = s => String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const pct = v => Math.round(v * 100) + "%";

function badges(m){
  const b = [];
  b.push(["길이", m.dur.toFixed(2) + "s", m.dur <= 0.16 ? "good" : (m.dur > 0.6 ? "warn" : "")]);
  b.push(["어택", m.attack_ms.toFixed(0) + "ms", m.attack_ms <= 8 ? "good" : (m.attack_ms > 50 ? "warn" : "")]);
  b.push(["잔향", m.tail_ms.toFixed(0) + "ms", ""]);
  b.push(["중심", m.centroid.toFixed(0) + "Hz", m.centroid >= 1000 ? "good" : ""]);
  b.push(["저역", pct(m.low), ""]);
  b.push(["중역", pct(m.mid), ""]);
  b.push(["피크", m.peak_db.toFixed(1) + "dB", m.peak_db < -3 ? "warn" : ""]);
  return b.map(([k,v,c]) => `<span class="bd ${c}"><b>${k}</b> ${v}</span>`).join("");
}
function waveSvg(path, cls){
  return `<svg class="${cls}" viewBox="0 0 300 40" preserveAspectRatio="none">
    <path d="${path}"></path><rect class="ph" x="-5" y="0" height="40"></rect></svg>`;
}
function verdictHtml(id){
  const v = state[id] && state[id].v;
  const btn = (k, label) => `<button class="v" data-id="${id}" data-v="${k}" aria-pressed="${v===k}">${label}</button>`;
  return `<span class="vlabel">판정</span>${btn("ok","채택")}${btn("hold","보류")}${btn("no","기각")}`;
}

const LABEL = { orig:"원본", proc:"가공본", burst:"연사", mix:"연사 + 저역" };
const ORDER = ["orig","proc","burst","mix"];

function card(it, rate){
  const cls = []; if(it.star) cls.push("star");
  const v = state[it.id] && state[it.id].v;
  if(v === "ok") cls.push("done"); if(v === "no") cls.push("no");
  const plays = ORDER.filter(k => it.clips[k]).map(k =>
    `<button class="pl ${k==="mix"||k==="burst"?"key":""}" data-src="${k}"><span class="t"></span>${LABEL[k]}${k==="burst"?" "+rate:""}</button>`).join("");
  return `<div class="card ${cls.join(" ")}" data-card="${it.id}">
    <div class="ctop">
      <span class="cname">${it.star?'<span class="st">★</span> ':""}${esc(it.short)}</span>
      <span class="cmeta">${esc(it.fmt)} · ${it.kb} KB · <a href="${it.url}" target="_blank" rel="noopener">freesound #${it.id}</a></span>
    </div>
    <p class="why">${esc(it.why).replace(/^★\s*/,"")}</p>
    ${waveSvg(it.wave, "wave")}
    <div class="badges">${badges(it.m)}</div>
    <div class="plays">${plays}</div>
    <div class="verdict">${verdictHtml(it.id)}
      <input class="memo" data-id="${it.id}" placeholder="한 줄 메모 (선택) — 왜 좋은지 / 뭐가 걸리는지"
             value="${esc((state[it.id]&&state[it.id].note)||"")}"></div>
  </div>`;
}

document.getElementById("groups").innerHTML = DATA.groups.map(g => `
  <section class="group" id="g-${g.id}">
    <div class="ghead">
      <div class="gtop"><h2>${esc(g.title)}</h2><span class="gneed">${esc(g.need)} 필요</span></div>
      <div class="gslot">${esc(g.slot)} &nbsp;·&nbsp; ${esc(g.code)}</div>
    </div>
    <p class="grole">${g.role}</p>
    <p class="grole" style="color:var(--ink-faint);font-size:12px">가공본 규칙: ${esc(g.proc_label)} + 페이드 + Weapon 버스 로우패스 6.5 kHz</p>
    ${g.items.map(i => card(i, g.rate)).join("")}
  </section>`).join("");

document.getElementById("rest").innerHTML = DATA.rest.map(it => `
  <div class="rrow" data-card="${it.id}">
    <button class="rp" data-src="orig"><span class="t"></span></button>
    <div class="rname">${esc(it.short)}
      <small>${it.m.dur.toFixed(2)}s · 중심 ${it.m.centroid.toFixed(0)}Hz · 저역 ${pct(it.m.low)} ·
      <a href="${it.url}" target="_blank" rel="noopener">#${it.id}</a></small></div>
    ${waveSvg(it.wave, "rw")}
    <div class="verdict">${verdictHtml(it.id)}</div>
  </div>`).join("");

// 재생 배선
const byId = {};
DATA.groups.forEach(g => g.items.forEach(i => byId[i.id] = i));
DATA.rest.forEach(i => byId[i.id] = i);

document.addEventListener("click", e => {
  const pb = e.target.closest(".pl, .rp");
  if(pb){
    const host = pb.closest("[data-card]");
    const it = byId[host.dataset.card];
    play(pb, it.clips[pb.dataset.src], host.querySelector("svg"));
    return;
  }
  const vb = e.target.closest(".v");
  if(vb){
    const id = vb.dataset.id, val = vb.dataset.v;
    state[id] = state[id] || {};
    state[id].v = (state[id].v === val) ? null : val;
    save(); refreshVerdicts(); return;
  }
});
document.addEventListener("input", e => {
  if(e.target.classList.contains("memo")){
    const id = e.target.dataset.id;
    state[id] = state[id] || {};
    state[id].note = e.target.value;
    save();
  }
});

function save(){ localStorage.setItem(KEY, JSON.stringify(state)); }
function refreshVerdicts(){
  document.querySelectorAll(".v").forEach(b => {
    const s = state[b.dataset.id];
    b.setAttribute("aria-pressed", !!(s && s.v === b.dataset.v));
  });
  document.querySelectorAll(".card").forEach(c => {
    const s = state[c.dataset.card];
    c.classList.toggle("done", !!(s && s.v === "ok"));
    c.classList.toggle("no", !!(s && s.v === "no"));
  });
  const vals = Object.values(state).map(s => s && s.v).filter(Boolean);
  document.getElementById("prog").textContent = vals.length;
  document.getElementById("nok").textContent = vals.filter(v => v === "ok").length;
  document.getElementById("nhold").textContent = vals.filter(v => v === "hold").length;
  document.getElementById("nno").textContent = vals.filter(v => v === "no").length;
}
const nCand = DATA.groups.reduce((a,g) => a + g.items.length, 0);
document.getElementById("ncand").textContent = nCand;
document.getElementById("tot").textContent = nCand + DATA.rest.length;
refreshVerdicts();

document.getElementById("stop").onclick = stopAll;
document.getElementById("reset").onclick = () => {
  if(!confirm("판정을 전부 지운다. 계속?")) return;
  Object.keys(state).forEach(k => delete state[k]);
  save(); refreshVerdicts();
  document.querySelectorAll(".memo").forEach(m => m.value = "");
};

const VN = { ok:"채택", hold:"보류", no:"기각" };
document.getElementById("export").onclick = () => {
  stopAll();
  const L = [];
  L.push("## 총격 사운드 오디션 결과 — Gun Sounds 01 (GokhanBiyik, CC-BY 4.0)");
  L.push("");
  let any = false;
  DATA.groups.forEach(g => {
    const rows = g.items.filter(i => state[i.id] && state[i.id].v);
    if(!rows.length) return;
    any = true;
    L.push(`### ${g.title}  (${g.need})`);
    L.push(`- 자리: \`${g.slot}\``);
    rows.forEach(i => {
      const s = state[i.id];
      L.push(`- **${VN[s.v]}** · \`${i.file}\`${s.note ? " — " + s.note : ""}`);
    });
    L.push("");
  });
  const extra = DATA.rest.filter(i => state[i.id] && state[i.id].v);
  if(extra.length){
    any = true;
    L.push("### 나머지에서 고른 것");
    extra.forEach(i => L.push(`- **${VN[state[i.id].v]}** · \`${i.file}\`${state[i.id].note ? " — " + state[i.id].note : ""}`));
    L.push("");
  }
  if(!any) L.push("_아직 아무것도 판정하지 않았다._\n");
  L.push("### 크레딧 관리");
  L.push("- [ ] CC-BY 4.0 크레딧(`Docs/CREDITS.md` + 게임 내 크레딧)을 감수하고 이 팩을 쓴다");
  L.push("- [ ] 아니면 이 팩은 전부 버리고 michorvath CC0 9종으로 간다");
  document.getElementById("outtext").value = L.join("\n");
  document.getElementById("out").classList.add("open");
};
document.getElementById("close").onclick = () => document.getElementById("out").classList.remove("open");
document.getElementById("copy").onclick = async () => {
  const ta = document.getElementById("outtext");
  ta.select();
  try{ await navigator.clipboard.writeText(ta.value); }catch(e){ document.execCommand("copy"); }
  const b = document.getElementById("copy");
  b.textContent = "복사됨"; setTimeout(() => b.textContent = "클립보드로 복사", 1400);
};
document.addEventListener("keydown", e => {
  if(e.key === "Escape"){ stopAll(); document.getElementById("out").classList.remove("open"); }
});
</script>
</body>
</html>
"""


if __name__ == "__main__":
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else OUT_DEFAULT)
