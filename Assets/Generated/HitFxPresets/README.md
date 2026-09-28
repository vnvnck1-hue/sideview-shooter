# Monster hit colour presets

`monster_hit_fx_presets.png` is captured from Godot 4.7.2 with the real
`ToxicTumorCrawler/walk_01.png` sprite and `prop_surface.gdshader`.

| Value | Preset | Duration | Intent |
|---:|---|---:|---|
| 0 | White Snap | 0.11 s | Metal Slug-style hard, full-body white hit |
| 1 | Complement Pulse | 0.17 s | Softer cyan/violet complementary shift that retains the source palette |
| 2 | Toxic Negative | 0.14 s | Acid-green/violet two-tone inversion for a mutant feel |
| 3 | Heat Echo | 0.20 s | White-hot ignition, red ember decay, and an expanding impact ring |

Runtime selection:

```gdscript
crawler.set_hit_fx_preset(0) # 0..3
```

Interactive comparison:

```text
godot --path GodotPrototype res://scenes/HitFxShowcase.tscn
```

Regenerate this image:

```text
godot --path GodotPrototype res://scenes/HitFxShowcase.tscn -- --capture
```
