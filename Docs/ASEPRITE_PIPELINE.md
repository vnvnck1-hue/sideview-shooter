# Aseprite 네이티브 픽셀 제작 파이프라인

이 문서는 `ART_GUIDE.md` **§0 승인 원화 보존 원칙과 §10–11**의 실행 절차다. 원화 생성에서 사용자 승인까지 디자인을 결정하고, 이후 Aseprite에서는 그 외관을 최대한 보존해 실제 픽셀로 옮긴다. 전체 문서 관계는 `ART_DOCUMENTATION_INDEX.md`에서 관리한다. 아래 목표 절차 전체가 자동 구현된 것은 아니다. 현재 도구의 한계는 ‘현재 실행 경로’의 ‘실행 기본값과 구현 경계’를 참고한다.

## 무엇을 실제 픽셀 아트로 보는가

- Aseprite 최종 캔버스의 **이미지 1px가 아트 1px**다. 현행 엔진 프로파일은 Nearest 4배 확대이며, 보존 손실로 다른 프로파일이 필요하면 사전 합의·구현 검증 후 사용한다.
- 펜으로 직접 찍은 픽셀과 Lua가 좌표·색을 지정해 찍은 픽셀은 동일한 네이티브 픽셀 데이터다. 마우스 조작 여부는 품질 기준이 아니다.
- 승인된 고해상도 원화는 형태뿐 아니라 색·디자인·명암·재질·디테일의 직접 기준이다. 가져오기·추적·오버레이·리샘플링·색 양자화는 보존형 초안을 만드는 보조 수단으로 사용할 수 있다. 자동 초안이나 파일 형식 변환만을 완성으로 취급하지 않는다. 최종 격자에서 경계·군집·색을 원화와 대조해 정리하고 손실을 검수한다. 재정리는 재디자인 허가가 아니다.
- `.aseprite`는 레이어·프레임·태그가 보존된 편집 원본이다. PNG/JSON은 이 원본에서 다시 만들 수 있는 산출물이다.

## 한 번의 제작 사이클

| 단계 | 입력 | 작업 | 산출물·통과 조건 |
|---|---|---|---|
| 1. 원화 생성 | 자연어 요청 + 그림체 가이드 + 기존 리소스 | 색감·형태·재질·밀도를 반영해 원화 생성 | 원화 후보와 기준 이미지 |
| 2. 사용자 원화 승인 | 원화 후보 | 디자인 결정, 수정 요청 반영 | 불변 원본·해시·대상 영역·승인 범위 |
| 3. 보존 브리프/규격 시험 | 승인 원화 + 실제 월드 크기 | 보존 목록 작성, 해상도·팔레트 후보 손실 비교 | 합의된 크기/색 수/출력 프로파일, 미승인 손실 없음 |
| 4. 보존형 픽셀화 | 승인 원화 + 브리프 | 참조/추적, 원화에 대응하는 구조·재질·기능·경계 정리 | staging의 버전별 `.aseprite`, 임의 재설계 없음 |
| 5. 내보내기/자동 검사 | `.aseprite` | PNG/JSON 재생성, 합의된 크기·색·알파·원본 일치 검사 | 규격 통과. 원화 충실도는 별도 |
| 6. 원화 보존 승인 | 원화 + 후보 | 동일 표시 크기 및 부분 확대 비교, 손실·변경 공개 | 사용자 픽셀화 결과 승인. 실패 시 3/4로 복귀 |
| 7. 게임 적합성 | 후보 + 기존 프랍·플레이어·배경 | 프로파일별 실제 배율·접지·조립 확인 | 호환성 확인; 원화 변경이 필요하면 2로 복귀 |
| 8. 선택 반입/엔진 검수 | 승인 파일만 | 프로파일에 맞게 출력·노멀맵·임포트, 실제 줌·빛·가림 검수 | 런타임 승인. 자동 일괄 반입 금지 |

자동 검사는 원화 충실도나 스타일 판단을 대신하지 않는다. 원화에서 승인된 실루엣·색감·재질·세부가 달라지면 규격 통과와 무관하게 실패다. 배경 대비 문제 때문에 프랍을 재색칠하지 않는다. 원화 보존 실패는 크기·색 수를 먼저 재검토하고 임의 생략으로 해결하지 않는다.

