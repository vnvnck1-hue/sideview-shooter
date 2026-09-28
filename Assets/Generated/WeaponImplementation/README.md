# 무기 구현 에셋 · 2026-09-28

사용자 요청: “필요한 에셋 생성,가공해서 게임에 직접 넣어줘”, “플레이어는 컨셉원화처럼 딱 저 모습으로 총을 들고있게해줘.” P02 불독, P03 코일랜스, B04 아크위버를 구현 대상으로 적용했다. 구현 결과에 대한 사용자의 후속 검수는 아직 받지 않았다.

## 원본과 가공

- 승인 컨셉: `Deliverables/무기_컨셉_시안/P02_bulldog.png`, `P03_coil_lance.png`, `B04_arc_weaver.png`.
- 플레이어는 생성 모델이 다시 그린 캐릭터를 사용하지 않는다. **원본 EQUIPPED 패널의 픽셀을 직접 추출**하고 배경을 제거한 뒤 몸통·총과 양손·앞다리·뒷다리로 나눴다. 중립 자세로 합성했을 때 배경 제거 후 추출본과 픽셀 차이가 0임을 자동 검사했다.
- 총 아래 가려져 있는 몸통에만 어두운 옷 색을 보완했다. 조준 회전 시 빈 구멍이 드러나는 것을 막으며, 중립 자세 원본 픽셀에는 영향이 없다. 움직이는 자세는 이 레이어들의 회전·이동으로 만든다.
- 사용자 요청의 외형 보존을 위해 기존 65px 높이로 축소하지 않고, 추출본 420×374 / 371×366px를 보존했다. 게임 표시 높이는 기존과 같은 264 월드 단위이며 Nearest 필터다. 기존 Native4 고정 격자 애니메이션을 재사용하는 방식은 아니다.
- 아크위버는 B04 대형 포탑의 투명 배경 추출 생성본을 사용했다. 전체 형태·축전기·케이블·갈라진 포구를 보존하도록 지시했고, Aseprite에서 알파 경계를 정리했다. 플레이어의 픽셀 동일성 검사는 아크위버에 해당하지 않는다.
- 산탄·코일 바늘·전기 구체도 컨셉 시트에서 추출했다. 비행 잔상·충격파·전격선·조명은 게임에서 생성한다.

`Source/`는 생성 당시 결과를 보존한다. `bulldog_equipped.png`, `coil_equipped.png` 생성본은 참고용이며 실제 게임에는 사용하지 않는다. 생성 지시는 `generation-prompts.json`, 원본 및 산출물 SHA-256은 `provenance.json`에 기록했다.

## 재생성

저장소 루트에서 Aseprite 정식 버전으로 실행:

```powershell
& "$env:LOCALAPPDATA\Programs\Aseprite\current\aseprite.exe" --batch --script-param "root=$((Get-Location).Path.Replace('\','/'))" --script Tools/Aseprite/build_weapon_concepts.lua
```

편집 원본은 `Aseprite/*.aseprite`, 런타임 PNG/피벗 JSON은 `GodotPrototype/assets/weapons/`에 저장된다. 가공 스크립트에는 추출 좌표, 분리 다각형, 피벗과 숨겨진 몸통 보완 범위가 명시돼 있다.

게임 구현·조작·검사 결과: `Docs/WEAPON_IMPLEMENTATION.md`.
