# 괴생명체 3종 제작 에셋 V1

선택한 **1 천장종 / 4 환상척추 / 5 틈새꽃**의 게임 반입 전 에셋 패키지다. **24클립, 109프레임**을 제작했다. 모든 개별 컬러 프레임은 투명 PNG이며, 종별 공통 16색·알파 0/255·고정 캔버스/피벗을 사용한다.

[애니메이션 검토 화면 열기](review.html). 이 HTML은 이미지와 재생 데이터를 내장하므로 인터넷이나 서버 없이 브라우저에서 열 수 있다. 배속, 밝은/어두운 배경, 프레임 이동, 사망 마지막 프레임 유지, 기존 플레이어 크기 비교를 지원한다.

## 애니메이션 목록

| 괴물 | 클립과 프레임 수 | 합계 |
|---|---|---:|
| 천장종 `CeilingBell` | 대기 idle 4 · 예고 anticipate 4 · 내려찍기 strike 4 · 유지 hold 4 · 회수 retract 4 · 닫기 close 5 · 피격 hurt 4 · 사망 death 4 | 33 |
| 환상척추 `RingSpine` | 대기 idle 4 · 구르기 roll 12 · 고리 해제 uncoil 4 · 채찍 lash 4 · 회수 recoil 5 · 다시 말기 coil 5 · 피격 hurt 4 · 사망 death 4 | 42 |
| 틈새꽃 `SeamAmbusher` | 위장 dormant 4 · 출현 emerge 4 · 포획 snap 4 · 유지 hold 4 · 해제 release 5 · 숨기 withdraw 5 · 피격 hurt 4 · 사망 death 4 | 34 |

천장종·틈새꽃은 고정형으로 걷기 클립이 필요하지 않다. 환상척추의 구르기는 제자리 회전이며 실제 이동은 게임 로직이 맡는다. 사망 클립은 1회 재생한 뒤 잔해 프레임을 유지한다. GIF는 미리보기 특성상 반복되며 실제 반복 여부와 정확한 시간은 `animation.json`이 기준이다.

## 파일 위치

각 `processed/<괴물 ID>/` 안:

- `<ID>.aseprite`: 편집 원본. 프레임, 8개 태그, 타이밍, 공통 팔레트 및 3개 레이어를 보존한다.
- `frames/<clip>/*.png`: 네이티브 투명 개별 프레임.
- `sheets/<clip>.png`: 클립별 가로 시트.
- `atlas.png`, `atlas.json`: Aseprite CLI에서 다시 내보낸 전체 아틀라스 및 프레임 사각형.
- `animation.json`: 클립 반복/시간, 피벗, 색상, 시각적 약점 중심, 공격·약점 이벤트, Native4 사용 정보.
- `normals/<clip>/*.png`: 네이티브 조명용 노멀맵.
- `runtime4x/frames/`, `runtime4x/normals/`: 현행 Native4 배율의 컬러/노멀 쌍. Nearest 4배이며 게임 폴더로 복사하지 않았다.
- `preview/`: 클립별 GIF 8개, 전투 연결 GIF, 8클립 접촉 시트, 원본/가공 비교.
- `verification.json`: Aseprite 재열기·전 픽셀 동일성 검사 결과.

`sources/`는 내장 image_gen으로 만든 원본 시트 6장, `prepared/`는 연결된 투명 영역을 기준으로 분리한 96개 원본 포즈다. 원본 시트는 수정하지 않았다. `approved_concepts/`에는 사용자가 선택한 콘셉트 원본 복사본을 보존한다. 전체 프롬프트는 [prompts.md](prompts.md), 해시는 `source_manifest.json`과 `package_manifest.json`에 있다.

## 캔버스와 피벗

| ID | 네이티브 셀 | 피벗 (art px) | 4배 셀 | 피벗 의미 |
|---|---|---|---|---|
| CeilingBell | 144×192 | (72, 8) | 576×768 | 천장 고정근 중앙 |
| RingSpine | 176×112 | (44, 104) | 704×448 | 고리 중심의 지면 기준 |
| SeamAmbusher | 144×160 | (12, 52) | 576×640 | 벽 부착점 |

셀에는 동작 여유가 포함되어 있으므로 셀 전체 크기를 충돌 크기로 사용하면 안 된다. 네이티브 프레임을 사용할 때 배율 4를 주거나, `runtime4x`를 배율 1로 사용한다. 두 방법을 중복하면 16배가 된다. 필터 Nearest, mipmap 꺼짐을 권장한다. 메타데이터 좌표도 4배 PNG 사용 시 4배 환산한다.

