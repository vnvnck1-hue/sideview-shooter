# 의료 처치실 — 2배 픽셀

사용자가 3배·4배 결과는 너무 깨진다고 평가하고 **2배로 변경**하도록 요청해 만든 결과다. 여기서 2배는 원본 샘플링 간격 `pixelPitch=2.0`이며 게임 출력 배율이 아니다. 현재 선택·후속 외관 피드백·게임 적용 상태는 [ART_ASSET_STATUS](../../../../../Docs/ART_ASSET_STATUS.md)에서 관리한다. 다른 자산의 배율을 일괄 변경하지 않았다.

- [Aseprite](retro_medical_triage_room_concept_v1.aseprite)
- [네이티브 PNG](retro_medical_triage_room_concept_v1.png)
- [원본과 같은 크기의 전체 미리보기](review/2x-source-size.png)
- 확대 비교(원본 / 새 2배 / 이전 3배): [모니터](review/monitor-source-2x-3x.png), [세면대](review/wash-source-2x-3x.png), [침대](review/bed-source-2x-3x.png)

원본 1672×941 → 내용 영역 836×471, 투명 여백 포함 캔버스 **838×473**. 출력색 2,472개, 알파 0/255. 전체 미리보기는 정수 Nearest 2배이며 마지막 부분 셀과 투명 여백을 원본의 표시 범위에 맞춰 잘랐다.

기존 `r2/prepared/`의 전체 해상도 원본 기반 준비 문서를 다시 검사한 뒤 재사용했다. 색 보존 설정 `Tolerance=4 / Snap=20 / Coherent=true / Passes=3`과 원본색 선택 방식은 같다. **3배·4배 완성본을 확대하거나 재축소한 것이 아니다.** 원본 기반 준비 단계에서 독립적으로 2배 격자를 선택했다. 평균색·블러·추가 대비·디더링은 없다.

시각 비교에서 모니터의 파형, 세면대 수도꼭지와 금속 테두리, 침대 담요의 작은 묘사가 3배보다 더 남는다. 일부 미세 선과 색 변화는 여전히 정리되므로 무손실 변환은 아니다. 3배·4배 결과는 비교 기록으로 보존하고 기본 선택에서 제외한다.

[verification.json](verification.json): 원본/준비 문서 불변, 원본 참조와 레이어 검사, 최종 Aseprite 재열기·PNG RGBA 전 픽셀 일치, 원본/준비본에 없는 출력 RGB 0개, 치수·이진 알파·투명 여백을 검증했다. 원본과 기존 게임 리소스는 변경하지 않았다.

이 JSON의 승인 필드는 실행 당시 스냅샷이다. 이후 피드백은 위 상태 문서에서 확인하며 재현 실행이 사용자 승인을 자동으로 생성하지 않는다. 방 전체 그림의 변환은 개별 프랍·타일 분리나 게임용 조립 검수를 대신하지 않는다.

재현(저장소 루트):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/Aseprite/build_triage_room_two_x.ps1 -RunName two-x-repro
```

기존 출력 폴더가 있으면 중단한다. 준비 문서는 `../r2/prepared/`에 있으므로 해당 폴더를 함께 보존한다.