프랍의 과거 분석·실패 이력은 [`PROP_STYLE_REVIEW.md`](PROP_STYLE_REVIEW.md)에 있다. 현재 실행 원칙은 이 문서와 ART_GUIDE §0을 따른다. Lua 자동화는 픽셀 입력 수단이지 원화 충실도 보증이 아니다. `.aseprite`를 수정한 뒤에는 생성 스크립트 재실행으로 원본을 덮어쓰지 말고 그 원본에서 내보낸다.

## 작업 시작 전 브리프

최소한 아래 값을 먼저 확정한다.

- 자산 종류와 대상 경로
- 승인 원화 경로·버전·SHA256·크롭 좌표·승인 범위. 원본은 별도로 불변 보존
- 형태/비율·부품 수와 위치·명암·컬러·재질·마모·핵심 디테일의 보존 목록, 불가피한 변경과 승인 여부
- 네이티브 캔버스 크기와 실제 불투명 실루엣의 목표 크기
- 피벗, 바닥선 또는 회전축 좌표
- 원화에서 도출한 팔레트와 자산별 검사 상한. 캐릭터는 배경과 구별하기 위한 8~16색 목표를 유지하고, 배경·프랍에는 일괄 16색 제한을 적용하지 않음
- 현재/대안 해상도에서의 보존 손실, 원본 샘플링 간격 `pixelPitch`, 내용/여백/캔버스 크기, 게임 출력 배율, 카메라 zoom, 최종 선택 근거. 미확정 값은 미확정으로 기록하고 자동 반입하지 않음
- 실제 런타임 기준 파일의 해시·아트 격자와 후보의 시각 목표. 주요 재질의 3단계 명암은 외곽선/접촉 암부/발광색과 따로 지정한다.
- 레이어 이름, 애니메이션 프레임 수·FPS·태그
- 투명 경계 필요 여부와 타일 이음새 검사 방식

자산별 예외가 있으면 `CHARACTER_ART_GUIDE.md`, `TOXIC_TUMOR_CRAWLER_ANATOMY.md`, `SENTRY_TURRET_HEAD_STRUCTURE.md` 같은 전문 문서에 기록한다. 명시된 예외가 없는 값은 `ART_GUIDE.md`가 우선한다.

## 현재 실행 경로 (v1.13)

새 작업은 `ART_GUIDE.md` §0의 원칙 → 위 제작 사이클/브리프 → 아래 자산별 실행 경로 순으로 진행한다. 단위 정의는 ART_GUIDE §0, 현재 선택·승인 상태는 [`ART_ASSET_STATUS.md`](ART_ASSET_STATUS.md)가 단일 출처다. 과거 실패 기록은 실행 기본값이 아니다.

| 적용 범위 | 원본색 정리 설정 | pixelPitch | 실행 진입점 |
|---|---|---|---|
| 승인된 세 프랍 재현 | Tolerance=12 / Snap=20 / Coherent=true / Passes=3 | 1.0 | `build_crisp_prop_trial.ps1` |
| 의료실 선택본 재현 | Tolerance=4 / Snap=20 / Coherent=true / Passes=3 | 2.0 | `build_triage_room_two_x.ps1` |
| 신규 원화 | 보존 브리프와 부분 비교 후 결정 | 자산별 비교·선택 | 범용 입력 실행기는 아직 미구현. 위 전용 스크립트를 임의 원화용 명령으로 안내하지 않음 |

캐릭터 8~16색은 별도의 디자인 목표이며, 위 프랍/방 정리 설정이 이를 구현하거나 보장하지 않는다. 제한 팔레트 캐릭터의 원화·변환 결과는 해당 목표로 따로 검수한다.

### 의료실 2.0의 처리와 재현

