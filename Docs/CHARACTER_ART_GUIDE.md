# 인물 아트 가이드

> 2026-09-19. `Docs/ART_GUIDE.md`의 픽셀·조명·카메라 규격을 인물에 적용한다.
> 아래 NPC 그림은 **형태와 팔레트 검토용 콘셉트**이고, 게임에 들어간 것은 그 콘셉트를 §5 규격으로 구운 결과물이다
> (`Tools/build_npc_sprites.py`). 대화 시스템은 `Docs/DIALOGUE_SYSTEM.md`.
>
> 문서 역할: 인물의 비율·실루엣·애니메이션에만 특화된 보조 규격이다. 공통 픽셀 규격은
> [`ART_GUIDE.md`](ART_GUIDE.md), 제작·검사 명령은 [`ASEPRITE_PIPELINE.md`](ASEPRITE_PIPELINE.md),
> 전체 문서 구조는 [`ART_DOCUMENTATION_INDEX.md`](ART_DOCUMENTATION_INDEX.md)를 따른다.

## 1. 캐릭터의 공통 결

- 어둡고 낡은 지하 스테이션에 사는 **평범한 사람**으로 보이게 한다. 직업은 복장과 들고 있는 물건 한 가지로 읽힌다.
- 인물은 차가운 배경보다 강한 실루엣 대비를 가진다. 따뜻한 프랍 앞에서도 머리·어깨·손·발의 윤곽이 사라지지 않아야 한다.
- 같은 세계의 인물로 묶는 요소는 큰 사각 픽셀 클러스터, 계단식 명암, 짙은 외곽선, 먼지 낀 옷 색이다. 같은 몸통에 색과 장비만 바꾸는 방식은 피한다.
- 오른쪽을 향한 **엄격한 사이드뷰**를 기본으로 한다. 양쪽 눈이나 정면 가슴을 보여 주는 3/4 시점은 사용하지 않는다.

## 2. 비율과 실루엣

- **현재 게임에서 쓰는 붉은 후드 플레이어**를 크기와 덩어리감의 기준으로 삼는다. NPC는 같은 바닥선에 세웠을 때 플레이어보다 한참 작거나 가늘게 보이지 않아야 한다.
- 머리와 머리카락을 포함한 높이는 서 있는 전체 키의 **약 30~40%를 출발점으로 잡는다**. 살짝 만화적인 비율이지만, 키만 키우지 말고 머리·어깨·몸통·부츠의 큰 형태를 함께 맞춘다.
- 키는 캐릭터마다 조금 달라도 발바닥은 같은 바닥선에 닿는다. 머리를 키울 때 전체 키만 키우지 말고 몸통·다리 비율을 함께 줄인다.
- 세부 색을 보기 전에 단색 실루엣으로 구분한다: 관리인은 넓은 몸통, 관제원은 좁고 곧은 몸, 수경재배사는 약간 굽은 등, 연구원은 헤어스타일과 겉옷의 길이로 나눈다.
- 한 인물의 직업 표식은 1~2개면 충분하다. 장비를 여러 개 겹쳐 실루엣을 복잡하게 만들지 않는다.

## 3. 얼굴과 머리

- **플레이어**는 붉은 후드와 작은 호박색 바이저로 얼굴을 감춘다. 이 조합은 플레이어의 고유 표식이다.
- **일반 인간 NPC**는 얼굴이 보인다. 피부는 큰 2~3단계 색면으로 묶고, 보이는 눈 1개·코의 돌출·턱선만으로 표정을 읽힌다. 작은 입·주름·속눈썹을 촘촘히 그리지 않는다.
- 머리카락은 인물별 큰 형태로 구분한다. 예: 짧은 회색 머리, 각진 단발, 낮은 묶음머리, 벗겨진 앞머리. 머리카락 한 올 대신 넓은 명암 패치를 쓴다.
- 안경·이어피스는 얼굴을 가리지 않는 작은 직업 단서로만 사용한다. 일반 NPC에 플레이어의 바이저나 후드 실루엣을 반복하지 않는다.

## 4. 복장과 색

