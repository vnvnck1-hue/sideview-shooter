# -*- coding: utf-8 -*-
"""Kenney 오디오 선별 결과를 브라우저에서 하나씩 들어볼 수 있는 단일 HTML로 만든다.

ogg를 base64 data URI로 박아 넣으므로 결과 파일 하나만 있으면 어디서든 재생된다.
선별 근거는 Docs/KENNEY_AUDIO_PICKS.md, 실제 복사는 Tools/stage_kenney_audio.ps1.

사용:
    python Tools/build_audio_audition.py [출력경로.html]
"""

import base64
import html
import json
import sys
from pathlib import Path

KENNEY = Path(
    r"D:\2020_이전승찬파일\작업,내파일"
    r"\Kenney Game Assets All-in-1 3.4.0 (Windows)"
    r"\Kenney Game Assets All-in-1 3.7.0\Audio"
)

# status: ok = 그대로 사용 / temp = 임시 대체, 교체 예정 / raw = 가공 후 사용
GROUPS = [
    {
        "id": "footstep",
        "event": "걷기",
        "code": "player.gd:169",
        "status": "ok",
        "note": "콘크리트 5배리에이션. AudioStreamRandomizer에 묶고 피치 0.95~1.05.",
        "pack": "Impact Sounds",
        "src": "Audio/footstep_concrete_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Player/footstep_{n:02d}.ogg",
    },
    {
        "id": "cloth",
        "event": "앉기 / 일어서기",
        "code": "player.gd crouch",
        "status": "ok",
        "note": "옷 스침. 크라우치 전환에 짧게.",
        "pack": "RPG Audio",
        "src": "Audio/cloth{i}.ogg",
        "idx": range(1, 5),
        "dest": "SFX/Player/cloth_{n:02d}.ogg",
    },
    {
        "id": "roll_woosh",
        "event": "구르기 · 회전",
        "code": "player.gd:297",
        "status": "ok",
        "note": "착지음(아래)과 2레이어로 겹칠 것.",
        "pack": "Foley Sounds",
        "src": "Audio/Woosh/woosh{i}.ogg",
        "idx": range(1, 5),
        "dest": "SFX/Player/roll_woosh_{n:02d}.ogg",
    },
    {
        "id": "roll_land",
        "event": "구르기 · 착지",
        "code": "player.gd:314",
        "status": "ok",
        "note": "둔탁한 몸 착지.",
        "pack": "Impact Sounds",
        "src": "Audio/impactSoft_medium_00{i}.ogg",
        "idx": range(0, 3),
        "dest": "SFX/Player/roll_land_{n:02d}.ogg",
    },
    {
        "id": "fire",
        "event": "발사",
        "code": "player.gd:257",
        "status": "temp",
        "note": "Kenney에 실총성이 없어 SF 레이저로 임시 대체. 아래 '조합 후보'도 같이 들어볼 것.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/laserSmall_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Weapon/fire_temp_{n:02d}.ogg",
    },
    {
        "id": "fire_alt",
        "event": "발사 · 조합 후보",
        "code": "player.gd:257",
        "status": "temp",
        "note": "이 둘을 짧게 겹치면 둔탁한 실총에 가까워진다. 레이저보다 나은지 비교해 볼 것.",
        "files": [
            ("Sci-Fi Sounds", "Audio/impactMetal_000.ogg", "금속 타격(어택용)"),
            ("Sci-Fi Sounds", "Audio/impactMetal_001.ogg", "금속 타격 변형"),
            ("Sci-Fi Sounds", "Audio/explosionCrunch_000.ogg", "크런치(보디용)"),
            ("Sci-Fi Sounds", "Audio/lowFrequency_explosion_000.ogg", "저역 보강"),
        ],
    },
    {
        "id": "shell",
        "event": "탄피 낙하",
        "code": "shell_casing.gd",
        "status": "raw",
        "note": "가장 근접. 피치를 3~5반음 올리면 탄피에 가까워진다.",
        "pack": "Impact Sounds",
        "src": "Audio/impactTin_medium_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Weapon/shell_{n:02d}.ogg",
    },
    {
        "id": "imp_metal",
        "event": "탄착 · 금속",
        "code": "bullet.gd:144",
        "status": "ok",
        "note": "",
        "pack": "Impact Sounds",
        "src": "Audio/impactMetal_light_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Impact/metal_{n:02d}.ogg",
    },
    {
        "id": "imp_concrete",
        "event": "탄착 · 콘크리트",
        "code": "bullet.gd:144",
        "status": "ok",
        "note": "광산 곡괭이 계열. 돌·콘크리트 재질에 잘 맞는다.",
        "pack": "Impact Sounds",
        "src": "Audio/impactMining_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Impact/concrete_{n:02d}.ogg",
    },
    {
        "id": "imp_wood",
        "event": "탄착 · 목재",
        "code": "bullet.gd:144",
        "status": "ok",
        "note": "",
        "pack": "Impact Sounds",
        "src": "Audio/impactWood_medium_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Impact/wood_{n:02d}.ogg",
    },
    {
        "id": "imp_generic",
        "event": "탄착 · 범용",
        "code": "bullet.gd:144",
        "status": "ok",
        "note": "재질 판정이 없는 경우의 기본값.",
        "pack": "Impact Sounds",
        "src": "Audio/impactGeneric_light_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Impact/generic_{n:02d}.ogg",
    },
    {
        "id": "glass_crack",
        "event": "유리 · 금가기",
        "code": "glass_window.gd:29",
        "status": "ok",
        "note": "1단계. 아래 파손음과 2단계로 나눠 쓴다.",
        "pack": "Impact Sounds",
        "src": "Audio/impactGlass_light_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Glass/crack_{n:02d}.ogg",
    },
    {
        "id": "glass_shatter",
        "event": "유리 · 파손",
        "code": "glass_window.gd:29",
        "status": "ok",
        "note": "2단계.",
        "pack": "Impact Sounds",
        "src": "Audio/impactGlass_heavy_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Glass/shatter_{n:02d}.ogg",
    },
    {
        "id": "prop_plate",
        "event": "프랍 타격 · 금속판",
        "code": "hit_prop.gd:52",
        "status": "ok",
        "note": "",
        "pack": "Foley Sounds",
        "src": "Audio/Plating/platesHit{i}.ogg",
        "idx": range(1, 6),
        "dest": "SFX/Prop/plate_{n:02d}.ogg",
    },
    {
        "id": "prop_stone",
        "event": "프랍 타격 · 돌",
        "code": "hit_prop.gd:52",
        "status": "ok",
        "note": "",
        "pack": "Foley Sounds",
        "src": "Audio/Rocks/stoneHit{i}.ogg",
        "idx": range(1, 6),
        "dest": "SFX/Prop/stone_{n:02d}.ogg",
    },
    {
        "id": "prop_plank",
        "event": "프랍 타격 · 판자",
        "code": "hit_prop.gd:52",
        "status": "ok",
        "note": "",
        "pack": "Impact Sounds",
        "src": "Audio/impactPlank_medium_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Prop/plank_{n:02d}.ogg",
    },
    {
        "id": "lamp_zap",
        "event": "조명 파괴 · 스파크",
        "code": "lamp_light.gd:105",
        "status": "ok",
        "note": "유리 파손 + 스파크 + 글리치 3레이어로 조합할 것.",
        "pack": "Digital Audio",
        "src": "Audio/zap{i}.ogg",
        "idx": range(1, 3),
        "dest": "SFX/Lamp/zap_{n:02d}.ogg",
    },
    {
        "id": "lamp_glitch",
        "event": "조명 파괴 · 글리치",
        "code": "lamp_light.gd:105",
        "status": "ok",
        "note": "회로가 죽는 느낌의 꼬리.",
        "pack": "Interface Sounds",
        "src": "Audio/glitch_00{i}.ogg",
        "idx": range(1, 5),
        "dest": "SFX/Lamp/glitch_{n:02d}.ogg",
    },
    {
        "id": "lamp_hum",
        "event": "조명 점멸 · 버즈 소스",
        "code": "lamp_light.gd:133",
        "status": "raw",
        "note": "그대로 쓰면 SF 역장 소리다. 로우패스 + 피치다운해야 형광등 험이 된다.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/forceField_00{i}.ogg",
        "idx": range(0, 5),
        "dest": "SFX/Lamp/hum_src_{n:02d}.ogg",
    },
    {
        "id": "door_open",
        "event": "문 열림",
        "code": "room.gd:131",
        "status": "ok",
        "note": "SF 해치 톤. 벌크헤드 도어 아트와 맞는다.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/doorOpen_00{i}.ogg",
        "idx": range(0, 3),
        "dest": "SFX/Door/scifi_open_{n:02d}.ogg",
    },
    {
        "id": "door_close",
        "event": "문 닫힘",
        "code": "room.gd:131",
        "status": "ok",
        "note": "",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/doorClose_00{i}.ogg",
        "idx": range(0, 3),
        "dest": "SFX/Door/scifi_close_{n:02d}.ogg",
    },
    {
        "id": "door_creak",
        "event": "문 삐걱 / 래치",
        "code": "room.gd:131",
        "status": "ok",
        "note": "낡은 느낌 보강용. 개폐음 앞에 짧게 붙인다.",
        "files": [
            ("RPG Audio", "Audio/creak1.ogg", "삐걱임 1"),
            ("RPG Audio", "Audio/creak2.ogg", "삐걱임 2"),
            ("RPG Audio", "Audio/creak3.ogg", "삐걱임 3"),
            ("RPG Audio", "Audio/metalLatch.ogg", "금속 래치"),
            ("RPG Audio", "Audio/metalClick.ogg", "금속 클릭"),
        ],
    },
    {
        "id": "explosion",
        "event": "대형 파괴 / 폭발",
        "code": "미구현",
        "status": "ok",
        "note": "크런치 + 저역을 겹치면 무게가 생긴다.",
        "files": [
            ("Sci-Fi Sounds", "Audio/explosionCrunch_000.ogg", "크런치 1"),
            ("Sci-Fi Sounds", "Audio/explosionCrunch_001.ogg", "크런치 2"),
            ("Sci-Fi Sounds", "Audio/explosionCrunch_002.ogg", "크런치 3"),
            ("Sci-Fi Sounds", "Audio/explosionCrunch_003.ogg", "크런치 4"),
            ("Sci-Fi Sounds", "Audio/explosionCrunch_004.ogg", "크런치 5"),
            ("Sci-Fi Sounds", "Audio/lowFrequency_explosion_000.ogg", "저역 1"),
            ("Sci-Fi Sounds", "Audio/lowFrequency_explosion_001.ogg", "저역 2"),
        ],
    },
    {
        "id": "amb_drip",
        "event": "앰비언스 · 물방울",
        "code": "room.gd",
        "status": "ok",
        "note": "지하 분위기에 직결. 불규칙한 간격으로 원샷 재생.",
        "pack": "Foley Sounds",
        "src": "Audio/Water/drip{i}.ogg",
        "idx": range(1, 5),
        "dest": "Ambience/drip_{n:02d}.ogg",
    },
    {
        "id": "amb_rumble",
        "event": "앰비언스 · 저역 소스",
        "code": "room.gd",
        "status": "raw",
        "note": "우주선 엔진 톤이라 그대로는 안 맞는다. 볼륨 크게 낮추고 로우패스.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/spaceEngineLow_00{i}.ogg",
        "idx": range(0, 3),
        "dest": "Ambience/rumble_src_{n:02d}.ogg",
    },
    {
        "id": "amb_machine",
        "event": "앰비언스 · 기계 소스",
        "code": "room.gd",
        "status": "raw",
        "note": "가장 긴 루프 소재. 가공 전제.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/engineCircular_00{i}.ogg",
        "idx": range(0, 3),
        "dest": "Ambience/machine_src_{n:02d}.ogg",
    },
    {
        "id": "amb_terminal",
        "event": "앰비언스 · 터미널",
        "code": "room.gd",
        "status": "ok",
        "note": "배경 소품(단말기)용.",
        "pack": "Sci-Fi Sounds",
        "src": "Audio/computerNoise_00{i}.ogg",
        "idx": range(0, 4),
        "dest": "Ambience/terminal_{n:02d}.ogg",
    },
    {
        "id": "ui",
        "event": "UI",
        "code": "미구현",
        "status": "ok",
        "note": "Interface Sounds 약 100개 중 대표만 추림. 더 필요하면 팩 전체에서 고를 수 있다.",
        "files": [
            ("Interface Sounds", "Audio/click_001.ogg", "클릭 1"),
            ("Interface Sounds", "Audio/click_002.ogg", "클릭 2"),
            ("Interface Sounds", "Audio/select_001.ogg", "호버"),
            ("Interface Sounds", "Audio/confirmation_001.ogg", "확인"),
            ("Interface Sounds", "Audio/back_001.ogg", "뒤로"),
            ("Interface Sounds", "Audio/error_001.ogg", "오류"),
            ("Interface Sounds", "Audio/switch_001.ogg", "토글"),
            ("Interface Sounds", "Audio/tick_001.ogg", "틱"),
        ],
    },
]

