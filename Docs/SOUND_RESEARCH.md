# 사운드 리서치 (무료 라이선스)

> 조사일: 2026-09-20. 대상: 사이드뷰 슈팅 프로토타입(어둡고 폐쇄적인 지하 작업실).
> 모든 항목은 **무료 + 상업적 사용 가능**. 출처 링크를 그대로 실어 두었으니 직접 확인 후 채택할 것.

---

## 0. 라이선스 등급 먼저 정하기

프로젝트 기준을 **CC0 우선, CC-BY 허용(크레딧 문서 관리), 나머지는 예외 승인**으로 잡는 것을 권한다.

| 등급 | 라이선스 | 크레딧 | 판단 |
|---|---|---|---|
| A | CC0 / Public Domain | 불필요 | 기본 채택 |
| A | Sonniss GDC 번들 (로열티 프리) | 불필요 | 기본 채택 (재배포·SFX 라이브러리 재판매만 금지) |
| B | CC-BY 4.0 / 3.0 | **필수** | 크레딧 파일 관리 가능하면 채택 |
| B | Pixabay License | 불필요 | 채택 가능하나 출처 검증 권장(아래 주의) |
| C | ZapSplat 무료 계정 | **필수**("ZapSplat" 표기) | 크레딧 감수 시만 |
| X | CC-BY-NC / CC-BY-SA | — | 상업 불가 / 전염성. **사용 금지** |

주의 두 가지:

