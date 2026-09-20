# -*- coding: utf-8 -*-
"""NPC 말소리 **방식 10종**을 게임과 같은 규칙으로 들어 보는 한 장짜리 HTML.

파일 하나씩 눌러 봐서는 판단할 수 없다. 귀에 닿는 것은 조각 하나가 아니라
**한 사람이 한 줄을 말하는 동안 흘러가는 소리**이기 때문이다.
그래서 여기서는 dialogue_bubble.gd 의 재생 규칙을 그대로 옮겨 재현한다.

  타자 시계(cps · 문장부호 쉼) → 말투별 최소 간격 → 인물 기준음 × 문장 억양 × 글자별 흔들림
  + 방식(DialogueVoice.PRESETS)이 정하는 갈래 — 모음 블립 · 음소 블립 · 웅얼거림 · 줄머리 · 무음

같은 줄을 **사람(유나)과 기계(UNIT-7) 양쪽으로** 들어 볼 수 있게 두 벌씩 붙였다.
사람과 기계를 소리로 가르는 조합이 이 표의 핵심이기 때문이다.

게임 안에서 고르려면 NPC 대화 테스트씬(로비 → "대화 UI 랩")에서 V / Shift+V.
수치를 고치려면 dialogue_bubble.gd(VOICES · VOICE_*) · npc_data.gd(CAST.tone) ·
dialogue_voice.gd(PRESETS) 를 보고 아래 표를 같이 맞춘다.

사용:
    python Tools/build_voice_audition.py
출력:
    Docs/_audition/voice.html
"""

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VOICE_DIR = ROOT / "GodotPrototype/assets/audio/sfx/voice"
OUT = ROOT / "Docs/_audition/voice.html"

# dialogue_bubble.gd VOICES
VOICES = {
    "slow":    {"cps": 27.0, "gap": 0.085, "jit": 0.05},
    "soft":    {"cps": 31.0, "gap": 0.075, "jit": 0.055},
    "clipped": {"cps": 39.0, "gap": 0.062, "jit": 0.035},
    "quick":   {"cps": 44.0, "gap": 0.056, "jit": 0.065},
    "machine": {"cps": 34.0, "gap": 0.070, "jit": 0.02},
}

# dialogue_voice.gd PRESETS
PRESETS = [
    ("모음 블립", "글자마다 아무 모음 조각 하나. 언더테일 결", "blip", "blip", False),
    ("음소 블립", "글자마다 그 글자의 실제 모음. 동물의 숲 결", "phoneme", "phoneme", False),
    ("웅얼거림", "말하는 동안 이음 루프가 돈다. 음높이만 억양을 따라간다", "murmur", "murmur", False),
    ("줄머리 한마디", "줄이 시작될 때 두세 음절만 한 번. 나머지는 조용하다", "off", "off", True),
    ("무음", "소리 없이 자막만 — 비교 기준선", "off", "off", False),
    ("블립 + 기계 웅얼", "사람은 블립 그대로, UNIT-7 만 웅얼로 가른다", "blip", "murmur", False),
    ("음소 + 기계 웅얼", "추천 — 사람은 모음을 따라 말하고 기계는 웅얼거린다", "phoneme", "murmur", False),
    ("음소 + 줄머리", "한마디로 열고 음소 블립으로 잇는다", "phoneme", "phoneme", True),
    ("음소 + 기계 웅얼 + 줄머리", "추천안 + 줄머리. 가장 두껍다", "phoneme", "murmur", True),
    ("웅얼 + 줄머리", "한마디로 열고 나머지는 웅얼로 흘린다", "murmur", "murmur", True),
]

# npc_data.gd CAST — 사람 하나, 기계 하나. 대사는 그 인물이 실제로 하는 말이다
SPEAKERS = [
    ("유나 (연구원)", "quick", 1.05, "그거, 아무한테도 말 안 할 수 있어? 진짜로?"),
    ("UNIT-7 (로봇)", "machine", 1.00, "질의. 이 목록에 사람이 없는 이유."),
]

PUNCT_PAUSE = {".": 0.20, "!": 0.24, "?": 0.24, ",": 0.11, "…": 0.28, "—": 0.16, "·": 0.10}
SILENT = " \t.,!?…—·:;\"'()[]{}<>~-"

# dialogue_voice.gd 의 모음 7종과 중성 접기표
VOWELS = ["a", "eo", "o", "u", "eu", "i", "e"]
JUNG_TO_VOWEL = [0, 6, 0, 6, 1, 6, 1, 6, 2, 0, 6, 6, 2, 3, 1, 6, 5, 3, 4, 5, 5]