STATUS_LABEL = {
    "ok": ("그대로 사용", "ok"),
    "temp": ("임시 · 교체 예정", "temp"),
    "raw": ("가공 필요", "raw"),
}


def load(pack: str, rel: str):
    p = KENNEY / pack / rel
    if not p.exists():
        return None, 0
    data = p.read_bytes()
    return base64.b64encode(data).decode("ascii"), len(data)


def build():
    groups_out = []
    total_bytes = 0
    missing = []

    for g in GROUPS:
        rows = []
        if "files" in g:
            entries = [(pack, rel, label, None) for pack, rel, label in g["files"]]
        else:
            entries = [
                (g["pack"], g["src"].format(i=i), None, g["dest"].format(n=n))
                for n, i in enumerate(g["idx"], start=1)
            ]

        for pack, rel, label, dest in entries:
            b64, size = load(pack, rel)
            if b64 is None:
                missing.append(f"{pack}/{rel}")
                continue
            total_bytes += size
            rows.append(
                {
                    "id": f"{g['id']}-{len(rows) + 1}",
                    "src": rel.rsplit("/", 1)[-1],
                    "pack": pack,
                    "dest": dest or "",
                    "label": label or "",
                    "kb": round(size / 1024, 1),
                    "b64": b64,
                }
            )

        groups_out.append(
            {
                "id": g["id"],
                "event": g["event"],
                "code": g["code"],
                "status": g["status"],
                "note": g["note"],
                "rows": rows,
            }
        )

    return groups_out, total_bytes, missing


