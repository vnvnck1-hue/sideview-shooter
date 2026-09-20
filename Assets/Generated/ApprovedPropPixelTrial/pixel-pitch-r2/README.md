# 픽셀 크기 3단계 비교 — 선택 전 후보

사용자 요청: 승인된 프로세스에서 픽셀 덩어리만 조금 더 크게 하고 3단계로 비교한다. 현재 승인본 `../crisp-final-r1/`과 원본은 변경하지 않았다. 아래 9개 결과는 새 승인 전 후보이며 게임 반입은 하지 않았다.

| 비교 항목 | 현재 승인본 | A | B | C |
|---|---:|---:|---:|---:|
| 같은 표시 크기에서 픽셀 한 변 | 1.00배 | 1.25배 | 1.50배 | 2.00배 |
| 가로·세로 해상도 비율(대략) | 100% | 80% | 66.7% | 50% |
| 세면대 캔버스 | 209×302 | 168×242 | 140×202 | 106×152 |
| 캐비닛 캔버스 | 372×317 | 298×254 | 249×212 | 187×160 |
| 의자 캔버스 | 288×242 | 231×194 | 193×162 | 145×122 |

모든 캔버스는 1px 투명 여백을 포함한다. 내용 크기는 `ceil(원본 크기 / 픽셀 배율)`이며 끝부분의 부분 셀 때문에 비율이 약간 반올림된다.

## 비교 이미지

전체 비교판은 위쪽 **현재 / A**, 아래쪽 **B / C**다. 세 자산 모두 같은 구도·같은 표시 크기로 비교한다.

- 세면대: [전체](review/crew_wash_station-levels.png) · [확대](review/crew_wash_station-detail.png)
- 캐비닛: [전체](review/workshop_locker_game_scale-levels.png) · [확대](review/workshop_locker_game_scale-detail.png)
- 의자: [전체](review/workshop_armchair_game_scale-levels.png) · [확대](review/workshop_armchair_game_scale-detail.png)

확대판은 왼쪽부터 현재 / A / B / C다. 공통 4배 표시 공간에서 각 네이티브 픽셀은 정확히 **4 / 5 / 6 / 8 표시 픽셀**로 보인다(크롭 가장자리 제외). 뷰어는 이미지 100%로 확인하는 것이 좋다. 전체 비교판의 1.25·1.5배는 비정수 표시 배율이므로 일부 블록이 화면에서 1px/2px로 번갈아 보이는 현상이 있다. 블러는 없지만, 균일한 픽셀 크기 판단은 확대판을 우선한다. 이는 비교용 표시이며 엔진 렌더링 정책이 아니다.

## Aseprite / PNG

| 대상 | A · 1.25배 | B · 1.5배 | C · 2배 |
|---|---|---|---|
| 세면대 | [Aseprite](a-125/crew_wash_station.aseprite) · [PNG](a-125/crew_wash_station.png) | [Aseprite](b-150/crew_wash_station.aseprite) · [PNG](b-150/crew_wash_station.png) | [Aseprite](c-200/crew_wash_station.aseprite) · [PNG](c-200/crew_wash_station.png) |
| 캐비닛 | [Aseprite](a-125/workshop_locker_game_scale.aseprite) · [PNG](a-125/workshop_locker_game_scale.png) | [Aseprite](b-150/workshop_locker_game_scale.aseprite) · [PNG](b-150/workshop_locker_game_scale.png) | [Aseprite](c-200/workshop_locker_game_scale.aseprite) · [PNG](c-200/workshop_locker_game_scale.png) |
| 의자 | [Aseprite](a-125/workshop_armchair_game_scale.aseprite) · [PNG](a-125/workshop_armchair_game_scale.png) | [Aseprite](b-150/workshop_armchair_game_scale.aseprite) · [PNG](b-150/workshop_armchair_game_scale.png) | [Aseprite](c-200/workshop_armchair_game_scale.aseprite) · [PNG](c-200/workshop_armchair_game_scale.png) |

