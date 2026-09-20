# 앰비언트(환경음) 리서치 — 무료 라이선스

> 조사일: 2026-09-20 · 대상 `GodotPrototype/` (지하·폐쇄 스테이션, 21개 방 / 4개 구역)
> 전 항목 **무료 + 상업적 사용 가능**. 링크는 그대로 실어 두었으니 다운로드 시점에 직접 재확인할 것.
> SFX(총성·탄착·발소리 등) 전반은 [`SOUND_RESEARCH.md`](SOUND_RESEARCH.md) / [`KENNEY_AUDIO_PICKS.md`](KENNEY_AUDIO_PICKS.md).
> 이 문서는 그 두 문서가 "나중에 붙이는 레이어"로 미뤄 둔 **14번 방 앰비언스 / 갭 ③ 룸톤**만 파고든 것이다.

---

## 0. 결론 먼저

1. **베이스 룸톤은 CC0 실사 녹음으로 깐다** — Signature Sounds `Room Tones`, Freesound `lwdickens`/`mzui` 팩.
2. **구역 색깔은 SF 드론 루프로 얹는다** — Eric Berzins 무료 팩(15루프) + OpenGameArt CC0 앰비언스 팩.
3. **점 소리(물방울·릴레이 틱·환풍 덜컹)는 이미 받아 둔 Kenney에서 뽑아 랜덤 산발 재생**한다.
4. Tabletop Audio는 **CC BY-NC-ND라 상업 불가 — 쓰지 말 것.**

---

## 1. 라이선스 등급 (앰비언스 소스 기준)

| 등급 | 소스 | 라이선스 | 크레딧 | 판단 |
|---|---|---|---|---|
| A | Signature Sounds | CC0 | 불필요 | 기본 채택 |
| A | Freesound (CC0 필터) | CC0 | 불필요 | 기본 채택, **파일별 확인 필수** |
| A | OpenGameArt (CC0 항목) | CC0 | 불필요 | 기본 채택, **항목별 확인 필수** |
| A | Kenney | CC0 | 불필요 | 이미 보유 |
| A | Sonniss GDC 번들 | 로열티 프리 | 불필요 | 채택 (사운드 파일 재배포·재판매만 금지) |
| B | Eric Berzins (itch) | 자체 무료 라이선스 | 불필요(권장) | 채택 — **재판매·저작자 사칭·AI 학습 금지** |
| B | Pixabay | Pixabay License | 불필요 | 채택 가능, 업로드 출처 검증이 느슨 → 다운로드 페이지 캡처 보관 |
| C | Soundimage.org (Eric Matyas) | 무료 + **크레딧 필수** | 필수 | 크레딧 감수 시. SFX 1개당 $5로 크레딧 면제 구매 가능 |
| X | **Tabletop Audio** | CC BY-NC-ND 4.0 | — | **상업 불가 · 개작 불가. 사용 금지** |
| X | Envato Elements / 유료 itch 팩 | 구독·유료 | — | 이번 범위 밖 |

---

## 2. 1순위 — CC0 실사 룸톤 (베이스 레이어)

지하 스테이션의 "공기"는 SF 드론이 아니라 **실제 실내 녹음**에서 나온다. 드론만 깔면 우주선이 되고,
룸톤을 깔아야 *낡은 지하 시설*이 된다. 현재 아트 방향과 맞는 쪽은 후자다.

