# Creature production V2 — game integration

V1 원화·픽셀 프레임은 보존하고 V2 Aseprite의 프레임 시간을 수정했습니다.

- 천장종: 준비 460ms → 뻗기 56ms → 타격 자세 170ms 유지.
- 환상척추: 몸을 푸는 예고 후 lash의 180ms 준비 자세 → 36ms 급격한 뻗기 → 150ms 타격 자세.
- 봉합매복자: emerge 470ms, snap 준비 자세 180ms → 36ms 뻗기 → 160ms 타격 자세.
- 일반·거대 크롤러: attack 준비 60+240ms → 분출 45ms → 회수 자세 200ms. 거대종 내려찍기는 55ms. 도약 이동 시간도 단축했습니다.

환상척추의 게임 내 구르기는 정지 원본을 실제 회전시킵니다. 각도는 `이동 거리 / 몸체 반지름`으로 누적하며, 미리 회전한 roll 프레임을 중복 재생하지 않습니다. 900px/s까지 가속하고 짧은 몸체 잔상을 남깁니다.

## 게임에서 보기

- 서쪽 정비 통로 `corr_west`: 천장종·환상척추.
- 케이블 덕트 `cable_run`: 봉합매복자.
- `GodotPrototype/scenes/CreatureCombatLab.tscn`: 실제 Main·플레이어·무기·조명을 사용하는 3종 전투 확인 장면.
- `GodotPrototype/run_creature_combat.bat`을 실행하면 전투 확인 장면이 바로 열립니다.
- 기존 이동·조준·사격·구르기 조작을 그대로 사용합니다.

## VFX와 판정

몸체 잔상, 3단계 타격 섬광, 기존 체액 효과, 승인된 몸체의 뼈 부분에서 추출한 12종 파편을 사용합니다. 파편 시트는 `GodotPrototype/assets/effects/creature_fragments.png`입니다. 새 라이트는 추가하지 않았습니다.

새 3종은 알파 픽셀 기반 총알 판정, 공격 프레임 이벤트, 1회 공격당 중복 피해 방지, 구르기 회피, 약점 피해, 전기 감속, 사망 처리를 공유합니다. AI는 같은 구역과 시야를 확인합니다. 기존 버그봇도 새 몬스터를 표적으로 삼을 수 있습니다.

## 검증과 재생성

`CreatureValidation.tscn`에서 좌우 방향별 20fps 공격·복귀, 단일 피해, 회피, 사거리 밖 빗나감, 실제 무기 선분 판정, 구르기 회전각과 이동 거리 일치, 빈 고리 중심의 총알 통과, 피격·사망, 기존 크롤러의 타이밍을 검사합니다.

`Tools/Aseprite/import_creatures_v2.lua`로 V1에서 V2와 게임 에셋을 재생성합니다. 실제 GPU 렌더 캡처는 `research-images/creatures-v2/`에 있으며 `game-motion.gif`는 게임 화면 2초 분량입니다. `CreatureCombatLab.tscn -- --capture`로 다시 캡처할 수 있습니다.

게임 에셋은 네이티브 그림을 최근접 4배 확대하고 기존 V1 노멀맵을 사용합니다. 네이티브 원본과 게임 에셋의 픽셀 대응 및 109프레임 전체 존재를 검증합니다. 기존 V1 미리보기는 수정하지 않았습니다.