1. 승인 원본에서 만든 전체 해상도 준비본 `r2/prepared/`의 원본 참조·레이어·해시를 검사한다. 세 프랍의 설정을 바꾸지 않고 의료실에서만 Tolerance=4를 사용한다.
2. `coarsen_crisp_prop.lua`가 준비본에서 2×2 영역의 대표 원본색을 선택한다. 평균 RGB·블러·추가 대비·디더링은 쓰지 않는다. 3.0/4.0 완성본의 재축소가 아니다.
3. 내용 크기는 `ceil(sourceWidth / pixelPitch) × ceil(sourceHeight / pixelPitch)`. 현재 정수 피치 시험은 네 면 1px 여백을 더한다. 의료실은 836×471 내용, 838×473 캔버스다.
4. 큰 격자에서는 얇은 선과 알파 실루엣도 달라질 수 있다. 전체 해상도 기준의 실루엣 완전 일치 검사를 그대로 적용하거나, 불투명 방의 maskIoU=1을 내부 디테일 보존 증명으로 쓰지 않는다.
5. 원본과 동일 표시 크기 및 같은 좌표의 확대판을 비교하고 Aseprite 재열기/PNG 전 픽셀 일치를 검사한다. 원본 크기 미리보기는 내용만 정수 Nearest 확대 후 원본 범위로 자르며, 이를 네이티브 납품본으로 혼동하지 않는다.

```powershell
# 저장소 루트에서 실행. 기존 출력이 있으면 다른 새 RunName을 지정한다.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_triage_room_two_x.ps1 -RunName two-x-repro
```

이 명령은 기존 `r2/verification.json`, `r2/prepared/`, 원본 및 이전 비교 이미지에 의존한다. [결과 README](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/README.md)의 의존 폴더를 함께 보존한다. 처음부터 임의의 방을 변환하는 범용 명령이 아니다.

### 실행 기본값과 구현 경계

- 재현은 자산별 PowerShell 진입점을 사용한다. `preserve_crisp_prop.lua`를 인수 없이 직접 실행하는 것을 표준 절차로 안내하지 않는다. 현재 Lua 생략 기본값은 Tolerance=12 / Snap=28 / Coherent=false / Passes=0으로, 승인된 실행기의 12 / 20 / true / 3과 다르다. 직접 호출할 때는 입력·출력과 네 설정을 모두 명시한다.
- 도구를 범용화할 때는 입력 원화/해시, 자산 종류, 팔레트 목표, 보존 설정, pixelPitch, 여백, 출력 경로, 비교 영역을 한 실행 명세에서 읽도록 한다. 실제 적용값·도구 버전/해시·출력 해시는 `verification.json`에 저장하고, 게임 반입과 사용자 승인은 자동화하지 않는다.
- 위 범용화와 기본값 일치는 **후속 구현 항목**이다. 이번 문서 정리로 실행 코드·기존 이미지·엔진 프로파일이 변경되었다고 간주하지 않는다.
- 가장 먼저 정할 게임 적용 항목은 목표 월드 크기와 출력 프로파일이다. 방 전체 픽셀화는 개별 프랍/타일 분리 및 실제 조립·조명 검수를 대신하지 않는다.

## 과거 구현 문제와 시험 이력 (v1.11 당시)

다음은 v1.11 문서 개정 당시 확인한 문제다. 이후 원화 직접 입력 시험의 범위와 한계는 바로 아래 ‘직접 입력 시험’에 기록한다. 새 엔진 프로파일과 전체 원화 변환 품질을 검증한 것은 아니다.