| 소스 | 내용 | 라이선스 | 링크 |
|---|---|---|---|
| **Signature Sounds** | 실내 룸톤·앰비언스, 고해상도 WAV. 사이트 전체 CC0 | CC0, 크레딧 불필요 | https://signaturesounds.org/ ※ 검색에 뜨던 `/store/p/room-tones` 직링크는 404 — 사이트 목록에서 `Loops Of Ambience` 등으로 접근할 것 |
| Freesound — `lwdickens` room tone 팩 | **카펫 깔린 작은 지하실** 룸톤 등 | 팩 내 파일별 확인 | https://freesound.org/people/lwdickens/packs/16211/ |
| Freesound — `mzui` 산업·실내 룸톤 팩 | 공장·실내 룸톤 (기존 문서에서도 지목) | 파일별 확인 | https://freesound.org/people/mzui/packs/12983/ |
| Freesound — `RokZRooM` CC0 팩 | CC0 전용 업로더 | CC0 | https://freesound.org/people/RokZRooM/packs/12161/ |
| Freesound — Industrial Factory/Fans Loop | 공장 팬 루프 — 기계 험 베이스 | 파일별 확인 | https://freesound.org/people/IanStarGem/sounds/271096/ |
| Freesound — Sci-fi Ambient Drone | 단품 SF 드론 | CC0 | https://freesound.org/people/LookIMadeAThing/sounds/534018/ |
| Sonniss — GDC 번들 Room Tone / Ambience | 프로급 원음 대량 | 로열티 프리 | https://sonniss.com/gameaudiogdc/ · 카테고리 https://sonniss.com/category/sound-libraries/ambience/room-tone-ambience/ |

> Freesound는 검색 후 좌측 License 필터에서 **Creative Commons 0** 를 켠 뒤 받는다.
> 태그 브라우즈: https://freesound.org/browse/tags/cc0/
> 검색어: `room tone`, `industrial hum`, `air conditioner`, `ventilation`, `server room`, `fluorescent hum`, `water drip`, `pipe`

---

## 3. 2순위 — SF 드론·시설 앰비언스 루프 (색깔 레이어)

| 팩 | 개수 | 가격/라이선스 | 비고 | 링크 |
|---|---:|---|---|---|
| **Ultra Sci-Fi Game Audio Ambience Pack** (Eric Berzins) | 15 | **무료**, 로열티 프리, 크레딧 불필요 / 재판매·AI 학습 금지 | 함선 복도·이계 톤. 이 프로젝트 1순위 드론 팩 | https://eberzins.itch.io/ultra-sci-fi-game-audio-ambience-pack |
| Ambience Pack 1 — Sci Fi Horror (OGA) | 5 | 항목별 라이선스 확인 | 약 1분 풀 루프, 어두운 톤 | https://opengameart.org/content/ambience-pack-1-sci-fi-horror |
| 30 CC0 SFX loops (OGA) | 30 | CC0 | 알람 3 · 앰비언트 3 · **머신 11** — 릴레이실에 직결 | https://opengameart.org/content/30-cc0-sfx-loops |
| CC0 Background Ambience (OGA) | — | CC0 | 범용 배경 | https://opengameart.org/content/cc0-background-ambience |
| Factory ambiance (OGA) | — | CC0 | 산업 단지 배경 | https://opengameart.org/content/factory-ambiance |
| Scifi City — Ambient Loop (OGA) | 1 | 항목 확인 | 넓은 공간용 | https://opengameart.org/content/scifi-city-ambient-loop |
| Dark Sci-Fi Audio Pack (OGA) | 곡 5 + UI 3 | CC0 | 음악 쪽이지만 저음 드론으로 전용 가능 | https://opengameart.org/content/dark-sci-fi-audio-pack |
| Sci-Fi Sound Effects Library (OGA) | 33 | 항목 확인 | 앰비언스 4 · 알람 루프 2 포함 | https://opengameart.org/content/sci-fi-sound-effects-library |
| Soundimage — AMB Sci-Fi Ambience | — | 무료 + **크레딧 필수** | 양은 많음. 크레딧 관리 가능할 때만 | https://soundimage.org/amb-sci-fi-ambience/ |
| Soundimage — SFX SciFi Amb | — | 무료 + 크레딧 필수 | 위와 동일 · 크레딧 규정 https://soundimage.org/attribution-info/ | https://soundimage.org/sfx-scifi-amb/ |

> OGA 라이선스 필터: https://opengameart.org/art-search-advanced 에서 CC0만 체크.

---

## 4. 구역별 매칭 (`room_data.gd` 4개 구역 / 21개 방)

앰비언스는 방마다 새로 만들지 않는다. **구역 베드 4종 + 방 성격 오버레이**로 조합한다.