- **Pixabay**: 라이선스 자체는 크레딧 불필요·상업 허용이지만, 업로드 출처 검증이 느슨하다는 지적이 있다. 상업 출시 빌드에 쓸 때는 다운로드 시점의 페이지를 스크린샷으로 남겨 둘 것. ([Pixabay License 설명](https://pixabay.com/blog/posts/pixabay-license-what-is-allowed-and-what-is-not-4/), [검증 리스크 지적](https://www.michaelmusco.com/2026/02/pixabay-music-review.html))
- **Freesound / OpenGameArt**: 사이트 전체가 한 라이선스가 아니다. 파일 단위로 CC0 / CC-BY / CC-BY-NC가 섞여 있으므로 **반드시 파일별 라이선스 필터**를 걸고 받을 것.

---

## 1. 1순위 소스 (CC0, 크레딧 불필요)

### Kenney — 게임용 SFX 팩 (전부 CC0)
가장 안전하고 톤이 정돈되어 있다. 프로토타입 단계 사운드는 여기서 대부분 해결된다.

| 팩 | 개수 | 용도 | 링크 |
|---|---:|---|---|
| Sci-fi Sounds | 70 | 총성, 레이저, 기계음, 문 | https://kenney.nl/assets/sci-fi-sounds |
| Impact Sounds | 130 | 탄착, 프랍 타격, 파편 | https://kenney.nl/assets/impact-sounds |
| Interface Sounds | — | UI, 메뉴, 확인/취소 | https://kenney.nl/assets/interface-sounds |
| Digital Audio | — | 글리치, 전자 노이즈(조명 고장에 적합) | https://kenney.nl/assets/digital-audio |
| 전체 에셋 목록 | 40,000+ | — | https://kenney.nl/assets |

- 라이선스: **CC0 1.0** — 개인·교육·상업 전부 허용, 크레딧 불필요.
- Godot용으로 미리 정리된 미러도 있음: https://github.com/Calinou/kenney-ui-audio
- OpenGameArt 미러 컬렉션: https://opengameart.org/content/all-cc0-uploader-kenney

### OpenGameArt — CC0 팩 (개별 확인 필수)

| 팩 | 라이선스 | 용도 | 링크 |
|---|---|---|---|
| 50 CC0 Sci-Fi SFX (rubberduck) | CC0 | 슛 2종, 폭발, 터미널 9종, 루프 5종 | https://opengameart.org/content/50-cc0-sci-fi-sfx |
| Sci-Fi Sound Effects Library | 확인 필요 | 기계·환경음 | https://opengameart.org/content/sci-fi-sound-effects-library |
| CC0 Sound Effects | CC0 | 범용 | https://opengameart.org/content/cc0-sound-effects |
| CC0 Sounds Library | CC0 | 범용 대량 | https://opengameart.org/content/cc0-sounds-library |
| 100 CC0 SFX #2 | CC0 | 범용 | https://opengameart.org/content/100-cc0-sfx-2 |
| 512 Sound Effects (8-bit style) | CC0 | 레트로 톤 — 현재 아트와는 불일치, 참고용 | https://opengameart.org/content/512-sound-effects-8-bit-style |

> 검색 시 라이선스 필터: https://opengameart.org/art-search-advanced 에서 CC0만 체크.

### Freesound — CC0 필터 검색 (약 38만 개)
생짜 소재(총성 원음, 룸톤, 금속 충돌)를 직접 고르고 가공할 때 쓴다.

- CC0 태그 브라우즈: https://freesound.org/browse/tags/cc0/
- 검색 후 좌측 License 필터에서 **Creative Commons 0** 체크
- 산업·실내 룸톤 팩 (지하 작업실 앰비언스에 직결): https://freesound.org/people/mzui/packs/12983/
- CC0 전용 업로더 팩 예시: https://freesound.org/people/RokZRooM/packs/12161/
- 라이선스 FAQ: https://freesound.org/help/faq/

### Sonniss — GDC 로열티 프리 번들 (연간 무료 배포)
프로급 원음이 필요할 때. 2026판 기준 7.47GB / 347 WAV, 2015년판부터 전부 다운로드 가능.

- https://sonniss.com/gameaudiogdc/
- 라이선스: 로열티 프리, 크레딧 불필요, 프로젝트 수 무제한 상업 사용 가능. **단 사운드 파일 자체의 재배포·SFX 라이브러리로의 재판매 금지.**

### gamesounds.xyz — 위 소스들의 정리된 미러
- https://gamesounds.xyz/
- Kenney 팩 디렉터리: https://gamesounds.xyz/?dir=Kenney%27s+Sound+Pack

---

## 2. 음악 (BGM)

| 소스 | 라이선스 | 특징 | 링크 |
|---|---|---|---|
| **Abstraction — Three Red Hearts** | 저작권 포기(CC0 상당) | 24개 심리스 루프. 크레딧 불필요(권장: "Abstraction"). **NFT/AI 학습/무수정 재판매는 작가가 비권장** | https://tallbeard.itch.io/three-red-hearts-prepare-to-dev |
| Juhani Junkala — 5 Chiptunes (Action) | CC0 | 루프 대응 액션 트랙 | https://opengameart.org/content/5-chiptunes-action |
| OpenGameArt 음악 전체 | 혼재 | CC0 필터 필수 | https://opengameart.org/art-search-advanced |
| Incompetech (Kevin MacLeod) | CC-BY 4.0 | 대량, 분위기별 분류 우수. **크레딧 필수** | https://incompetech.com/music/royalty-free/ |
| Eric Skiff — Resistor Anthems | CC-BY 3.0 | 칩튠. 크레딧 필수 | https://ericskiff.com/music/ |

> 현재 아트 방향(어둡고 폐쇄적인 지하)에는 칩튠보다 **저음 드론 + 산업 노이즈 레이어**가 맞다.
> Freesound CC0에서 `drone`, `room tone`, `industrial hum`, `air conditioner` 태그로 루프 소재를 받아 직접 레이어링하는 쪽을 권한다.

---

## 3. 이 프로토타입에 필요한 사운드 목록 → 매칭

현재 스크립트(`GodotPrototype/scripts/`)에서 실제로 발생하는 이벤트 기준.

| # | 이벤트 | 코드 위치 | 필요한 소리 | 추천 소스 |
|---|---|---|---|---|
| 1 | 발사 | `player.gd:257 _fire()` | 건조한 단발 총성 + 기계 슬라이드 | Kenney Sci-fi Sounds / Sonniss 원음 |
| 2 | 탄환 비행 | `bullet.gd` | 짧은 whiz, 프로토 단계에선 생략 가능 | Freesound CC0 `bullet whiz` |
| 3 | 탄착 | `bullet.gd:144 _impact()` | 재질별 3종(금속/콘크리트/나무) | Kenney Impact Sounds |
| 4 | 탄피 낙하 | `shell_casing.gd` | 금속 탄피 바닥 튐 2~3 배리에이션 | Freesound CC0 `shell casing` |
| 5 | 유리 파손 | `glass_window.gd:29 crack()` | 금 가는 소리 / 깨짐 2단계 | Kenney Impact + Freesound `glass crack` |
| 6 | 프랍 타격 | `hit_prop.gd:52 hit()` | 둔탁한 나무·금속 충격 | Kenney Impact Sounds |
| 7 | 조명 파괴 | `lamp_light.gd:105 break_lamp()` | 전구 파열 + 전기 글리치 + 잔여 버즈 | Kenney Digital Audio + Freesound `light bulb break` |
| 8 | 조명 점멸 | `lamp_light.gd:133 _process()` | 형광등 버즈 루프 | Freesound CC0 `fluorescent hum` |
| 9 | 걷기 | `player.gd:169 _process()` | 콘크리트 발소리 4~6 배리에이션 | Freesound CC0 `concrete footsteps` |
| 10 | 앉기/일어서기 | `player.gd` crouch | 옷 스침 + 가벼운 착지 | Freesound CC0 `cloth movement` |
| 11 | 구르기 | `player.gd:297 _start_roll()` | 몸 구름 + 착지 | Freesound CC0 `body roll thud` |
| 12 | 숨소리 | `player.gd:244 _update_breath()` | 마스크 호흡 루프(저음량) | Freesound CC0 `gas mask breathing` |
| 13 | 문 개폐 / 방 이동 | `room.gd:131 _add_side_door()` | 금속 해치 개폐 + 잠금 해제 | Kenney Sci-fi Sounds |
| 14 | 방 앰비언스 | `room.gd`, `dust_layer.gd` | 지하 룸톤 루프 + 파이프 드립 | Freesound mzui 룸톤 팩 |
| 15 | UI | 미구현 | 확인/취소/호버 | Kenney Interface Sounds |

**최소 구성 우선순위**: 1 → 3 → 9 → 13 → 14. 이 5종만 넣어도 프로토타입 체감이 크게 달라진다.

---

## 4. 실무 진행 제안

1. **1차 수급**: Kenney Sci-fi / Impact / Interface / Digital Audio 4개 팩 전부 다운로드 (전부 CC0, 즉시 사용 가능).
2. **2차 보강**: 발소리·룸톤·탄피만 Freesound CC0에서 개별 선별.
3. **배치 규칙**: `Assets/GameReady/Audio/{SFX,Ambience,Music}/` 로 분리하고, 이벤트명 그대로 파일명 사용 (`fire_01.wav`, `impact_metal_01.wav` …).
4. **포맷**: SFX는 `.wav`(16bit 44.1kHz), 루프·BGM은 `.ogg`. Godot은 `.ogg` 루프 설정을 import 탭에서 지정.
5. **크레딧 관리**: CC-BY를 하나라도 쓰는 순간 `Docs/CREDITS.md` 생성해 누적 관리.
6. **증빙 보관**: 각 팩의 라이선스 페이지를 다운로드 시점 기준으로 캡처해 `Assets/GameReady/Audio/_licenses/`에 보관.

---

## 5. 링크 모음 (검증용)

**CC0 SFX**
- Kenney 전체: https://kenney.nl/assets
- Kenney Sci-fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds
- Kenney Interface Sounds: https://kenney.nl/assets/interface-sounds
- Kenney Digital Audio: https://kenney.nl/assets/digital-audio
- OpenGameArt Kenney 미러: https://opengameart.org/content/all-cc0-uploader-kenney
- 50 CC0 Sci-Fi SFX: https://opengameart.org/content/50-cc0-sci-fi-sfx
- CC0 Sound Effects: https://opengameart.org/content/cc0-sound-effects
- CC0 Sounds Library: https://opengameart.org/content/cc0-sounds-library
- 100 CC0 SFX #2: https://opengameart.org/content/100-cc0-sfx-2
- Sci-Fi Sound Effects Library: https://opengameart.org/content/sci-fi-sound-effects-library
- 512 Sound Effects (8-bit): https://opengameart.org/content/512-sound-effects-8-bit-style
- Freesound CC0 태그: https://freesound.org/browse/tags/cc0/
- Freesound 산업 룸톤 팩: https://freesound.org/people/mzui/packs/12983/
- Freesound CC0 팩(RokZRooM): https://freesound.org/people/RokZRooM/packs/12161/
- gamesounds.xyz: https://gamesounds.xyz/

**로열티 프리 대용량**
- Sonniss GDC 번들: https://sonniss.com/gameaudiogdc/

**음악**
- Abstraction Three Red Hearts: https://tallbeard.itch.io/three-red-hearts-prepare-to-dev
- Juhani Junkala 5 Chiptunes: https://opengameart.org/content/5-chiptunes-action
- Incompetech (CC-BY): https://incompetech.com/music/royalty-free/
- Eric Skiff (CC-BY): https://ericskiff.com/music/

**라이선스 원문**
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
- Pixabay License: https://pixabay.com/service/terms/
- ZapSplat 무료 라이선스(크레딧 필수): https://www.zapsplat.com/license-type/standard-license/
- ZapSplat CC0 분류: https://www.zapsplat.com/license-type/cc0-1-0-universal/