1. **재설계 생성기를 보존형 전환기로 오인한 것이 첫 문제다.** `create_prop_geometry_revision.lua`는 승인 원화 입력 없이 고정 도형·좌표·16색 역할 팔레트를 그린다. `build_prop_style_batch2.ps1`은 현미경 55×59, 카트 63×48, 랙 61×88 및 `MaxOpaqueColors 16`을 고정한다. 이는 원화의 부품·색·재질을 옮기는 파이프라인이 아니다. 새 보존 작업에 그대로 사용하지 않는다.
2. **원화 보존 검수 입력이 빠져 있다.** 기존 비교판은 기존 프랍/저밀도본/새 시험본 중심이다. 승인 원화의 대상 영역과 후보의 대응, 색·형태·부품·세부 손실을 비교하는 첫 검수가 필요하다. 출력 해시·반복 부품 검사만으로 대신할 수 없다.
3. **허용 가능한 화소 수는 아직 측정하지 않았다.** 대표 원화 1개를 선정해 전체+세부 보존 목록, 현행/상향 해상도·팔레트 후보, 같은 표시 크기 비교와 게임 크기 비교를 먼저 만든다. 단순 확대나 색 추가만으로 충실도가 해결된다고 가정하지 않는다.
4. **화소 증가와 엔진 크기가 결합되어 있다.** `Tools/upscale_native4.py`의 `SCALE = 4`와 `main.gd`의 `ART_CELL = 4.0`이 현행 연결점이다. 월드 크기를 유지하며 해상도를 높이려면 출력/카메라/기존 자산의 픽셀 크기 혼용까지 확인해야 한다. 이 개정은 상수나 게임 크기를 변경하지 않는다.

범용 내보내기·재열기·알파/크기 검사는 재사용할 수 있다. 기존 생성기의 고정 디자인과 합격 숫자는 재사용하지 않는다. 아래의 과거 실험 명령은 실패 재현용이고 새 프로세스의 실행 명령이 아니다.

### 직접 입력 시험 — 세면대·캐비닛·의자

**아래 2px 평균 축소 시험은 경계 둔화 피드백으로 기본 방식에서 제외했다.** 대비 강화 A/B도 이미 사라진 경계를 되살리지 못했다. 최신 실행은 다음 절을 따른다. 과거 기록과 파일은 비교용으로 보존한다.

사용자가 별도로 지정한 세 PNG로 `preserve_approved_prop.lua`를 실행했다. 고정 도형 생성 대신 원본 RGBA를 읽어 4px/2px 격자 및 64/96색 후보를 만들고 실제 원본과 비교했다. 2px/96색 기반을 선택하되 세면대의 작은 녹색 소품에서 사라진 색을 국소 레이어로 복원했다. 해당 파일은 102색이며 새 공통 상한을 의미하지 않는다. 대표 실제 색 선택 방식의 추가 실험은 잡점 증가로 제외했다.

결과·보존 목록·미세 손실·검사와 재현: [ApprovedPropPixelTrial](../Assets/Generated/ApprovedPropPixelTrial/README.md). 모든 최종 파일은 Aseprite 재열기/PNG RGBA 일치 검사를 통과했고 별도 재생성 PNG도 일치한다. 원본은 변경하지 않았다. 현재 결과는 **사용자 검토용 시안**이며 게임에 반입하지 않았다. 원본의 2px 블록을 네이티브 1px로 옮긴 이번 시험을 현행 ×4 반입에 바로 넣으면 물체 크기가 약 2배가 되는 점에 유의한다.

### 경계 보존 재제작 — 원본 해상도 유지 (v1.12)

**2026-09-20 사용자 승인:** `crisp-final-r1` 세 결과의 원화 보존과 선명도를 긍정 평가하고 이 프로세스의 재사용을 요청했다. 이후 보존형 변환의 기본 경로로 사용한다. 승인 설정은 `Tolerance=12 / Snap=20 / Coherent=true / Passes=3`이며, 신규 원화는 개별 비교 검수를 생략하지 않는다. 게임 반입 승인은 별도다.

실행: `Tools/Aseprite/build_crisp_prop_trial.ps1`, 픽셀 작업: `preserve_crisp_prop.lua`. 기존 축소본이나 대비 강조본을 입력으로 쓰지 않고 `r2/sources/`의 승인 원본에서 다시 시작한다.

