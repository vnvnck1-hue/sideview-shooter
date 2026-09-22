# 4족보행 기체: 탄성 동작과 독립 조준

기존 리그 비교씬 `GodotPrototype/scenes/WalkerLegacyLab.tscn`과 인게임 `WalkerUnit`은 같은 `ProcWalker` 및 `WalkerRig`를 사용한다. 인게임 기체는 기존 거미 걸음과 0.5배 크기를 유지하면서 아래 개선을 함께 받는다. 로비의 `WalkerLab.tscn`은 이후 요청한 [원화 기준 본 구조 검토씬](WALKER_BONE_PROTOTYPE.md)으로 변경했다.

이후 관절 구조 교정으로 인게임의 다리 계산은 [거미형 공간 보행](WALKER_SPIDER_GAIT.md)으로 바뀌었다. 저장한 다리 피벗과 공통 `SpiderLegIK`를 사용하며, 기존 비교씬의 다른 프리셋은 이전 계산을 유지한다. 아래의 상체 탄성·독립 조준·사격 연결은 그대로 사용한다.

- 발을 딛는 충격, 가속·제동의 무게 이동, 몸통 높이·기울기를 감쇠 스프링으로 연결한다. 정지하면 마지막 발을 정리하고 작은 호흡 동작으로 안정된다.
- 발은 빠르게 떼고 긴 호를 따라 부드럽게 내려놓는다. 착지한 발은 지면에 고정한다.
- 점프 직전 짧게 압축하고, 상승 중 다리를 접었다가 하강 중 펼친다. 착지 충격은 몸통이 눌렸다 복원되며 흡수한다.
- 상체만 조준 쪽으로 선회한다. 조준 중에는 하체 방향을 유지하므로 전진·후진·방향 전환과 사격 방향을 독립적으로 조작할 수 있다.
- 포신은 위·아래·뒤쪽까지 360° 조준한다. 총열과 탄도가 같은 월드 각도를 사용하고, 발사 위치는 최종 자세와 반동을 반영한 총구에서 나온다.
- 사격은 로봇 위치를 순간적으로 밀지 않고 서스펜션에 충격을 전달한다. 독립된 하체 연결부가 선회하는 상체와 네 고관절을 연결한다.

## 조작

| 입력 | 테스트씬 / 인게임 기체 |
|---|---|
| A/D 또는 ←/→ | 전진·후진; 마우스 조준과 독립 |
| 마우스 | 상체 선회 및 360° 조준 |
| 좌클릭 | 연사 |
| Shift | 달리기 |
| Space | 준비동작 후 점프 |
| W/↑, S/Ctrl/↓ | 인게임에서 기동·탑승, 하차 |
| 1~6, F2, F4 | 랩에서 걸음새, 접지 디버그, 리그/그레이박스 비교 |

## 구현 경계

`proc_walker.gd`의 `yaw`/`facing`/`project()`는 하체와 IK에 사용한다. `torso_yaw`/`body_project()`는 상체 그림과 포가에 사용한다. `presentation_scale()`은 상체에만 작은 압축·신장을 더하며 발 위치에는 적용하지 않는다. `WalkerRig`와 `muzzle()`은 같은 변환을 공유한다.

`WalkerUnit`의 입력, 부모 공간 변환, 과열, 방 경계, 조종/원격조종과 `Main`의 공용 사격 경로는 그대로 사용한다. 별도 랩 전용 애니메이션을 복제하지 않는다.

## 검증과 미리보기

Godot 실행 파일로 프로젝트 루트에서 다음을 실행한다.

```text
godot --headless --path GodotPrototype --script res://tools/validate_walker_expression.gd
godot --headless --path GodotPrototype --script res://tools/validate_walker_unit.gd
godot --headless --path GodotPrototype --script res://tools/validate_walker.gd -- preset=6
```

`validate_walker_expression.gd`는 30/60/120Hz에서 조준 8방향, 각도 경계 통과, 정지 접지, 반대 방향 이동·사격, 이동 반전, 점프·착지, 실제 인게임 입력/사격/하차를 검사한다. 실제 포신 스프라이트의 총구와 탄 출발점도 비교한다. 기존 보행 검증은 `preset=1`부터 `6`까지 실행할 수 있다.

```text
godot --path GodotPrototype --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script res://tools/capture_walker_expression.gd -- frames
```

렌더 캡처는 숨겨진 창의 SubViewport에서 실제 랩을 구동한다. 스틸 8장과 선택적 15fps 프레임은 `GodotPrototype/tools/artifacts/walker_expression/`에 저장된다. `--headless`로는 이미지를 생성할 수 없다.