def render(groups, total_bytes, missing):
    nav = "\n".join(
        '<a class="navlink" href="#g-{id}"><span>{event}</span>'
        '<span class="navnum">{n}</span></a>'.format(
            id=g["id"], event=html.escape(g["event"]), n=len(g["rows"])
        )
        for g in groups
    )

    sections = []
    for g in groups:
        label, cls = STATUS_LABEL[g["status"]]
        rows = []
        for r in g["rows"]:
            sub = r["dest"] or r["label"]
            rows.append(
                """<li class="row" data-id="{rid}">
  <button class="play" type="button" data-id="{rid}" aria-label="{src} 재생">
    <span class="tri" aria-hidden="true"></span>
  </button>
  <div class="meta">
    <span class="dest">{sub}</span>
    <span class="src">{pack} / {src}</span>
  </div>
  <div class="bar"><i></i></div>
  <span class="kb">{kb} KB</span>
  <button class="pick" type="button" data-id="{rid}" aria-pressed="false">채택</button>
</li>""".format(
                    rid=r["id"],
                    src=html.escape(r["src"]),
                    pack=html.escape(r["pack"]),
                    sub=html.escape(sub) if sub else "&nbsp;",
                    kb=r["kb"],
                )
            )

        note = (
            '<p class="note">{}</p>'.format(html.escape(g["note"])) if g["note"] else ""
        )
        sections.append(
            """<section class="group" id="g-{id}">
  <header class="ghead">
    <div class="gtitle">
      <h2>{event}</h2>
      <code class="loc">{code}</code>
    </div>
    <div class="gtools">
      <span class="chip {cls}">{label}</span>
      <button class="seq" type="button" data-group="{id}">연속 재생</button>
    </div>
  </header>
  {note}
  <ul class="rows">
{rows}
  </ul>
</section>""".format(
                id=g["id"],
                event=html.escape(g["event"]),
                code=html.escape(g["code"]),
                cls=cls,
                label=label,
                note=note,
                rows="\n".join(rows),
            )
        )

    audio_map = {r["id"]: r["b64"] for g in groups for r in g["rows"]}
    name_map = {
        r["id"]: (r["dest"] or r["label"] or r["src"]) + "  ←  " + r["src"]
        for g in groups
        for r in g["rows"]
    }
    seq_map = {g["id"]: [r["id"] for r in g["rows"]] for g in groups}

    total_rows = sum(len(g["rows"]) for g in groups)
    warn = ""
    if missing:
        warn = '<p class="warn">원본을 찾지 못한 파일 {}개: {}</p>'.format(
            len(missing), html.escape(", ".join(missing))
        )

    return TEMPLATE.format(
        nav=nav,
        sections="\n".join(sections),
        total_rows=total_rows,
        total_groups=len(groups),
        total_mb=round(total_bytes / 1024 / 1024, 2),
        warn=warn,
        audio=json.dumps(audio_map),
        names=json.dumps(name_map, ensure_ascii=False),
        seqs=json.dumps(seq_map),
    )


