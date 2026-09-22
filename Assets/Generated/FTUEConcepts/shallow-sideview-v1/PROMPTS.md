# FTUE shallow-sideview-v1 — prompts

2026-09-22. Built-in `image_gen`; CLI/API fallback not used. Each scene is a separate generated concept. User approval and runtime import pending.

## Shared prompt

```text
Use case: stylized-concept.
Asset type: individual full-frame environment-and-story concept for an original chunky pixel-art side-scrolling robot rescue game. Produce ONE finished panoramic image, approximately 2.49:1 aspect ratio (2240x900 composition), not a collage or storyboard sheet.
Art direction: Match the supplied preferred maintenance hall and power relay style references: rich crafted industrial pixel art, strong chunky silhouette design, deliberate stepped shade clusters, convincing steel and copper materials, organized wear concentrated at edges. Large architecture, medium functional assemblies, selective fine detail, with large quiet surfaces. This is a new room design, do not copy their workbenches and switchboards everywhere.
Critical spatial rule: WIDE BUT SHALLOW. Near-frontal side view, rear wall close to actors; lateral architecture fills the frame to the edges and overhead, not a little room floating inside a black rectangle. Thin local top and side faces only; narrow floor strip, clear horizontal feet line around 88% of image height. Standing player approximately 21–22% of image height, chunky red fabric hood, dark inset mechanical face with small amber rectangular eyes, compact tan/brown mechanical body and boots matching the hall reference. Preserve protagonist identity; no human face.
Depth comes from shallow wall recesses, overlapping mounting frames and contact shadows, never an expansive receding floor. Low restrained cropped foreground conduit ends only in lower corners, never across actors or functional controls. No giant near-camera machinery. No central tunnel vanishing point, isometric view, elevated camera or deep floor apron.
Color and gameplay hierarchy: preserve blue-violet/blue-grey/charcoal industrial metal, localized rust/copper, dirty ivory gauges, red hood, and restrained warm/cool lamps. Do NOT repaint functional props yellow or orange, do NOT give all props new bright accent colors. Fixed background machinery has a compressed local value range and subdued wear/bolts. Functional props retain their blue-grey material, readable mass, handles, switches and silhouette, separated using a calm darker wall immediately behind them and selective intrinsic highlights. Characters are most legible, usable props second, fixed architecture third. Crisp background pixels, not blurry or blacked out. No white outlines, glowing selection rings, halos or theatrical spotlight circles.
Output constraints: no HUD, health bars, minimap, captions, overlay instructions, speech balloons, logos, watermarks, decorative border or letterboxing. Do not add labels on top of the picture. In-world monitors may show simple pixel diagrams only. No photographic texture, smoothed illustration, glossy 3D render, excessive bloom, rainbow neon or CRT screen filter. No new platforms, stairs or extra storeys of gameplay.
```

## 01 · 에어록 — 기동 직후

Output: `01_airlock_reboot.png`

The final prompt is the shared prompt above followed by this scene brief:

```text
Scene: first moment after the robot's optical sensors focus during emergency reboot. Safe airlock interior, unsettling silence; no monsters and absolutely no gun on the player. Show the robot pushing itself upright from one knee, centered slightly left. Its hands are empty and feet meet the low walk line. A weary broad-built grey-haired caretaker in ochre-brown work clothes, based on reference 3, stands quietly on the right, noticing it but not speaking yet. He is human, not a second robot.
New environment design: massive round pressure bulkhead on the left built flat into the close wall; across the upper wall a broad ventilation plenum, horizontal pressure pipes and a few large circular gauges. On the right is a blue-grey waist-high communications console with a small recessed cyan CRT and physical handset, the future usable link terminal. A battered red upholstered maintenance chair sits near that terminal. One leaking overhead pipe drips into a narrow floor drain. A weak blue-white fluorescent and one small warm emergency beacon; enough light to read the background, not a pitch-black room.
Fixed pressure tanks/pipework and bulkhead are lower-contrast set dressing. The usable communications terminal is legible through its silhouette and functional controls, NOT a different overall hue. Keep a clean restful patch behind the red-hood robot. Tension from inactivity, not combat or a lab experiment. No manufacturing robot arms, no upright glass capsule, no extra humans.
Input roles: Image 1 preferred hall spatial/pixel/character style reference; Image 2 power room material and shallow-wall reference, not its exact equipment layout; Image 3 caretaker identity reference.
```

## 02 · 에어록 — 첫 생존자

Output: `02_airlock_first_contact.png`

The final prompt is the shared prompt above followed by this scene brief:

```text
Continuation of the immediately preceding airlock reboot scene. Preserve its complete physical environment, same camera, same pressure bulkhead, pipes, wall panels, floor, console and chair: this is the same room moments later. Change the actors' poses and staging to show the first conversation. The red-hood robot now stands fully upright, empty-handed, facing caretaker Arkady near the communications terminal. Arkady is a broad-built tired grey-haired man in ochre-brown work clothes, belt pressure gauge, grey beard and work boots, based on the supplied identity reference. He makes a restrained open-hand questioning gesture toward the robot. Both stand on the same shallow walk line and neither occludes the terminal's controls.
The blue-grey communications console remains the only emphasized usable prop: cyan small recessed screen, handset, switches, modest metallic functional edges, calm wall behind it. No recoloring of console or background. Slightly steadier practical light than during reboot, preserving all material colors. The atmosphere is uneasy human contact in a monster-free safe room. No weapon on the robot, no monsters, no holographic popup or dialogue text.
Input roles: Image 1 is the new airlock scene to continue with architecture and character identities preserved; Image 2 caretaker identity reference; Image 3 preferred maintenance hall style reference.
```

