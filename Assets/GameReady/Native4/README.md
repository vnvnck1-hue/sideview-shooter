# Native4 — 네이티브 4px 규격 원본

이미지 1 px = 아트 1 px = 게임 월드 4 px = 화면 2 px. 규격·크기표·그리는 법은 `Docs/ART_GUIDE.md` §10.

- 하위 폴더 구조는 `GodotPrototype/assets/` 와 같게 둔다 (예: `tiles/workshop_modular/…`, `props/…`, `character/Split/body/idle/idle_01.png`).
- 반입: 저장소 루트에서 `python Tools/upscale_native4.py` → `python Tools/build_normal_maps.py` → `GodotPrototype/run.bat`(헤드리스 임포트 포함).
- 알파는 0 또는 255 만. 반투명 픽셀이 있으면 반입 스크립트가 그 파일을 건너뛴다.
