# 아트 선택본·승인 상태

2026-09-22 갱신. 이 문서는 아래 보존형 변환 사례와 배경 원화 시안의 **현재 선택과 승인 범위**를 관리한다. 프로젝트 전체 런타임 자산 목록이 아니다. 공통 미술 정책은 `ART_GUIDE.md`, 배경 제작 방향은 `BACKGROUND_ART_DIRECTION.md`, 실행 설정과 명령은 `ASEPRITE_PIPELINE.md`를 따른다.

## 기록 원칙

- 원화 지정/승인, 픽셀 간격 선택, 결과 외관 승인, 자동 검사, 게임 반입/런타임 승인을 구분한다. 한 단계의 승인이 다음 단계로 자동 전파되지 않는다.
- `verification.json`은 해당 실행의 입력/출력 해시·설정·검사와 당시 상태를 담은 스냅샷이다. 이후 피드백 때문에 과거 검사 기록을 다시 쓰지 않고 이 문서에 대상 버전과 근거를 남긴다. 스냅샷의 `userApproval`과 현재 상태가 다르면 아래 후속 기록을 확인한다.
- README는 구현·손실·재현 설명을 유지하고 현재 승인 상태는 이 문서를 연결한다. 새 결과는 기존 승인본과 동일한 알고리즘이어도 별도 검토 대상이다.
- “좋아” 같은 일반적 응답을 확대 해석해 런타임 승인으로 기록하지 않는다. 원화 변환 결과의 수용과 게임 적용 허가는 별개다.

## 현재 선택본

| 대상/버전 | 원화 및 변환 선택 | 외관·프로세스 피드백 | 게임 적용 |
|---|---|---|---|
| 세면대·캐비닛·의자 `crisp-final-r1` | 사용자가 지정한 세 원본, pixelPitch=1.0 | “거의 90% 이상 보존”, 선명도 긍정 평가 및 프로세스 재사용 요청. 세 결과의 외관·프로세스 승인 | 반입 미실행, 런타임 승인 없음 |
| 의료실 `two-x-r1` | 사용자가 지정한 `retro_medical_triage_room_concept_v1`, pixelPitch=2.0 선택 | “너무 깨진다. 그냥 2배로 하자.” 이후 2배 결과에 이어 “좋아”라고 응답하고 문서 검토 요청. 2배 결과 수용으로 기록; 세부 보존율 평가는 별도 없음 | 방 전체 이미지 시안. 개별 모듈 분리·게임 출력 프로파일·반입·런타임 검수 미완료 |
| 의료실 `r2/3x`, `r2/4x` | 같은 원화의 3.0/4.0 비교 | 디테일 손실이 커 선택에서 제외. 삭제하지 않고 비교 기록으로 보존 | 반입 미실행 |
| 통신 관제실 `retro_comm_control_room_concept_v1` | 원화 후보 | 이 기록 범위에서 명시적 승인 및 픽셀화 확인 없음 | 미반입 후보 |

## 배경 리서치 이후 시안 상태 — 2026-09-22

아래 네 장은 내장 image_gen으로 생성한 원화 시안이다. **공간 방향 수용, 구분 효과 인정, 현재 상태 유지와 전면적인 디자인/납품 승인을 구별**한다. 어떤 시안도 이번 작업에서 픽셀화·모듈 분리·엔진 반입·런타임 검수를 완료하지 않았다.

