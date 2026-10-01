"""Verify procedural modeling, materials, native save, GLB export and rendering.

Run with run_blender.ps1. All outputs stay in Deliverables/BlenderSetup.
This script uses a fresh background scene, never the open interactive session.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector

output = Path(__file__).resolve().parents[2] / 'Deliverables' / 'BlenderSetup'
output.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = 0.32
    return mat

body_mat = material('Blue metal', (0.045, 0.24, 0.36), 0.65)
trim_mat = material('Orange trim', (1.0, 0.30, 0.04), 0.35)
floor_mat = material('Studio floor', (0.045, 0.055, 0.075))
parts = []

def box(name, location, scale, mat, bevel=0.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new('Rounded edges', 'BEVEL')
    modifier.width = bevel
    modifier.segments = 3
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return obj

parts.append(box('Test crate body', (0, 0, 0.8), (1.8, 1.3, 1.4), body_mat))
for x in (-0.62, 0.62):
    parts.append(box('Reinforcing strap', (x, 0, 0.8), (0.14, 1.38, 1.48), trim_mat, 0.025))
parts.append(box('Front panel', (0, -0.69, 0.85), (0.60, 0.08, 0.45), trim_mat, 0.025))
box('Ground', (0, 0, -0.06), (200, 200, 0.1), floor_mat, 0)

scene = bpy.context.scene
scene.world.color = (0.18, 0.18, 0.18)
for name, location, energy, size in (
    ('Key', (3, -4, 6), 1000, 4),
    ('Fill', (-4, -1, 3), 700, 3),
    ('Rim', (1, 4, 5), 1200, 3),
):
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 0.7)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(3.4, -4.8, 3.0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.75)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.7
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(output / 'setup_preview.png')
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(filepath=str(output / 'setup_crate.glb'), export_format='GLB', use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output / 'setup_crate.blend'))
bpy.ops.render.render(write_still=True)
for filename in ('setup_crate.blend', 'setup_crate.glb', 'setup_preview.png'):
    assert (output / filename).stat().st_size > 0, filename
(output / 'verification.json').write_text(json.dumps({
    'blender_version': bpy.app.version_string,
    'model_parts': len(parts),
    'verified': ['modeling', 'materials', 'blend_save', 'glb_export', 'cpu_render'],
}, indent=2), encoding='utf-8')
print('BLENDER_SETUP_OK', output)
