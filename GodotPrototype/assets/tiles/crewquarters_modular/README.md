# Crew Quarters Modular Tile Set v2

기존 CrewQuarters 매크로 타일을 128×128 셀 기반 확장형 리소스로 분리했다.

- `Background/`: X/Y 방향으로 반복하는 내부 배경 셀 6종
- `Frame/`: 외곽 벽 라인 오버레이 8종
- `Frame/InnerCorners/`: 안쪽으로 꺾이는 오목 코너 4종
- `crewquarters_modular_tiles_v2.json`: 규격과 배치 정보
- `crewquarters_modular_ruletile_rules_v2.json`: 오목 코너 3×3 연결 패턴

배경을 먼저 원하는 셀 수만큼 채우고, 프레임의 모서리·변을 한 셀 외곽에 오버레이한다. 환기구·램프·프랍은 반복 타일에 넣지 않고 별도 레이어로 유지한다.

재생성:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Tools\build_workshop_modular_tiles.ps1 -Theme CrewQuarters
```
