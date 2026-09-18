# Sideview Pixel Art Resource Pack

이번 사이드뷰 픽셀 아트 작업에서 제작한 기준 이미지, 디오라마, 프랍, 배경 타일, 연결 문과 검증 자료를 한곳에 모은 전달용 리소스 팩이다.

원래 제작 경로의 파일은 보존되어 있으며, 이 폴더에는 현재 결과물을 용도별로 복사해 정리했다.

## 폴더 구성

- `00_Reference/`: 프랍 투영과 구도의 최종 기준 이미지
- `01_Docs/`: 누적 아트가이드와 게임 배치 규격
- `02_Dioramas/`: 작업실 변형, 다른 테마 방, 빈 연결 복도 이미지
- `03_Background_Source/`: 프랍을 제거한 작업실 배경 원본
- `04_Props/Initial/`: 최초 생성한 가구 3종과 캐릭터
- `04_Props/Canonical/`: 기준 이미지 투영을 반영한 캐비넷·소파와 교정된 책상
- `04_Props/GameReady/`: 공통 장면 스케일과 투명 배경으로 가공한 실제 배치용 프랍
- `04_Props/Hydroponics/`: 수경재배실의 투명 프랍 6종
- `04_Props/CrewQuarters/`: 승무원 숙소의 투명 프랍 6종
- `04_Props/RoomPropSheets/`: 두 방의 생성 원본 및 알파 변환 프랍 시트
- `04_Characters/HoodedMechanic/`: 아이들·걷기·사격·숙이기 시트, 개별 프레임과 메타데이터
- `04_Characters/Source/`: 캐릭터 애니메이션 생성 원본 시트
- `05_Tiles/Workshop/`: 긴 작업실을 조립하는 세로 매크로 배경 타일
- `05_Tiles/Workshop_Modular/`: X/Y 확장용 128px 배경 셀 + 투명 외곽 프레임 타일
- `05_Tiles/Corridor_Modular/`: 복도용 X/Y 확장 배경 셀 + 프레임 + 오목 코너
- `05_Tiles/Hydroponics_Modular/`: 수경재배실용 X/Y 확장 배경 셀 + 프레임 + 오목 코너
- `05_Tiles/CrewQuarters_Modular/`: 숙소용 X/Y 확장 배경 셀 + 프레임 + 오목 코너
- `05_Tiles/Corridor/`: 빈 연결 복도 타일
- `05_Tiles/Hydroponics/`: 수경재배실 빈 배경 타일
- `05_Tiles/CrewQuarters/`: 승무원 숙소 빈 배경 타일
- `06_Connectors/Source/`: 정면문·측벽문의 생성 원본
- `06_Connectors/GameReady/`: 장면 스케일로 가공한 실제 배치용 문
- `07_Validation/`: 배경 타일 조립본, 프랍 배치 검증본과 좌표 JSON
- `08_Tools/`: 작업실 타일·프랍·문을 다시 가공하는 빌드 스크립트

## 게임에 우선 사용할 폴더

실제 게임 배치에는 아래 세 폴더를 우선 사용한다.

1. 배경: `05_Tiles/Workshop/`
2. 가구와 캐릭터: `04_Props/GameReady/`
3. 정면문과 측벽문: `06_Connectors/GameReady/`
4. 캐릭터 애니메이션: `04_Characters/HoodedMechanic/`

추가 방을 구성할 때는 `05_Tiles/<Theme>/`의 배경 타일과 `04_Props/<Theme>/`의 투명 프랍을 조합한다. 복도는 의도적으로 별도 프랍 없이 비워 둔다.

조립 결과와 정확한 배치 좌표는 `07_Validation/workshop_long_room_tile_prop_validation.png` 및 같은 이름의 JSON에서 확인한다.

타일 조립, 바닥선, 캐릭터 시트 슬라이싱, 애니메이션 상태 구성과 Unity 임포트 절차는 `01_Docs/RESOURCE_USAGE_GUIDE.md`를 따른다.

## 현재 타일 규격

- 세로 매크로 타일 높이: 560 px
- 중앙 벽 타일 너비: 256 px
- 좌우 마감 캡 너비: 160 px
- 검증 장면 바닥선: Y = 670 px
- 이미지 스케일링: Point / Nearest
- 프랍과 연결 문: 투명 PNG

## Workshop Modular Tile Set v2

기존 세로 매크로 타일과 별개로, 작업실을 가로·세로 모두 확장할 수 있는 두 레이어 리소스를 추가했다.

- `05_Tiles/Workshop_Modular/Background/`: 128×128 불투명 내부 배경 셀 6종
- `05_Tiles/Workshop_Modular/Frame/`: 128×128 투명 외곽 프레임 8종
- `05_Tiles/Workshop_Modular/Frame/InnerCorners/`: 128×128 투명 오목 코너 4종
- `05_Tiles/Workshop_Modular/workshop_modular_frame_inner_corners_sheet_4x1.png`: 오목 코너 시트
- 검증본: `07_Validation/workshop_modular_12x6_preview.png`
- 오목 코너 검증본: `07_Validation/workshop_modular_inner_corners_preview.png`
- 조립 메타데이터: `05_Tiles/Workshop_Modular/workshop_modular_tiles_v2.json`
- 룰타일 패턴: `05_Tiles/Workshop_Modular/workshop_modular_ruletile_rules_v2.json`

배경을 원하는 셀 수만큼 먼저 채우고, 네 모서리와 반복 가능한 상·하·좌·우 프레임을 한 셀 외곽에 오버레이한다. 램프·환기구·문·프랍은 반복 타일에서 분리해 별도 장식 레이어로 유지한다.

네 테마 전체 리소스 재생성 스크립트는 `08_Tools/build_all_modular_room_tiles.ps1`다.

## 프랍 투영 기준

`00_Reference/canonical_workshop_reference.png`의 캐비넷과 소파를 기준으로 한다. 완전한 정면 정사영이 아니라 윗면과 한쪽 측면이 소량 보이는 매우 약한 원근을 사용한다. 책상은 이 기준에 맞게 교정돼 있다.

`04_Props/Canonical/workshop_workbench_corrected_projection_rgb_v2.png`는 배경 제거 전 편집 원본이고, 실제 사용 시에는 투명 배경 버전 또는 `GameReady` 버전을 사용한다.