## 제작과 보정

1. 선택된 콘셉트를 참조해 종별 A/B 두 장, 각 16포즈를 생성했다. 포즈 번호는 왼쪽부터, 위에서 아래 순서다.
2. 균등한 시트 칸으로 자르면 옆 칸에 걸친 꼬리/발톱이 잘리는 문제가 있어, 알파 연결 영역으로 96개 포즈를 분리했다. 독립된 극소 잡점(원본 9px 미만)은 제거했다. 전체 생체 부착근과 사망 잔해는 보존했다.
3. 종별 일정 샘플링 간격(천장종·틈새꽃 3, 환상척추 4)과 고정 기준점을 사용했다. 프레임별 바운딩 박스 맞춤 확대는 하지 않았다. 공간 평균이나 블러 없이 실제 원본 픽셀을 선택했다.
4. 살·골판·황록색 기관의 재질별 대표 원본색을 6/6/4개 확보해 종별 공통 16색 팔레트를 만들고 Aseprite에서 색 군집과 작은 내부 잡점을 정리했다. 알파 외곽선은 정리 단계에서 바꾸지 않았다.
5. 천장종 B 시트의 골판/목 표현이 A와 달라 회수·닫기에는 A 공격/예고의 역순을 사용했다. 피격은 A 대기 몸체의 고정근 아래를 국소 굽힘 처리했다. B의 사망은 별도 붕괴 포즈로 사용한다.
6. 환상척추는 대기 기준 몸체를 30도 간격으로 회전해 12프레임의 골판/기관 배치를 고정했다. 회수·다시 말기와 틈새꽃의 해제·숨기는 동일 공격 원본을 역순으로 연결하고 대기 연결 프레임을 추가했다.
7. 최종 Aseprite를 다시 열어 전 프레임을 PNG·클립 시트·CLI 아틀라스와 비교했다.

## 검증과 표현상 한계

- 세 종 109프레임 모두 Aseprite 재열기 성공, 전 RGBA 픽셀 일치, 태그/타이밍 일치, 공통 16색, 이진 알파, 빈 프레임 없음, 1px 투명 테두리 검사 통과.
- Native4 출력의 모든 4×4 블록이 네이티브 1px와 정확히 같다. 컬러와 노멀의 치수 일치, 노멀 벡터 길이 오차 1.5% 이내, 배경의 평면 노멀, GIF 프레임 수를 확인했다.
- 브라우저에서 세 종의 연결 재생, 사망 마지막 프레임 유지, 0.5배속, 밝은 배경과 기존 플레이어 크기 비교를 확인했다.
- 고밀도 원본의 작은 이빨·힘줄·질감은 네이티브에서 일부 단순화된다. `preview/source_native_comparison.png`에 실제 차이를 나란히 기록했다. 원본 디테일의 완전한 무손실 변환이라고 주장하지 않는다.
- 4프레임의 주요 포즈 기반 동작이며, 회전 클립은 12프레임이다. 생성된 유기체의 변형 포즈는 골판의 미세한 모양까지 프레임 간 동일하지 않다. 회전과 역순 동작은 동일 원본을 재사용해 이 변화를 줄였다.
- 노멀맵은 밝기와 2 art px 외곽 높이에서 파생한 초안이다. 수작업 면 분할 노멀이나 실제 게임 조명 검수 완료를 의미하지 않는다.
- 현재 공격 이벤트와 약점 중심은 반입을 위한 제작 정보다. 물리 충돌·피격 판정, AI, 게임 내 전투 밸런스는 이번 에셋 제작에 포함되지 않는다. 실제 게임 반입은 미실행이며 가공 결과의 사용자 외관 검토를 기다린다.

## 재현

저장소 루트에서 정식 Aseprite 설치를 사용한다. 기존 승인 파일을 덮어쓰지 않도록 V1 결과를 수정할 경우 먼저 별도 버전을 만든다.

```powershell
# PowerShell에서 실행 정책 때문에 직접 실행이 막힌 환경은 아래와 같이 해당 프로세스에만 적용한다.
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/prepare_creature_sources.ps1
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_creature_production.ps1
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/export_creature_package.ps1
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/verify_creature_exports.ps1
node Tools/Aseprite/build_creature_review.cjs
```

생성형 시트는 위 재현 명령에서 재생성하지 않는다. 보존된 `sources/`와 선택 원화를 입력으로 사용하므로 API 키가 필요 없다. Aseprite를 수동 수정한 뒤에는 제작 스크립트로 수정본을 덮어쓰지 말고 해당 편집 원본에서 내보낸다.
