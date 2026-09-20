# 아트 선택본·승인 상태

2026-09-21 정리. 이 문서는 아래 보존형 변환 사례의 **현재 선택과 승인 범위**를 관리한다. 프로젝트 전체 런타임 자산 목록이 아니다. 공통 미술 정책은 `ART_GUIDE.md`, 실행 설정과 명령은 `ASEPRITE_PIPELINE.md`를 따른다.

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

## 원본·검사·재현 근거

- 세 프랍: [결과 README](../Assets/Generated/ApprovedPropPixelTrial/crisp-final-r1/README.md), [검사 스냅샷](../Assets/Generated/ApprovedPropPixelTrial/crisp-final-r1/verification.json). 위 90%는 사용자의 시각적 표현이지 측정값이나 신규 자산 보증이 아니다.
- 의료실 선택본: [2배 README](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/README.md), [검사 스냅샷](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/verification.json). 스냅샷의 `pixel_pitch_selected_final_visual_pending`는 후속 “좋아” 이전 실행 시점 상태다. 재현 실행도 인간의 후속 승인을 자동 복제하지 않는다.
- 의료실 제외 후보: [3배/4배 비교 기록](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/r2/README.md).
- 방 원화 브리프: [RETRO_STATION_ROOM_CONCEPTS.md](RETRO_STATION_ROOM_CONCEPTS.md).

## 이후 갱신 시 필수 항목

대상 자산/결과 버전, 검사 스냅샷 경로와 출력 해시, 사용자 피드백 근거, 원화/픽셀 간격/외관/게임 적용 각각의 상태, 남은 손실·검수 항목을 함께 기록한다. 반입 시에는 실제 반입 파일 목록과 엔진 검수 근거를 추가한다. 문서 승인만으로 이미지를 교체하지 않는다.
