# 초반 FTUE 배경 5장 — shallow-sideview-v1

> 후속 상태: **미채택**. 기존 장면과 캐릭터 비율에서 벗어났다는 사용자 피드백으로 이 묶음을 제작 기준에서 제외했다. 아래는 생성 당시의 기록이다. [현재 상태](../../../../Docs/ART_ASSET_STATUS.md) · [후속 v3](../structural-redesign-v3/README.md).

2026-09-22. **사용자 검토용 원화 시안**. 원화 승인·실제 픽셀화·개별 모듈 분리·게임 반입은 아직 하지 않았다.

## 구성 근거

- [현재 배경 제작 방향](../../../../Docs/BACKGROUND_ART_DIRECTION.md): 넓지만 얕은 정면 사이드뷰, 가까운 뒤벽, 좁은 바닥, 고유색 보존, 상호작용 위계.
- [OPENING_FLOW](../../../../Docs/OPENING_FLOW.md)의 **처음 다섯 비트(0:00–13:00)**를 선택했다. 첫 두 장은 새 방 두 개가 아니라 **같은 에어록의 연속 장면**이다. 1번은 검은 부팅 화면 자체가 아니라 센서 초점이 맞은 직후다.
- 기존 FTUEConcepts에는 제조·현재 전환·평화로운 순찰·선체 파손·엔딩 이미지가 함께 있다. 이번에는 그 다섯 파일을 덮어쓰거나 스토리를 합치지 않고, 현재 문서의 초반 순서를 시각화했다. 이전 이미지와 기획 문서는 변경하지 않았다.
- [정비홀 v1](../../../../research-images/comparison/hall-redesign-v1.png), [전력 릴레이실 v1](../../../../research-images/comparison/power-relay-concept-v1.png)을 공간·그림체 기준으로 사용했다. 미채택 정비홀 v2와 재색칠 불만이 있던 전력실 v2는 입력하지 않았다.
- 에어록 인물은 [아르카디 콘셉트 v5](../../NPCConcepts/airlock_caretaker_concept_v5.png)를 추가 참조했다.

## 이번 제출본

| # | FTUE 위치 | 장면 | 내용 | 배경/기능 대상 구분 |
|---|---|---|---|---|
| 1 | 0:00–1:30 / 비트 1 | 에어록 — 기동 직후 | 맨몸으로 일어나는 로봇, 안전한 방, 누수·비상등 | 압력문·탱크·덕트는 고정 설비. 통신 단말은 다음 장면의 조작 대상. |
| 2 | 1:30–4:30 / 비트 2 | 에어록 — 첫 생존자 | 아르카디와의 대화, 첫 단말 접근 | 1번과 같은 방을 유지. 인물과 link_airlock 역할의 단말을 읽히게 함. |
| 3 | 4:30–7:00 / 비트 3 | 서쪽 정비 통로 — 첫 무장·전투 | 빈 무기 거치대, 무장한 로봇, 크롤러 한 마리 | 무기 캐비닛·백업 단말은 기능 대상. 포탑 해치는 닫힘·무전력 상태. |
| 4 | 7:00–10:00 / 비트 4 | 작업실 — 원격 조종 | 몸은 작업실, CRT에는 다른 방의 포탑 도식 | 오른쪽 sec_workshop 역할의 조작부가 중심. 왼쪽 선반/모터는 고정 배경. |
| 5 | 10:00–13:00 / 비트 5 | 대형 정비홀 — 첫 위기 | 잠긴 출입문, 밀려드는 크롤러, 첫 사망 직전 | 전투 실루엣 우선. 팬·크레인·정비 모터는 배경으로 후퇴. |

작업실은 첫 생성본의 구리 로터·볼트 광택이 단말과 경쟁해 **같은 색을 유지한 국소 대비 보정본 r2**를 제출본으로 선택했다. 이는 제작자 검수 선택이며 사용자 승인이 아니다. 첫 생성본도 [비교용](04_workshop_remote_link.png)으로 보존한다.

### 01 · 에어록 — 기동 직후

[원본 PNG](01_airlock_reboot.png)

![01 · 에어록 — 기동 직후](C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/Assets/Generated/FTUEConcepts/shallow-sideview-v1/01_airlock_reboot.png)

### 02 · 에어록 — 첫 생존자

[원본 PNG](02_airlock_first_contact.png)

![02 · 에어록 — 첫 생존자](C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/Assets/Generated/FTUEConcepts/shallow-sideview-v1/02_airlock_first_contact.png)

### 03 · 서쪽 정비 통로 — 첫 무장·전투

[원본 PNG](03_west_corridor_first_combat.png)

![03 · 서쪽 정비 통로 — 첫 무장·전투](C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/Assets/Generated/FTUEConcepts/shallow-sideview-v1/03_west_corridor_first_combat.png)

### 04 · 작업실 — 원격 조종

[원본 PNG](04_workshop_remote_link_r2.png)

![04 · 작업실 — 원격 조종](C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/Assets/Generated/FTUEConcepts/shallow-sideview-v1/04_workshop_remote_link_r2.png)

### 05 · 대형 정비홀 — 첫 위기

[원본 PNG](05_maintenance_hall_first_crisis.png)

![05 · 대형 정비홀 — 첫 위기](C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/Assets/Generated/FTUEConcepts/shallow-sideview-v1/05_maintenance_hall_first_crisis.png)

## 제작·검수 기록

- 제작: imagegen 스킬의 **내장 image_gen**. 서로 다른 장면별로 별도 호출, 작업실만 대비 보정 호출을 추가했다. CLI/API fallback은 사용하지 않았다.
- 전체 최종 프롬프트: [PROMPTS.md](PROMPTS.md), 작업실 보정: [PROMPT_04_R2.md](PROMPT_04_R2.md).
- 원본 PNG를 수정 없이 프로젝트 폴더로 복사했다. 원래 생성 경로·입력 참조·실제 치수·SHA256: [manifest.json](manifest.json).
- 시각 확인: 가로로 펼쳐진 가까운 뒤벽, 좁은 지면, 낮은 모서리 근경, 고유색을 바꾸지 않은 단말, 에어록의 무장 없음, 첫 전투의 크롤러 한 마리, 작업실의 원격 화면을 확인했다.
- 서로 다른 방의 설비를 새로 구성했다. 1–2번 건축은 연속성을 위해 의도적으로 유지했다.
- **한계/후속 검수:** AI 원화로, 픽셀 격자·색 수·정수 배율·실제 조작부/충돌이 검증된 게임 스프라이트가 아니다. 프롬프트의 2240×900은 구도 가이드이며 실제 출력은 약 1975–1978×795–796이다. 장면별 인물 비율·세부 디자인은 편차가 있어 실제 반입 전 승인 캐릭터와의 합성 검수가 필요하다. 원본 픽셀 단위의 완전한 색 보존이나 배치 동일성을 검증했다고 주장하지 않는다.
- 흑백·실제 게임 표시 크기·엔진 조명/CRT/가림 검수, 픽셀화, 프랍 레이어 분리는 아직 하지 않았다. 엔진 파일·카메라·방 구조·상호작용 코드는 변경하지 않았다.
- 현재 승인 상태: [ART_ASSET_STATUS](../../../../Docs/ART_ASSET_STATUS.md). 다섯 장 모두 새 사용자 피드백 대기.
