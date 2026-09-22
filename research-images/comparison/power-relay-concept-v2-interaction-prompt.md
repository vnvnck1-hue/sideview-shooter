# Power relay room — interaction readability v2

- Method: built-in image_gen, targeted reference-image edit.
- Input/edit target: power-relay-concept-v1.png.
- Output: power-relay-concept-v2-interaction.png. Previous concept preserved.
- Scope: concept illustration only; no runtime assets, scenes, settings or gameplay interactions changed.
- Design assumption: right-hand switchgear bank is the interactable assembly; left coils and architectural equipment are fixed background. This is a proposed visual role assignment, not a statement about existing game behavior.
- Change: reduce competing highlights on fixed machinery and give the right-hand control assembly a warm ochre body, broader light-dark range and more prominent functional controls. Preserve shallow side-view space, narrow floor, character placement and sparse foreground.
- Inspection: generated result visibly separates the warm control assembly from the cooler fixed machinery. No exact palette, grayscale-threshold or production-grid validation claimed.

## Final generation prompt

Use case: precise-object-edit.
Asset type: gameplay-readability paintover of the supplied pixel-art power relay room.
Input image 1 is the EDIT TARGET. Make ONE revised image, not a comparison sheet.
Primary request: the current noninteractive scenery and interactable props share the same visual treatment. Separate their VISUAL ROLES through deliberate tonal ranges, silhouette contrast and pixel-detail hierarchy, comparable to the legibility of classic arcade run-and-gun scenery. This is a targeted readability revision, NOT a new room design or perspective change.

STRICT INVARIANTS:
Keep the exact panoramic composition and shallow frontal side-view space. Preserve the location, scale and form of the red-hooded character, copper coil installations, right-hand switchgear bank, door, narrow floor and lower-corner conduits. Preserve the character's colors and strong silhouette. Keep the footline close to 88% frame height. Do not deepen the floor, shrink the player, relocate props, open distant space, add new objects, or change to an isometric view. Keep consistent crisp square pixel clusters everywhere.

GAMEPLAY ROLE ASSUMPTION FOR THIS CONCEPT:
The large LEFT copper coils, ivory insulators, wall pipes, structural beams, overhead bus bars and surrounding wall are FIXED NONINTERACTIVE BACKGROUND.
The RIGHT-HAND analog-gauge / lever switchgear cabinet bank is ONE INTERACTABLE PROP ASSEMBLY.
The red-hooded player is the PRIMARY moving gameplay subject.
The short lower-corner conduits are NONINTERACTIVE FOREGROUND FRAMING.
Communicate this distinction WITHOUT UI, labels, selection outlines, arrows, icons or floating interaction prompts.

BACKGROUND TREATMENT:
Retain all large electrical shapes, but group fixed machinery and architecture into a restrained cool blue-violet / muted copper family with a noticeably compressed local light-dark range. The background should remain readable and handsome, NOT almost black and NOT blurred. Reduce the bright white highlights on porcelain insulators, shiny copper coils, bolt heads and chipped edges. Make the insulators muted cool gray-lavender rather than brilliant white. Keep the copper identity as subdued brown-violet copper with broad controlled value steps instead of many sparkling gold stripes. Simplify small rivets/scuffs into fewer lower-contrast clusters. Background practical lamps may remain warm, but their tiny highlights should not compete with the interactive assembly. Reduce edge contrast at the outer contour of fixed machinery so it visually belongs to the wall. Do not use Gaussian blur, fog, low-resolution artifacts or a dark transparent veil that destroys the material planes. Repaint its pixel ramps thoughtfully.

INTERACTABLE RIGHT SWITCHGEAR:
Make this clearly read as a separately authored usable game prop, still physically integrated with the same shallow room. Preserve its housing shape, meters, levers, position and scale. Give the main cabinet body a restrained worn warm ochre / aged mustard painted metal, distinct from the cooler background; not electric yellow or neon. Use broader readable midtone front planes, confident dark seams and outer edges, selected pale warm highlights on bevels, cream meter faces and red-brown or vermilion operating handles. Maintain a substantially broader local value range than the backdrop. Slight localized grounding shadow and a slim dark separation at its perimeter help the silhouette detach without adding spatial depth. Concentrate crisp high-contrast functional detail on the gauges and handles; keep weathering subordinate. Indicators remain small. Do not make the entire cabinet glow, do not add a spotlight halo and do not add a thick cartoon or white outline. It should be instantly identifiable as an object the player can operate even at thumbnail size and even without the color difference.

FOREGROUND AND FLOOR:
Keep the same sparse cropped corner conduits, quiet dark cool shapes with little surface sparkle. Keep the narrow walk surface and its modest illumination. Do not add bright bolts everywhere along the floor edge.
Visual priority: player and its gun first, usable right switchgear second, fixed electrical background third, quiet edge framing last. Distinguish layers by ART DIRECTION and tonal treatment, not by more physical depth.
Single coherent polished pixel-art frame. No titles, legends, comparisons, HUD, prompts, arrows, selection glow, watermark, CRT filter or new atmospheric effects.