### 4-1. 구역 베드 (루프, 상시 재생, -28 ~ -22 dB)

| 구역 | 방 | 베드 성격 | 소스 |
|---|---|---|---|
| **정비 (workshop)** | 에어록 · 서쪽 정비 통로 · 작업실 · 대형 정비 홀 · 짧은 연결 통로 · 격납고 · 창고 | 넓은 금속 공간 룸톤 + 먼 환풍 저음 | Signature Sounds 지하실/홀 룸톤 + `IanStarGem` 팬 루프의 저역만 |
| **전력 (power_relay)** | 케이블 덕트 · 전력 릴레이실 · 축전기 저장고 · 비상 발전실 | 전기 험 + 변압기 웅웅 + 간헐 릴레이 틱 | OGA `30 CC0 SFX loops` 머신 11종 + Freesound `transformer hum` (CC0) |
| **승무원 (crewquarters)** | 숙소 복도 · 침실 A/B · 식당 · 세면실 | 가장 조용함. 좁은 실내 룸톤 + 형광등 버즈 + 배관 | Signature Sounds 침실/복도 룸톤 + `fluorescent hum` |
| **수경재배 (hydroponics)** | 재배실 전실 · 대형 재배실 · 급수 통로 · 저수조실 · 육묘실 | 물 순환 + 펌프 + 습한 공기. 유일하게 "살아 있는" 구역 | Freesound `water pump loop` · `aquarium filter` · `greenhouse` (CC0) + Kenney `Foley/Water/drip` |
| **복도 (corridor)** | 서쪽 통로 · 짧은 연결 · 숙소 복도 · 급수 통로 | 인접 구역 베드를 **로우패스 + -6dB**로 눌러 재사용 | 가공만 (신규 수급 불필요) |

### 4-2. 방 성격 오버레이 (베드 위에 1~2개)

| 오버레이 | 붙는 방 | 소리 | 소스 |
|---|---|---|---|
| 넓은 공간 잔향 | 대형 정비 홀 · 격납고 · 대형 재배실 | 먼 금속 삐걱임 + 공간 잔향 | Kenney `RPG/creak1~3` 산발 + Reverb 버스 |
| 고전압 위협감 | 전력 릴레이실 · 축전기 저장고 | 축전기 차지 휘잉 + 스파크 틱 | Kenney `Digital/zap1~2` · `Sci-Fi/forceField_*` 가공 |
| 물방울 | 창고 · 케이블 덕트 · 저수조실 | 3~8초 랜덤 간격 물방울 | Kenney `Foley/Water/drip1~4` (보유) |
| 단말기 근접 | 터미널 배치된 방 | 낮은 CRT 험 + 데이터 처리음 | Kenney `Sci-Fi/computerNoise_000~003` (보유) |
| 외벽 접점 | 에어록 | 먼 압력 쉬익 + 금속 수축음 | Sonniss 번들 / Freesound `airlock`, `metal stress` |
| 정적 | 위험도 높은 방 | **베드만 남기고 전부 끔** — 빼는 게 가장 센 연출이다 | — |

---

## 5. 레이어링 규칙 (이게 제일 중요함)

앰비언스 품질은 좋은 파일을 찾는 것보다 **어떻게 겹치느냐**로 결정된다. 3레이어 고정:

```
L1 BED      상시 루프, -28~-22dB, 로우패스로 배경에 밀어냄.  구역당 1개
L2 TEXTURE  상시 루프, -24~-18dB, 방 성격(팬·펌프·전기 험).  방당 0~2개
L3 SPOT     원샷, -18~-12dB, 3~12초 랜덤 간격(물방울·틱·삐걱). 방당 0~3종
```

- **L1과 L2는 서로 다른 주파수대를 차지해야 한다.** 둘 다 저역이면 진흙이 된다.
  BED는 20~200Hz, TEXTURE는 200Hz~2kHz 중심으로 EQ를 갈라 놓을 것.