TEMPLATE = """<title>사운드 오디션 콘솔</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gothic+A1:wght@500;800&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+KR:wght@400;500&display=swap">
<style>
:root {{
  color-scheme: dark;
  --ground: #101319;
  --surface: #171B23;
  --surface-2: #1E232D;
  --line: #2A303C;
  --line-soft: #222836;
  --ink: #DCE0E8;
  --ink-dim: #8B93A3;
  --ink-faint: #5E6675;
  --amber: #E8A33D;
  --rust: #C4523E;
  --steel: #6E8BA8;
  --ok: #7FA663;
  --display: 'Gothic A1', 'Malgun Gothic', sans-serif;
  --body: 'IBM Plex Sans KR', 'Malgun Gothic', sans-serif;
  --mono: 'IBM Plex Mono', ui-monospace, monospace;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--ground);
  color: var(--ink);
  font-family: var(--body);
  font-size: 14px;
  line-height: 1.6;
}}
.wrap {{
  max-width: 1120px;
  margin: 0 auto;
  padding-inline: 20px;
  padding-block: 0 72px;
}}

/* ---------- 헤더 ---------- */
.top {{
  border-bottom: 1px solid var(--line);
  padding-block: 40px 28px;
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
  align-items: flex-end;
  justify-content: space-between;
}}
.eyebrow {{
  font-family: var(--mono);
  font-size: 11px;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-faint);
  margin: 0 0 10px;
}}
h1 {{
  font-family: var(--display);
  font-weight: 800;
  font-size: clamp(26px, 5vw, 38px);
  line-height: 1.15;
  margin: 0;
  text-wrap: balance;
}}
.lede {{ color: var(--ink-dim); margin: 12px 0 0; max-width: 54ch; }}
.stats {{ display: flex; gap: 28px; font-family: var(--mono); }}
.stat b {{
  display: block;
  font-size: 24px;
  font-weight: 500;
  color: var(--amber);
  font-variant-numeric: tabular-nums;
}}
.stat span {{ font-size: 11px; color: var(--ink-faint); letter-spacing: .08em; }}

/* ---------- 본문 2단 ---------- */
.main {{ display: grid; grid-template-columns: 200px 1fr; gap: 40px; padding-top: 32px; }}
@media (max-width: 860px) {{ .main {{ grid-template-columns: 1fr; gap: 24px; }} }}

nav.rail {{ position: sticky; top: env(safe-area-inset-top, 0px); align-self: start; padding-top: 4px; }}
@media (max-width: 860px) {{
  nav.rail {{ position: static; display: flex; flex-wrap: wrap; gap: 6px; }}
  nav.rail .railhead {{ width: 100%; }}
}}
.railhead {{
  font-family: var(--mono);
  font-size: 10px;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-faint);
  padding-bottom: 10px;
  border-bottom: 1px solid var(--line-soft);
  margin-bottom: 8px;
}}
.navlink {{
  display: flex;
  justify-content: space-between;
  gap: 10px;
  padding: 5px 8px;
  color: var(--ink-dim);
  text-decoration: none;
  border-radius: 3px;
  font-size: 13px;
}}
.navlink:hover {{ background: var(--surface); color: var(--ink); }}
.navnum {{ font-family: var(--mono); font-size: 11px; color: var(--ink-faint); }}

/* ---------- 그룹 ---------- */
.group {{ margin-bottom: 40px; scroll-margin-top: 20px; }}
.ghead {{
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: baseline;
  justify-content: space-between;
  border-bottom: 1px solid var(--line);
  padding-bottom: 10px;
}}
.gtitle {{ display: flex; flex-wrap: wrap; gap: 10px; align-items: baseline; }}
.ghead h2 {{ font-family: var(--display); font-weight: 800; font-size: 17px; margin: 0; }}
.loc {{ font-family: var(--mono); font-size: 11px; color: var(--ink-faint); }}
.gtools {{ display: flex; gap: 10px; align-items: center; }}
.chip {{
  font-family: var(--mono);
  font-size: 10px;
  letter-spacing: .06em;
  padding: 3px 8px;
  border-radius: 2px;
  border: 1px solid;
  white-space: nowrap;
}}
.chip.ok   {{ color: var(--ok);    border-color: color-mix(in srgb, var(--ok) 45%, transparent); }}
.chip.temp {{ color: var(--rust);  border-color: color-mix(in srgb, var(--rust) 50%, transparent); }}
.chip.raw  {{ color: var(--amber); border-color: color-mix(in srgb, var(--amber) 45%, transparent); }}
.seq {{
  font-family: var(--mono);
  font-size: 11px;
  background: none;
  border: 1px solid var(--line);
  color: var(--ink-dim);
  padding: 3px 9px;
  border-radius: 2px;
  cursor: pointer;
}}
.seq:hover {{ border-color: var(--steel); color: var(--ink); }}
.note {{ color: var(--ink-dim); font-size: 13px; margin: 10px 0 0; max-width: 62ch; }}

/* ---------- 행 ---------- */
.rows {{ list-style: none; margin: 8px 0 0; padding: 0; }}
.row {{
  display: grid;
  grid-template-columns: 30px minmax(0, 1fr) 110px 58px 54px;
  gap: 14px;
  align-items: center;
  padding: 7px 8px 7px 0;
  border-bottom: 1px solid var(--line-soft);
}}
@media (max-width: 680px) {{
  .row {{ grid-template-columns: 30px minmax(0, 1fr) 54px; row-gap: 6px; }}
  .row .bar {{ grid-column: 2 / 4; }}
  .row .kb {{ display: none; }}
}}
.row.active {{ background: var(--surface); }}
.play {{
  width: 30px; height: 30px;
  border-radius: 50%;
  border: 1px solid var(--line);
  background: var(--surface-2);
  display: grid; place-items: center;
  cursor: pointer;
  padding: 0;
}}
.play:hover {{ border-color: var(--amber); }}
.tri {{
  width: 0; height: 0;
  border-left: 7px solid var(--ink-dim);
  border-top: 5px solid transparent;
  border-bottom: 5px solid transparent;
  margin-left: 2px;
}}
.row.active .tri {{ border-left-color: var(--amber); }}
.meta {{ min-width: 0; display: flex; flex-direction: column; }}
.dest {{
  font-family: var(--mono);
  font-size: 12.5px;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}}
.src {{
  font-family: var(--mono);
  font-size: 10.5px;
  color: var(--ink-faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}}
.bar {{ height: 3px; background: var(--line-soft); border-radius: 2px; overflow: hidden; }}
.bar i {{ display: block; height: 100%; width: 0; background: var(--amber); }}
.kb {{
  font-family: var(--mono);
  font-size: 10.5px;
  color: var(--ink-faint);
  text-align: right;
  font-variant-numeric: tabular-nums;
}}
.pick {{
  font-family: var(--mono);
  font-size: 11px;
  background: none;
  border: 1px solid var(--line);
  color: var(--ink-faint);
  padding: 3px 0;
  border-radius: 2px;
  cursor: pointer;
}}
.pick:hover {{ border-color: var(--steel); }}
.pick[aria-pressed="true"] {{
  background: color-mix(in srgb, var(--ok) 18%, transparent);
  border-color: var(--ok);
  color: var(--ok);
}}

/* ---------- 하단 바 ---------- */
.dock {{
  position: fixed;
  left: 0; right: 0; bottom: 0;
  background: color-mix(in srgb, var(--surface) 94%, transparent);
  backdrop-filter: blur(8px);
  border-top: 1px solid var(--line);
  padding: 10px 20px;
  padding-bottom: calc(10px + env(safe-area-inset-bottom, 0px));
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  z-index: 10;
}}
.now {{
  font-family: var(--mono);
  font-size: 11.5px;
  color: var(--ink-dim);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}}
.dock .right {{ display: flex; gap: 10px; align-items: center; }}
.count {{ font-family: var(--mono); font-size: 11.5px; color: var(--amber); }}
.dock button {{
  font-family: var(--mono);
  font-size: 11.5px;
  background: var(--surface-2);
  border: 1px solid var(--line);
  color: var(--ink-dim);
  padding: 5px 11px;
  border-radius: 2px;
  cursor: pointer;
}}
.dock button:hover {{ border-color: var(--amber); color: var(--ink); }}
.warn {{
  border-left: 2px solid var(--rust);
  padding-left: 12px;
  color: var(--rust);
  font-size: 13px;
}}
:focus-visible {{ outline: 2px solid var(--amber); outline-offset: 2px; }}
@media (prefers-reduced-motion: reduce) {{ * {{ transition: none !important; }} }}
</style>

<div class="wrap">
  <header class="top">
    <div>
      <p class="eyebrow">Kenney All-in-1 · CC0 · sideview-shooter</p>
      <h1>사운드 오디션 콘솔</h1>
      <p class="lede">프로젝트에 넣으려는 후보를 게임 이벤트별로 묶었습니다. 하나씩 들어보고 채택할 것만 표시하세요. 아래쪽 <b>선택 결과 복사</b>를 누르면 목록이 클립보드로 복사됩니다.</p>
    </div>
    <div class="stats">
      <div class="stat"><b>{total_rows}</b><span>SOUNDS</span></div>
      <div class="stat"><b>{total_groups}</b><span>EVENTS</span></div>
      <div class="stat"><b>{total_mb}</b><span>MB</span></div>
    </div>
  </header>

  {warn}

  <div class="main">
    <nav class="rail">
      <div class="railhead">이벤트</div>
      {nav}
    </nav>
    <div>
{sections}
    </div>
  </div>
</div>

<div class="dock">
  <span class="now" id="now">재생 대기 중</span>
  <div class="right">
    <span class="count" id="count">채택 0</span>
    <button type="button" id="copy">선택 결과 복사</button>
    <button type="button" id="clear">초기화</button>
  </div>
</div>

<script>
const AUDIO = {audio};
const NAMES = {names};
const SEQS  = {seqs};
const KEY = 'sideview-audio-picks';

const el = new Audio();
let current = null, seq = null, seqPos = 0;

function readPicks() {{
  try {{ return new Set(JSON.parse(localStorage.getItem(KEY) || '[]')); }}
  catch (e) {{ return new Set(); }}
}}
function writePicks(set) {{
  try {{ localStorage.setItem(KEY, JSON.stringify([...set])); }} catch (e) {{}}
}}
let picks = readPicks();

function refreshCount() {{
  document.getElementById('count').textContent = '채택 ' + picks.size;
}}

function setActive(id) {{
  document.querySelectorAll('.row.active').forEach(r => r.classList.remove('active'));
  document.querySelectorAll('.bar i').forEach(b => b.style.width = '0');
  if (!id) return;
  const row = document.querySelector('.row[data-id="' + id + '"]');
  if (row) row.classList.add('active');
}}

function play(id) {{
  const b64 = AUDIO[id];
  if (!b64) return;
  current = id;
  setActive(id);
  document.getElementById('now').textContent = '▶ ' + NAMES[id];
  el.src = 'data:audio/ogg;base64,' + b64;
  el.currentTime = 0;
  el.play().catch(() => {{
    document.getElementById('now').textContent = '재생 실패 — 페이지를 한 번 클릭한 뒤 다시 시도하세요';
  }});
}}

el.addEventListener('timeupdate', () => {{
  if (!current || !el.duration) return;
  const bar = document.querySelector('.row[data-id="' + current + '"] .bar i');
  if (bar) bar.style.width = (el.currentTime / el.duration * 100) + '%';
}});

el.addEventListener('ended', () => {{
  const bar = document.querySelector('.row[data-id="' + current + '"] .bar i');
  if (bar) bar.style.width = '100%';
  if (seq && seqPos < seq.length) {{
    setTimeout(() => {{ if (seq) play(seq[seqPos++]); }}, 260);
  }} else {{
    seq = null;
    document.getElementById('now').textContent = '재생 대기 중';
  }}
}});

document.addEventListener('click', (e) => {{
  const p = e.target.closest('.play');
  if (p) {{ seq = null; play(p.dataset.id); return; }}

  const s = e.target.closest('.seq');
  if (s) {{
    seq = SEQS[s.dataset.group].slice();
    seqPos = 0;
    if (seq.length) play(seq[seqPos++]);
    return;
  }}

  const k = e.target.closest('.pick');
  if (k) {{
    const id = k.dataset.id;
    if (picks.has(id)) {{ picks.delete(id); k.setAttribute('aria-pressed', 'false'); }}
    else {{ picks.add(id); k.setAttribute('aria-pressed', 'true'); }}
    writePicks(picks);
    refreshCount();
  }}
}});

document.getElementById('copy').addEventListener('click', () => {{
  if (!picks.size) {{ document.getElementById('now').textContent = '채택한 항목이 없습니다'; return; }}
  const lines = [...picks].map(id => NAMES[id]).sort();
  const text = '채택 사운드 ' + lines.length + '개\\n\\n' + lines.join('\\n');
  navigator.clipboard.writeText(text).then(
    () => {{ document.getElementById('now').textContent = '복사 완료 — ' + lines.length + '개'; }},
    () => {{ document.getElementById('now').textContent = '복사 실패 — 수동으로 옮겨 주세요'; }}
  );
}});

document.getElementById('clear').addEventListener('click', () => {{
  picks = new Set();
  writePicks(picks);
  document.querySelectorAll('.pick').forEach(b => b.setAttribute('aria-pressed', 'false'));
  refreshCount();
}});

// 저장된 선택 복원
document.querySelectorAll('.pick').forEach(b => {{
  if (picks.has(b.dataset.id)) b.setAttribute('aria-pressed', 'true');
}});
refreshCount();
</script>
"""


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("audio_audition.html")
    groups, total, missing = build()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(groups, total, missing), encoding="utf-8")
    rows = sum(len(g["rows"]) for g in groups)
    print(f"{out}  |  {rows} sounds  |  raw {total/1024/1024:.2f} MB")
    if missing:
        print("missing:", *missing, sep="\n  ")


if __name__ == "__main__":
    main()
