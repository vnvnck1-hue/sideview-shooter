"""Author three clean research room kits at native 4 px art resolution.

Run with the bundled Python runtime. Outputs native sources, 4x game assets,
tile atlases, transparent props, metadata, and assembled validation previews.
"""
from __future__ import annotations

import json
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "Assets/GameReady/Native4"
READY = ROOT / "Assets/GameReady"
RUNTIME = ROOT / "GodotPrototype/assets"
VALIDATION = READY / "Validation"
S = 4
CELL = 32
ROOMS = {
    "research_analysis": {
        "title": "검체 분석실 / Specimen Analysis",
        "wall": "#879da6", "panel": "#99adb4", "light": "#b7c8c8", "shade": "#667e89",
        "line": "#526d79", "deep": "#314b5b", "floor": "#b7c4c2", "accent": "#77c5b7",
        "glass": "#9bc9c9", "screen": "#408f91", "warm": "#d4d5c6",
        "props": ["specimen_chamber", "analysis_bench", "microscope_station", "cold_storage", "sample_cart"],
    },
    "research_isolation": {
        "title": "멸균·격리실 / Decontamination & Isolation",
        "wall": "#94a5ad", "panel": "#aab9bd", "light": "#d1d9d6", "shade": "#748992",
        "line": "#5e747e", "deep": "#374f5c", "floor": "#c4d0cc", "accent": "#75c8da",
        "glass": "#aedbe0", "screen": "#4b98ac", "warm": "#d8dcd4",
        "props": ["decon_arch", "isolation_pod", "wash_station", "medical_cabinet", "uv_sterilizer"],
    },
    "research_diagnostics": {
        "title": "진단 관제실 / Diagnostics Control",
        "wall": "#81939f", "panel": "#96a8b2", "light": "#c1ced0", "shade": "#617886",
        "line": "#4c6573", "deep": "#293f53", "floor": "#acbdc2", "accent": "#85b8e1",
        "glass": "#91b9c9", "screen": "#39799b", "warm": "#d3d5cc",
        "props": ["diagnostic_console", "server_rack", "wall_display", "signal_scope", "drone_dock"],
    },
}


def rgba(hex_color: str, alpha=255):
    h = hex_color.lstrip("#")
    return tuple(bytes.fromhex(h)) + (alpha,)


def new(w, h, fill=None):
    return Image.new("RGBA", (w, h), rgba(fill) if fill else (0, 0, 0, 0))


def rect(d, box, c):
    d.rectangle(box, fill=rgba(c))


def line(d, points, c, width=1):
    d.line(points, fill=rgba(c), width=width)


def save(img, rel, ready_rel=None):
    source = NATIVE / rel
    source.parent.mkdir(parents=True, exist_ok=True)
    img.save(source, optimize=True)
    large = img.resize((img.width*S, img.height*S), Image.Resampling.NEAREST)
    target = RUNTIME / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    large.save(target, optimize=True)
    if ready_rel:
        path = READY / ready_rel
        path.parent.mkdir(parents=True, exist_ok=True)
        large.save(path, optimize=True)
    return large


def make_bg(p, variant):
    im = new(CELL, CELL, p["wall"])
    d = ImageDraw.Draw(im)
    # The edge colors match across every variation. Detail stays inside the cell.
    rect(d, (0, 0, 31, 0), p["line"])
    rect(d, (0, 1, 31, 2), p["light"])
    rect(d, (0, 30, 31, 31), p["line"])
    rect(d, (0, 28, 31, 29), p["shade"])
    rect(d, (1, 3, 30, 27), p["panel"])
    rect(d, (2, 4, 29, 5), p["light"])
    rect(d, (1, 6, 2, 25), p["light"])
    rect(d, (29, 6, 30, 26), p["shade"])
    if variant == 1:
        rect(d, (6, 8, 25, 9), p["light"])
        rect(d, (6, 10, 25, 10), p["shade"])
    elif variant == 2:
        rect(d, (4, 14, 27, 14), p["shade"])
        rect(d, (4, 15, 27, 15), p["light"])
        rect(d, (6, 18, 8, 18), p["accent"])
    elif variant == 3:
        rect(d, (21, 8, 26, 20), p["shade"])
        rect(d, (22, 9, 25, 18), p["glass"])
        rect(d, (22, 19, 25, 19), p["line"])
    elif variant == 4:
        rect(d, (5, 9, 9, 10), p["line"])
        rect(d, (6, 10, 8, 10), p["accent"])
        rect(d, (11, 9, 15, 10), p["line"])
        rect(d, (12, 10, 14, 10), p["light"])
    elif variant == 5:
        rect(d, (4, 24, 27, 25), p["shade"])
        rect(d, (4, 23, 27, 23), p["light"])
    return im


