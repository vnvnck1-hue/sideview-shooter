# Workshop Modular Tile Set v2

첨부 시안의 구분 방식에 맞춰 작업실 방을 두 레이어로 분리한 타일 리소스다.

## 규격

- 논리 셀: 128 × 128 px
- 좌표계: 좌상단 원점, +X 오른쪽, +Y 아래쪽
- `Background/`: 방 내부를 X/Y 어느 방향으로든 반복하는 불투명 배경 타일 6종
- `Frame/`: 외곽 벽 라인용 투명 오버레이 8종
- `Frame/InnerCorners/`: 안쪽으로 꺾이는 오목 코너 4종
- 시트: `workshop_modular_background_sheet_3x2.png`, `workshop_modular_frame_sheet_4x2.png`
- 안쪽 코너 시트: `workshop_modular_frame_inner_corners_sheet_4x1.png`
- 검증본: `Assets/GameReady/Validation/workshop_modular_12x6_preview.png`
- 룰 패턴: `workshop_modular_ruletile_rules_v2.json`

## 조립 규칙

1. 방의 전체 바닥/천장 포함 영역을 `Background` 타일로 먼저 채운다.
2. 방 안쪽을 원하는 가로·세로 셀 수만큼 늘린다.
3. 한 셀짜리 외곽 링에 `Frame` 타일을 오버레이한다.
4. 네 모서리는 한 번씩 배치하고, `top`/`bottom`은 X축으로, `left`/`right`는 Y축으로 반복한다.
5. 램프·환기구·문·프랍은 이 세트에 포함하지 않고 별도 레이어로 배치한다.

### 프레임 배치

```text
top_left  top  top  ... top  top_right
left      BG   BG   ... BG   right
left      BG   BG   ... BG   right
...       ...  ...  ... ...  ...
bottom_left bottom ... bottom bottom_right
```

`Frame` PNG는 중앙이 투명하므로, 배경을 먼저 깔아야 외곽 라인 안쪽이 자연스럽게 이어진다. Godot에서는 각 PNG를 `Sprite2D.centered = false`로 두고 셀 위치에 정수 좌표로 배치하면 된다.

`InnerCorners`는 파일명 기준으로 열린 사분면을 나타낸다. 예를 들어 `inner_top_left`는 위·왼쪽이 비고 아래·오른쪽 프레임 밴드가 보이는 오목 코너다. 각 코너의 3×3 이웃 패턴은 `workshop_modular_ruletile_rules_v2.json`에 기록했다.

재생성 명령:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Tools\build_workshop_modular_tiles.ps1
```

상세 파일 목록과 미리보기 셀 수는 `workshop_modular_tiles_v2.json`을 참고한다.
