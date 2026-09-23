# Giant Toxic Tumor Crawler

The giant uses its own detailed animation textures. The standard crawler still uses the 10px-grid frames in `../ToxicTumorCrawler`.

- Five clips: `walk`, `jump`, `death`, `attack`, `roar`; four frames each.
- Every RGBA frame has a 1086 × 1512 cell. `crawler_meta.json` records the measured foot line and visible bounds per frame.
- The art comes from the archived, pre-grid character masters. The four roar frames come from the matching GameReady masters. `Tools/build_giant_crawler_assets.py` rebuilds this set.
- Matching normal maps live under `assets/normals/character/GiantToxicTumorCrawler` and are rebuilt with `Tools/build_normal_maps.py character/GiantToxicTumorCrawler`.
- In `Crawler.make_giant()`, the image scale is `0.4 × 3.5 ÷ 2 = 0.7`. The 2× frame dimensions make the world silhouette exactly 70% of the previous 5× giant.
- Spraying uses the attack animation; slamming uses the jump animation. Wall and corner animations are exclusive to the standard crawler.

The generic pixel-grid bake excludes this folder so the added source detail survives rebuilds.