def make_frame(p, kind):
    im = new(CELL, CELL)
    d = ImageDraw.Draw(im)
    top = kind in ("top", "top_left", "top_right")
    bottom = kind in ("bottom", "bottom_left", "bottom_right")
    left = kind in ("left", "top_left", "bottom_left")
    right = kind in ("right", "top_right", "bottom_right")
    if top:
        rect(d, (0, 0, 31, 11), p["deep"])
        rect(d, (0, 2, 31, 3), p["shade"])
        rect(d, (0, 4, 31, 9), p["light"])
        rect(d, (0, 10, 31, 11), p["line"])
        if kind == "top":
            rect(d, (10, 5, 21, 7), p["accent"])
    if bottom:
        rect(d, (0, 20, 31, 31), p["deep"])
        rect(d, (0, 20, 31, 21), p["line"])
        rect(d, (0, 22, 31, 25), p["floor"])
        rect(d, (0, 26, 31, 26), p["light"])
        rect(d, (0, 27, 31, 31), p["shade"])
        if kind == "bottom":
            rect(d, (14, 23, 17, 24), p["line"])
    if left:
        rect(d, (0, 0, 13, 31), p["deep"])
        rect(d, (2, 0, 3, 31), p["shade"])
        rect(d, (4, 0, 11, 31), p["light"])
        rect(d, (12, 0, 13, 31), p["line"])
        if kind == "left":
            rect(d, (5, 15, 9, 16), p["shade"])
    if right:
        rect(d, (18, 0, 31, 31), p["deep"])
        rect(d, (18, 0, 19, 31), p["line"])
        rect(d, (20, 0, 27, 31), p["light"])
        rect(d, (28, 0, 29, 31), p["shade"])
        if kind == "right":
            rect(d, (23, 15, 27, 16), p["shade"])
    # Corners need a visible beveled junction.
    if (top or bottom) and (left or right):
        x = 10 if left else 20
        y = 8 if top else 22
        rect(d, (x, y, x+1, y+1), p["accent"])
    return im


def make_bend(p, name):
    im = new(CELL, CELL)
    src = make_frame(p, "top_left" if name == "top_left" else "top_right" if name == "top_right" else "bottom_left" if name == "bottom_left" else "bottom_right")
    box = (0, 0, 14, 12) if name == "top_left" else (18, 0, 32, 12) if name == "top_right" else (0, 20, 14, 32) if name == "bottom_left" else (18, 20, 32, 32)
    im.paste(src.crop(box), box[:2])
    return im


def body(d, p, box, top=3, side=4):
    x0,y0,x1,y1=box
    rect(d, (x0,y0,x1,y1), p["deep"])
    rect(d, (x0+1,y0+top,x1-side,y1-1), p["warm"])
    rect(d, (x0+1,y0+1,x1-side,y0+top-1), p["light"])
    rect(d, (x1-side+1,y0+1,x1-1,y1-1), p["shade"])
    rect(d, (x0+2,y0+top+1,x1-side-2,y0+top+1), p["light"])


def screen(d, p, box, bars=True):
    x0,y0,x1,y1=box
    rect(d, box, p["deep"])
    rect(d, (x0+2,y0+2,x1-2,y1-2), p["screen"])
    rect(d, (x0+3,y0+3,x1-3,y0+4), p["accent"])
    if bars and x1-x0>14:
        rect(d, (x0+4,y1-5,x0+8,y1-4), p["glass"])
        rect(d, (x0+10,y1-8,x0+13,y1-4), p["glass"])
        rect(d, (x0+15,y1-6,x0+18,y1-4), p["glass"])


def glass(d,p,box):
    x0,y0,x1,y1=box
    rect(d, box, p["line"])
    rect(d, (x0+2,y0+2,x1-2,y1-2), p["glass"])
    rect(d, (x0+4,y0+3,x0+5,y1-5), p["light"])
    rect(d, (x1-4,y0+4,x1-3,y1-3), p["shade"])


