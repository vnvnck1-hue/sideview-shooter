# 총격 사운드 리서치

> 조사일: 2026-09-20
> 범위: **발사음 전용**. 일반 사운드 소스 전반은 `Docs/SOUND_RESEARCH.md`, 현재 적용된 믹스는 `Docs/AUDIO_MIX.md`.
> 배경: `Docs/KENNEY_AUDIO_PICKS.md` 3장에서 "실사 총성"을 Kenney로 메울 수 없는 **1순위 갭**으로 지목했다. 이 문서가 그 갭을 메우기 위한 조사다.

---

## 0. 확정 결과 (2026-09-20)

> **이 문서 아래 내용은 조사 기록이다.** 실제로는 다른 팩을 받아 오디션을 거쳐 확정했다.
> 적용 결과는 `Docs/AUDIO_MIX.md`, 크레딧은 `Docs/CREDITS.md` 를 본다.

채택한 것: **GokhanBiyik "Gun Sounds 01"** (Freesound 팩 23279, **CC BY 4.0 — 크레딧 의무**)
https://freesound.org/people/GokhanBiyik/packs/23279/

36개를 전부 측정·오디션한 결과 5종이 확정됐다.

| 자리 | 파일 | 원본 |
|---|---|---|
| 발사 · 보디 1 | `fire_body_01.wav` | gunshort03 |
| 발사 · 보디 2 | `fire_body_02.wav` | gunshort12 |
| 발사 · 저역 | `fire_sub_01.wav` | mg04 |
| 사격 종료 잔향 | `fire_tail_01.wav` | gunsound04 |
| 센트리건 | `turret_fire_01.wav` | gunshort06 |

**이 팩의 성격**: 극단적으로 저역 편중이다(대부분 에너지의 70~98%가 150 Hz 아래).
"쿵"은 있는데 "탁"이 거의 없어서, 기존 Kenney 금속 타격음을 버리지 않고 **어택 보강 레이어로 남겼다**
(`fire_attack`, -15 dB). 즉 최종 구성은 실총 보디 + Kenney 어택 + 실총 저역의 3레이어다.

오디션 페이지는 `python Tools/build_gunshot_audition.py` 로 다시 만들 수 있고,
가공(자르기·레벨 맞추기)은 `python Tools/stage_gunshot_audio.py` 로 재현된다.

**아래 michorvath CC0 조사는 여전히 유효하다.** 재장전·빈 탄창 딸깍은 이 팩에 없어서 아직 비어 있고,
CC-BY 크레딧을 없애고 싶어지면 그쪽으로 갈아타면 된다.

---

## 1. 참고 — 원래 결론이었던 것

(조사 시점의 1순위 추천이었다. 실제 채택은 0장 참조 — 다만 아래 내용은 **재장전·빈 탄창을 채울 때 여전히 유효하다.**)

Freesound 사용자 `michorvath` 의 총기 9종 — 전부 CC0, 크레딧 불필요, 우리에게 필요한 레이어가 거의 다 들어 있다.

| 쓸 곳 | 파일 | 링크 |
|---|---|---|
| 발사 · 어택/보디 | 9mm pistol shot | https://freesound.org/people/michorvath/sounds/427592/ |
| 발사 · 날카로운 변주 | 22 magnum pistol shot | https://freesound.org/people/michorvath/sounds/427594/ |
| **테일(실내 잔향)** | AR15 rifle shot from 50 yards away | https://freesound.org/people/michorvath/sounds/427597/ |
| **센트리건(원거리)** | 〃 · AR15 rifle shot | https://freesound.org/people/michorvath/sounds/427596/ |
| **재장전 기계음** | 9mm pistol load and chamber | https://freesound.org/people/michorvath/sounds/427593/ |
| 재장전 변주 | AR15 pistol load and chamber | https://freesound.org/people/michorvath/sounds/427599/ |
| **탄창 비었을 때 딸깍** | Rifle clip empty | https://freesound.org/people/michorvath/sounds/427603/ |
| 대형 파괴음 소재 | 20 gauge shotgun gunshot | https://freesound.org/people/michorvath/sounds/427595/ |

업로더 전체 목록: https://freesound.org/people/michorvath/sounds/ (총 46개 중 위 9개가 총기)

굵게 표시한 4개가 **현재 완전히 무음이거나 가짜로 때우고 있는 자리**다. 재장전은 지금 천 스침(`cloth_01~03`)으로 대신하고 있고, 탄창 소진 딸깍과 총성 테일은 아예 없다.

---

## 2. 우리 총이 어떤 총인지부터 정한다

