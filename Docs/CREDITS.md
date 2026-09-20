# 크레딧 · 서드파티 에셋

> 최초 작성: 2026-09-20
> **이 파일은 법적 의무다.** CC-BY 계열 에셋을 하나라도 쓰는 한 유지해야 한다.
> 에셋을 추가·교체할 때마다 같이 갱신할 것. 라이선스 원문 사본은 `GodotPrototype/assets/audio/_licenses/` 에 있다.

---

## 표기가 의무인 것 (CC BY 4.0)

게임 내 크레딧 화면과 배포 페이지 양쪽에 아래 문구가 들어가야 한다.

```
Gun Sounds 01 by GokhanBiyik (freesound.org) — licensed under CC BY 4.0
https://freesound.org/people/GokhanBiyik/packs/23279/
https://creativecommons.org/licenses/by/4.0/
```

실제로 쓰고 있는 파일:

| 게임 내 파일 | 원본 | Freesound |
|---|---|---|
| `sfx/weapon/fire_body_01.wav` | `413094__gokhanbiyik__gunshort03.wav` | https://freesound.org/s/413094/ |
| `sfx/weapon/fire_body_02.wav` | `413115__gokhanbiyik__gunshort12.wav` | https://freesound.org/s/413115/ |
| `sfx/weapon/fire_sub_01.wav` | `413127__gokhanbiyik__mg04.wav` | https://freesound.org/s/413127/ |
| `sfx/weapon/fire_tail_01.wav` | `413119__gokhanbiyik__gunsound04.wav` | https://freesound.org/s/413119/ |
| `sfx/weapon/turret_fire_01.wav` | `413099__gokhanbiyik__gunshort06.wav` | https://freesound.org/s/413099/ |

전부 잘라내고 레벨을 맞춘 **개작본**이다. CC BY 4.0 은 개작을 허용하지만
**개작했다는 사실을 밝혀야 한다** — 위 문구 아래에 한 줄 덧붙인다.

```
Sounds were trimmed and level-matched for this game.
```

가공 규칙은 `Tools/stage_gunshot_audio.py` 에 전부 적혀 있다.

---

## 표기가 필요 없는 것 (CC0 / 퍼블릭 도메인)

의무는 아니지만 관례상 적어 둔다. 지우더라도 법적 문제는 없다.

| 출처 | 범위 | 라이선스 |
|---|---|---|
| **Kenney** (kenney.nl) | 효과음 대부분 — 발소리, 탄착, 천 스침, 탄피, UI, 어택 레이어(`fire_metal_*`) | CC0 1.0 |
| OpenGameArt — 30 CC0 SFX loops | 앰비언스 일부 | CC0 1.0 |
| OpenGameArt — [80 CC0 creature SFX](https://opengameart.org/content/80-cc0-creature-sfx) (rubberduck) | 크롤러 보컬 9종 (`sfx/creature/*`) | CC0 1.0 |
| Eric Berzins — Ultra Sci-Fi Ambience | 앰비언스 | `_licenses/` 참고 |

## 받아 온 것이 아닌 것 (직접 합성)

| 파일 | 만든 것 |
|---|---|
| `sfx/voice/{slow,soft,clipped,quick,machine}_0N.wav` (15개) | NPC 대사 블립. `Tools/build_npc_voice_blips.py` 가 코드로 합성한다 (톱니파 → 포먼트 공명 → 엔벨로프). 외부 자산이 아니라 **출처 표기 의무가 없다** |

---

## 에셋을 추가할 때 지킬 것

1. **라이선스를 먼저 본다.** 사이트 전체가 한 라이선스인 경우는 드물다 — Freesound · OpenGameArt 는
   파일 단위로 CC0 / CC-BY / CC-BY-NC 가 섞여 있다.
2. **CC-BY-NC · CC-BY-SA 는 쓰지 않는다.** 상업 불가이거나 전염성이 있다.
3. 받은 즉시 라이선스 페이지를 `GodotPrototype/assets/audio/_licenses/` 에 사본으로 남긴다.
4. CC-BY 면 위 표에 줄을 추가한다. **나중에 몰아서 하면 반드시 빠진다.**

판단 기준 전체는 `Docs/SOUND_RESEARCH.md` 0장에 있다.