def prop(name,p):
    sizes={
        "specimen_chamber":(52,84), "analysis_bench":(96,53), "microscope_station":(55,59),
        "cold_storage":(56,75), "sample_cart":(63,48), "decon_arch":(79,102),
        "isolation_pod":(102,62), "wash_station":(65,59), "medical_cabinet":(54,79),
        "uv_sterilizer":(54,68), "diagnostic_console":(94,62), "server_rack":(61,88),
        "wall_display":(100,53), "signal_scope":(58,65), "drone_dock":(80,55),
    }
    w,h=sizes[name]
    im=new(w,h); d=ImageDraw.Draw(im)
    if name=="specimen_chamber":
        body(d,p,(5,3,w-6,h-2),4,5); glass(d,p,(11,12,w-15,h-17))
        rect(d,(18,25,w-23,54),p["screen"]); rect(d,(20,28,w-25,50),p["accent"])
        rect(d,(13,h-14,w-17,h-12),p["accent"]); rect(d,(10,h-3,w-12,h-1),p["deep"])
    elif name=="analysis_bench":
        body(d,p,(2,23,w-3,34),3,5); rect(d,(8,33,14,h-2),p["shade"]); rect(d,(w-16,33,w-10,h-2),p["shade"])
        body(d,p,(11,5,49,23),2,4); screen(d,p,(17,8,43,19)); rect(d,(57,16,77,22),p["glass"])
        rect(d,(61,11,72,15),p["light"]); rect(d,(25,34,48,41),p["deep"]); rect(d,(27,36,46,39),p["warm"])
    elif name=="microscope_station":
        body(d,p,(8,34,w-8,h-2),3,4); rect(d,(18,7,37,11),p["deep"])
        rect(d,(22,9,31,25),p["shade"]); rect(d,(27,22,42,26),p["deep"])
        rect(d,(39,25,45,34),p["line"]); rect(d,(16,29,46,33),p["light"])
        rect(d,(20,42,33,43),p["accent"])
    elif name=="cold_storage":
        body(d,p,(5,2,w-6,h-2),4,5); rect(d,(10,10,w-15,36),p["light"])
        rect(d,(10,39,w-15,h-11),p["light"]); rect(d,(12,37,w-17,38),p["line"])
        rect(d,(34,20,37,29),p["shade"]); rect(d,(34,51,37,60),p["shade"])
        rect(d,(16,11,27,13),p["accent"])
    elif name=="sample_cart":
        body(d,p,(5,13,w-6,24),2,4); body(d,p,(8,29,w-9,37),2,4)
        rect(d,(11,23,14,h-7),p["line"]); rect(d,(w-16,23,w-13,h-7),p["line"])
        rect(d,(11,4,19,12),p["glass"]); rect(d,(24,6,34,12),p["accent"])
        rect(d,(14,h-6,19,h-1),p["deep"]); rect(d,(w-20,h-6,w-15,h-1),p["deep"])
    elif name=="decon_arch":
        rect(d,(3,2,w-4,h-1),p["deep"]); rect(d,(8,7,w-9,h-1),p["light"])
        rect(d,(18,20,w-19,h-1),p["glass"]); rect(d,(22,23,w-23,h-1),p["panel"])
        rect(d,(10,11,w-11,16),p["accent"]); rect(d,(11,29,15,75),p["accent"])
        rect(d,(w-16,29,w-12,75),p["accent"]); rect(d,(5,h-5,w-6,h-1),p["shade"])
    elif name=="isolation_pod":
        body(d,p,(3,27,w-4,h-3),3,5); glass(d,p,(9,9,w-11,33))
        rect(d,(17,13,29,29),p["light"]); rect(d,(32,14,72,27),p["warm"])
        rect(d,(74,15,87,25),p["accent"]); rect(d,(9,h-9,w-10,h-7),p["shade"])
    elif name=="wash_station":
        body(d,p,(6,29,w-7,h-2),3,4); rect(d,(11,18,w-12,30),p["light"])
        rect(d,(17,22,w-18,27),p["glass"]); rect(d,(30,6,33,19),p["line"])
        rect(d,(31,6,46,8),p["line"]); rect(d,(44,8,46,14),p["line"])
        rect(d,(12,39,27,42),p["accent"])
    elif name=="medical_cabinet":
        body(d,p,(5,2,w-6,h-2),4,5); glass(d,p,(11,11,w-15,45))
        rect(d,(17,21,33,26),p["light"]); rect(d,(22,16,27,32),p["light"])
        rect(d,(13,51,w-17,53),p["shade"]); rect(d,(16,59,34,62),p["accent"])
    elif name=="uv_sterilizer":
        body(d,p,(5,7,w-6,h-2),4,5); glass(d,p,(11,17,w-15,47))
        rect(d,(15,22,w-19,25),p["accent"]); rect(d,(15,38,w-19,40),p["screen"])
        rect(d,(17,52,30,54),p["accent"]); rect(d,(10,3,w-11,8),p["deep"])
    elif name=="diagnostic_console":
        body(d,p,(3,29,w-4,h-2),4,6); screen(d,p,(10,7,48,30)); screen(d,p,(51,11,w-11,32))
        rect(d,(15,42,39,44),p["accent"]); rect(d,(48,42,73,44),p["line"])
        rect(d,(12,51,18,h-1),p["shade"]); rect(d,(w-20,51,w-14,h-1),p["shade"])
    elif name=="server_rack":
        body(d,p,(5,2,w-6,h-2),4,5)
        for y in (12,25,38,51,64):
            rect(d,(11,y,w-15,y+9),p["deep"]); rect(d,(15,y+3,34,y+4),p["shade"])
            rect(d,(39,y+3,43,y+4),p["accent"]); rect(d,(46,y+3,48,y+4),p["light"])
    elif name=="wall_display":
        body(d,p,(1,1,w-2,h-2),3,4); screen(d,p,(7,6,w-10,h-9))
        line(d,[(13,33),(25,29),(37,31),(48,20),(62,24),(77,15)],p["glass"],2)
        rect(d,(71,32,77,38),p["accent"]); rect(d,(80,27,85,38),p["glass"])
    elif name=="signal_scope":
        body(d,p,(7,24,w-8,h-2),3,4); screen(d,p,(11,5,w-12,29))
        line(d,[(16,19),(25,19),(29,12),(33,24),(37,17),(43,17)],p["glass"],2)
        rect(d,(20,39,36,41),p["accent"])
    elif name=="drone_dock":
        body(d,p,(4,28,w-5,h-2),4,5); rect(d,(12,24,w-13,29),p["shade"])
        rect(d,(22,12,57,21),p["deep"]); rect(d,(27,14,52,18),p["light"])
        rect(d,(11,17,69,20),p["shade"]); rect(d,(37,19,43,29),p["line"])
        rect(d,(20,35,60,37),p["accent"])
    return im