- 작업복, 제복, 앞치마, 실험복, 카디건처럼 **익숙한 옷의 큰 재단선**을 우선한다. 벨트·깃·소매·옷자락은 작은 휘장이나 글자보다 중요하다.
- 배경의 청회색과 구분되도록 옷에는 먼지 낀 웜그레이·황갈색·슬레이트색·남보라를 섞는다. 순백 실험복, 선명한 형광색, 넓은 붉은 면은 피한다.
- **캐릭터는 자산당 8~16색 목표를 유지한다** (2026-09-20 사용자 재확인). 배경보다 간결한 색면으로 인물을 구분하기 위한 의도적인 차별화이며, 배경·프랍의 일괄 색 수 제한 해제와 별개다. 피부, 머리, 옷, 외곽선 각각 2~3단계 명암을 기본으로 하고, 강조색은 계기판·배지·시료통 같은 한 곳에만 둔다.
- 원화 생성 단계부터 이 팔레트 목표로 디자인하고 승인받는다. 승인 원화를 16색으로 기계적으로 줄여 핵심 색·명암이 손실되면 비교를 제시하고 팔레트/원화를 재검토한다. 목표를 임의로 해제하거나 승인 후 디자인을 몰래 바꾸지 않는다. 애니메이션은 인물별 공통 팔레트를 사용하고 브리프에 검사 범위를 기록한다.
- 흰색 계열 실험복은 낡은 아이보리와 회색 음영으로 낮춘다. 플레이어의 붉은 후드가 화면의 우선 시선으로 남아야 한다.

## 5. 픽셀 제작 규격

- 신규 인물은 `Docs/ART_GUIDE.md`의 **Native4** 방식으로 제작한다: 1 art px = 4 월드 px. 최종 파일은 투명 PNG, 알파 0 또는 255, 안티앨리어싱·블러·매끈한 그라데이션 없음.
- 기본 애니메이션 셀은 **80×80 art px**(게임에서 320×320 월드 px). 현재 플레이어의 서 있는 실루엣은 약 40×67 art px이며, NPC는 체형에 따라 너비와 키를 조정한다.
- 모든 프레임은 같은 셀 크기, **Bottom Center 피벗**, 같은 발바닥선을 쓴다. 오른쪽 기본 프레임을 만들고 왼쪽은 필요한 경우 반전한다.
- 1 art px 윤곽선은 허용한다. 명암은 큰 계단식 패치로 나누고, 장식용 1px 점을 반복하지 않는다. 표식은 글자 대신 색 블록이나 단순한 아이콘으로 표시한다.
- 콘셉트 PNG를 줄여 넣는 것만으로 완료하지 않는다. 실제 크기의 Native4 격자에서 얼굴·옷자락·손과 장비를 다시 정리한다.

## 6. 애니메이션 출발점

- 일반 NPC는 `idle` 1프레임 + 절차적 움직임이다. **젊은 연구원 유나**는 아래 프레임 클립을 실제 NPC 런타임에서 재생한다. 남자 연구원도 같은 규격의 클립 자산이 준비되어 있으며, 배치·대사 정의가 추가되면 연결할 수 있다.
- 연구원 클립 네 가지: `idle_breathe`(호흡), `idle_notes`(기록 확인), `idle_listen`(고개를 들고 듣기)은 각 **4프레임 / 3 fps**, `walk`는 **8프레임 / 8 fps**. 모두 오른쪽 기본 방향이며 왼쪽은 반전한다.
- 유나는 평상시 `idle_breathe`, 간헐적으로 `idle_notes` 한 번, 대화 중 `idle_listen`을 재생한다. `walk`는 이동 AI가 연결될 때 `Npc.play_animation_clip("walk")`로 호출한다. 프레임 클립이 켜지면 기존 절차적 호흡 스케일은 중복하지 않는다.
- 손으로 그리는 경우 `idle` 3~4프레임을 우선한다. 숨쉬기와 머리카락·소매·손의 작은 변화만 주고, 발 위치는 고정한다.
- 이동이 필요한 NPC는 접지 → 통과 → 반대쪽 접지가 분명한 걷기를 만든다. 프레임마다 몸통 중심이 흔들리지 않게 한다.
- 대화 제스처는 머리 끄덕임 또는 손에 든 물건을 드는 동작 하나로 읽히게 한다. 작은 입 모양 애니메이션에 의존하지 않는다.

## 7. 현재 인물 콘셉트 기준