- **루프 길이는 서로 소수(prime)로** 잡는다 (예: 17초 / 23초 / 31초). 같은 길이면 반복 주기가 드러난다.
- L3에는 **피치 ±5% 랜덤** 필수. `AudioStreamRandomizer` 사용.
- 방 이동 시 **1.5~2.5초 크로스페이드**. 즉시 전환하면 문이 아니라 편집점처럼 들린다.
- 전투 중 앰비언스 버스를 **-6dB 덕킹**, 종료 후 3초에 걸쳐 복귀. 정적이 돌아오는 그 순간이 연출이다.

### Godot 구현 메모

- 버스: `Master ← Ambience(L1/L2/L3) ← SFX ← Music`. Ambience 버스에 로우패스 + 리버브 하나씩.
- 루프는 `.ogg`, Import 탭에서 **Loop 켜기 / Loop Offset 0**. 원샷은 Loop 반드시 해제.
- 구역 베드는 방마다 재생성하지 말고 **오토로드 1개**에 물려 두고 `room.gd` 전환 시 스트림만 교체 + 페이드.
- 배치: `Assets/GameReady/Audio/Ambience/{Bed,Texture,Spot}/` — 현재 평면 구조를 이 3단으로 재편 권장.
- 파일명: `bed_workshop.ogg`, `tex_power_hum.ogg`, `spot_drip_01.ogg` …

---

## 6. 수급 순서 (실무)

1. **Signature Sounds Room Tones** 로 구역 베드 4개부터 만든다 (CC0, 마찰 없음).
2. **Eric Berzins 15루프**를 정비·전력 구역 TEXTURE로 얹는다 (무료, 크레딧 불필요).
3. **OGA `30 CC0 SFX loops`** 의 머신 11종에서 릴레이실 험을 고른다.
4. 수경재배 물소리만 **Freesound CC0**에서 개별 선별 (`water pump`, `drip`, `greenhouse`).
5. SPOT은 **이미 받아 둔 Kenney**로 전부 해결 — 추가 다운로드 불필요.
6. 부족분만 **Sonniss 번들**에서 보충.

증빙: 각 소스의 라이선스 페이지를 다운로드 시점 기준으로 캡처해 `Assets/GameReady/Audio/_licenses/`에 보관.
Soundimage를 하나라도 쓰면 `Docs/CREDITS.md` 생성 필수.

---

## 7. 쓰면 안 되는 것

| 소스 | 이유 | 링크 |
|---|---|---|
| **Tabletop Audio** | 전 트랙 **CC BY-NC-ND 4.0** — 상업 불가 + 개작 불가. 품질 때문에 자주 추천되지만 우리 기준으로는 탈락 | https://tabletopaudio.com/about.html |
| Looperman | 유저 업로드 루프. 재배포·샘플팩화 금지 조항 + 업로드 출처 검증이 약함 | https://www.looperman.com/loops/tags/free-drone-loops-samples-sounds-wavs-download |
| Envato Elements | 구독 필요 | https://elements.envato.com/ |
| NOXIS `Dark Lab Atmospheres` | $2.99 유료. 톤은 우리 게임에 매우 적합하므로 **예산 생기면 1순위 후보** | https://noxis-sound.itch.io/dark-laboratory-sci-fi-horror-ambient-loops-experimental-facility-sound-pack |
| CC-BY-NC / CC-BY-SA 전반 | 상업 불가 / 전염성 | https://creativecommons.org/licenses/ |

---

## 8. 링크 모음

**CC0 룸톤·환경음**
- Signature Sounds (전 팩 CC0): https://signaturesounds.org/
- Signature Sounds Loops Of Ambience (CC0): https://signaturesounds.org/store/p/ambient-loops-free-download-cc0-wav-sample-pack-
- Freesound CC0 태그: https://freesound.org/browse/tags/cc0/
- Freesound lwdickens room tone: https://freesound.org/people/lwdickens/packs/16211/
- Freesound mzui 산업 룸톤: https://freesound.org/people/mzui/packs/12983/
- Freesound RokZRooM CC0: https://freesound.org/people/RokZRooM/packs/12161/
- Freesound Industrial Factory/Fans Loop: https://freesound.org/people/IanStarGem/sounds/271096/
- Freesound Sci-fi Ambient Drone: https://freesound.org/people/LookIMadeAThing/sounds/534018/

