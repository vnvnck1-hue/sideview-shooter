# 픽셀 크기 2.0 / 3.0 / 4.0 비교

사용자 요청에 따라 이전 1.25 / 1.5 / 2.0 비교의 범위를 넓혔다. **승인된 원본색·대비·경계 정리 설정은 그대로 유지하고 픽셀 격자 크기만 변경**했다. 현재 승인본 `../crisp-final-r1/`, 원본, 게임 자산은 변경하지 않았다. 새 9개 후보는 선택 전이며 게임 반입은 미실행이다.

## 비교 방법

전체 비교판은 위쪽 **현재 1배 / A 2배**, 아래쪽 **B 3배 / C 4배**다. 물체의 표시 크기는 동일하다. 확대판은 왼쪽부터 **현재 / 2배 / 3배 / 4배**다.

| 대상 | 전체 | 4배 부분 확대 |
|---|---|---|
| 세면대 | [전체 비교](review/crew_wash_station-levels.png) | [테두리·배수 연결부](review/crew_wash_station-detail.png) |
| 캐비닛 | [전체 비교](review/workshop_locker_game_scale-levels.png) | [손잡이](review/workshop_locker_game_scale-detail.png) |
| 의자 | [전체 비교](review/workshop_armchair_game_scale-levels.png) | [찢어진 천](review/workshop_armchair_game_scale-detail.png) |

이미지를 뷰어에서 100%로 보면 전체판의 네이티브 픽셀 한 변이 각각 1 / 2 / 3 / 4 화면 픽셀이다. 부분 확대판에서는 각각 4 / 8 / 12 / 16 화면 픽셀이다. 모두 정수 배율이며 보간 블러 없이 표시한다. 앱이 비교판 전체를 축소해 보여주면 이미지를 열어 100%로 확인한다.

## 파일 및 규격

캔버스 크기는 원본 크기를 배율로 나누고 올림한 뒤 네 면에 투명 여백 1px을 더한 값이다.

| 대상 | A · 2배 | B · 3배 | C · 4배 |
|---|---|---|---|
| 세면대 | 106×152 · [Aseprite](a-200/crew_wash_station.aseprite) · [PNG](a-200/crew_wash_station.png) | 71×102 · [Aseprite](b-300/crew_wash_station.aseprite) · [PNG](b-300/crew_wash_station.png) | 54×77 · [Aseprite](c-400/crew_wash_station.aseprite) · [PNG](c-400/crew_wash_station.png) |
| 캐비닛 | 187×160 · [Aseprite](a-200/workshop_locker_game_scale.aseprite) · [PNG](a-200/workshop_locker_game_scale.png) | 126×107 · [Aseprite](b-300/workshop_locker_game_scale.aseprite) · [PNG](b-300/workshop_locker_game_scale.png) | 95×81 · [Aseprite](c-400/workshop_locker_game_scale.aseprite) · [PNG](c-400/workshop_locker_game_scale.png) |
| 의자 | 145×122 · [Aseprite](a-200/workshop_armchair_game_scale.aseprite) · [PNG](a-200/workshop_armchair_game_scale.png) | 98×82 · [Aseprite](b-300/workshop_armchair_game_scale.aseprite) · [PNG](b-300/workshop_armchair_game_scale.png) | 74×62 · [Aseprite](c-400/workshop_armchair_game_scale.aseprite) · [PNG](c-400/workshop_armchair_game_scale.png) |

## 동일 프로세스와 손실

- 승인 원본에서 `Tolerance=12 / Snap=20 / Coherent=true / Passes=3`으로 전체 해상도 준비 단계를 다시 실행했다. `prepared/*.png`는 승인본과 RGBA 전 픽셀이 일치한다.
- 모든 후보는 같은 준비 결과에서 독립적으로 변환한다. 2배 결과를 다시 줄여 3배·4배를 만드는 연쇄 축소는 하지 않는다.
- 기존 `coarsen_crisp_prop.lua`의 색면 면적 지지 기반 선택을 그대로 사용했다. 변경은 허용 배율 상한 2→4와 비교판/실행기의 배율 설정뿐이다. 새로운 RGB 평균색·전역 대비·디더링·팔레트 압축은 없다.
- 2배는 지난 비교 `../pixel-pitch-r2/c-200/`과 세 프랍 모두 RGBA 전 픽셀이 일치한다. 이전과 이번 비교를 연결하는 대조 기준이다.
- 3배·4배는 화소 수가 크게 줄어든다. 경계는 픽셀 단위로 단단하게 유지되지만 얇은 선과 작은 재질 무늬가 합쳐지거나 사라질 수 있다. 이를 선명도·디테일 무손실이라고 주장하지 않는다.
- 실제 시각 검토에서 4배 세면대의 거울 반사·수건 주름·접합부, 캐비닛 손잡이와 경첩, 의자의 천 찢김과 마모가 특히 단순해진 것을 확인했다. 사용자가 판단하기 전 기본 프로세스/규격으로 승격하지 않는다.

작은 Aseprite 파일은 숨김 `center_sample_reference`와 표시 `coverage_selected_pixels`의 두 레이어다. 전체 원본 참조·색 군집·경계 정리는 `prepared/*.aseprite`에 보존된다.

## 검증과 재현

[verification.json](verification.json)에 9개 결과의 크기·색 수·원본/승인본/산출물 해시를 남겼다. Aseprite 재열기와 레이어/프레임/합성 검사, PNG RGBA 전 픽셀 일치, 알파 0/255, 투명 여백, 승인본에 없는 RGB 0개, 원본과 승인본 불변 검사를 모두 통과했다. 실루엣 IoU와 색 오차는 제한된 손실 지표이며 사용자 승인이나 품질 점수가 아니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_pixel_pitch_trials.ps1 -RunName pixel-pitch-234-repro -PitchSet coarse
```

같은 출력 폴더가 있으면 중단한다. 기존 세밀한 후보는 `-PitchSet fine`으로 재현할 수 있다. 실제 게임 적용은 별도 요청·배율/크기 검토가 필요하다.
