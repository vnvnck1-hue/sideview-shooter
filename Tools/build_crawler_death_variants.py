"""Assetize Imagegen six-cell death strips; preserve a fixed ground pivot and pose scale."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from build_normal_maps import height_map, normal_from_height
from bake_pixel_grid import bake

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Assets/Generated/CharacterAnimation/ToxicTumorCrawler/DeathVariants'
READY = ROOT / 'Assets/GameReady/Characters/ToxicTumorCrawler/DeathVariants'
CLIPS = {'death_inflate': 6.0, 'death_flyback': 7.5, 'death_agony': 3.75}

def main():
    for clip, fps in CLIPS.items():
        img = Image.open(SOURCE / f'{clip}_source.png').convert('RGBA')
        w, h = img.size
        cells = []
        for i in range(6):
            cell = img.crop((round(i*w/6), 0, round((i+1)*w/6), h))
            data = np.array(cell)
            mask = data[...,3] >= 128
            ys = np.where(mask.sum(axis=1) >= 6)[0]
            xs = np.where(mask.sum(axis=0) >= 6)[0]
            # Imagegen's near-transparent stray pixels must never move the ground pivot.
            clean = np.zeros_like(mask)
            clean[ys[0]:ys[-1]+1,xs[0]:xs[-1]+1] = mask[ys[0]:ys[-1]+1,xs[0]:xs[-1]+1]
            data[...,3] = clean.astype(np.uint8)*255
            cells.append(Image.fromarray(data))
        # One scale for the entire sequence so swelling and collapse remain visible.
        first = cells[0].getbbox()
        scale = 490 / (first[2] - first[0])
        scale = min(scale, 530/max(c.getbbox()[2]-c.getbbox()[0] for c in cells))
        bottom = max(c.getbbox()[3] for c in cells)
        authored = []
        for i, cell in enumerate(cells, 1):
            box = cell.getbbox()
            crop = cell.crop(box)
            crop = crop.resize((round(crop.width*scale), round(crop.height*scale)), Image.Resampling.NEAREST)
            frame = Image.new('RGBA', (543, 756))
            frame.alpha_composite(crop, ((543-crop.width)//2, 620-round((bottom-box[3])*scale)-crop.height))
            path = READY / clip / f'{clip}_{i:02d}.png'
            path.parent.mkdir(parents=True, exist_ok=True)
            frame.save(path)
            authored.append(frame)
        strip = Image.new('RGBA', (543*6, 756))
        for i, frame in enumerate(authored):
            strip.alpha_composite(frame, (543*i, 0))
        strip.save(READY / f'{clip}_sheet.png')
        preview = [f.resize((272,378), Image.Resampling.NEAREST) for f in authored]
        preview[0].save(READY / f'{clip}_preview.gif', save_all=True, append_images=preview[1:], duration=round(1000/fps), loop=0, disposal=2)
        for giant in (False, True):
            name = 'GiantToxicTumorCrawler' if giant else 'ToxicTumorCrawler'
            base = ROOT / 'GodotPrototype/assets/character' / name
            meta_path = base / 'crawler_meta.json'
            meta = json.loads(meta_path.read_text(encoding='utf-8'))
            meta['clips'][clip] = {'fps': fps, 'loop': False, 'frames': 6}
            for i, frame in enumerate(authored, 1):
                key = f'{clip}_{i:02d}'
                game = frame.resize((1086,1512), Image.Resampling.NEAREST) if giant else bake(frame,10,False)
                path = base / clip / f'{key}.png'
                path.parent.mkdir(parents=True,exist_ok=True)
                game.save(path)
                bbox = game.getbbox()
                meta['frames'][key] = {'feet_y': 1240 if giant else 620, 'bbox': list(bbox)}
                height, alpha = height_map(game,10 if giant else 5,1.4 if giant else .7)
                normal = normal_from_height(height,2.6)
                npth = ROOT / 'GodotPrototype/assets/normals/character' / name / clip / f'{key}.png'
                npth.parent.mkdir(parents=True,exist_ok=True)
                rgb = ((normal * 0.5 + 0.5) * 255).clip(0,255).astype(np.uint8)
                Image.fromarray(rgb).save(npth)
            meta_path.write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
        print(clip, '6 authored frames, normal + giant game assets')
    for name in ('ToxicTumorCrawler', 'GiantToxicTumorCrawler'):
        base = ROOT / 'GodotPrototype/assets/character' / name
        lines = ['[gd_resource type="SpriteFrames" load_steps=19 format=3]', '']
        animations = []
        idx = 0
        for clip, fps in CLIPS.items():
            frames = []
            for i in range(1,7):
                idx += 1
                lines.append(f'[ext_resource type="Texture2D" path="res://assets/character/{name}/{clip}/{clip}_{i:02d}.png" id="{idx}"]')
                frames.append('{"duration": 1.0, "texture": ExtResource("%s")}' % idx)
            animations.append('{"frames": [%s], "loop": false, "name": &"%s", "speed": %s}' % (', '.join(frames),clip,fps))
        lines += ['', '[resource]', 'animations = [%s]' % ',\n'.join(animations)]
        (base/'death_variants.tres').write_text('\n'.join(lines),encoding='utf-8')
    (READY/'clips.json').write_text(json.dumps({k:{'frames':6,'fps':v,'loop':False,'pivot':[271.5,620]} for k,v in CLIPS.items()},indent=2),encoding='utf-8')

if __name__ == '__main__':
    main()
