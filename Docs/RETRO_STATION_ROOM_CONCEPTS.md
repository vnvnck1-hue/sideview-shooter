# 레트로 우주정거장 2D 방 원화 — 조사 및 디자인 브리프

이 문서는 두 방의 원화 조사·디자인 브리프다. 의료실은 이후 Aseprite 픽셀화를 수행했으므로 두 방을 일괄적으로 ‘픽셀화 전’으로 취급하지 않는다. 현재 선택본·승인 범위·게임 적용 상태는 [`ART_ASSET_STATUS.md`](ART_ASSET_STATUS.md)에서 관리한다.

## 조사: Alien: Isolation의 배경 조형

- [SEGA 공식 콘셉트 아트 소개](https://alienisolation.sega.jp/special_conceptart.html)는 정거장 내부의 문, 계단, 배선, 에어록, 무광 표면과 실용적 구조에 1979년 영화의 미술이 영향을 주었다고 설명한다. 당시 세트에서 제작 가능했을 물건만 고른다는 제약도 밝힌다.
- [Creative Assembly 크리에이티브 리드의 설명](https://blog.playstation.com/2014/06/10/new-alien-isolation-details-revealed/)은 이 세계를 1970년대식 저기술 SF로 규정한다.
- [Creative Assembly UI 아티스트 인터뷰](https://d362wsx8rkw9qn.cloudfront.net/title/alien-isolation/)는 오래된 영상 기술을 거치는 컴퓨터 화면과 첫 영화 세트의 분위기를 기준으로 삼았다고 설명한다.

위 자료를 2D 방에 옮길 때는 **두꺼운 CRT, 물리 버튼·레버, 노출 배선, 무광 패널, 기능별 장비 배치**를 쓰고, 홀로그램이나 매끈한 미래형 표면은 피한다. 폐쇄감은 조명을 적게 두고 방 바깥을 암부로 남겨 표현한다. 이 마지막 두 문장은 자료와 프로젝트 아트 가이드를 결합한 디자인 판단이다.

## 프로젝트 그림체 대응

- 최상위 기준: [`ART_GUIDE.md`](ART_GUIDE.md) §0–6. 방 외곽의 넓이·높이, 약한 원근, 연속된 바닥, 배경보다 또렷한 프랍, 단계적인 픽셀 조명을 따른다.
- 형태·명암 비교 이미지: `Assets/Generated/Environments/underground_workshop_diorama_v4_subtle_zoomout.png`, `Assets/Generated/PowerRelayRoom/Concept/power_relay_room_concept_v1.png`, `Deliverables/SideviewPixelArtResourcePack/02_Dioramas/crew_quarters_room_block_v1.png`.
- 기존 연구시설 세 방 원화는 의료 장비의 복잡도 참고에만 썼다. 밝고 깨끗한 벽 전체를 이번 방으로 그대로 옮기지는 않았다.

## 방 1 — 아날로그 통신 관제실

원화: `Assets/Generated/Environments/retro_comm_control_room_concept_v1.png`

중앙의 세 CRT와 물리 제어 콘솔, 왼쪽 릴레이 랙, 벽의 패치 패널·굵은 케이블, 오른쪽 서비스 해치로 기능을 읽게 했다. 올리브빛 장비와 청회색 벽, 제한된 주황 상태등 및 녹색 CRT가 시선의 중심이다. 작업실·전력실 원화의 거친 구조재와 그림자 덩어리를 비교 기준으로 사용했다.

## 방 2 — 진찰·분류 의무실

원화: `Assets/Generated/Environments/retro_medical_triage_room_concept_v1.png`

진찰대, 두꺼운 CRT 진단 장비, 유리 약품장, 세면대, 커튼 뒤 빈 침상을 배치했다. 낡은 아이보리·회녹색 의료 장비가 청회색 그림자와 분리된다. 차가운 형광등 한 줄과 작은 주황 경고등으로 작업 구역만 비춘다. 숙소 원화의 침상·커튼 구조와 픽셀 명암을 비교 기준으로 사용했다.

두 그림은 기존 게임 화면을 복제한 것이 아니라 조사된 조형 규칙과 이 프로젝트의 그림체로 새로 구성한 원화다. 의료실의 [2배 Aseprite 결과](../Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1/two-x-r1/README.md)는 방 전체 외관의 변환이며 개별 프랍 분리·가려진 면 복원·타일 제작·게임 반입을 완료한 것이 아니다. 캐릭터·개별 프랍 제작은 별도 범위로 검토한다.