**SF 앰비언스 루프**
- Eric Berzins Ultra Sci-Fi Ambience (무료): https://eberzins.itch.io/ultra-sci-fi-game-audio-ambience-pack
- OGA Ambience Pack 1 Sci-Fi Horror: https://opengameart.org/content/ambience-pack-1-sci-fi-horror
- OGA 30 CC0 SFX loops: https://opengameart.org/content/30-cc0-sfx-loops
- OGA CC0 Background Ambience: https://opengameart.org/content/cc0-background-ambience
- OGA Factory ambiance: https://opengameart.org/content/factory-ambiance
- OGA Scifi City Ambient Loop: https://opengameart.org/content/scifi-city-ambient-loop
- OGA Dark Sci-Fi Audio Pack: https://opengameart.org/content/dark-sci-fi-audio-pack
- OGA Sci-Fi Sound Effects Library: https://opengameart.org/content/sci-fi-sound-effects-library
- OGA CC0 필터 검색: https://opengameart.org/art-search-advanced
- Soundimage AMB Sci-Fi (크레딧 필수): https://soundimage.org/amb-sci-fi-ambience/
- Soundimage SFX SciFi Amb: https://soundimage.org/sfx-scifi-amb/
- Soundimage 크레딧 규정: https://soundimage.org/attribution-info/

**대용량 로열티 프리**
- Sonniss GDC 번들: https://sonniss.com/gameaudiogdc/
- Sonniss Room Tone 카테고리: https://sonniss.com/category/sound-libraries/ambience/room-tone-ambience/
- Kenney 전체: https://kenney.nl/assets
- gamesounds.xyz 미러: https://gamesounds.xyz/

**라이선스 원문**
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
- CC BY-NC-ND 4.0 (사용 금지 근거): https://creativecommons.org/licenses/by-nc-nd/4.0/
- Pixabay License: https://pixabay.com/service/terms/

---

## 9. 채택 결과 (2026-09-20)

오디션 페이지(`Downloads/ambience_review.html`, 후보 61개)에서 **11개 확정**.
`Tools/stage_ambience.py` 가 OGG 변환 + RMS -24dBFS 정규화까지 해서
`GodotPrototype/assets/audio/ambience/` 로 옮긴다. 합계 1.8MB.

| 파일 | 원본 | 라이선스 | 용도 |
|---|---|---|---|
| `bed_common.ogg` | Berzins Loop 15 | 무료 상업OK | 전 구역 기본 베드 |
| `bed_workshop.ogg` | Berzins Loop 8 | 무료 상업OK | 정비 구역 베드 |
| `bed_power.ogg` | Berzins Loop 6 | 무료 상업OK | 전력 구역 베드 |
| `tex_power_highvolt.ogg` | Berzins Loop 13 | 무료 상업OK | 릴레이실 고전압 위협감 |
| `tex_hydro_air.ogg` | Berzins Loop 11 | 무료 상업OK | 수경재배 공조 |
| `tex_crew_quiet.ogg` | Berzins Loop 7 | 무료 상업OK | 승무원 구역 |
| `tex_power_machine_01.ogg` | OGA machine_11 | CC0 | 릴레이실 기계 험 |
| `tex_power_machine_02.ogg` | OGA machine_08 | CC0 | 발전실·축전기 저장고 |
| `tex_hydro_pump.ogg` | OGA pump_01 | CC0 | 급수 통로·저수조실 펌프 |
| `tex_hydro_water.ogg` | OGA water_flowing | CC0 | 저수조실 물 흐름 |
| `tex_terminal_noise.ogg` | OGA noise_01 | CC0 | 단말기 노이즈·조명 지지직 |

