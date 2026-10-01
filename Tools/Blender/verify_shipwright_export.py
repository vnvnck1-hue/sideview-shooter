"""Import the delivered GLB in a clean scene and validate its contents."""
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector

out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
path=out/'shipwright.glb'
data=path.read_bytes();magic,version,length=struct.unpack_from('<4sII',data)
assert magic==b'glTF' and version==2 and length==len(data)
json_len,json_type=struct.unpack_from('<I4s',data,12)
document=json.loads(data[20:20+json_len])
assert not document.get('cameras'),'Studio cameras must not be exported'
assert all('uri' not in image for image in document.get('images',[])),'Textures must be embedded'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(path))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)>100
assert not any(o.name=='Studio shadow ground' for o in objects)
assert sum(bool(o.data.materials) and o.data.materials[0].name.startswith('09 | luminous mint lenses') for o in objects)==3
points=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
lower=[min(p[k] for p in points) for k in range(3)]
upper=[max(p[k] for p in points) for k in range(3)]
report={
    'glb_header_valid':True,
    'imported_successfully':True,
    'mesh_objects':len(objects),
    'triangles':sum(len(o.data.polygons) for o in objects),
    'embedded_images':len(document.get('images',[])),
    'bounds_min':lower,'bounds_max':upper,
    'studio_excluded':True,
    'file_bytes':len(data),
}
(out/'export_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('GLB_IMPORT_AUDIT_OK',json.dumps(report))
