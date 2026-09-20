# Aseprite pipeline probe

이 폴더는 `Tools/Aseprite/run_pipeline_probe.ps1`의 재현 가능한 검증 산출물이다. 게임에 직접 사용하는 리소스가 아니라 Aseprite 로컬 설치, Lua 픽셀 제작, 레이어·프레임·태그 보존, PNG/JSON 내보내기와 Native4 규격 검사가 모두 작동하는지 확인한다.

- 원본: `native32_pipeline_probe.aseprite`
- 출력: `native32_pipeline_probe_sheet.png`
- 메타데이터: `native32_pipeline_probe_sheet.json`
- 프레임: 32×32 네이티브 픽셀 4장
- 시트: 128×32 RGBA8888
- 알파: 0/255
- 불투명 색상: 8색

재생성:

```powershell
powershell.exe -ExecutionPolicy Bypass -File Tools/Aseprite/run_pipeline_probe.ps1
```