1. 원본 SHA256 확인. 승인 원본 1px를 네이티브 1px에 대응하고 네 면에 투명 여백 1px 추가. 크기 유지도 명시적인 해상도 후보이며 자동 게임 반입 규격이 아니다.
2. 공간 평균 없이 원본의 실제 RGB 중에서 색을 선택한다. 고정 96색 상한 대신 원본 픽셀 대비 채널/명도 오차 한도 안에서 팔레트를 구성한다.
3. 이웃 픽셀을 평균 내지 않고 기존 색 라벨 중 하나를 선택해 작은 색 잡점을 정리한다. 강한 원본 경계를 넘는 병합은 제한한다. 이 과정도 질감 손실 가능성이 있으므로 시각 검토가 필수다.
4. 원본 경계 양쪽의 연속된 색을 확인해 중간 전이색을 한쪽 색으로 정리한다. 애매한 픽셀은 그대로 두며, 이미 처리한 결과에서 반복 증폭하지 않는다. 전역 대비 곡선·블러·디더링은 사용하지 않는다.
5. `source_reference`(숨김 원본), `native_color_clusters`, `edge_side_cleanup`를 저장한다. 숨겨진 원본은 원래의 반투명 값을 보존하며 **보이는 최종 출력**만 이진 알파다. 경계 정리 레이어를 끄면 색 군집 단계와 비교할 수 있다.
6. Aseprite 재열기 후 레이어/참조/크기 검사, 출력 RGBA 전 픽셀 일치, 원본 알파 128 기준 실루엣 일치, 모든 출력색의 원본 내 존재 여부를 검사한다. 동일 좌표의 강한 내부 경계 대비를 이전본과 비교한다.
7. 같은 표시 크기의 전체 비교와 세면대·손잡이·해진 천 확대를 직접 보고 잡점/선 두께/명암 손실을 검토한다. 결과 사용자 승인 전에는 staging에만 둔다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_crisp_prop_trial.ps1 -RunName crisp-review-new
```

출력 폴더가 있으면 중단한다. 현재 기본값은 색 오차 한도 12, 경계 명도 이동 한도 20, 색 라벨 정리 3회이며 **이 세 원본에 대한 선택값**이지 범용 품질 보장이 아니다. 실제 출력색은 원본에서만 선택한다. 최신 [결과·한계·검증 기록](../Assets/Generated/ApprovedPropPixelTrial/crisp-final-r1/README.md)을 함께 읽는다. 이 결과를 현행 ×4 반입기에 넣으면 원본 대비 물체 크기가 약 4배이므로 그대로 반입하지 않는다.

## 로컬 설치

- 기준 버전: Aseprite v1.3.18.5 소스 빌드
- 기본 실행 파일: `%LOCALAPPDATA%\Programs\Aseprite\current\Aseprite.exe`
- 대체 지정: 사용자 환경 변수 `ASEPRITE_EXE`
- 라이선스 주의: 로컬에서 컴파일한 Aseprite 실행 파일은 저장소나 빌드 산출물에 포함해 제3자에게 재배포하지 않는다.

`Tools/Aseprite/Aseprite.Common.ps1`은 환경 변수, 로컬 설치, 소스 빌드, Program Files, Steam 순서로 실행 파일을 찾는다.

## 빠른 검증

저장소 루트의 PowerShell에서 실행한다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File Tools/Aseprite/run_pipeline_probe.ps1
```

생성 결과:

- `Assets/Generated/AsepritePipeline/native32_pipeline_probe.aseprite`
- `Assets/Generated/AsepritePipeline/native32_pipeline_probe_sheet.png`
- `Assets/Generated/AsepritePipeline/native32_pipeline_probe_sheet.json`

프로브는 32×32 네이티브 프레임 4장, 레이어 2개, `pulse` 태그를 만든다. 내보낸 128×32 시트는 다음 조건을 자동 검사한다.

- 정확한 폭과 높이
- 불투명 색상 8개 이하
- 알파값 0 또는 255만 사용
- 캔버스 경계에 불투명 픽셀이 없음

## 일반 스프라이트시트 내보내기

```powershell
powershell.exe -ExecutionPolicy Bypass -File Tools/Aseprite/export_sprite.ps1 `
  -Source Assets/GameReady/Native4/example.aseprite `
  -Sheet Assets/GameReady/Native4/example_sheet.png `
  -Data Assets/GameReady/Native4/example_sheet.json `
  -SheetType horizontal
```

특정 애니메이션 태그만 내보내려면 `-Tag walk`처럼 지정한다.

권장 저장 구조는 다음과 같다.

