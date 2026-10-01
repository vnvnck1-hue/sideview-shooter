"""Render a contact sheet from actual model cameras, without changing the native file."""
import bpy
from pathlib import Path
from mathutils import Vector

out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(1,1,1,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=1
def emission(name,color):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear()
    output=nodes.new('ShaderNodeOutputMaterial');em=nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=color
    mat.node_tree.links.new(em.outputs[0],output.inputs['Surface'])
    return mat,em
ink,_=emission('Sheet ink',(.04,.065,.1,1))
def text(body,pos,size):
    d=bpy.data.curves.new(body,'FONT');d.body=body;d.size=size;d.align_x='CENTER'
    o=bpy.data.objects.new(body,d);scene.collection.objects.link(o);o.location=pos;d.materials.append(ink)
for x,key,title in ((-6.25,'front','FRONT'),(0,'right','RIGHT SIDE'),(6.25,'back','BACK')):
    image=bpy.data.images.load(str(out/'renders'/f'{key}.png'))
    bpy.ops.mesh.primitive_plane_add(size=6,location=(x,.10,0))
    o=bpy.context.object;o.name=title
    mat,em=emission(title+' image',(1,1,1,1))
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[1].default_value=(1,1,1,1)
    mat.node_tree.links.new(tex.outputs['Alpha'],mix.inputs[0]);mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[2])
    mat.node_tree.links.new(mix.outputs[0],em.inputs['Color']);o.data.materials.append(mat)
    text(title,(x,-3.24,.01),.19)
text('SHIPWRIGHT / MODEL ORTHOGRAPHICS',(0,3.35,.01),.23)
text('Single-image reconstruction / Rear and concealed geometry inferred',(0,-3.52,.01),.13)
bpy.ops.object.camera_add(location=(0,0,20))
cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=19.3;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.use_denoising=False
scene.render.resolution_x=3300;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/'renders'/'model_turnaround.png')
bpy.ops.render.render(write_still=True)
print('MODEL_TURNAROUND_RENDERED')
