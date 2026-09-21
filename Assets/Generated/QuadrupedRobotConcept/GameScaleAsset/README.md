# Quadruped 78 게임 스케일 에셋 후보

사용자가 선택한 배경 비교 장면의 최종 크기(절반 축소본에서 15% 확대)를 기준으로 만든 정지 프레임 후보다.

## 파일

- `quadruped_78_source_cutout.png`: 내장 이미지 생성 도구로 배경을 제거한 보존용 소스. 반투명 픽셀이 있으므로 런타임에 직접 사용하지 않는다.
- `quadruped_78_idle_native.png`: 72×52 네이티브 캔버스. 실제 불투명 실루엣은 69×47이고 알파는 0/255만 사용한다.
- `quadruped_78_idle_4x.png`: 288×208 월드 크기. 네이티브 이미지를 픽셀당 정확히 4×4로 복제했다.
- `quadruped_78_idle.json`: 크기, 피벗, 해시, 검사 결과와 미완료 통합 상태.

## 피벗과 방향

- 네이티브 피벗: 하단 중앙 `(36, 52)`
- 4배 피벗: 하단 중앙 `(144, 208)`
- 기본 방향: 왼쪽

## 검증

- 네이티브와 4배 PNG의 알파 값은 `0`, `255`뿐이다.
- 4배 PNG와 네이티브 PNG의 4×4 블록 비교 불일치: `0` 픽셀.
- 선택 장면에서 보인 로봇 실루엣 목표인 약 276×188 월드 px를 유지한다.

## 현재 경계

이 폴더는 검수용 에셋 후보이며 `Assets/GameReady/Native4/`로 승격하지 않았다. 작은 네이티브 크기에서 `78` 표기와 일부 얇은 기계 디테일의 가독성 손실이 있으므로 Aseprite 국소 정리, 애니메이션 프레임, 충돌체, 런타임 화면 검수는 별도 작업이다.

재현 명령:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_quadruped78_asset.ps1 `
  -Source <transparent-cutout-source> `
  -OutDir <new-empty-output-directory>
```
