# Power Relay Room — Game-ready art pack

지하 전력 릴레이·축전실을 위한 새 룸 테마다. `Docs/ART_GUIDE.md` §10 방식 B를 기준으로 제작했으며, 기존 Workshop Modular의 확장형 방 조립 규칙을 그대로 사용한다.

## 폴더

- `Tiles/Background/`: 16×16 art px 네이티브 배경 6종과 128×128 game-scale 출력
- `Tiles/Frame/`: 기존 모듈형 외곽 프레임 문법을 이 테마에 포함한 8종과 InnerCorners 4종
- `Props/`: 바닥 프랍 6종. 캐비닛, 축전기 뱅크, 차단기 박스, 정비 카트, 작업 램프, 배관 접속부
- `Lighting/`: 실제 조명 기구 6종. 광원 콘/반응은 코드 레이어에서 별도 처리
- `Cables/`: 양 끝 고정점이 읽히는 물리 전선 6종
- `Destruction/`: 릴레이 캐비닛 조립 상태 1종 + 분리 가능한 파츠 13종
- `Validation/`: 14×8 셀 조립 미리보기

네이티브 원본은 `Assets/GameReady/Native8/PowerRelayRoom/`에 있다. 게임에서 바로 쓰는 128×128 셀/8배 출력은 이 폴더의 각 `*_game_scale.png` 파일과 `GodotPrototype/assets/power_relay_room/`에 있다.

## 타일 조립

`Tiles/Background`로 12×6 내부 셀을 먼저 반복 채우고, 한 셀짜리 외곽 링에 `Tiles/Frame`을 오버레이한다. 프레임은 좌상단 원점, +X 오른쪽, +Y 아래쪽, 128 world px 셀이다. 기존 `Workshop_Modular`와 동일하게 모서리는 한 번, `top`/`bottom`은 X축, `left`/`right`는 Y축으로 반복한다.

## 파괴 가능한 릴레이 캐비닛

`Destruction/power_relay_cabinet_assembled.png`를 초기 상태로 두고, 충격 단계에 따라 다음 파츠를 분리한다.

1. `left_door`, `right_door`
2. `top_cap`
3. `inner_core`
4. `lower_base`
5. `hinge_a/b`, `cable_chunk_a/b`, `debris_a/b/c/d`

모든 파츠는 독립 투명 PNG이며, 캐비닛 조립 위치와 파츠 역할은 `power_relay_room_manifest_v1.json`의 `destructionParts`에 기록했다. 런타임에서는 초기 파츠를 부모 프랍에 붙이고, 충격 시 부모에서 분리해 Rigidbody2D/충돌체를 켜면 된다. 조립 상태와 파츠 상태 모두 같은 8px art grid에 맞는다.

## 전선

`Cables`의 각 스프라이트는 커넥터가 분리점이 되도록 설계했다. Godot 런타임에서는 `GodotPrototype/scripts/power_relay_cable.gd`가 생성된 직선 케이블 텍스처를 처짐·흔들림이 있는 Verlet 체인에 입혀, 천장 앵커와 자유 끝점이 충격에 반응한다. 스프라이트 자체에는 빛·스파크를 굽지 않았다.

## 임포트

- Filter: Point / Nearest
- Compression: None 또는 무손실
- Mipmaps: Off
- Alpha: 0 또는 255만 사용
- 비정수 스케일: 금지
- 바닥 프랍 피벗: Bottom Center
- 분리 파츠·전선·조명 기구: Center 또는 앵커 기준 피벗을 런타임에서 지정
- 조명 반응용 노멀맵: `GodotPrototype/assets/normals/power_relay_room/`에 대응 파일 포함

전체 목록과 권장 레이어 순서는 `power_relay_room_manifest_v1.json`을 참고한다.