```text
Assets/GameReady/Native4/<runtime 상대경로>/
  asset.aseprite       # 제작 원본
  asset.png            # 단일 프레임 또는 런타임 입력
  asset_sheet.png      # 애니메이션 시트
  asset_sheet.json     # 프레임·태그 메타데이터
```

## PNG 규격 검사

```powershell
powershell.exe -ExecutionPolicy Bypass -File Tools/Aseprite/verify_native_pixel_art.ps1 `
  -Path Assets/GameReady/Native4/example.png `
  -ExpectedWidth 80 `
  -ExpectedHeight 80 `
  -MaxOpaqueColors 16 `
  -RequireBinaryAlpha `
  -RequireTransparentBorder
```

`-RequireTransparentBorder`는 캐릭터·프랍처럼 잘림 방지가 필요한 리소스에 사용한다. 서로 맞닿아야 하는 타일에는 사용하지 않는다.

위 `MaxOpaqueColors 16`은 16색을 선택한 자산의 **예시**다. 새 보존 작업에는 합의된 자산별 상한을 명시한다. 기존 배치 생성기의 하드코딩 값은 아직 수정되지 않았으므로 그대로 실행하면 새 정책과 맞지 않는다.

## 제작 규칙

1. 손실 검토로 합의한 네이티브 캔버스에서 승인 원화를 참조/추적해 작업한다. 불변 원화와 최종 출력 레이어를 구분하고, 원화 참조 이미지가 게임 출력에 섞이지 않도록 한다.
2. 안티앨리어싱과 반투명 픽셀을 사용하지 않는다.
3. 원화의 색·명암·재질을 보존하는 자산별 팔레트를 사용한다. 캐릭터는 배경과의 차별화를 위한 8~16색 목표를 유지한다. 배경·프랍에는 일괄 상한을 두지 않는다. 충돌 시 원화/팔레트 검토로 돌아간다.
4. 애니메이션 프레임은 같은 캔버스와 Bottom Center 접촉 기준을 유지한다.
5. `.aseprite` 원본에는 레이어, 프레임, 태그를 보존하고 PNG/JSON은 CLI로 재생성한다.
6. 현행 4px 호환 자산만 `Tools/upscale_native4.py`로 4배 출력한다. 다른 프로파일 후보는 이 도구에 넣지 않고, 합의·구현 검증 전까지 staging에 둔다.

## 형태 잠금과 회귀 검사

승인 원화에서 축·두께·원근·부품 연결을 추적 → 원화와 구조 사본 비교 → 재질·기능·마감 보존 순서로 진행한다. 임의로 더 반듯한 모양을 만드는 단계가 아니다. 원화와 다른 실루엣을 먼저 고정한 뒤 그 마스크 안에 있다는 이유로 합격시키지 않는다. 원화 보존을 위해 구조를 수정하면 직접 비교부터 다시 한다.

### 과거 실험 재현 전용 — 원화 보존 방식으로 채택되지 않음

다음 명령은 batch2 r4의 구조 실험을 재현한다. 사용자가 톤 불일치를 지적한 실패 기록이며 신규 보존형 전환의 기본 실행 예가 아니다.

```powershell
& Tools/Aseprite/build_prop_style_batch2.ps1 -Revision 4
# r4가 이미 있으면 새 경로로 재현한다. 기존 원본은 덮어쓰지 않는다.
& Tools/Aseprite/build_prop_style_batch2.ps1 -Revision 4 -RunName r4-repro
& Tools/Aseprite/test_prop_geometry_pipeline.ps1
```

`r4`는 네이티브 크기를 유지한 현미경/카트/랙의 구조 재설계다. `*-structure.aseprite`는 디테일 이전 구조 사본이며 최종 원본은 접미사가 없는 `.aseprite`다. `verify_prop_geometry.lua`는 최종 Aseprite를 실제 합성해 지정된 직선, 선반·기둥·바퀴/팬의 반복 정렬과 광학 공간을 검사한다. 의도적으로 깨뜨린 픽셀이 거부되는지도 검사한다. `test_prop_geometry_pipeline.ps1`은 r4/r4-repro 픽셀 및 원본 일치를 검증한다. 모두 **이 세 프랍에 한정한 회귀 검사**이며 보편적 자동 미술 심사가 아니다.