**OGG 변환이 선택이 아닌 이유**: `audio_manager._looped()` 는 `AudioStreamOggVorbis` 에만 `loop = true` 를 건다.
WAV 로 두면 베드가 한 번 울리고 끝난다.
**정규화한 이유**: 원본 RMS 가 -13 ~ -24dBFS 로 제각각이라 그대로 두면 방마다 앰비언스 크기가 널뛴다.

### 레벨 — 한 번 크게 틀린 곳

처음에 목표를 **-24dBFS 로 잡았다가 게임에서 앰비언스가 통째로 안 들렸다.**
옛 베드(Kenney `rumble_*`)가 **-7.6dBFS** 였고 `BED_DB` -13 은 *그 레벨을 전제로* 튜닝된 값이었는데,
파일만 보고 목표를 정하는 바람에 17dB 가 비었다 (최종 -47dBFS → 총소리 옆에서 들릴 수가 없다).

**레벨은 소스 파일의 RMS 와 믹스 상수가 한 쌍이다. 둘 중 하나만 보면 반드시 틀린다.**

| | 값 | 근거 |
|---|---|---|
| 스테이징 목표 RMS | **-14dBFS** | 옛 베드의 실효 레벨(-30.6dBFS)에서 역산 |
| `BED_DB` | **-5.0** | -14 -5 -10(버스) = **-29dBFS** ≈ 옛 -30.6 |
| `TEX_DB` | **-11.0** | 베드보다 6dB 아래 |
| `TEX_TRIM` | 4개 파일 +3.3 ~ +6.0 | crest 가 커서 피크에 걸려 -14 까지 못 올라간 만큼을 재생 게인으로 되돌림 |

`stage_ambience.py` 가 파일마다 **실제 도달한 RMS** 와 "목표보다 N dB 낮음" 을 찍는다.
그 숫자가 곧 `TEX_TRIM` 에 넣을 값이다 — 소스를 다시 뽑으면 이 둘을 같이 갱신할 것.

### 로우패스도 같이 올렸다

Ambience 버스 컷오프는 **700Hz → 2200Hz**. 700 은 Kenney SF 엔진 루프의 금속성 고역을 죽이려던 값인데,
지금 텍스처는 고역이 있어야 성격이 사는 것들이라 그대로 두면 깎여 나갔다 —
`tex_hydro_water` -10.7dB, `tex_terminal_noise` -7.0dB, `tex_hydro_pump` -6.3dB.

> 참고: libsndfile 의 vorbis 인코더가 20초 넘는 버퍼를 한 번에 받으면 죽는다.
> `stage_ambience.py` 는 1초씩 끊어 쓴다.

### 배선 (`audio_manager.gd`)

옛 구성은 `BEDS` 3종을 `hash(room_id)` 로 랜덤 배정 + `MACHINE_BED` 한 겹이었다.
**옆방으로 한 칸 걸어갔을 뿐인데 공간의 성격이 통째로 바뀌는 게** 그 방식의 문제였다.
지금은 2단이다.

| | 무엇이 정하나 | 상수 | 레벨 |
|---|---|---|---|
| L1 BED | **구역**(`RoomData` 의 zone) | `ZONE_BEDS` + `BED_FALLBACK` | `BED_DB` -13 |
| L2 TEXTURE | **방**(없으면 구역 기본) | `ROOM_TEX` → `ZONE_TEX` | `TEX_DB` -19 |

- 방 id 가 아니라 zone 으로 고르므로 **맵에 방이 늘어도 그 구역 소리가 저절로 따라온다.**
- 구역이 같으면 베드는 건드리지 않는다. 문을 지날 때마다 바닥이 흔들리지 않게 하려는 것.
- 텍스처 슬롯은 `TEX_SLOTS` = 2. 슬롯이 물고 있는 경로가 그대로면 재시작하지 않는다
  (구역 안을 도는 동안 펌프 소리가 방마다 끊기면 제일 티가 난다).
- 정비 구역은 텍스처를 비워 뒀다 — 넓고 빈 공간이라 베드만 남기는 편이 낫다.

옛 `rumble_01~03` · `machine_01` 은 지우지 않고 뒀다. 비교해 들어볼 때 쓴다.

