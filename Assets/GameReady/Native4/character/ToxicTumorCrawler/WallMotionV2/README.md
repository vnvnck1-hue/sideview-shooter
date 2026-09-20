# ToxicTumorCrawler 벽 이동 v2 — 형태 고정

기준: `Docs/TOXIC_TUMOR_CRAWLER_ANATOMY.md`, `Docs/ART_GUIDE.md` §10, 기존 몬스터 원형 `toxic_tumor_crawler_base_v2.png`.

| 클립 | 순서 | 5프레임 시트 |
|---|---|---|
| `wall_jump` | 바닥 자세 0° → 오른쪽 벽 부착 90° | `wall_jump_5f_v2.png` |
| `corner_inside` | 오른쪽 벽 90° → 방 안쪽 ㄱ자 접점 → 천장 아래 180° | `corner_inside_5f_v2.png` |
| `corner_outside` | 돌출 구조물 왼쪽 수직면 90° → 볼록한 바깥 모서리 → 윗면 0° | `corner_outside_5f_v2.png` |

- 클립마다 80×80 네이티브 아트 픽셀 프레임 5장, 400×80 시트 1장. PNG RGBA, 알파 0/255, 16색.
- `canonical_80x80.png`를 **모든 프레임의 동일한 몸통·종양·머리·다리 원형**으로 사용했다. `Tools/build_crawler_wall_motion_v2.py`가 일정 배율로 축소한 뒤 Nearest 회전만 적용한다. 생성형 포즈 초안에서 나타났던 종양 크기·배치 변화는 최종 PNG에 반영하지 않았다.
- `wall_jump_05`, `corner_inside_01`, `corner_outside_01`은 같은 벽 부착 이미지다.
- 게임용 월드 픽셀 ×4 PNG는 `GodotPrototype/assets/character/ToxicTumorCrawler/WallMotionV2/`에 있다. 위치 이동과 벽·천장 접지는 게임 로직에서 적용한다.
- 5프레임은 몸통 방향 전환의 키포즈다. 개별 다리의 보행·잡기 사이클은 포함하지 않는다.
- `wall_motion_v2.json`에 각 프레임 경로, 각도, 공통 피벗과 원형 이미지 해시를 기록했다.

검수용 배경 그림 `Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_corner_types_anatomy_locked_v2.png`는 위쪽 줄에 안쪽, 아래쪽 줄에 바깥쪽 코너를 같은 시작 자세로 보여준다. 벽은 이 검수 그림에만 있고 스프라이트는 투명하다.

벽 점프 경로는 `Assets/Generated/CharacterAnimation/ToxicTumorCrawler/toxic_tumor_crawler_wall_jump_context_v2.png`에서 확인한다. 이 배경과 경로 오프셋도 검수용이며, 게임 내 실제 이동은 몬스터 로직이 담당한다.

## 포즈 제작 프롬프트 요약

- 벽 점프: 공식 원형의 거대 후방 종양, 작은 종양 배열, 사선 붉은 띠, 작은 앞머리와 촉수 다리의 수·배치를 잠근 채 바닥 웅크림 → 대각선 도약 → 공중 → 벽 접촉 → 오른쪽 벽 부착을 5포즈로 표현.
- 안쪽 코너: 위 벽 부착에서 시작해 몬스터 몸이 오른쪽 벽의 왼쪽·천장의 아래에 머무는 오목한 ㄱ자 접점을 지나 천장 아래에서 왼쪽을 향하도록 5포즈로 표현.
- 바깥쪽 코너: 같은 벽 부착에서 시작해 돌출 구조물의 왼쪽 수직면에서 볼록한 윗모서리를 넘어 윗면에 오르는 5포즈로 표현.

세 생성형 포즈 시트는 `Assets/Generated/CharacterAnimation/ToxicTumorCrawler/`에 `*_pose_study_v2.png`로 보존했다. 최종 게임용 PNG는 해부학적 일관성을 위해 그 시트의 몸통을 사용하지 않고 공식 원형에서 제작했다.
