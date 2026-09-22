# 사족보행 튜닝 — 남은 작업 인계 (완료)

2026-09-22. 인계 문서의 1·2·3 항목을 모두 실행했고 **남은 작업은 없다.** 아래는 실행 결과 기록이다.

## 1. 마지막 접지 보정 이후 전체 조정 범위 검증 — 통과

```powershell
& $godotExe --headless --path GodotPrototype --script res://tools/validate_walker_gait_settings.gd -- extremes
```

- 결과: **`WALKER GAIT SETTINGS: 304197 checks; PASS`** (기본값 + 18개 매개변수 최솟값/최댓값, 37개 경우 전체).
- 모든 경우에서 미도달 프레임 0, 접점 오차 최대 약 0.000068px, 공간 뼈 길이 오차 최대 약 0.000092px, 정지 시 지지 4발.
- 지지 발 수 최소는 대각 보행 2발, 순차 보행(`legs_up` 1) 3발로 유지됐다. NaN 없음.

## 2. 인게임/테스트씬 연동 회귀 — 통과

```powershell
& $godotExe --headless --path GodotPrototype --script res://tools/validate_walker_tuning_runtime.gd
& $godotExe --headless --path GodotPrototype --script res://tools/validate_walker_tuning_lab.gd
```

- runtime: **`30933 checks`**, 인게임 Unit과 미리보기 Proc의 포즈 차이 0.000000px, 고정 길이 오차 최대 0.000214px, 실패 0.
- UI: **`161 checks; 0 failures; protected files unchanged=true`**.

## 3. 넓은 발 벌림·긴 스텝 외형 확인 — 통과

- 기본 캡처 6장을 최신 코드로 다시 생성했고, 이번 보정의 관심 구간을 보기 위해 넓은 발 벌림 캡처 6장을 추가했다.
- 추가 캡처는 `capture_walker_tuning.gd`의 선택 모드다. 인자 없이 실행하면 기존 6장 그대로다.

```powershell
& $godotExe --path GodotPrototype --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script res://tools/capture_walker_tuning.gd
& $godotExe --path GodotPrototype --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script res://tools/capture_walker_tuning.gd -- wide_stride
```

- 적용 값: 발 벌림 1.35(최대), 걷기 스텝 시간 0.40(최대), 달리기 스텝 시간 0.32(최대), 착지 위치 선행 0.35(최대).
- `GodotPrototype/tools/artifacts/walker_tuning/`의 `11_`~`16_` 6장. 정지·걷기·뼈 겹쳐보기·달리기(2240)에서 발이 바닥에 닿고 지지 발 수가 유지되며, 발이 순간이동하거나 미끄러지는 모습은 보이지 않는다.
- 두 실행 모두 `protected unchanged=true`, 데모 문서 생성 없음.

## 사용자 안내

**로비 → 사족보행 랩 — 인게임 보행 튜닝**. 슬라이더/숫자로 조절하고 **Ctrl+S 저장 후 게임에 다시 진입**하면 적용된다.
기존 원화 편집기는 상단 **피벗 · 키프레임**, 복귀는 **보행 튜닝**이다. 자세한 사용법은 `Docs/WALKER_TUNING.md`.

## 보존 상태 확인

- `GodotPrototype/authoring/walker_gait.json`은 여전히 **없다.** 검증은 격리된 경로만 사용했다.
- SHA256 재확인 (인계 시점과 동일):
  - `GodotPrototype/authoring/walker_motion.json`: `3D3CF01DEFAE5ACBAE304DA75842A4F786821E429401157E8415458637EAD927`
  - `GodotPrototype/assets/reference/walker_original.png`: `198CAF260A0F20DD7BEE454172FDBDD9BE42F549548AA0657C8AC0304FAEBCC8`
- 커밋/배포는 하지 않았다.
