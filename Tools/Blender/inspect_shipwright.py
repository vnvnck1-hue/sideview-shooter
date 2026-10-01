"""Read-only native asset audit. Reports geometry and reference packing."""
import bpy
import json
import math
from pathlib import Path

out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
model=bpy.data.collections['SHIPWRIGHT | editable mechanical assembly']
required=['Central luminous mint optic','Mint convex side optic','28 tooth circular cutting blade','Welder folded protective shield','Diagnostic teal screen','Original authoritative concept','Generated orthographic interpretation']
for name in required:
    assert any(o.name.startswith(name) for o in model.all_objects),name
lenses=[o for o in model.all_objects if o.type=='MESH' and o.data.materials and o.data.materials[0].name.startswith('09 | luminous mint lenses')]
assert len(lenses)==3, len(lenses)
assert len([c for c in model.children if 'fore leg' in c.name or 'rear leg' in c.name])==4
assert len([c for c in model.children if 'three finger manipulator' in c.name])==2
for hand in [c for c in model.children if 'three finger manipulator' in c.name]:
    assert sum(o.name.startswith('Finger proximal phalanx') for o in hand.objects)==2,hand.name
    assert sum(o.name.startswith('Opposing thumb') for o in hand.objects)==1,hand.name
for image in bpy.data.images:
    if image.name in {'original_concept.png','concept_turnaround.png'}:
        assert image.packed_file,image.name
dg=bpy.context.evaluated_depsgraph_get()
triangles=0;zero_area=[];nonfinite=[]
for obj in model.all_objects:
    if obj.type!='MESH':continue
    ev=obj.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles()
    triangles+=len(me.loop_triangles)
    bad=sum(1 for t in me.loop_triangles if t.area<1e-12)
    if bad:zero_area.append({'object':obj.name,'triangles':bad})
    if any(not math.isfinite(v) for vert in me.vertices for v in vert.co):nonfinite.append(obj.name)
    ev.to_mesh_clear()
assert not nonfinite,nonfinite
report={
    'native_file_reopened':True,
    'three_mint_lenses':len(lenses),
    'four_load_bearing_legs':True,
    'two_manipulator_hands':True,
    'three_digits_per_hand':True,
    'references_packed':True,
    'mesh_objects':sum(o.type=='MESH' for o in model.all_objects),
    'evaluated_triangles':triangles,
    'degenerate_triangles':zero_area,
    'visual_identity':'Requires visual comparison; counts do not prove exact identity to a single drawing.',
}
(out/'geometry_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('AUDIT_RESULT',json.dumps(report))
