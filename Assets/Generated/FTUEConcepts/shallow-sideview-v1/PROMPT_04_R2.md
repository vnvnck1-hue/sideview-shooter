# 작업실 고정 배경 대비 보정 — r2

내장 image_gen. 입력: `04_workshop_remote_link.png`의 생성 원본. 기존 시안은 보존한다.

```text
Use case: lighting-weather / precise contrast edit.
Image 1 is the ONLY edit target: the pixel-art workshop. Keep exactly the same room layout, camera, crop, near-frontal shallow perspective, character identity, poses and scale, narrow walk strip, control desk silhouette, all equipment shapes and count, and all original material hues. Do not redraw this as a different scene.
Make one targeted art-direction correction: the large LEFT NONINTERACTIVE LATHE/MOTOR and its copper rotor are too contrasty and visually rival the RIGHT INTERACTIVE SECURITY CONSOLE. Compress the left fixed lathe's internal value range and lower its tiny highlights, especially the bright copper ridges, polished bolts, tools and handwheel. Keep copper recognizably the SAME copper hue, keep blue-grey steel its existing blue-grey hue. Pull these fixed assembly highlights into restrained midtones by roughly a third, preserving readable forms and crisp pixel boundaries. Subdue its little indicator lamps so they no longer pull attention. Keep the large background wall shapes readable. Do not apply a black veil or blur over the left half.
The robot and right blue-grey console must remain unchanged in hue, detail and overall brightness; their existing silhouette, hand lever and CRT become dominant by RELATIVE contrast. Do NOT repaint the console gold, mustard, yellow, orange, white or cyan. Do not add a halo, bright outline, selection ring, arrow, spotlight, HUD, text, border or watermark.
Keep the existing pixel-art cluster language, materials, wear placement and all geometry. One scene only; output the same panoramic composition.
```

