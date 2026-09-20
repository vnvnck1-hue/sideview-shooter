# 연구시설 3종 배경 리소스

기존 방의 128×128 월드 px 모듈 타일, 배경·프레임 2개 레이어, 독립 프랍 구조를 따른다. 그림은 32×32 네이티브 아트 px 셀로 제작했고, Godot 런타임에는 Nearest 4배 확대본과 노멀맵을 배치했다. 알파는 0/255만 사용한다.

| 방 테마 ID | 콘셉트 | 강조색 | 프랍 5종 |
|---|---|---|---|
| `research_analysis` | 검체 분석실 | 민트 | 검체 챔버, 분석 작업대, 현미경 스테이션, 저온 보관고, 검체 카트 |
| `research_isolation` | 멸균·격리실 | 시안 | 제염 아치, 격리 포드, 세척대, 의료 캐비닛, UV 멸균기 |
| `research_diagnostics` | 진단 관제실 | 청색 | 진단 콘솔, 서버 랙, 벽 디스플레이, 신호 계측기, 드론 도크 |

## 경로

- 네이티브 원본: `Assets/GameReady/Native4/tiles/<테마>_modular/`, `Assets/GameReady/Native4/props/<테마>/`
- 4배 게임 규격: `Assets/GameReady/Tiles/<테마>_Modular/`, `Assets/GameReady/Props/<테마>/`
- 런타임: `GodotPrototype/assets/tiles/<테마>_modular/`, `GodotPrototype/assets/props/<테마>/`
- 런타임 노멀맵: `GodotPrototype/assets/normals/tiles/<테마>_modular/`, `GodotPrototype/assets/normals/props/<테마>/`
- 배치 검토: `Assets/GameReady/Validation/<테마>_room_preview.png`
- 기계가 읽는 파일 목록과 프랍 크기: `Assets/GameReady/research_facility_manifest.json`
- 방향 시안: `Assets/Generated/Environments/research_facility_three_rooms_concept.png`

## 조립

각 테마는 불투명 배경 채움 6종, 투명 외곽 프레임 8종, 오목 코너 4종을 제공한다. 배경을 X/Y로 채우고, 그 위에 프레임을 한 셀 외곽 링으로 올린다. Godot의 `RoomTheme`는 3×2 배경 시트, 3×3 프레임 시트, 4×1 벤드 시트를 바로 읽는다. 프랍은 바닥 중앙 피벗으로 놓는다. `wall_display`만 벽 부착물이라 바닥 그림자 없이 `cy` 또는 `fy` 위치를 지정한다. 기존 방의 공통 문 소켓과 바닥 높이를 사용하고, 반복 타일에는 문이나 프랍을 굽지 않았다.

현재 세 테마는 `RoomTheme`에 등록되어 있으며, 기존 맵 방을 자동 교체하지 않는다. 새 방을 `RoomData`에 추가하거나 원하는 방의 `theme` 키로 선택하면 된다. 프랍 `tex`에는 `res://assets/props/<테마>/<테마>_<프랍명>.png` 전체 경로를 넣는다.

재생성: 번들 Python으로 `Tools/build_research_facility_assets.py`를 실행한다. 이 스크립트는 위 세 테마 경로만 갱신한다.
