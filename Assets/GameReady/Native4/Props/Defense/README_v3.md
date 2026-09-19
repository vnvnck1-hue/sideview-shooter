# Sentry Turret v3

기존 센트리의 표면 재질만 바꾼 변형이 아니라, 구조와 실루엣을 새로 설계한 미래형 벽·바닥 매립형 방어 프랍이다. 첨부 레퍼런스의 기능적인 탄약 드럼, 노출 급탄 라인, 조준 헤드 구성은 참고하되, 게임 배경에 맞게 방사형 매립 해치와 측면 카트리지, 다축 짐벌, 부유형 쌍열 헤드로 재구성했다.

## 리소스 구성

- `sentry_turret_mount_v3.png` — 별도 고정 하부 해치. 빨간 표시 영역의 방사형 전개 플레이트만 분리한 리소스. `base_v3`의 통합 해치를 숨기는 교체/재사용용으로 사용한다.
- `sentry_turret_base_v3.png` — 고정 하부 모듈. 벽/바닥에 자연스럽게 붙는 방사형 해치, 중앙 마스트, 짐벌 소켓, 측면 탄약 카트리지.
- `sentry_turret_firing_v3.png` — 별도 회전 발사부. 컴팩트한 쌍열 헤드, 상부 광학 센서, 하부 회전 피벗.
- `sentry_turret_ammo_feed_v3.png` — 개별 탄약 링크가 읽히는 장갑형 S자 급탄 라인.

상부 무기부는 추가로 세 파츠로 사용할 수 있다.

- `sentry_turret_optic_v3.png` — 상부 조준경/광학 센서.
- `sentry_turret_front_v3.png` — 전방 쌍열 총열과 총구 모듈.
- `sentry_turret_body_v3.png` — 중앙 장갑 리시버와 회전 피벗.
- `sentry_turret_body_core_v3.png` — 하부 원형 피벗과 하부 브래킷을 제외한 중앙 몸통만의 경량 분리형.

세 파츠와 body-core 변형의 결합 위치와 피벗은 `sentry_turret_weapon_split_v3.json`에 기록했다.

## 배치 규칙

- `sentry_turret_mount_v3.png`는 벽/바닥 표면과 flush하게 배치한다. `base_v3`의 통합 해치와 동시에 표시하지 않고, 필요하면 통합 해치를 숨긴 뒤 mount를 교체 파츠로 사용한다. mount는 native pivot `(64, 24)` 기준으로 고정한다.
- 발사부만 `sentry_turret_firing_v3.png`의 native pivot `(22, 28)` 기준으로 회전한다.
- 베이스 결합점은 `sentry_turret_base_v3.png` 상단 소켓 중앙 `(56, 14)`에 맞춘다.
- 급탄 라인은 발사부 하부 급탄구와 베이스 측면 카트리지 포트 사이에 배치하고, 회전 시에도 약간의 slack을 남긴다.
- 방사형 해치 칼라는 벽 또는 바닥 표면과 flush하게 배치해 평상시 매립되어 있던 장비처럼 보이게 한다.

Native4 PNG는 투명 배경과 알파 0/255로 정리했고, `GodotPrototype/assets/props/defense/`에는 ×4 nearest 적용본을 함께 배치했다.
