# 장애물 프랍 5종 — 컨셉 v1

제작: built-in image_gen. 컨셉 시트 및 기존 작업실 배경을 입력한 생성형 합성 시안이며, 게임 코드/충돌/데미지 구현은 포함하지 않는다.

| 번호 | 프랍 | 통과 방식 | 표현 |
|---|---|---|---|
| 01 | 낮은 철제 방호벽 | 점프 / 총격으로 파괴되지 않음 | 노란 경고 띠, 무거운 받침, 탄흔 |
| 02 | 케이블 드럼 | 점프 / 총격으로 파괴되지 않음 | 원형 플랜지, 감긴 케이블, 고정 받침 |
| 03 | 목재 보급 상자 | 점프 또는 사격 파괴 | 나무 판자와 철제 보강, 파괴 후 낮은 파편 |
| 04 | 균열 콘크리트 잔해 | 사격으로 파괴해 통로 확보 | 큰 균열, 노출 철근, 파괴 후 작은 돌무더기 |
| 05 | 폭발 가스통 | 사격 파괴 → 폭발 → 통로 확보 | 붉은 압력 용기, 밸브 보호대, 화염 표식 |

가스통 기믹 제안: 내구도가 소진되면 한 번 폭발하여 반경 내 적·플레이어·파괴 가능한 프랍에 거리별 피해를 준다. 근처 가스통에는 연쇄 폭발을 유발할 수 있다. 폭발 후 이동 충돌을 해제하고 찢어진 외피만 시각 잔해로 남긴다. 피해량, 반경, 내구도는 실제 구현 단계에서 조정한다.

시트의 프랍은 디자인을 읽기 위한 확대 표현이다. 배경 합성의 캐릭터 비교를 기준으로 실제 크기를 검토한다. 최종 런타임 스프라이트, 알파 분리, 픽셀 그리드 정규화 및 충돌 판정은 후속 제작 대상이다.

## 파일
- 01_prop_concepts.png: 원형 5종 및 피격/파손 상태
- 02_workshop_composite.png: 프로젝트 작업실 배경에 5종 배치

## 사용한 배경
Deliverables/SideviewPixelArtResourcePack/07_Validation/workshop_long_room_background_tiles_only.png

## 생성 프롬프트

### 컨셉 시트
Use case: stylized-concept. Create a polished pixel-art game obstacle concept sheet for this existing side-view shooter. Input image 1 is STYLE AND SCALE REFERENCE ONLY: match its chunky pixel clusters, near-black outlines, distressed industrial materials, blue-gray shadows, warm edge highlights and strict side-view, not isometric. Do not reproduce the room. Design EXACTLY FIVE props, in five equally spaced columns on dark blue-black neutral background, large readable intact sprites top row, smaller damaged/end-state sprites directly below. Wide landscape sheet. Clean editorial spacing, consistent ground baseline. Header text "OBSTACLE PROPS / 01–05". Column labels only: "01 BARRICADE", "02 CABLE REEL", "03 SUPPLY CRATE", "04 RUBBLE BLOCK", "05 GAS CYLINDER".
01: low heavy steel portable barricade, wide angular base, faded yellow-black caution stripe, blue steel rusty edges, solid filled body that physically blocks walking, approx 0.55 player height. Bulletproof jump-over obstacle. Below show same silhouette with bullet dents.
02: squat horizontal-axis industrial cable spool viewed from side, broad circular rusty wooden/steel flange and dense wrapped dark cable, approx 0.75 player height, flat stable foot, jump-over sturdy obstacle. Below bullet-scarred intact spool.
03: waist-high single wooden supply crate with diagonal wood brace and olive metal corner straps, visibly fragile yellow-brown wood, approx 0.65 player height. Shoot to break or jump over. Below collapsed planks and metal straps leaving floor passage.
04: cracked upright concrete rubble block with embedded rusted rebar, broken industrial partition remnant, approx 1.05 player height and narrower than crate, a strongly visible broad diagonal fracture and chipped pale stone expose vulnerability. Shoot to shatter. Below low pile of broken concrete and bent rebar, clear path.
05: red pressurized GAS CYLINDER, tall narrow tank with rounded shoulder, protected valve cage and tiny pressure gauge, heavy foot ring, chipped vermilion paint, cream band and simple flame hazard pictogram, approx 0.8 player height. Not an oil barrel. Shoot causes explosion and radial area damage. Below ruptured empty cylinder shell and a small orange-yellow pixel explosion effect, visually distinct from the intact tank.
Include one small red-hooded reference player silhouette at far left margin for scale, matching reference. Five props are coherent environment sprites with strong readable silhouettes, no photorealism, no smooth airbrush, no 3D render, no UI clutter. Bottom text under each column respectively "JUMP", "JUMP", "BREAK / JUMP", "BREAK", "EXPLODE / AOE". High-quality art design review sheet, not implementation.

### 배경 합성
Use case: compositing. Image 1 is the ACTUAL GAME BACKGROUND EDIT TARGET. Preserve exactly its long workshop room architecture, blue brick wall, cracks, ceiling and floor tiles, pipes, vent positions, hanging lamp, dark outside border, fixed straight side view and original wide aspect ratio. Do not redesign the room or turn it into a perspective illustration. Image 2 is the PROP DESIGN INPUT: insert all five intact top-row props from it, preserving recognizable silhouettes, materials, colors and crisp pixel art. Image 3 is PLAYER REFERENCE ONLY, insert that red hood player, do not copy its furniture.
Create a single in-game art mockup with all five props resting on the SAME walkable floor baseline, making their collision role obvious. Show all props completely with generous horizontal gaps, never overlapping one another. Place the red hood player at far left, about the same on-screen size as the player in image 3, approximately 18% of interior room height. Then from left to right: 01 low steel caution barricade, 02 cable reel, 03 wooden supply crate, 04 cracked upright concrete rubble block, 05 red gas cylinder.
CRITICAL SCALE: use player height as H; barricade 0.55H, reel 0.75H, crate 0.65H, rubble 1.05H, gas cylinder 0.8H. The concept sheet image 2 exaggerated some props relative to the small player; RESCALE them here to these gameplay heights. All props are in front of back wall, feet flush on walkable top floor edge. Keep background visually subdued and add subtle warm top-left pixel highlights/contact shadows so interactive props separate from walls. Maintain same pixel resolution density as original art; no smoothed edges or photorealistic glow.
Place only small discrete numeric identifiers 01 02 03 04 05 above each prop, no lines or UI panels. In dark top margin add small clean title "WORKSHOP / OBSTACLE LAYOUT". In dark bottom margin add restrained legend: "01–02  JUMP     03  BREAK / JUMP     04  BREAK     05  EXPLODE / AOE". Intact props only in this main room, gas tank must be unlit and visibly a pressurized cylinder with valve and flame pictogram. This is a readable actual game background composite, not a new background concept or cinematic scene.

### 캐릭터 스케일 조정
Use case: precise-object-edit. Edit this game background composite with ONE change only: enlarge the red hood player at far left to approximately 180 pixels tall in this 1962x801 reference (currently about 118), keeping feet on the same floor baseline at y=568, same x-center around 230, same pose, same sprite design, sharp pixel clusters. Thus head should rise to approximately y=388. The larger player establishes gameplay scale: low barricade is waist high, cable reel below head, crate chest high, cracked concrete slightly taller than player, gas cylinder a little shorter than player. Keep all five props EXACTLY unchanged in size, location, design. Keep wall, lamp, pipes, floors, background, labels, margins and all text unchanged. No additional props, no new UI, no retouch elsewhere. Preserve original wide aspect ratio.