## 고정한 것과 바꾼 것

1. 승인 원본 `r2/sources/`부터 기존 변환기를 동일 설정 `12 / 20 / true / 3`으로 재실행했다. 새 `prepared/` 결과와 승인본의 RGBA 전 픽셀이 일치함을 확인했다. 승인된 생성기와 파일은 수정하지 않았다.
2. 이 원본 기반 색 군집·경계 결과를 더 큰 격자로 옮기는 **격자 선택 단계만 추가**했다. 각 셀 안에서 색면의 면적 지지를 계산하고 실제 존재하는 색 하나를 선택한다. 면적을 계산하는 것은 RGB를 평균 내는 것과 다르다. 평균색 생성, 블러, 디더링, 새 대비 곡선, 새로운 팔레트 압축은 사용하지 않는다.
3. 각 후보를 이전 단계 후보에서 연쇄 축소하지 않는다. 모두 동일한 전체 해상도의 원본 기반 준비 결과에서 독립적으로 선택한다. 단순히 완성 PNG를 Nearest로 줄이는 것과 달리 셀 안의 색면 지지를 확인하지만, 이 단계 역시 정보가 줄어드는 리샘플링이다. 손실 없는 변환이라고 주장하지 않는다.
4. 알파는 셀의 전경 면적이 절반 이상이면 불투명으로 결정한다. 외곽의 작은 돌출부, 내부 얇은 선과 점무늬는 합쳐지거나 한 셀 정도 이동할 수 있다. 특히 C는 가로·세로 절반이므로 작은 변화만 있는 후보가 아니라 비교 범위의 굵은 끝이다.

색·대비·디자인을 별도로 바꾸지 않았으며, 팔레트 색 수가 줄어든 것은 작은 격자에서 일부 기존 색이 선택되지 않았기 때문이다. 새 색은 없다. 명암선이 같은 칸에 겹치면 둘 다 보존할 수 없으므로 각 단계의 손실을 직접 판단한다.

### 레이어

- `center_sample_reference`: 숨김. 동일 격자의 단순 중심 샘플링 대조본.
- `coverage_selected_pixels`: 실제 출력. 색면 지지로 결정한 픽셀.

전체 해상도의 원본 참조/색 군집/경계 레이어는 `prepared/*.aseprite`에 남는다.

## 검수와 재현

9개 후보의 Aseprite 재열기 PNG 전 픽셀 일치, 치수, 이진 알파, 투명 여백, 승인본에 없던 출력색 0개를 검사했다. 입력·승인본 해시는 그대로다. [verification.json](verification.json)의 실루엣 IoU와 색 오차는 손실을 보는 보조 자료이며 품질 점수나 승인률이 아니다.

`../pixel-pitch-repro/`에 독립 재실행하여 9개 모두 이 제출본과 RGBA 전 픽셀 일치를 확인했다. 재실행에서는 Aseprite의 두 레이어 이름·숨김 상태·단일 프레임·보이는 합성 결과까지 추가 검사했다. 이 폴더의 PNG/Aseprite 해시와 README 링크도 검증했다.

시각 검토: A는 대부분의 형태와 미세 무늬가 남으며 경계 위치가 조금 달라진다. B는 선과 재질 덩어리가 더 굵게 묶인다. C는 세면대 접합부·수건 주름, 캐비닛 손잡이 반사광, 의자 충전재 가장자리의 미세 묘사가 더 많이 단순해진다. 사용자가 선택하기 전 어느 후보도 기본값으로 승격하지 않는다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_pixel_pitch_trials.ps1 -RunName pixel-pitch-repro
```

기존 폴더가 있으면 중단한다. `pixel-pitch-r1/`은 검사 JSON의 숫자 포맷 오류로 중단된 최초 실행이며 비교 대상이 아니다. 새 후보를 게임에 적용하려면 기존 월드 크기와 배율을 별도로 검토해야 한다. 이번에는 엔진·기존 게임 자산을 변경하지 않았다.
