# Research Facility V2 source sheets

These three source sheets were regenerated from the clean research-facility concept while using the established workshop assets as the pixel-density and material-rendering reference.

- `research_analysis_props_sheet_v2.png`
- `research_isolation_props_sheet_v2.png`
- `research_diagnostics_props_sheet_v2.png`
- `research_wall_macro_reference_v2.png` (tile direction reference; not loaded by the game)

## 현재 지위 — 승인된 외관 보존 기준 (ART_GUIDE v1.11)

사용자는 위 3개의 props 시트가 원하는 퀄리티와 밀도라고 명시했다. 이 원화들은 **형태·비율·부품 배치·컬러·명암·재질·디테일을 최대한 보존할 직접 기준**이며, 단순한 형태 참고가 아니다. 벽 참고 이미지는 이번 프랍 승인 범위에 포함하지 않는다.

Aseprite 작업은 재디자인이 아니라 보존형 픽셀 전환이다. 원본을 변경하지 않고 대상 영역과 SHA256을 기록한 뒤, 대표 프랍 하나로 해상도·팔레트에 따른 손실을 확인한다. 리샘플링/색 양자화는 초안용으로 허용하지만 자동 결과나 `.aseprite` 저장만으로 완료를 선언하지 않는다. 경계·군집을 통제하고 승인 원화와 직접 비교한다.

원화 보존에 비해 기존 화소 수가 부족하면 규격부터 재검토한다. 16색이나 과거 고정 캔버스에 억지로 맞추지 않는다. 현재 ×4 엔진 프로파일은 그대로이며 대체 해상도·출력 방식은 아직 미확정이다.

`Assets/GameReady/Native4/Props/research_*`의 이전 원본과 `PropStyleLab` 시험본은 이 원화의 성공적인 변환 결과가 아니다. `Tools/Aseprite/build_research_facility_props.ps1`은 불합격 블록아웃 재현용으로 격리되어 있고 기본 실행이 차단된다. batch2의 고정 좌표 생성기도 새 보존형 변환기로 사용하지 않는다.

현재 원칙: [ART_GUIDE](../../../Docs/ART_GUIDE.md) §0·§11. 실행 목표와 미구현 과제: [ASEPRITE_PIPELINE](../../../Docs/ASEPRITE_PIPELINE.md).

The source sheets and macro-wall reference are not loaded directly by the game.