소스를 고르기 전에 스펙을 못 박아야 한다. `player.gd` 기준:

| 항목 | 값 | 코드 |
|---|---|---|
| 연사 간격 | 0.09초 = **약 11발/초 (660 RPM)** | `FIRE_COOLDOWN` |
| 장탄수 | 14발 | `MAG_SIZE` |
| 재장전 | 1.15초 | `RELOAD_TIME` |
| 이동 중 사격 | 걷기 속도 이하에서만 | `FIRE_MAX_SPEED` |

660 RPM에 14발 탄창이면 **기관단총 / 머신피스톨** 급이다. 라이플도 권총도 아니다. 그리고 주인공은 군인이 아니라 정비공이고, 무대는 좁고 낡은 지하 시설이다. 그래서 톤은 이렇게 잡는다:

- **건조하고 작게.** 영화식 대구경 "쾅"이 아니라, 좁은 복도에서 나는 압축된 "탁". 저역은 깔되 부풀리지 않는다.
- **실내 반사를 테일로 표현.** 지하 콘크리트 방이므로 총성 꼬리가 짧고 탁하게 되돌아와야 한다. 이게 없으면 공간이 죽는다.
- **기계 소리가 들려야 한다.** 낡은 장비라는 설정상 슬라이드·탄창·공이 소리가 총성보다 캐릭터를 더 잘 전달한다.
- **11발/초를 버텨야 한다.** 한 발이 아무리 좋아도 초당 11번 반복해서 안 거슬리는 게 우선이다.

---

## 3. 총성은 한 덩어리가 아니라 5레이어다

업계 표준 분해 방식. Mark Kilborn(Call of Duty 오디오 디렉터)의 작업 방식과 여러 AAA 무기 사운드 파이프라인이 동일한 구조를 쓴다.

| 레이어 | 역할 | 대역 | 길이 |
|---|---|---|---|
| **Transient(어택)** | 첫 "딱". 살상감·명료도를 결정 | 2~8 kHz | 5~20 ms |
| **Body(보디)** | 총의 성격. 실제 총성 녹음의 본체 | 200 Hz~2 kHz | 50~150 ms |
| **Sub / LFE** | 명치를 치는 무게 | 40~90 Hz | 80~200 ms |
| **Mechanical(기계)** | 슬라이드·노리쇠·탄피 배출 | 1~6 kHz | 30~100 ms |
| **Tail(테일)** | 공간·거리. 실내면 반사, 야외면 에코 | 넓음, 고역 감쇠 | 200 ms~2 s |