| 인물 | 먼저 읽혀야 할 형태 | 옷과 작은 소품 | 기준 이미지 |
|---|---|---|---|
| 플레이어 정비공 | 붉은 후드, 가려진 얼굴 | 황갈색 재킷, 배낭 | `Assets/GameReady/Characters/HoodedMechanic/Frames/idle/idle_01.png` |
| 에어록 관리인 | 넓은 체형, 큰 회색 머리 | 황갈색 작업복, 압력 계기 | `Assets/Generated/NPCConcepts/airlock_caretaker_concept_v5.png` |
| 방어망 관제원 | 마른 체형, 각진 짧은 머리 | 남청색 제복, 이어피스·손목 패널 | `Assets/Generated/NPCConcepts/security_controller_concept_v5.png` |
| 수경재배사 | 굽은 자세, 낮은 묶음머리 | 갈색 셔츠, 짧은 앞치마·시료통 | `Assets/Generated/NPCConcepts/hydroponics_keeper_concept_v5.png` |
| 젊은 연구원 | 둥근 단발, 짧은 겉옷 | 낡은 아이보리 실험복, 기록판 | `Assets/Generated/NPCConcepts/researcher_junior_concept_v2.png` |
| 선임 연구원 | 벗겨진 이마, 안경 | 슬레이트 카디건, 수첩 | `Assets/Generated/NPCConcepts/researcher_senior_concept_v2.png` |
| 일반 남자 연구원 | 짧은 갈색 머리, 드러난 얼굴 | 긴 낡은 아이보리 실험복, 청록색 셔츠 | `Assets/Generated/NPCConcepts/researcher_male_concept_v1.png` |

## 7-1. 게임 속 이름

배치·대사는 `GodotPrototype/scripts/npc_data.gd` 의 `CAST` 가 단일 출처다.

| 자산 id | 게임 속 인물 | 대사 id |
|---|---|---|
| `airlock_caretaker` | 에어록 관리인 · 아르카디 | `caretaker` |
| `security_controller` | 방어망 관제원 · 세린 | `controller` |
| `hydroponics_keeper` | 수경재배사 · 미나 | `keeper` |
| `researcher_junior` | 연구원 · 유나 | `junior` |
| `researcher_senior` | 선임 연구원 · 델 박사 | `senior` |
| `researcher_male` | 연구 보조원 (이름·대사 미정) | `staff` |

## 8. 장면 검수

1. 플레이어와 NPC를 **같은 바닥선·실제 화면 크기**로 배치한다. 머리 비율과 픽셀 크기가 같은 세계로 읽히는지 확인한다.
2. 각 인물을 단색 실루엣으로 봐도 구분되는지 확인한다. 구분이 안 되면 색이나 배지를 추가하기 전에 머리·어깨·옷자락을 바꾼다.
3. 차가운 배경과 따뜻한 프랍 양쪽에서 얼굴과 손이 읽히는지 확인한다. 밝기가 부족하면 먼저 뒤쪽 배경과 겹침을 점검한다.
4. 가장 축소된 줌(화면 배율 ×2)에서도 직업 표식이 남는지 확인한다. 작은 눈썹·글자·버튼의 단순화는 원화 디자인 단계에서 결정한다. 이미 승인된 디테일은 확대에서만 보인다는 이유로 픽셀화 중 임의로 제거하지 않는다.
5. 대화 줌(화면 배율 ×5~×6)에서 얼굴을 다시 본다. 인물은 이 배율에서 가장 크게 보이므로 1 px 점·디더링·끊긴 외곽선이 그대로 드러난다. 두 배율 기준은 `ART_GUIDE.md` §10 단위 절을 따른다.
6. 최종 PNG는 80×80 셀, 공통 피벗, 알파 0/255, Native4 픽셀 규격을 검사한 뒤 `Assets/GameReady/Native4/character/npc/<id>/`에 넣는다.

### 현재 반입된 NPC 자산

아래 BOX 축소·16색 처리와 재생성 명령은 **현재 반입본의 구현 기록**이다. 캐릭터의 8~16색 목표는 유지하지만, 평균 축소까지 신규 보존형 작업의 표준으로 삼지는 않는다. 신규 변환은 `ASEPRITE_PIPELINE.md`를 따르고 승인 원화와 비교한다. 이 문서 정리는 기존 NPC 자산·애니메이션 도구를 변경하지 않는다.

`Tools/build_npc_sprites.py`가 콘셉트 PNG(1254×1254, ~16px 블록)를 §5 규격으로 굽는다:
알파 bbox로 인물만 잘라 → 면적 평균(BOX)으로 키를 아트 px까지 축소 → 알파 0/255 · 16색 → 80×80 셀 바닥 중심.