| 대상/버전 | 현재 선택·판단 | 사용자 피드백과 제한 | 픽셀화·게임 적용 |
|---|---|---|---|
| [정비홀 v1](../research-images/comparison/hall-redesign-v1.png) | **선호 공간/그림체 참조** | 처음에는 바닥·근경 보완을 요청했으나 v2 확인 후 “직전에 그려준게 우리에겐 맞는 것 같아”라며 얕은 구도로 복귀. 모든 개별 프랍·색·배치의 납품 승인으로 확대하지 않음 | 미실행·미승인 |
| [정비홀 v2](../research-images/comparison/hall-redesign-v2.png) | **미채택, 비교 기록 보존** | “공간의 깊이가 의도하지 않게 너무 깊어져서 별로네.” 넓은 지면·큰 근경을 신규 배경 기준으로 재사용하지 않음 | 미실행·미승인 |
| [전력 릴레이실 v1](../research-images/comparison/power-relay-concept-v1.png) | **방 콘셉트/얕은 공간 방향 수용** | “좋아. 나쁘지않아.” 이후 고정 배경과 인터랙션 프랍의 톤 차이 부족 지적. 역할 위계까지 완료된 것은 아님 | 미실행·미승인 |
| [전력 릴레이실 v2 — 상호작용 구분](../research-images/comparison/power-relay-concept-v2-interaction.png) | **구분 효과 인정, 색 불만을 남긴 현재 상태 유지** | “컬러 자체를 바꿔서 맘에 안들지만, 우선 구별은 되니까 그냥 그대로 둬야겠어.” 고유색 변경 방식의 선호·표준 승인 아님. 자동 재색칠/복원하지 않음 | 미실행·미승인. 배전반을 조작 대상으로 본 것은 시안 가정이며 실제 기능 연결 없음 |

현재 시안 유지와 이후 제작 원칙은 별개다. **다음 배경은 고유색을 보존하면서 배경 대비·배후 면·윤곽·기능 부위의 중요도로 상호작용을 구분**한다. 전력실 v2의 황토/노랑을 인터랙션 공통색으로 정하지 않는다. 미채택 이미지도 삭제하지 않는다.

시안별 입력 참조·프롬프트 전문·SHA256과 시간순 피드백은 [BACKGROUND_RESEARCH_LOG](BACKGROUND_RESEARCH_LOG.md)에 보존했다. 실제 프롬프트 수치나 PNG 존재만으로 자동 규격 검사를 통과했다고 간주하지 않는다.

## 기존 FTUE·엔딩 재설계 시안 — 2026-09-22 후속 상태

| 버전 | 현재 상태 | 판단 근거 |
|---|---|---|
| [shallow-sideview-v1](../Assets/Generated/FTUEConcepts/shallow-sideview-v1/README.md) | 미채택, 비교 기록 보존 | 이전 `OPENING_FLOW` 비트로 새 장면을 구성해 사용자가 정한 원화 장면과 캐릭터 비율을 이탈했다는 피드백. 이전의 검토 대기 표기를 폐기한다. |
| [original-scene-redraw-v2](../Assets/Generated/FTUEConcepts/original-scene-redraw-v2/PROMPTS.md) | 표시된 시안 미채택, 작업 중단 | 기존 장면을 지나치게 고정해 원화와 거의 같고 배경 재설계 목적을 달성하지 못했다는 피드백. 5장 완성본으로 기록하지 않는다. |
| [structural-redesign-v3](../Assets/Generated/FTUEConcepts/structural-redesign-v3/README.md) | 5장 생성 완료, 새 사용자 검토 후보 | 기존 사건·인물·캐릭터 비율을 제약으로 삼고 건축·설비·프랍 배치·화면 구성을 다시 설계. 순찰과 사고는 동일한 새 공간을 공유한다. 아직 사용자 승인 없음. |

v3의 01–04는 기존 오프닝, 05는 기존 희생 엔딩이다. 다섯 번째 FTUE 사건을 새로 만들어 넣지 않았다. 원본과 이전 시안은 덮어쓰지 않았으며, 모든 버전은 픽셀화·모듈 분리·게임 반입·런타임 승인 대상과 구분한다. 생성 제약으로 캐릭터 비율을 참조했다는 사실은 픽셀 단위 동일성이나 최종 외관 승인을 뜻하지 않는다.

이번 재설계에서 고정한 것은 **이야기와 캐릭터**, 바꾼 것은 **배경의 구조와 시각적 위계**다. 입력·프롬프트·실제 PNG 치수·해시는 v3 README와 manifest에 보존했다.