### 방별 조정은 랩에서 — 숫자를 코드에서 고치지 않는다

로비 → **♪ 앰비언스 랩**. 실제로 걸어 다니면서 그 방에 지금 무엇이 울리는지 패널로 보고
그 자리에서 고친다. 근경 랩과 달리 **플레이어 입력을 끄지 않는다** — 소리는 문을 넘나들며
베드가 바뀌는 순간을 들어야 판단이 되기 때문이다.

| 키 | |
|---|---|
| `Tab` | 편집 대상 (BED → TEX 0 → TEX 1) |
| `-` / `=` | 음량 ∓0.5dB (Shift 와 함께 ∓2.0dB) |
| `,` / `.` | 그 슬롯의 파일 순환 (`AudioManager.AMB_FILES`, 텍스처는 "(없음)" 도 거친다) |
| `Backspace` | 텍스처 슬롯 비우기 |
| `Ctrl+S` | `GodotPrototype/ambience/tuning.json` 저장 (그때까지 만진 방 전부) |
| `Ctrl+R` | 이 방 보정만 지우고 기본값으로 |
| `F5` | 패널 접기 |

저장 파일은 `AudioManager` 가 시작할 때 읽어 **기본값(ZONE_BEDS·ROOM_TEX·TEX_TRIM) 위에 덮는다.**
랩에서만 들리는 값이 아니라 본편에 그대로 적용된다는 뜻이다.
그래서 코드의 상수는 "출발점", `tuning.json` 은 "귀로 확정한 값" 으로 역할이 갈린다.
값이 굳으면 상수 쪽으로 옮기고 json 에서 지우는 편이 읽기에 낫다.

기본값과 보정을 합쳐 실제로 울릴 것을 정하는 곳은 `AudioManager.plan_for(room_id)` 한 군데다 —
랩 패널도, 재생부도, 저장도 전부 이 함수를 본다.

### 미채택 — lwdickens room tone 16개 (CC BY-NC, 상업 불가)

퀄리티는 검토한 것 중 가장 좋으나 라이선스가 막는다. 쓰고 싶은 3개와 처리 방침:

| 파일 | Freesound | 원하는 용도 |
|---|---|---|
| 복도 강한 환기 | [269385](https://freesound.org/s/269385/) | 정비 구역 실사 베드 |
| 환기 + 전기 기계 | [269384](https://freesound.org/s/269384/) | 전력 구역 실사 베드 |
| 복도 형광등 | [263506](https://freesound.org/s/263506/) | 형광등 버즈 (`lamp_light.gd`) |

1. **작가 허락 요청** — CC BY-NC 도 저작자의 별도 허락이 있으면 상업 사용이 열린다.
   Freesound 쪽지: https://freesound.org/home/messages/new/lwdickens/ · 승낙 원문을 `assets/audio/_licenses/` 에 보관.
2. **CC0 재수급** — 매칭 기준은 아래 측정값으로 잡는다.
3. **직접 녹음** — 지하주차장·기계실·계단실. 특수 장비가 필요한 종류의 소리가 아니다.
4. **합성** — Ambience 버스에 이미 700Hz 로우패스가 걸려 있어(`audio_manager.gd` `LOWPASS`)
   베드에서 실제로 들리는 건 저역뿐이다. 필터드 노이즈 합성으로 대체 가능한 범위.

재수급·녹음·합성의 목표 수치(원본 측정값):

| 대상 | 길이 | RMS | 저역비 | ZCR |
|---|---:|---:|---:|---:|
| 정비 베드 (269385) | 115초 | -31.1dB | 0.827 | 225 |
| 전력 베드 (269384) | 103초 | -34.9dB | 0.886 | 337 |
| 형광등 (263506) | 120초 | -39.5dB | 0.625 | **1155** |

> 형광등은 고역이 핵심이라 **Ambience 버스(700Hz 로우패스)에 태우면 사라진다.**
> 물방울과 같은 이유로 SFX 버스에 낮게 걸어야 한다.
