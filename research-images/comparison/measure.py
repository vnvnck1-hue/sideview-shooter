"""Read-only image/geometry measurements for the background comparison."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
records = json.loads((OUT / 'capture_metadata.json').read_text(encoding='utf-8'))
report = {'capture_conditions': '2240x900, Forward+, zoom 0.75, camera lead temporarily disabled in a separate diagnostic process; no game settings changed', 'rooms': [], 'assets': []}
for rec in records:
    w, h = rec['viewport']
    area = 0
    mask = np.zeros((h,w), dtype=bool)
    for x,y,cw,ch in rec['columns_screen']:
        x0,y0,x1,y1 = max(0,x),max(0,y),min(w,x+cw),min(h,y+ch)
        area += max(0,x1-x0)*max(0,y1-y0)
        mask[max(0,round(y0)):min(h,round(y1)),max(0,round(x0)):min(w,round(x1))] = True
    im = np.asarray(Image.open(OUT / (rec['room'] + '_world.png')).convert('RGB'))
    luma = im @ np.array([.2126,.7152,.0722])
    report['rooms'].append({'room':rec['room'], 'room_silhouette_area_percent':round(100*area/(w*h),2), 'outside_silhouette_percent':round(100*(1-area/(w*h)),2), 'feet_y_percent':round(rec['player_feet'][1]/h*100,2), 'room_bbox_screen_size':[round(rec['room_world'][2]*rec['zoom'],2),round(rec['room_world'][3]*rec['zoom'],2)], 'luma_room_p10_p50_p90':np.percentile(luma[mask],[10,50,90]).round(2).tolist()})

paths = [
 'character/Frames/idle/idle_01.png',
 'character/Split/body/idle/idle_01.png',
 'character/Split/head/idle/idle_01.png',
 'props/workshop_locker_game_scale.png',
 'props/workshop_workbench_game_scale.png',
 'props/workshop_armchair_game_scale.png',
 'tiles/workshop_modular/workshop_modular_background_sheet_3x2.png',
 'tiles/research_analysis_modular/research_analysis_modular_background_sheet_3x2.png',
 'props/research_analysis/research_analysis_analysis_bench.png',
]
for rel in paths:
    path = ROOT / 'GodotPrototype/assets' / rel
    if not path.exists():
        continue
    img = Image.open(path).convert('RGBA')
    rgba = np.asarray(img)
    opaque = rgba[:,:,3]>0
    box = img.getchannel('A').getbbox()
    # Lowest number of non-uniform 4x4 blocks, excluding transparent blocks.
    best = 1.
    offset = None
    for oy in range(4):
        for ox in range(4):
            sub=rgba[oy:oy+((img.height-oy)//4)*4, ox:ox+((img.width-ox)//4)*4]
            blocks=sub.reshape(sub.shape[0]//4,4,sub.shape[1]//4,4,4).transpose(0,2,1,3,4).reshape(-1,16,4)
            valid=blocks[:,:,3].max(1)>0
            frac=np.any(blocks.max(1)!=blocks.min(1),axis=1)[valid].mean() if valid.any() else 0
            if frac<best: best=float(frac);offset=[ox,oy]
    report['assets'].append({'file':rel,'canvas':list(img.size),'opaque_bbox':box,'bbox_size':[box[2]-box[0],box[3]-box[1]],'bbox_art4':[round((box[2]-box[0])/4,2),round((box[3]-box[1])/4,2)],'opaque_rgb_colors':len(np.unique(rgba[opaque,:3],axis=0)),'nonuniform_4x4_blocks_percent':round(best*100,2),'grid_offset':offset})
(OUT/'measurements.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