## 2레이어 패럴랙스 원화 비교 — 2026-09-22

[two-layer-maintenance-v1](../Assets/Generated/ParallaxConcepts/two-layer-maintenance-v1/README.md)의 A 벽체형 정비실·B 펌프 설비실 두 장을 생성했다. 같은 일상 정비 테마를 직선적·개방적인 구성과 둥근 설비·비대칭 겹침 구성으로 대비했다. 뒤 설비판과 앞 구조·바닥판의 정확히 두 움직임 그룹으로 가공할 것을 전제로 설계한 **평면 원화 후보**다.

현재 두 안 모두 사용자 선택·승인 대기다. PNG 레이어 분리, 가려진 면 복원, 픽셀화, 실제 패럴랙스 동작 검수, 게임 반입은 하지 않았다. 선택된 원화를 바탕으로 후속 가공하기 전까지 새 표준이나 승인된 게임 리소스로 취급하지 않는다. 기존 원본과 게임 설정은 변경하지 않았다.

### 컴퓨터 장비 밀집 전산실 — 후속 원화

[computer-equipment-room-v1](../Assets/Generated/ParallaxConcepts/computer-equipment-room-v1/README.md) 한 장을 추가 생성했다. 메인프레임·다수 CRT·키보드 콘솔·진단 랙을 모은 공간이며 뒤 컴퓨터 랙과 앞 설비·골조·바닥의 두 레이어 분리 구상을 유지한다. **사용자 검토 후보**로 기록하며, 원화 승인·분리 가공·픽셀화·게임 반입은 미실행이다. 기존 A/B 및 통신실 원화는 변경하지 않았다.

후속 피드백: 사용자가 전산실 v1을 “너무 오래된 스타일”로 판단하고 현대식 재설계를 요청했다. 따라서 v1은 현 요청의 채택본이 아니라 비교 기록으로 보존한다. [현대식 v2](../Assets/Generated/ParallaxConcepts/computer-equipment-room-modern-v2/README.md)는 프롬프트를 준비했으나 내장 이미지 생성 한도(`429 usage_limit_reached`)로 실패해 **이미지 미생성** 상태다. 새 원화나 승인본으로 기록하지 않는다.

## 원본·검사·재현 근거

- 세 프랍: [결과 README](../Assets/Generated/ApprovedPropPixelTrial/crisp-final-r1/README.md), [검사 스냅샷](../Assets/Generated/ApprovedPropPixelTrial/crisp-final-r1/verification.json). 위 90%는 사용자의 시각적 표현이지 측정값이나 신규 자산 보증이 아니다.
- 의료실 선택본: [2배 README](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/README.md), [검사 스냅샷](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/verification.json). 스냅샷의 `pixel_pitch_selected_final_visual_pending`는 후속 “좋아” 이전 실행 시점 상태다. 재현 실행도 인간의 후속 승인을 자동 복제하지 않는다.
- 의료실 제외 후보: [3배/4배 비교 기록](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/r2/README.md).
- 방 원화 브리프: [RETRO_STATION_ROOM_CONCEPTS.md](RETRO_STATION_ROOM_CONCEPTS.md).
- 메탈슬러그 비교 이후 배경 원화: [현재 제작 방향](BACKGROUND_ART_DIRECTION.md), [전체 조사·시안·결정 기록](BACKGROUND_RESEARCH_LOG.md). 위 시안 상태 표와 해당 기록을 함께 확인한다.

## 이후 갱신 시 필수 항목

대상 자산/결과 버전, 검사 스냅샷 경로와 출력 해시, 사용자 피드백 근거, 원화/픽셀 간격/외관/게임 적용 각각의 상태, 남은 손실·검수 항목을 함께 기록한다. 반입 시에는 실제 반입 파일 목록과 엔진 검수 근거를 추가한다. 문서 승인만으로 이미지를 교체하지 않는다.