| id | 아트 px (W×H) | 콘셉트 |
|---|---|---|
| `airlock_caretaker` | 39×65 | `airlock_caretaker_concept_v5.png` |
| `security_controller` | 26×68 | `security_controller_concept_v5.png` |
| `hydroponics_keeper` | 35×64 | `hydroponics_keeper_concept_v5.png` |
| `researcher_junior` | 27×63 | `researcher_junior_concept_v2.png` |
| `researcher_senior` | 34×65 | `researcher_senior_concept_v2.png` |
| `researcher_male` | 26×65 | `researcher_male_concept_v1.png` |

플레이어 서 있는 실루엣이 40×66 아트 px이므로 기존 다섯 인물과 새 남자 연구원은 같은 키 범위에서 읽힌다. 연구원 둘은 직업상 플레이어보다 좁은 몸 폭을 갖는다.

### 연구원 애니메이션 자산

- 소스 포즈 시트: `Assets/Generated/NPCAnimation/<id>_{idle,walk}_source.png`
- 최종 프레임: `Assets/GameReady/Native4/character/npc/<id>/animations/<clip>/<clip>_NN.png` (80×80, 알파 0/255, 인물별 공통 16색 팔레트)
- Godot 반입: `GodotPrototype/assets/character/npc/<id>/animations/` (320×320, 4배 Nearest) 및 같은 상대경로의 `assets/normals/` 노멀맵
- 재생·비교: `Assets/Generated/NPCAnimation/review/`에 인물별 접촉 시트와 GIF, 원래 플레이어를 포함한 복도 캡처와 GIF
- 재생성: `python Tools/build_researcher_animation.py` (프레임 정렬, 팔레트·알파 정리, 4배 반입, 노멀맵, 비교 이미지까지)
- 정렬 규칙: 포즈 바깥에 떠 있는 얼룩(생성 원화가 장화 아래 남기는 옅은 그림자 자국)은 몸의 1/20 미만이면
  버리고 나서 bbox 를 잡는다. 그렇지 않으면 그 얼룩만큼 키가 커진 것으로 계산되어 인물이 작아지고
  발이 셀 바닥에서 떠 버린다 — 모든 프레임이 같은 바닥선(아트 y=78)과 같은 머리선을 갖는지로 검사한다.
- 게임 안 사용: `npc_data.gd` CAST 의 `"anim"` 키가 이 폴더 id 를 가리킨다. 걷기는 배치의 `"roam"` 으로 쓰인다.

```
python Tools/build_npc_sprites.py
python Tools/upscale_native4.py                    # ×4 Nearest → GodotPrototype/assets/character/npc/
python Tools/build_normal_maps.py character/npc
```

키를 바꾸려면 `build_npc_sprites.py`의 `NPCS` 표만 고친다. 몸 폭은 `NpcData.CAST[*].body`에
월드 px로 적혀 있고 배치 검사(`tools/validate_map.gd`)가 벽 여유를 볼 때 쓴다.

현재 비교 캡처: `Assets/Generated/NPCConcepts/cast_player_scale_detail.png`. 배경에 이미 있는 **원래 플레이어** 옆에 다섯 NPC를 같은 바닥선으로 배치했다.

## 9. 플레이어 리디자인 검토 기록 (채택하지 않음)

- **기존 플레이어** `Assets/GameReady/Characters/HoodedMechanic/Frames/idle/idle_01.png`가 현재 게임과 NPC 제작의 기준이다. NPC 크기를 이쪽에 맞춘다.
- **후드 유지안** `Assets/Generated/PlayerConcepts/hooded_mechanic_npc_proportions_v1.png`: 머리와 몸 비율을 NPC 쪽으로 옮기되 붉은 후드·호박색 바이저를 유지한다. 기존 식별성이 강하지만 얼굴이 보이는 NPC와 표현 차이가 남는다.
- **얼굴 노출안** `Assets/Generated/PlayerConcepts/hooded_mechanic_face_visible_v2.png`: 후드를 뒤로 내리고 얼굴·머리카락을 보여 준다. 붉은 작업복과 호박색 고글로 플레이어 색을 유지하며, 일반 인간 NPC의 비율과 얼굴 규칙에 더 가깝다.
- 비교 캡처: `Assets/Generated/PlayerConcepts/player_redesign_comparison_detail_v2.png`. 두 안은 제작 과정의 비교 자료이며 현재 게임 플레이어를 교체하지 않는다.
