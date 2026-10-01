"""Export and render the inspected native asset without rebuilding its geometry.

Use run_blender.ps1 -InputBlend Deliverables/Shipwright/shipwright.blend.
"""
import bpy
from pathlib import Path

out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
scene=bpy.context.scene
model=bpy.data.collections['SHIPWRIGHT | editable mechanical assembly']
ground=bpy.data.objects['Studio shadow ground']
camera_names={
    'hero':'CAM 01 | original concept angle',
    'front':'CAM 02 | FRONT orthographic',
    'right':'CAM 03 | RIGHT orthographic',
    'back':'CAM 04 | BACK orthographic',
    'detail':'CAM 05 | face and equipment detail',
}
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.use_freestyle=True
scene.render.resolution_x=1600;scene.render.resolution_y=1600;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=False;ground.hide_render=False
scene.camera=bpy.data.objects[camera_names['hero']]
scene.render.filepath=str(out/'renders'/'hero.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'shipwright.blend'))
bpy.ops.object.select_all(action='DESELECT')
exported=[o for o in model.all_objects if o.type in {'MESH','CURVE','FONT'}]
for obj in exported:obj.select_set(True)
bpy.context.view_layer.objects.active=exported[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(out/'shipwright.glb'),export_format='GLB',use_selection=True,export_apply=True)
for key,name in camera_names.items():
    scene.camera=bpy.data.objects[name]
    ortho=key in {'front','right','back'}
    ground.hide_render=ortho;scene.render.film_transparent=ortho
    scene.render.filepath=str(out/'renders'/f'{key}.png')
    bpy.ops.render.render(write_still=True)
print('SHIPWRIGHT_FINALIZE_OK')