## 게임 반입과 승인

규격 검사와 반입 전 스타일·조립 검토를 통과하고 **Native4 월드 크기와 호환성이 확인된 선택 파일만** Native4에 승격한다. 다른 프로파일 후보와 원화 크기 기준 시안은 staging에 두고 출력 프로파일 합의·구현·검증을 먼저 한다. 의료실 pixelPitch=2.0 선택은 Native4 반입 승인이 아니다. 다음은 전체 반입 도구이므로 다른 작업의 미승인 Native4 파일이 섞여 있으면 실행하지 않는다. 선택 범위를 확인하거나 별도 격리 환경을 사용한다.

```powershell
python Tools/upscale_native4.py
python Tools/build_normal_maps.py
GodotPrototype\run.bat
```

최종 승인 순서는 `ART_GUIDE.md` §11과 같다.

1. 승인 원화와 후보의 전체/부분 비교로 형태·색·재질·부품·세부 보존 및 불가피한 변경 승인을 먼저 확인한다. 이어 네이티브 1×에서 군집, 외곽선, 이진 알파와 원본 재출력을 본다.
2. 동일 art px 배율의 기존/이전/후보를 화면 ×2·×3·×6 및 흑백으로 비교한다. ×4 월드 출력만 보고 통과시키지 않는다.
3. 타일·프레임·프랍이 함께 있는 조립 장면에서 반복과 위계를 보고, 플레이어를 같은 화면에 둔다.
4. 실제 엔진에서 줌·조명·가림·접지·상호작용을 확인한다. 오프라인 합성은 이 검사를 대신하지 않는다.

한 단계라도 실패하면 `.png`를 직접 덧칠해 임시 수정하지 말고 `.aseprite` 제작 원본을 고친 뒤 내보내기부터 다시 실행한다. 그래야 원본과 런타임 결과가 갈라지지 않는다.

## 프랍 스타일 시험실 — 과거 실험 재현 예 (신규 전환용 아님)

저장소 루트의 PowerShell에서 실행한다. 시험 도구는 Aseprite와 Windows의 System.Drawing만 사용한다. 이미지 생성 API·고해상도 축소·런타임 교체를 하지 않는다.

```powershell
& Tools/Aseprite/prepare_prop_style_review.ps1
& Tools/Aseprite/build_prop_style_studies.ps1 -Revision 3
& Tools/Aseprite/review_prop_style_studies.ps1 -Revision 3
& Tools/Aseprite/verify_prop_style_studies.ps1 -Revision 3
```

- 이미 `r3/`가 있으면 생성은 중단한다. 원본 덮어쓰기 없이 재현성을 검사할 때는 `-RunName r3-repro`처럼 새 이름을 사용한다. 검수 도구의 기본 입력은 `r3/`다.
- `prepare`는 현재 런타임 기준을 읽어 비교용 사본과 provenance를 만든다. 과거 검토의 기준을 바꾸지 않도록, 재실행 시 기존 provenance의 SHA와 런타임이 같은지 먼저 검사한다.
- `review`는 동일 픽셀 배율의 비교 PNG·흑백·배경/플레이어 접지 시트와 진단 CSV를 만든다. 접지 시트는 오프라인 부분 장면이며 엔진 스크린샷이 아니다.
- `verify`는 원본의 크기·편집 레이어·프레임을 열어 확인하고, 새 PNG를 다시 내보내 기존 PNG와 모든 픽셀을 비교한다. 규격 결과와 원본/PNG 해시를 `verification.json`에 남긴다. 아트 승인 상태는 자동 판정하지 않는다.
- 이전 `build_research_facility_props.ps1`의 15종 단순 도형 생성기는 **불합격 블록아웃 재현용**으로 격리했다. 기본 실행은 실패하며, `-GenerateLegacyBlockouts`를 명시해도 Generated 아래 새 폴더에만 출력한다. Native4·런타임·타일은 수정하지 않는다.