## 03 · 서쪽 정비 통로 — 첫 무장·전투

Output: `03_west_corridor_first_combat.png`

The final prompt is the shared prompt above followed by this scene brief:

```text
Scene: first small, readable combat immediately after weapon retrieval in a horizontal west maintenance corridor. The same red-hood robot stands left of center, holding its compact worn gun ready, facing right. Exactly ONE small hostile crawler on the right: green-olive swollen carapace/body with a few fleshy red legs, matching the hall reference creature language, much shorter than the player. No other enemies, no hidden silhouettes of a horde, no boss. No giant muzzle flash. A safe, readable encounter, not a catastrophic ambush.
New corridor architecture: a very long horizontal rounded air duct and pressure-line trunk occupy the upper close wall; a few wide steel panel bays and a closed flat service door, chunky framing at the sides. At left an opened blue-grey weapon cabinet shows one empty weapon mount (the robot just took that weapon). Around left-center a distinct compact blue-grey backup terminal has a small cyan diagnostic display and chunky connector sockets, actually usable. Farther right in the narrow walking floor is a FLUSH CLOSED low turret hatch, unpowered with unlit indicators: no deployed gun and no glowing marker.
Design different props from the references with functional logic. The cabinet opening and backup terminal read distinctly from the quieter fixed ductwork, with the SAME natural dark-grey materials, no gold repaint. Calm wall field behind actor and crawler. Small foreground cable clips cropped only at the far lower corners. Low lateral floor, no view looking down a corridor.
Input roles: Image 1 preferred maintenance hall spatial/style/player/creature reference; Image 2 power room material/shallow-wall reference. Neither is a layout to duplicate.
```

## 04 · 작업실 — 원격 조종

Output: `04_workshop_remote_link.png`

The final prompt is the shared prompt above followed by this scene brief:

```text
Scene: the robot alone in a workshop operating the security remote-link station. It is physically here; the remote target is a turret in the west corridor, shown only as a simple pixel schematized corridor/turret feed inside the console's built-in small CRT screen. This is NOT a split-screen composition, not a second robot in the room. The red-hood robot stands at the controls slightly right of center, hand on a chunky physical lever/control, own weapon lowered safely and not firing.
New architecture: a broad stationary lathe/motor winding fixture is mounted along the left rear wall as background, thick horizontal ducts over it; above are tightly rolled chain hoist and ribbed ventilation housings, not a deep second floor. Mid-right, the usable security terminal is a sturdy blue-grey angled operator desk with a hooded screen, physical lever, rugged connector panel and small amber/cyan status lamps. The screen and hand control are easy to read with no broad flood of light. A quiet vertical wall panel directly behind the station separates its silhouette.
Fixed bench machine, coiled hoses and tool rack are muted lower-contrast background, not every tool sparkling equally. The main interactive terminal remains original blue-grey steel, NOT mustard yellow, gold, orange or bright white. No giant bank of identical screens, no extra NPC, no monsters, no holographic UI hovering above the robot. Tiny cropped corner hose bundle as foreground, horizontal clear narrow floor.
Input roles: Image 1 preferred maintenance hall spatial/pixel/player style reference; Image 2 power room material/shallow-wall reference. Redesign the machinery for this workshop, not a copy of either room.
```

## 05 · 대형 정비홀 — 첫 위기

Output: `05_maintenance_hall_first_crisis.png`

The final prompt is the shared prompt above followed by this scene brief:

```text
Scene: the opening's first unwinnable encounter in the high-ceiling maintenance hall, just before the first robot death. Red-hood robot left of center at the usual large readable size, recoiling slightly with its gun lowered after ammunition runs low; it is not dismembered and not tiny. Four crawling creatures advance from the right in a readable staggered row, green-olive swollen backs and red fleshy legs matching Image 1; one partly entering at the far right implies continuous arrivals. Do not fill the whole floor with effects. Small few empty cartridge cases near the player, no large fireball.
Architecture: reinterpret the accepted maintenance hall with wide, high industrial scale but a CLOSE rear wall. Huge flat shut loading bulkhead on the left has visible locking bars, large stationary fan housings on the middle upper wall, an overhead maintenance crane rail spanning laterally, hoist parked high, hefty wall supports at wide intervals. One fixed disassembled motor fixture sits at the right rear, not repeated symmetrical workbenches. Wide wall masses and upper equipment imply scale without expanding the floor or shrinking the hero. No deep hangar perspective.
Set dressing and fan blades stay quieter/darker with compressed highlights than the combat silhouettes. Background blue-grey steel and local rust remain natural; sparse red emergency lamps can tint small local patches but MUST NOT wash the whole scene red. No new interactable golden cabinet inserted into combat, no colorful pickup pile. Thin local top surfaces, floor near 88% height, low cropped dark cable/conduit ends only at corners, no large boxes hiding feet. No HUD, game-over card, corpse scene or ending credits.
Input roles: Image 1 preferred maintenance hall spatial/style/player/creature anchor, preserve its shallow visual grammar but reorganize functional background; Image 2 material/shallow-wall reference.
```