HTML = """<!doctype html>
<meta charset="utf-8">
<title>NPC 말소리 방식 오디션</title>
<style>
 body{background:#12141a;color:#dcdfe6;font:15px/1.7 "Malgun Gothic",system-ui,sans-serif;margin:0;padding:40px 40px 80px}
 h1{font-size:22px;margin:0 0 6px}
 p.sub{color:#8d93a1;margin:0 0 26px;max-width:900px}
 .row{background:#181b22;border:1px solid #262b35;border-left:3px solid #5b6a86;padding:14px 18px;margin:0 0 10px;border-radius:4px;display:flex;align-items:center;gap:18px;flex-wrap:wrap}
 .row.pick{border-left-color:#c8a24a}
 .num{color:#6d7486;font-variant-numeric:tabular-nums;min-width:22px}
 .txt{flex:1;min-width:320px}
 .name{font-weight:700}
 .desc{color:#8d93a1;font-size:13.5px}
 button{background:#2b3240;color:#e6e9f0;border:1px solid #3a4354;border-radius:3px;padding:7px 14px;font:inherit;font-size:14px;cursor:pointer}
 button:hover{background:#39425a}
 button.stop{background:#3a2b2b;border-color:#54393a}
 .bar{position:fixed;left:0;right:0;bottom:0;background:#0e1016;border-top:1px solid #262b35;padding:12px 40px;color:#8d93a1;font-size:13.5px}
 .line{color:#c8cdd8}
 code{color:#a8b3c7}
</style>
<h1>NPC 말소리 방식 오디션</h1>
<p class="sub">
 같은 대사를 방식만 바꿔 가며 듣는다. 왼쪽 버튼은 <b>사람(유나)</b>, 오른쪽은 <b>기계(UNIT-7)</b> —
 사람과 기계를 소리로 가르는 조합이 이 표의 핵심이라 두 벌을 나란히 두었다.
 게임 안에서 고르려면 NPC 대화 테스트씬에서 <code>V</code> / <code>Shift+V</code>.
</p>
<div id="rows"></div>
<div class="bar">
 소리: <code>Tools/build_npc_voice_blips.py</code> · 방식 표: <code>scripts/dialogue_voice.gd</code> ·
 재생 규칙: <code>scripts/dialogue_bubble.gd</code>
</div>
<script>
const SAMPLES = __SAMPLES__;      /* "quick_a" 같은 키 → base64 wav */
const VOICES = __VOICES__;
const PRESETS = __PRESETS__;
const SPEAKERS = __SPEAKERS__;
const PUNCT = __PUNCT__;
const SILENT = __SILENT__;
const VOWELS = __VOWELS__;
const JUNG = __JUNG__;
const START_PITCH = 1.035, END_PITCH = 0.965, Q_PITCH = 1.10;
const MURMUR_GAIN = 0.42, OPEN_GAIN = 1.0, BLIP_GAIN = 0.85;

const ctx = new (window.AudioContext || window.webkitAudioContext)();
const buffers = {};
let playing = [];

async function load() {
  for (const [key, b64] of Object.entries(SAMPLES)) {
    const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
    buffers[key] = await ctx.decodeAudioData(bytes.buffer);
  }
}

/* dialogue_voice.gd vowel_for() — 한글이면 중성을 떼어 7종으로 접는다 */
function vowelFor(ch) {
  const c = ch.codePointAt(0);
  if (c >= 0xAC00 && c <= 0xD7A3) return VOWELS[JUNG[Math.floor((c - 0xAC00) / 28) % 21]];
  return VOWELS[c % VOWELS.length];
}

function stopAll() {
  playing.forEach(n => { try { n.stop(); } catch (e) {} });
  playing = [];
}

function one(key, when, pitch, gain) {
  const buf = buffers[key];
  if (!buf) return;
  const src = ctx.createBufferSource();
  src.buffer = buf;
  src.playbackRate.value = pitch;
  const g = ctx.createGain();
  g.gain.value = gain;
  src.connect(g).connect(ctx.destination);
  src.start(when);
  playing.push(src);
}

/* 한 줄을 그 방식으로 말한다 — dialogue_bubble.gd 의 타자 시계 + _speak_upto() + _blip_pitch() */
function speak(presetIndex, speakerIndex) {
  stopAll();
  const [, , human, machine, opener] = PRESETS[presetIndex];
  const [, voiceId, tone, text] = SPEAKERS[speakerIndex];
  const mode = voiceId === "machine" ? machine : human;
  const v = VOICES[voiceId];
  const chars = Array.from(text);
  const question = text.trim().endsWith("?");
  const voiced = chars.filter(c => !SILENT.includes(c)).length;
  const t0 = ctx.currentTime + 0.06;

  const contour = at => {
    const end = question ? Q_PITCH : END_PITCH;
    const k = question ? at * at : at;
    return START_PITCH + (end - START_PITCH) * k;
  };

  if (opener) {
    const n = 1 + Math.floor(Math.random() * 3);
    one(`${voiceId}_open_0${n}`, t0, tone, OPEN_GAIN);
  }

  /* 줄 전체 길이 = 타자 시계의 끝 */
  let total = 0;
  chars.forEach(ch => { total += (ch === " " ? 0.5 : 1.0) / v.cps; total += PUNCT[ch] || 0; });

  if (mode === "murmur") {
    const src = ctx.createBufferSource();
    src.buffer = buffers[`${voiceId}_murmur`];
    src.loop = true;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(MURMUR_GAIN, t0 + 0.07);
    g.gain.setValueAtTime(MURMUR_GAIN, t0 + total - 0.07);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + total);
    /* 음높이만 문장 억양을 따라 움직인다 */
    src.playbackRate.setValueAtTime(tone * contour(0), t0);
    for (let i = 1; i <= 12; i++) {
      const at = i / 12;
      src.playbackRate.linearRampToValueAtTime(tone * contour(at), t0 + total * at);
    }
    src.connect(g).connect(ctx.destination);
    src.start(t0);
    src.stop(t0 + total + 0.05);
    playing.push(src);
    return;
  }
  if (mode === "off") return;

  let t = 0, lastBlip = -99, n = 0;
  chars.forEach(ch => {
    if (!SILENT.includes(ch)) {
      if (t - lastBlip >= v.gap) {
        lastBlip = t;
        const at = Math.min(n / Math.max(voiced - 1, 1), 1);
        const jit = v.jit * (Math.random() * 2 - 1);
        const vowel = mode === "phoneme" ? vowelFor(ch) : VOWELS[(Math.random() * VOWELS.length) | 0];
        one(`${voiceId}_${vowel}`, t0 + t, tone * contour(at) * (1 + jit), BLIP_GAIN);
      }
      n++;
    }
    t += (ch === " " ? 0.5 : 1.0) / v.cps;
    t += PUNCT[ch] || 0;
  });
}

const rows = document.getElementById("rows");
PRESETS.forEach(([name, desc], i) => {
  const el = document.createElement("div");
  el.className = "row" + (name.startsWith("음소 + 기계") ? " pick" : "");
  el.innerHTML = `<div class="num">${i + 1}</div>
    <div class="txt"><div class="name">${name}</div><div class="desc">${desc}</div></div>`;
  SPEAKERS.forEach(([who], si) => {
    const b = document.createElement("button");
    b.textContent = "▶ " + who.split(" ")[0];
    b.onclick = async () => { await ctx.resume(); speak(i, si); };
    el.appendChild(b);
  });
  rows.appendChild(el);
});
const stop = document.createElement("button");
stop.textContent = "■ 멈춤";
stop.className = "stop";
stop.onclick = stopAll;
rows.appendChild(stop);
load();
</script>
"""


def main() -> None:
    samples = {}
    for wav in sorted(VOICE_DIR.glob("*.wav")):
        samples[wav.stem] = base64.b64encode(wav.read_bytes()).decode("ascii")
    if not samples:
        raise SystemExit("소리가 없다 — 먼저 Tools/build_npc_voice_blips.py 를 돌릴 것")

    html = (HTML
            .replace("__SAMPLES__", json.dumps(samples))
            .replace("__VOICES__", json.dumps(VOICES, ensure_ascii=False))
            .replace("__PRESETS__", json.dumps(PRESETS, ensure_ascii=False))
            .replace("__SPEAKERS__", json.dumps(SPEAKERS, ensure_ascii=False))
            .replace("__PUNCT__", json.dumps(PUNCT_PAUSE, ensure_ascii=False))
            .replace("__SILENT__", json.dumps(SILENT))
            .replace("__VOWELS__", json.dumps(VOWELS))
            .replace("__JUNG__", json.dumps(JUNG_TO_VOWEL)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print("%s  (%d 소리 · %.1f MB)" % (OUT, len(samples), OUT.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