출처: [Pro Sound Effects — FPS 총성 사운드 디자인 (Mark Kilborn)](https://blog.prosoundeffects.com/how-to-sound-design-first-person-shooter-gunshot-sound-effects-with-mark-kilborn), [Splice — 게임 무기 사운드 디자인](https://splice.com/blog/design-weapon-sound-video-games/), [Arcella Sound — 모듈형 무기 오디오 설계](https://www.arcellasound.com/post/aaa-weapon-sound-design-architecting-modular-combat-audio-for-xdev-pipelines)

보통 **3~5레이어**면 설득력 있는 단발이 만들어진다. 또 한 가지 중요한 관행: 실제 현장에서도 **한 총의 녹음만 쓰지 않는다.** 마이크 위치가 다른 여러 녹음, 심지어 다른 총기의 녹음을 섞어서 고유한 소리를 만든다. 우리도 9mm 보디 + AR15 원거리 테일을 섞는 걸 주저할 이유가 없다.

### 조사 시점의 구현은 2레이어였다

```
fire_metal  (Kenney impactMetal, 피치 0.78~0.90)  -7 dB  ← Transient + Body 겸용
fire_low    (Kenney explosion, gap 0.16)         -14 dB  ← Sub
```

**금속 타격음으로 총성을 흉내 내는 임시 구성**이었다. Body 가 실제 총성이 아니라서 "총"으로 안 들리고, Mechanical 과 Tail 이 통째로 없어서 공간감과 질감이 없었다.

### 실제로 들어간 구성

Gun Sounds 01 을 채택하면서 이렇게 확정됐다. `fire_mech`(재장전 기계음)만 아직 비어 있다 —
이 팩에 슬라이드·탄창 소리가 없어서다.

| 키 | 소스 | 레벨 | 규칙 |
|---|---|---|---|
| `fire_body` | gunshort03 / gunshort12 — 앞 130 ms 만 | -7 dB | 매 발. 피치 0.94~1.06, 2 배리에이션 |
| `fire_attack` | 기존 Kenney `fire_metal_01/02` 유지 | -15 dB | 매 발. 이 팩에 없는 "탁"을 얇게 얹는다 |
| `fire_sub` | mg04 — 앞 220 ms | -13 dB | **gap 0.16** — 두 발에 한 번 |
| `fire_tail` | gunsound04 — 자르지 않음(0.61초) | -17 dB | **연사 중엔 재생 안 함.** 사격이 끊기고 0.12초 뒤 1회 |
| `fire_mech` | — | — | **미구현.** michorvath 427593 에서 슬라이드 구간만 잘라 쓰면 된다 |
| `turret_fire` | gunshort06 — 앞 150 ms | -11 dB | 센트리건 전용. 초당 18발이라 `gap 0.045` |

`fire_tail` 의 "마지막 발에만" 규칙이 핵심이다. 테일을 매 발 깔면 11발/초에서 잔향이 무한히 겹쳐 먹먹해진다. 사격이 끊긴 순간에만 한 번 울려야 "방이 울렸다"로 들린다.

---

## 4. 소스 후보 — 등급별

라이선스 등급 기준은 `Docs/SOUND_RESEARCH.md` 0장과 동일하다 (CC0 우선 / CC-BY 허용 / 나머지 예외 승인).

### A등급 — CC0, 바로 채택 가능

| 소스 | 내용 | 비고 | 링크 |
|---|---|---|---|
| **Freesound · michorvath** | 9mm·22mag·AR15·20게이지 + load/chamber + 빈 탄창. **44.1 kHz / 16bit / 모노** | 우리 목적에 가장 잘 맞는다. 0장 참조 | https://freesound.org/people/michorvath/sounds/ |
| Freesound · LeMudCrab "Pistol Shot" | 콜트 1911 .45 실사 녹음, CC0 | 보디 레이어 대안 | https://freesound.org/people/LeMudCrab/sounds/163456/ |
| **Sonniss GDC 번들** | 2026판 7.47 GB / 347 WAV, 17개 벤더. 무기 카테고리 포함 | 프로급 다중 마이크 녹음. 테일·원거리 레이어 확보에 최적. 2015년판부터 전부 다운로드 가능 | https://gdc.sonniss.com/ · 라이선스: https://sonniss.com/gdc-bundle-license/ |
| Freesound CC0 필터 검색 | 전체 73.4만 중 **약 38.1만이 CC0** | `gunshot`/`pistol`/`smg` 검색 후 좌측 License = Creative Commons 0 | https://freesound.org/search/?q=gunshot |
| 미 정부 기관 영상 추출 자동화기 | 공공 도메인 | Freesound에 다수 업로드. 자동사격 원음이 필요할 때 | https://freesound.org/browse/tags/cc0/ |

> Sonniss 번들 라이선스 주의: 로열티 프리·크레딧 불필요·프로젝트 수 무제한이지만 **사운드 파일 자체의 재배포와 SFX 라이브러리로의 재판매는 금지**다. 게임에 넣어 파는 건 전부 허용.

### B등급 — 파일별 라이선스 확인 필요

| 소스 | 내용 | 확인할 것 | 링크 |
|---|---|---|---|
| Freesound · newlocknew "Guns.Misc" | 합성·레이어링·리샘플링으로 만든 총성 모음 | 팩 페이지에 통합 라이선스 표기가 없다. **파일별로 CC0인지 확인 후 받을 것** | https://freesound.org/people/newlocknew/packs/27885/ |
| itch.io · zblogda "x3 free gun slide sounds" | 슬라이드 3종, CC0 명시, 크레딧 불필요 | 소량이지만 Mechanical 레이어에 바로 쓸 수 있다 | https://zblogda.itch.io/x3-free-gun-slide-sounds-effects |
| itch.io CC0 사운드 전체 | CC0 필터가 걸린 목록 | 팩마다 개별 확인 | https://itch.io/game-assets/assets-cc0/tag-sound-effects |
| itch.io 무료 총기 사운드 | 무료 필터 + gun 태그 | 무료 ≠ CC0. 페이지 하단 라이선스 문구 확인 필수 | https://itch.io/game-assets/free/tag-gun/tag-sound-effects |

### C등급 — 쓰지 말거나, 쓸 거면 근거를 남길 것

| 소스 | 문제 | 링크 |
|---|---|---|
| itch.io · Dan Sfx "Single Handgun" (29 WAV / 24bit 96k, 원음 + 디자인본 + 폴리) | **내용물은 우리 목적에 거의 완벽한데 라이선스가 없다.** 제작자가 "라이선스는 따로 안 붙였지만 자유롭게 쓰세요"라고만 적어 뒀다. 구두 허용은 상업 출시 근거로 약하다 — 쓰려면 제작자에게 문의해 명시적 허가를 받고 그 답변을 보관할 것 | https://cdansantana.itch.io/hgsfx |
| SoundBible | 파일마다 라이선스가 뒤섞여 있고(퍼블릭 도메인 / CC-BY / "개인 사용만") 표기가 불명확한 항목이 많다 | https://soundbible.com/tags-submachine-gun.html |
| Pixabay · Mixkit | 라이선스는 상업 허용이지만 업로드 출처 검증이 느슨하다. 총성처럼 상업 라이브러리에서 유출되기 쉬운 소재는 특히 위험 | https://pixabay.com/sound-effects/search/gun/ |
| ZapSplat | 무료 계정은 **"ZapSplat" 크레딧 필수**. 이것 하나 때문에 크레딧 파일을 만들 가치는 없다 | https://www.zapsplat.com/sound-effect-category/guns/ |

### 유료 — 참고용 (지금은 불필요)

| 소스 | 가격 | 내용 |
|---|---|---|
| Gamemaster Audio "Gun Sound Pack" | $19 | 266종(권총·리볼버·샷건·라이플·저격·반자동·**기관단총**·기관총) + 보너스 포함 416종. 로열티 프리 상업 허용, Godot 명시 지원 | https://gamemaster-audio.itch.io/gun-sound-pack |

**판단: 지금은 사지 말 것.** 위 A등급 조합으로 프로토타입에 충분하고, 실제로 무기가 여러 종류로 늘어나는 시점(기관단총 말고 샷건·라이플이 추가될 때)에 재검토하면 된다. 그때는 $19가 가장 빠른 해답이다.

---

## 5. 11발/초를 버티게 하는 규칙

총성은 게임 사운드 중 **가장 자주 반복되는 소리**다. 한 발의 품질보다 반복 내성이 중요하다. `audio_manager.gd` 에 이미 들어 있는 장치와, 총성 교체 시 추가로 지켜야 할 것.

**이미 있는 것** (자세한 내용은 `AUDIO_MIX.md` 2장)

1. 매 재생마다 피치·음량 무작위화 (`pitch`, `db_var`)
2. 키별 최소 간격(`gap`)과 동시 보이스 수(`voices`) 제한
3. 보이스 풀(20)이 차면 새 소리를 조용히 버린다
4. Weapon 버스 로우패스 6.5 kHz + Master 하드 리미터
5. 패닝 강도 0.35

**총성을 실사로 바꾸면서 추가로 지킬 것**

6. **배리에이션은 최소 3종.** 실사 총성은 Kenney 금속음보다 특징이 뚜렷해서 반복감이 훨씬 빨리 들린다. 피치 흔들기만으로는 못 가린다. `fire_body` 는 반드시 3개 이상의 파일을 둔다.
7. **꼬리를 잘라라.** 받은 원음에는 대부분 0.5~1.5초의 잔향이 붙어 있다(michorvath 9mm도 1.66초 중 실제 총성은 앞 0.1초). **보디 레이어는 150 ms 에서 페이드아웃으로 자르고**, 잘라낸 꼬리는 따로 `fire_tail` 로 쓴다. 안 자르면 11발/초에서 잔향이 겹쳐 진창이 된다.
8. **Sub 는 매 발 깔지 않는다.** 기존 `fire_low` 의 `gap = 0.16` 규칙을 그대로 유지한다. 저역은 누적이 가장 빠르다.
9. **Tail 은 사격 종료 후 1회만.** 4레이어 구성 참조.
10. **첫 발만 조금 크게.** 연사 시작 첫 발에 +1.5~2 dB, 이후는 기본값. 연사가 "시작"되는 느낌이 살고 전체 평균 음량은 안 올라간다.
11. **센트리건은 같은 샘플 + 감쇠가 아니라 다른 샘플을 쓴다.** 지금은 플레이어와 동일 샘플에 -3 dB만 걸려 있다. AR15 원거리(427597)를 쓰면 "저쪽에서 다른 총이 쏜다"가 한 번에 전달된다.

---

## 6. 작업 순서

1. **받기** — michorvath 9종 전부. Freesound 로그인 필요. 받은 즉시 라이선스 표기(CC0)가 보이는 페이지를 캡처해 `GodotPrototype/assets/audio/_licenses/` 에 보관.
2. **자르기** — 각 원음에서 ① 보디(첫 150 ms) ② 테일(그 이후) ③ 기계음(load/chamber에서 슬라이드 구간만) 을 분리해 별도 파일로 저장. Audacity면 충분하다.
3. **변환** — `.ogg`, 44.1 kHz. 기존 `assets/audio/sfx/weapon/` 규칙을 따른다 (`fire_body_01~03.ogg`, `fire_tail_01.ogg`, `fire_mech_01.ogg`, `reload_01.ogg`, `dry_fire_01.ogg`).
4. **등록** — `audio_manager.gd` 의 `SOUNDS` 에 3장 목표 구성표대로 추가하고, `fire()` 를 4레이어로 확장. 호출부(`player.gd:_fire()`)는 손댈 필요 없다.
5. **새 이벤트 연결** — 재장전은 `player.gd:start_reload()` 에서 `cloth` 대신 `reload` 를, 탄창 소진은 `_fire()` 의 `ammo == 0` 분기에서 `dry_fire` 를 울린다.
6. **검증** — 트리거를 5초간 누른 채로 들어본다. 먹먹해지거나 찢어지면 `fire_sub` 의 `gap` 을 올리고, 그래도 안 되면 `fire_body` 의 어택을 더 잘라낸다.

> 총성 교체는 코드 리뷰와 산출물 측정까지 마쳤다. **귀로 듣는 확인만 남았다** — 확인할 항목은 `AUDIO_MIX.md` 6장.

---

## 7. 링크 모음

**CC0 총성 원음**
- michorvath 업로드 전체 (총기 9종): https://freesound.org/people/michorvath/sounds/
  - 9mm pistol shot: https://freesound.org/people/michorvath/sounds/427592/
  - 9mm pistol load and chamber: https://freesound.org/people/michorvath/sounds/427593/
  - 22 magnum pistol shot: https://freesound.org/people/michorvath/sounds/427594/
  - 20 gauge shotgun: https://freesound.org/people/michorvath/sounds/427595/
  - AR15 rifle shot: https://freesound.org/people/michorvath/sounds/427596/
  - AR15 rifle shot from 50 yards: https://freesound.org/people/michorvath/sounds/427597/
  - AR15 pistol shot: https://freesound.org/people/michorvath/sounds/427598/
  - AR15 pistol load and chamber: https://freesound.org/people/michorvath/sounds/427599/
  - Rifle clip empty: https://freesound.org/people/michorvath/sounds/427603/
- LeMudCrab — Pistol Shot (Colt 1911 .45): https://freesound.org/people/LeMudCrab/sounds/163456/
- Freesound gunshot 검색(License 필터 CC0): https://freesound.org/search/?q=gunshot
- Freesound CC0 태그 브라우즈: https://freesound.org/browse/tags/cc0/
- newlocknew — Guns.Misc 팩 (파일별 확인): https://freesound.org/people/newlocknew/packs/27885/

**로열티 프리 대용량**
- Sonniss GDC 2026 번들: https://gdc.sonniss.com/
- Sonniss 번들 라이선스 원문: https://sonniss.com/gdc-bundle-license/
- Sonniss 총기 라이브러리 카테고리(유료): https://sonniss.com/category/sound-libraries/guns/

**기계음 / 폴리**
- zblogda — x3 free gun slide sounds (CC0): https://zblogda.itch.io/x3-free-gun-slide-sounds-effects
- Dan Sfx — Single Handgun (라이선스 미표기, 문의 필요): https://cdansantana.itch.io/hgsfx

**유료 참고**
- Gamemaster Audio — Gun Sound Pack ($19, 416종): https://gamemaster-audio.itch.io/gun-sound-pack

**디자인 이론**
- Pro Sound Effects — FPS 총성 디자인 (Mark Kilborn): https://blog.prosoundeffects.com/how-to-sound-design-first-person-shooter-gunshot-sound-effects-with-mark-kilborn
- Splice — 게임 무기 사운드 디자인: https://splice.com/blog/design-weapon-sound-video-games/
- Arcella Sound — 모듈형 무기 오디오 설계: https://www.arcellasound.com/post/aaa-weapon-sound-design-architecting-modular-combat-audio-for-xdev-pipelines
- Pixflow — 총기 사운드 가이드: https://pixflow.net/blog/gun-gunfire-sound-effects/

**주의 소스 (근거 남기고 쓸 것)**
- SoundBible: https://soundbible.com/tags-submachine-gun.html
- Pixabay 총기: https://pixabay.com/sound-effects/search/gun/
- Mixkit 총기: https://mixkit.co/free-sound-effects/gun/
- ZapSplat 총기(크레딧 필수): https://www.zapsplat.com/sound-effect-category/guns/

**라이선스 원문**
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
