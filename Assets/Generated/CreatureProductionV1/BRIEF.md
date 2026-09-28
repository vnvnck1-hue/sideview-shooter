# Creature Production V1

사용자 선택: 천장종(1), 환상척추(4), 틈새꽃(5). 원화 선택 및 에셋/애니메이션 제작을 요청받았다. 게임 반입 전 검토 패키지로 제작한다.

## 보존 항목

- CeilingBell: 세 갈래 고정근, 매달린 힘줄, 아이보리 골판, 붉은 코어, 분절된 하강 포획구, 세 갈래 발톱, 열린 목의 황록색 고리.
- RingSpine: 중앙이 빈 고리, 연속된 척추, 외측 아이보리 골판/내측 붉은 힘줄, 꼬리를 문 접점의 황록색 기관. 고리 해제 후에도 같은 길이의 몸.
- SeamAmbusher: 하나의 벽 부착점, 네 장의 긴 포획엽, 안쪽 갈고리 이빨, 중앙 황록색 인두. 접힘/펼침/포획 중 부착점 유지.

## 산출물

종별 8개 클립, 클립별 최소 4프레임(총 96 이상). 투명 개별 PNG, 클립 시트, 태그/타이밍을 가진 Aseprite 편집원본, JSON 피벗/타격·약점 이벤트, 재생 미리보기와 보존 비교. 생성 원본은 수정 없이 보존한다. 프레임별 바운딩 박스 맞춤 확대를 금지하며 종별 동일 축척·고정 부착점으로 가공한다. 프레임 공통 16색과 이진 알파. 세부 디테일 손실과 시각 검수 결과는 별도 기록한다.

## 클립

- CeilingBell: idle, anticipate, strike, hold, retract, close, hurt, death.
- RingSpine: idle, roll, uncoil, lash, recoil, coil, hurt, death.
- SeamAmbusher: dormant, emerge, snap, hold, release, withdraw, hurt, death.

환상척추 이동은 제자리 회전 클립이고 이동량은 메타데이터의 제안값으로 분리한다. 천장종/틈새꽃은 고정형이므로 걷기 클립이 없다. 사망은 소멸 대신 잔해가 남는 마지막 프레임으로 종료한다.

최종 규격은 생성된 원본의 가독성 비교 후 결정한다. 현행 Native4에서 플레이어 키 약 67 art px를 기준으로 상대 크기를 확인한다. 본 작업은 GodotPrototype 파일을 수정하지 않는다.
