# 크롤러 죽음 애니메이션 3종

기존 death 클립에 6프레임 클립 세 가지를 추가했다. 일반·거대 크롤러 모두 치명타를 받으면 네 클립 중 하나를 같은 확률로 선택한다. Crawler.death_style은 0=랜덤, 1=기존, 2=팽창 폭발, 3=뒤로 날아감, 4=고통이다.

|클립|길이|죽음 VFX|
|---|---|---|
|death_inflate|1.0초|5번째 프레임에서 방사형 체액·비말, 더 많은 육편, 넓은 벽/바닥 자국|
|death_flyback|약 0.8초, 공중 사망 시 착지까지 연장|탄 진행 방향으로 날아가는 포물선, 시작의 가는 체액 꼬리, 착지의 낮은 방향성 비산·먼지·소량 육편|
|death_agony|1.6초|경련하는 동안 작은 체액 누출, 쓰러질 때 좁은 바닥 비산, 육편 없음|

원화는 built-in Imagegen으로 생성했으며 프롬프트는 Assets/Generated/CharacterAnimation/ToxicTumorCrawler/DeathVariants/PROMPTS.md에 보관했다.

## 리소스

- 원화: Assets/Generated/CharacterAnimation/ToxicTumorCrawler/DeathVariants/*_source.png
- 가공 클립: Assets/GameReady/Characters/ToxicTumorCrawler/DeathVariants — 18개 투명 PNG 프레임, 3개 시트, 3개 GIF, clips.json.
- 게임 에셋: GodotPrototype/assets/character/{ToxicTumorCrawler,GiantToxicTumorCrawler}/{death_inflate,death_flyback,death_agony}
- Godot 애니메이션: 각 몬스터 폴더의 death_variants.tres (SpriteFrames). 게임 프레임 빌더가 해당 리소스를 사용한다.
- 라이팅: 대응하는 assets/normals/character 경로의 노멀맵 36개.

재가공: 번들 Python 또는 Pillow/NumPy가 있는 Python으로 `python Tools/build_crawler_death_variants.py`를 실행한 다음 Godot에서 프로젝트를 import한다. 기존 원화/기존 모션은 덮어쓰지 않는다. 전체 시퀀스에 같은 배율과 고정 접지점(543×756 셀의 y=620, 거대종은 2배)을 적용한다. 근투명 생성 잡음은 접지점을 계산하기 전에 제거한다.

## 미리보기와 검증

Godot에서 scenes/CrawlerDeathLab.tscn을 열고 F6을 누르면 실제 Crawler 세 모션과 VFX가 반복된다.

`godot --headless --path GodotPrototype res://scenes/CrawlerDeathLab.tscn -- --validate`

16가지 조건(기존 포함 4종 × 일반/거대 × 좌우 및 공중 사망)으로 클립, 죽은 몬스터 피격 차단, 신호 단발성, 착지, VFX 이벤트, 잔해 프레임, 경련 종료, 7초 뒤 정리를 확인한다.

`godot --headless --path GodotPrototype res://scenes/CrawlerDeathLab.tscn -- --game-validate`

실제 Main/Room에서 3종을 스폰하고 치명타를 주어 죽음 처리와 Room의 체액 자국/분사를 확인한다. 둘 다 PASS. Compatibility 렌더링으로 0.15/0.40/0.70/1.10/1.65초 화면을 캡처하고 시각 검수했다(Docs/crawler_death_review).

이 환경의 headless 렌더러는 기존 라이팅 셰이더의 custom_sampler 진단을 출력한다. 화면 검수는 GPU Compatibility 렌더링으로 별도로 수행했다.