def sheet(images, columns):
    rows=(len(images)+columns-1)//columns
    out=new(columns*CELL,rows*CELL)
    for i,img in enumerate(images):
        out.alpha_composite(img,((i%columns)*CELL,(i//columns)*CELL))
    return out


def preview(theme,p,bgs,frames,props):
    cols,rows=14,6
    canvas=new(cols*CELL,rows*CELL,p["deep"])
    # Outer ring, four quiet wall rows, one continuous floor line.
    for y in range(rows):
        for x in range(cols):
            bg=bgs[(x*5+y*3)%6]
            canvas.alpha_composite(bg,(x*CELL,y*CELL))
            vertical = "top" if y == 0 else "bottom" if y == rows - 1 else ""
            horizontal = "left" if x == 0 else "right" if x == cols - 1 else ""
            edge = f"{vertical}_{horizontal}" if vertical and horizontal else vertical or horizontal
            if edge:
                canvas.alpha_composite(frames[edge],(x*CELL,y*CELL))
    placements={
        "research_analysis":[(0,40),(1,105),(2,195),(3,275),(4,365)],
        "research_isolation":[(0,45),(1,138),(2,258),(3,330),(4,395)],
        "research_diagnostics":[(1,55),(0,145),(3,255),(4,340)],
    }[theme]
    ground=rows*CELL-12
    for i,x in placements:
        img=props[p["props"][i]]
        canvas.alpha_composite(img,(x,ground-img.height+1))
    if theme=="research_diagnostics":
        img=props["wall_display"]
        canvas.alpha_composite(img,(258,45))
    return canvas.resize((canvas.width*S,canvas.height*S),Image.Resampling.NEAREST)


def build():
    VALIDATION.mkdir(parents=True,exist_ok=True)
    names=["top_left","top","top_right","left","right","bottom_left","bottom","bottom_right"]
    summary={"formatVersion":1,"artPixelWorldPx":4,"cellWorldPx":128,"rooms":{}}
    for theme,p in ROOMS.items():
        base=f"tiles/{theme}_modular"
        bgs=[make_bg(p,i) for i in range(6)]
        frames={n:make_frame(p,n) for n in names}
        bends={n:make_bend(p,n) for n in ("top_left","top_right","bottom_left","bottom_right")}
        for i,img in enumerate(bgs):
            save(img,f"{base}/Background/{theme}_bg_fill_{'abcdef'[i]}.png",f"Tiles/{theme}_Modular/Background/{theme}_bg_fill_{'abcdef'[i]}.png")
        for n,img in frames.items():
            save(img,f"{base}/Frame/{theme}_frame_{n}.png",f"Tiles/{theme}_Modular/Frame/{theme}_frame_{n}.png")
        for n,img in bends.items():
            save(img,f"{base}/Frame/InnerCorners/{theme}_frame_inner_{n}.png",f"Tiles/{theme}_Modular/Frame/InnerCorners/{theme}_frame_inner_{n}.png")
        bg_sheet=sheet(bgs,3)
        frame_sheet=sheet([frames[n] for n in names],4)
        terrain=sheet([frames[n] for n in ["top_left","top","top_right","left","right","bottom_left","bottom","bottom_right"]]+[new(32,32)],3)
        bend_sheet=sheet([bends[n] for n in ("top_left","top_right","bottom_left","bottom_right")],4)
        for filename,img in (("background_sheet_3x2",bg_sheet),("frame_sheet_4x2",frame_sheet),("frame_terrain_3x3",terrain),("frame_bend_sheet_4x1",bend_sheet)):
            save(img,f"{base}/{theme}_modular_{filename}.png",f"Tiles/{theme}_Modular/{theme}_modular_{filename}.png")
        drawn={}
        for n in p["props"]:
            drawn[n]=prop(n,p)
            save(drawn[n],f"props/{theme}/{theme}_{n}.png",f"Props/{theme}/{theme}_{n}.png")
        out=preview(theme,p,bgs,frames,drawn)
        out.save(VALIDATION/f"{theme}_room_preview.png",optimize=True)
        summary["rooms"][theme]={"title":p["title"],"backgroundTiles":6,"frameTiles":8,"innerCornerTiles":4,"props":[{"file":f"{theme}_{n}.png","nativeSizePx":list(drawn[n].size),"pivot":"bottom_center" if n!="wall_display" else "wall_mount"} for n in p["props"]],"preview":f"Assets/GameReady/Validation/{theme}_room_preview.png","sheets":{"background":f"{theme}_modular_background_sheet_3x2.png","frame":f"{theme}_modular_frame_terrain_3x3.png","bend":f"{theme}_modular_frame_bend_sheet_4x1.png"}}
    (READY/"research_facility_manifest.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    build_normals()
    print("Built 3 research rooms: 18 backgrounds, 24 frames, 12 bends, 15 props, 12 sheets, 3 previews.")


def build_normals():
    """Use the project's normal-map algorithm, limited to our own new assets."""
    spec = importlib.util.spec_from_file_location("project_normals", ROOT/"Tools/build_normal_maps.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    for group, strength, bevel, blur in (("tiles",2.4,0,1.0),("props",3.2,6,0.8)):
        for theme in ROOMS:
            folder = RUNTIME/group/(f"{theme}_modular" if group=="tiles" else theme)
            for path in folder.rglob("*.png"):
                image=Image.open(path)
                height,alpha=mod.height_map(image,bevel,blur)
                normal=mod.normal_from_height(height,strength)
                rgb=((normal*.5+.5)*255).round().clip(0,255).astype(np.uint8)
                rgb[alpha<0.03]=(128,128,255)
                out=np.dstack((rgb,np.full(alpha.shape,255,dtype=np.uint8)))
                target=RUNTIME/"normals"/group/path.relative_to(RUNTIME/group)
                target.parent.mkdir(parents=True,exist_ok=True)
                Image.fromarray(out,"RGBA").save(target,optimize=True)


if __name__=="__main__":
    build()
