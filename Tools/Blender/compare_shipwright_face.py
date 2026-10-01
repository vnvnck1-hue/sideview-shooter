"""Compare three visible facial landmarks, not overall design identity.

Source centers are approximate hand observations in the supplied 1067x992 image.
Ratios cancel framing/translation, but do not cancel differences in camera angle.
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
source={'center_lens':(459,559),'near_lens':(636,530),'camera':(509,454)}

def relative_distances(points):
    p={k:Vector(v) for k,v in points.items()}
    eye_distance=(p['near_lens']-p['center_lens']).length
    return {'camera_to_center_over_eye_spacing':(p['camera']-p['center_lens']).length/eye_distance}

report={'scope':'Approximate three-landmark comparison only; not an identity score.',
        'source_centers_pixels':source,'source_ratios':relative_distances(source),'models':{}}
for revision,path in [('v4',out/'revisions'/'v4'/'shipwright.blend'),('v5',out/'revisions'/'v5'/'shipwright.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(path),use_scripts=False)
    scene=bpy.context.scene;camera=bpy.data.objects['CAM 01 | original concept angle']
    lenses=[o for o in scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0].name.startswith('09 | luminous mint lenses')]
    central=next(o for o in lenses if o.name.startswith('Central luminous'))
    side=max((o for o in lenses if o!=central),key=lambda o:sum((o.matrix_world@v.co).x for v in o.data.vertices)/len(o.data.vertices))
    points={}
    for key,obj in [('center_lens',central),('near_lens',side),('camera',bpy.data.objects['Forehead auxiliary camera'])]:
        projected=[world_to_camera_view(scene,camera,obj.matrix_world@v.co) for v in obj.data.vertices]
        points[key]=((min(p.x for p in projected)+max(p.x for p in projected))/2,
                     1-(min(p.y for p in projected)+max(p.y for p in projected))/2)
    report['models'][revision]={'centers_normalized':points,'ratios':relative_distances(points)}
(out/'face_landmark_comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('FACE_LANDMARK_COMPARISON',json.dumps(report))
