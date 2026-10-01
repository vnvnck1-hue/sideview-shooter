"""Shipwright concept reconstruction. X=width, -Y=front, Z=up.

Rebuild: run_blender.ps1 -Script Tools/Blender/build_shipwright.py
Outputs are isolated in Deliverables/Shipwright. No interactive scene is edited.
"""
import bpy
import bmesh
import math
import json
import sys
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Deliverables' / 'Shipwright'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'renders').mkdir(exist_ok=True)
PREVIEW = '--preview' in sys.argv
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name != 'Collection':
        bpy.data.collections.remove(collection)
scene = bpy.context.scene
model = bpy.data.collections.new('SHIPWRIGHT | editable mechanical assembly')
scene.collection.children.link(model)
active_collection = model
groups = {}

def group(name):
    global active_collection
    active_collection = bpy.data.collections.new(name)
    model.children.link(active_collection)
    groups[name] = active_collection

def track(obj):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    active_collection.objects.link(obj)
    return obj

def mat(name, color, metal=0, rough=.4, glow=0, wear=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color,1)
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Roughness'].default_value = rough
    if glow:
        bs.inputs['Emission Color'].default_value = (*color,1)
        bs.inputs['Emission Strength'].default_value = glow
    if wear:
        nodes=m.node_tree.nodes; links=m.node_tree.links
        noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=90
        noise.inputs['Detail'].default_value=2
        bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.12; bump.inputs['Distance'].default_value=.012
        links.new(noise.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    return m

BLUE=mat('01 | desaturated cobalt enamel',(.032,.09,.185),.28,.46,wear=True)
BLUE_LIGHT=mat('02 | chamfer blue',(.075,.17,.30),.30,.42)
BLUE_DARK=mat('03 | recessed blue',(.058,.125,.20),.4,.4)
GRAPHITE=mat('04 | graphite mechanics',(.035,.040,.055),.35,.43)
BLACK=mat('05 | rubber and panel gaps',(.014,.024,.034),.12,.5)
STEEL=mat('06 | brushed silver alloy',(.28,.31,.35),.65,.34,wear=True)
EDGE=mat('07 | polished steel edges',(.64,.70,.72),.8,.23)
PLATE=mat('08 | warm grey armor',(.13,.15,.17),.4,.46,wear=True)
CYAN=mat('09 | luminous mint lenses',(.16,.88,.73),.05,.12,.35)
CYAN.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.35
CYAN.node_tree.nodes.get('Principled BSDF').inputs['Coat Roughness'].default_value=.10
GLOW=mat('10 | cyan task lights',(.02,.72,.61),.2,.24,2)
WHITE=mat('11 | warm white stencil',(.78,.85,.84),.12,.55)
RED=mat('12 | faded red warnings',(.65,.10,.09),.3,.5)
GOLD=mat('13 | tool brass',(.43,.32,.13),.7,.35)
SCREEN=mat('14 | display glass',(.015,.085,.11),.2,.25,.3)
UI=mat('15 | phosphor display',(.12,.57,.60),.0,.5,1)

def finish(obj,name,material,bevel=0,smooth=False):
    obj.name=name; track(obj)
    if material: obj.data.materials.append(material)
    if bevel:
        mod=obj.modifiers.new('Machined edge radii','BEVEL');mod.width=bevel;mod.segments=3
        mod=obj.modifiers.new('Face weighted normals','WEIGHTED_NORMAL')
    if smooth:
        for p in obj.data.polygons:p.use_smooth=True
    return obj

def box(name,loc,size,material,bevel=.035,rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rotation:o.rotation_euler=rotation
    return finish(o,name,material,bevel)

def uv(name,loc,size,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,location=loc)
    o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,material,smooth=True)

def cyl(name,a,b,r,material,vertices=32,r2=None):
    a,b=Vector(a),Vector(b);delta=b-a
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=delta.length,location=(a+b)/2)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r2,depth=delta.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y')
    return finish(o,name,material,min(.009,r*.18,delta.length*.15) if r>.025 else 0,True)

def torus(name,loc,major,minor,material,axis=(0,-1,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=40,minor_segments=10,location=loc)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector(axis).to_track_quat('Z','Y')
    return finish(o,name,material,smooth=True)

def mesh(name,verts,faces,material,bevel=.025):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    o=bpy.data.objects.new(name,data);active_collection.objects.link(o)
    if material:data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Plate edge bevel','BEVEL');mod.width=bevel;mod.segments=3
        o.modifiers.new('Weighted plate normals','WEIGHTED_NORMAL')
    return o

def plate(name,poly,depth,material):
    # Polygon is supplied in world coordinates; extrude along an arbitrary vector.
    n=len(poly);d=Vector(depth)
    verts=[tuple(Vector(p)-d/2) for p in poly]+[tuple(Vector(p)+d/2) for p in poly]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    edge_min=min((Vector(poly[(i+1)%n])-Vector(poly[i])).length for i in range(n))
    return mesh(name,verts,faces,material,min(.025,d.length*.18,edge_min*.15))

def hose(name,points,r=.04,material=BLACK):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=20
    data.bevel_depth=r;data.bevel_resolution=3
    spl=data.splines.new('BEZIER');spl.bezier_points.add(len(points)-1)
    for p,co in zip(spl.bezier_points,points):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,data);active_collection.objects.link(obj);data.materials.append(material)
    return obj

def bolt(loc,axis=(0,-1,0),r=.027):
    p=Vector(loc);n=Vector(axis).normalized()
    cyl('Recessed fastener',p-n*.012,p+n*.008,r,BLACK,16)
    cyl('Hex socket screw',p+n*.01,p+n*.025,r*.67,STEEL,6)

def label(text,loc,size,material=WHITE,rotation=(math.pi/2,0,0),name=None):
    data=bpy.data.curves.new('Stencil '+text,'FONT');data.body=text;data.size=size;data.extrude=.0005
    obj=bpy.data.objects.new(name or 'Stencil '+text,data);active_collection.objects.link(obj)
    obj.location=loc;obj.rotation_euler=rotation;data.materials.append(material)
    return obj

def reference_decal(name,quad,pixels,glow=0):
    # Preserve source micrographics by mapping the original quadrilateral as a texture.
    source=bpy.data.images.load(str(OUT/'references'/'original_concept.png'),check_existing=True)
    source.pack()
    material=bpy.data.materials.new(name+' | original concept UV decal');material.use_nodes=True
    nodes=material.node_tree.nodes;bs=nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.52;bs.inputs['Specular IOR Level'].default_value=.15
    tex=nodes.new('ShaderNodeTexImage');tex.image=source
    material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if glow:
        material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value=glow
    obj=mesh(name,quad,[(0,3,2,1)],material,0)
    uv=obj.data.uv_layers.new(name='Source quadrilateral UV')
    for face in obj.data.polygons:
        for li in face.loop_indices:
            vi=obj.data.loops[li].vertex_index;px,py=pixels[vi]
            uv.data[li].uv=(px/source.size[0],1-py/source.size[1])
    return obj

def optic(name,center,rx,rz,depth,angles):
    p=Vector(center);rotation=Euler(angles).to_matrix();segments=80;rings=20
    def world(v):return tuple(p+rotation@Vector(v))
    # Closed, hollow retaining bezel. The lens is not intersected by a solid sphere.
    profile=[(rx+.07,rz+.07,.14),(rx+.075,rz+.075,.018),(rx+.035,rz+.035,-.030),(rx,rz,-.022),(rx,rz,.14)]
    verts=[]
    for xx,zz,yy in profile:
        verts.extend(world((xx*math.cos(i*math.tau/segments),yy,zz*math.sin(i*math.tau/segments))) for i in range(segments))
    faces=[]
    for j in range(len(profile)):
        nj=(j+1)%len(profile)
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,nj*segments+(i+1)%segments,nj*segments+i))
    bezel=mesh(name+' hollow retaining bezel',verts,faces,GRAPHITE,0)
    bezel.data.materials.append(PLATE)
    for index,face in enumerate(bezel.data.polygons):
        face.use_smooth=True
        if index//segments==1:face.material_index=1
    # Opaque rear seat prevents the far optic's open underside from showing cyan.
    backing=[world(((rx+.025)*math.cos(i*math.tau/segments),.135,(rz+.025)*math.sin(i*math.tau/segments))) for i in range(segments)]
    mesh(name+' opaque rear seat',backing,[tuple(range(segments))],GRAPHITE,0)
    # Smooth elliptical convex cap with a unique apex vertex and a clean aperture rim.
    verts=[world((0,-depth-.025,0))]
    for j in range(1,rings+1):
        theta=j*math.pi/(2*rings)
        for i in range(segments):
            phi=i*math.tau/segments
            verts.append(world((rx*math.sin(theta)*math.cos(phi),-depth*math.cos(theta)-.025,rz*math.sin(theta)*math.sin(phi))))
    faces=[(0,1+i,1+(i+1)%segments) for i in range(segments)]
    for j in range(rings-1):
        a=1+j*segments;b=a+segments
        for i in range(segments):faces.append((a+i,b+i,b+(i+1)%segments,a+(i+1)%segments))
    lens=mesh(name,verts,faces,CYAN,0)
    for face in lens.data.polygons:face.use_smooth=True
    for dx,dz in ((-.040,0),(.034,-.023),(.020,.061)):
        yy=-depth*math.sqrt(1-(dx/rx)**2-(dz/rz)**2)-.032
        dot=uv(name+' three dot sensor',world((dx,yy,dz)),(.017,.010,.019),BLACK)
        dot.rotation_euler=angles
    if name.startswith('Mint convex side'):
        steps=28;verts=[]
        for yy in (.075,.17):
            for inner in (False,True):
                xx=rx+(.060 if inner else .105);zz=rz+(.065 if inner else .105)
                for i in range(steps+1):
                    phi=math.radians(15+i*150/steps)
                    verts.append(world((xx*math.cos(phi),yy,zz*math.sin(phi))))
        n=steps+1;faces=[]
        for i in range(steps):
            faces.extend([(i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),(i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)])
        faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
        mesh('Blue armored side optic brow',verts,faces,BLUE,.018)
    return lens

def segment(name,a,b,width,depth,material,side=(1,0,0)):
    # Faceted armor plate, wide at the joint and tapered near the foot.
    a,b=Vector(a),Vector(b);z=(b-a).normalized();x=Vector(side);x=(x-z*x.dot(z)).normalized();y=z.cross(x)
    length=(b-a).length
    profile=[(-.38,0),(.35,0),(.54,.18),(.43,.72),(.22,1),(-.24,1),(-.48,.80),(-.50,.16)]
    pts=[a+x*(u*width)+z*(v*length) for u,v in profile]
    return plate(name,pts,y*depth,material)

def joint(name,loc,r=.24,axis=(1,0,0)):
    p=Vector(loc);n=Vector(axis).normalized()
    flat_cover=name=='Forward visible knee bearing'
    cyl(name+' rubber bearing',p-n*.17,p+n*.17,r*1.08,BLACK)
    cyl(name+' steel cap',p-n*.195,p+n*.195,r,STEEL if flat_cover else PLATE)
    for sign in (-1,1):
        c=p+n*.202*sign
        if not flat_cover:
            cyl(name+' hub',c,c+n*.04*sign,r*.45,GRAPHITE)
        else:
            cyl(name+' flush central spindle',c,c+n*.006*sign,r*.10,PLATE)
        # Bolt ring in the disk plane.
        u=n.cross(Vector((0,0,1))).normalized();v=n.cross(u)
        for ang in range(0,360,60 if flat_cover else 90):
            q=c+(u*math.cos(math.radians(ang))+v*math.sin(math.radians(ang)))*r*.76
            bolt(q,n*sign,.017)

def loft(name,rings,material):
    # rings: y, center z, half-width, half-height. Clipped rectangular section.
    profile=[(-.68,-1),(.68,-1),(1,-.65),(1,.60),(.64,1),(-.64,1),(-1,.6),(-1,-.65)]
    verts=[]
    for y,z,w,h in rings:
        verts += [(u*w,y,z+v*h) for u,v in profile]
    faces=[tuple(reversed(range(8))),tuple(range((len(rings)-1)*8,len(rings)*8))]
    for j in range(len(rings)-1):
        for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
    return mesh(name,verts,faces,material,.06)

def ribbon(name,rows,material,thickness=.12,sign=1):
    # Molded main armor follows a smooth longitudinal curve and a crowned section.
    if name in {'Long blue forehead rail','Blue raised shoulder fairing'}:
        controls=[Vector(row) for row in rows];sampled=[]
        for j in range(len(controls)-1):
            p0=controls[max(0,j-1)];p1=controls[j];p2=controls[j+1];p3=controls[min(len(controls)-1,j+2)]
            for k in range(8):
                t=k/8
                sampled.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
        sampled.append(controls[-1]);rows=sampled
        cross=(-.5,-.43,0,.43,.5);verts=[]
        for bottom in (False,True):
            for x,y,z,width in rows:
                for u in cross:
                    crown=.065*width*math.cos(math.pi*u) if not bottom else -thickness
                    verts.append((sign*(x+u*width),y,z+crown))
        n=len(rows)*5;faces=[]
        for j in range(len(rows)-1):
            for i in range(4):
                a=j*5+i;b=a+5
                faces.extend([(a,a+1,b+1,b),(a+n,b+n,b+n+1,a+n+1)])
            a=j*5;b=a+5
            faces.extend([(a,b,b+n,a+n),(a+4,a+n+4,b+n+4,b+4)])
        for i in range(4):
            faces.extend([(i,i+n,i+n+1,i+1),(n-5+i,n-4+i,2*n-4+i,2*n-5+i)])
        obj=mesh(name,verts,faces,material,.003)
        for face in obj.data.polygons:face.use_smooth=True
        if name=='Long blue forehead rail':
            edge=[(sign*(x+width*.5),y,z+.005) for x,y,z,width in rows]
            hose('Forehead conforming edge trim',edge,.006,BLUE_LIGHT)
            for index in (19,21,23,25):
                x,y,z,width=rows[index]
                p=Vector((sign*(x+width*.29),y,z+.065*width*math.cos(math.pi*.29)+.006))
                axis=Vector((0,-.43,1)).normalized()
                cyl('Forehead armor small vent',p,p+axis*.009,.017,BLACK,16)
        return obj
    # Secondary flat strips retain their machined profile.
    verts=[]
    for dz in (0,-thickness):
        for x,y,z,width in rows:
            verts.extend([(sign*(x-width/2),y,z+dz),(sign*(x+width/2),y,z+dz)])
    n=len(rows)*2;faces=[]
    for i in range(0,n-2,2):
        faces.extend([(i,i+1,i+3,i+2),(i+n+2,i+n+3,i+n+1,i+n),(i,i+2,i+n+2,i+n),(i+1,i+n+1,i+n+3,i+3)])
    faces.extend([(0,n,n+1,1),(n-2,n-1,2*n-1,2*n-2)])
    obj=mesh(name,verts,faces,material,.04)
    return obj

def molded_forearm(a,b):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized()
    across=Vector((1,0,0));across=(across-direction*across.dot(direction)).normalized();outward=direction.cross(across)
    sections=[(0,.15,.14),(.10,.28,.20),(.30,.31,.24),(.64,.29,.24),(.88,.24,.205),(1,.205,.18)]
    verts=[];count=16
    for t,w,d in sections:
        center=a.lerp(b,t)
        for i in range(count):
            ang=i*math.tau/count
            verts.append(tuple(center+across*(w*math.cos(ang))+outward*(d*math.sin(ang))))
    faces=[tuple(reversed(range(count))),tuple(range((len(sections)-1)*count,len(sections)*count))]
    for j in range(len(sections)-1):
        for i in range(count):faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
    obj=mesh('Molded rounded forearm shell',verts,faces,BLUE,.025)
    for face in obj.data.polygons:face.use_smooth=True
    return obj

def shoulder_inset(fairing):
    """Thin insert follows the actual sampled surface of the shoulder armor."""
    # The fairing has five vertices per transverse row on its upper surface.
    top_rows=len(fairing.data.vertices)//10
    cross=(-.5,-.43,0,.43,.5)
    rows=[]
    for index in range(13,min(29,top_rows)):
        surface=[fairing.data.vertices[index*5+j].co.copy() for j in range(5)]
        row=[]
        taper=.78 if index in (13,28) else 1.0
        for u in (-.35,-.29,-.055,.18,.24):
            u=-.055+(u+.055)*taper
            segment_index=next(j for j in range(4) if cross[j]<=u<=cross[j+1])
            t=(u-cross[segment_index])/(cross[segment_index+1]-cross[segment_index])
            p=surface[segment_index].lerp(surface[segment_index+1],t)
            p.z+=.025
            row.append(p)
        rows.append(row)
    verts=[tuple(p-Vector((0,0,depth))) for depth in (0,.018) for row in rows for p in row]
    n=len(rows)*5;faces=[]
    for j in range(len(rows)-1):
        a=j*5;b=a+5
        for i in range(4):
            faces.extend([(a+i,a+i+1,b+i+1,b+i),(a+n+i,b+n+i,b+n+i+1,a+n+i+1)])
        faces.extend([(a,b,b+n,a+n),(a+4,a+n+4,b+n+4,b+4)])
    for i in range(4):
        faces.extend([(i,i+n,i+n+1,i+1),(n-5+i,n-4+i,2*n-4+i,2*n-5+i)])
    obj=mesh('Shoulder silver inset',verts,faces,PLATE,.003)
    for face in obj.data.polygons:face.use_smooth=True
    return obj

# Rear thorax and inset maintenance spine.
group('01 | thorax and upper service armor')
loft('Rear powerplant dark undershell',[(.0,2.45,.83,.70),(.45,2.91,1.09,.99),(1.25,3.02,1.01,.92),(1.62,2.91,.78,.75)],GRAPHITE)
for s in (-1,1):
    fairing=ribbon('Blue raised shoulder fairing',[(.92,-.04,2.56,.53),(1.0,.12,3.10,.53),(.88,.46,3.67,.56),(.78,.85,4.02,.50),(.66,1.47,4.03,.34)],BLUE,.20,s)
    shoulder_inset(fairing)
    plate('Lower shoulder slab',[(s*.90,-.03,2.32),(s*1.29,.13,2.45),(s*1.35,.56,2.89),(s*1.14,.85,3.36),(s*.97,.21,3.29)],(s*.13,0,0),BLUE_LIGHT)
    box('Shoulder light inset',(s*1.075,-.13,2.79),(.37,.20,.42),GRAPHITE,.07)
    box('Shoulder square mint lamp',(s*1.075,-.242,2.80),(.20,.035,.255),GLOW,.025)
    box('Side steel service panel',(s*1.14,.57,2.8),(.13,.73,.67),PLATE,.06)
    for y,z in ((.2,3.38),(.67,3.76),(1.23,3.86),(.6,2.61)):
        bolt((s*1.17,y,z),(s,0,0))
    for k in range(4):
        box('Side radiator recess',(s*1.085,1.12,2.51+k*.11),(.08,.5,.055),BLACK,.008)
    plate('Shoulder hanging dark side skirt',[(s*1.07,.13,2.71),(s*1.12,1.20,2.82),(s*.99,1.36,1.97),(s*.83,.15,1.61)],(s*.18,0,0),GRAPHITE)
    plate('Shoulder skirt inset armor',[(s*1.19,.41,2.53),(s*1.20,.92,2.56),(s*1.17,1.01,2.06),(s*1.09,.53,1.95)],(s*.03,0,0),BLUE_DARK)
    for z in (2.11,2.29):bolt((s*1.21,.96,z),(s,0,0),.03)
loft('Grey central dorsal shell',[(.01,3.23,.55,.26),(.55,3.74,.58,.22),(1.32,3.91,.55,.16),(1.53,3.78,.46,.14)],PLATE)
for s in (-1,1):
    hose('Dorsal panel separation',[(s*.52,.01,3.45),(s*.59,.50,3.94),(s*.53,1.3,4.08)],.016,BLACK)
    for y,z in ((.12,3.55),(.65,3.99),(1.24,4.085)):
        bolt((s*.40,y,z),(0,-.5,1),.025)
box('Dorsal dark recess',(0,.93,4.10),(.40,.72,.05),GRAPHITE,.04)
for y in (.72,1.12):
    torus('Spine access port',(0,y,4.14),.092,.018,STEEL,(0,0,1))
box('Spine latch',(0,.25,3.70),(.43,.12,.18),GRAPHITE,.025,(-.6,0,0))
hose('Latch grab handle',[(-.19,.23,3.70),(-.18,.20,3.80),(.18,.20,3.80),(.19,.23,3.70)],.025,STEEL)
triangle_points=[(-.067,.42,3.91),(.067,.42,3.91),(0,.52,3.985)]
for i in range(3):cyl('Outline dorsal warning triangle',triangle_points[i],triangle_points[(i+1)%3],.008,RED,8)
box('Upper latch connector',(0,.33,3.80),(.27,.12,.16),GRAPHITE,.018,(-.6,0,0))
for xx in (-.075,.075):
    for zz in (3.78,3.83):bolt((xx,.25,zz),(0,-1,.3),.012)
box('Neck radiator solid backing',(0,-.011,3.25),(.56,.16,.35),GRAPHITE,.035)
for k in range(5):
    box('Neck radiator',(0,-.06,3.13+k*.055),(.44,.10,.024),BLACK,.005)

# Forward head: low sloping saddle with large oval convex eyes and curved blue rails.
group('02 | head carapace and mint optic lenses')
loft('Forward head graphite shell',[(-2.05,1.95,.54,.30),(-1.72,2.20,.91,.43),(-.92,2.49,.96,.54),(-.16,2.87,.68,.35),(.11,2.89,.53,.27)],GRAPHITE)
for s in (-1,1):
    optic('Mint convex side optic',(s*1.010,-1.32,2.562),.310,.358,.205,(math.radians(-10),0,s*math.radians(72)))
    # Forehead rail follows the forehead slope, widening around outer cheek.
    ribbon('Long blue forehead rail',[(.52,-2.10,1.86,.26),(.59,-2.04,2.24,.30),(.66,-1.81,2.70,.32),(.64,-1.46,2.93,.35),(.58,-.87,3.19,.40),(.46,-.22,3.36,.43)],BLUE,.14,s)
    plate('Outer silver temple insert',[(s*1.06,-1.49,2.35),(s*1.13,-1.02,2.79),(s*.91,-.47,3.13),(s*.75,-.37,3.18),(s*.99,-1.04,2.79),(s*.94,-1.46,2.30)],(s*.07,0,0),STEEL)
    for x,y,z in ((.41,-1.76,2.82),(.69,-.25,3.36),(.96,-1.66,2.34),(.83,-2.08,1.96)):
        bolt((s*x,y,z),(0,-.65,.7))
    # Round cheek task light with cyan horizontal louvres.
    lamp=Vector((s*1.0,-2.025,1.96));axis=Vector((s*.28,-1,.1)).normalized()
    cyl('Cheek light armored barrel',lamp-axis*.10,lamp+axis*.095,.245,GRAPHITE)
    cyl('Cheek turquoise lens',lamp+axis*.10,lamp+axis*.13,.199,GLOW)
    torus('Cheek lamp metal retaining rim',lamp+axis*.14,.218,.025,PLATE,axis)
    for dz in (-.10,0,.10):
        length=math.sqrt(.192**2-dz**2)
        box('Cheek lens dark louvre',lamp+axis*.15+Vector((0,0,dz)),(length*2,.045,.035),BLUE_DARK,.01,rotation=(0,0,s*.23))
    box('Cheek light top bracket',(s*1.01,-2.01,2.20),(.15,.17,.065),STEEL,.02)
    # Vent slots adjacent to eye sockets.
    for k in range(4):
        box('Temple slit',(s*1.076,-1.28+k*.11,2.55+k*.06),(.03,.063,.095),BLACK,.008)
    # Small grey badge on the side of the head, below the large side optic.
    plate('Temple silver identification badge',[(s*1.14,-1.59,2.18),(s*1.17,-1.23,2.19),(s*1.16,-1.12,1.90),(s*1.08,-1.49,1.84)],(s*.035,0,0),PLATE)
    for yy,zz in ((-1.54,2.13),(-1.20,1.96)):bolt((s*1.19,yy,zz),(s,0,0),.018)
    badge_u=Vector((0,s,0));badge_v=Vector((0,0,1));badge_n=badge_u.cross(badge_v)
    badge_rot=Matrix((badge_u,badge_v,badge_n)).transposed().to_euler()
    reference_decal('Source side industrial nameplate',[(s*1.21,-1.54,2.18),(s*1.21,-1.18,2.18),(s*1.21,-1.18,1.88),(s*1.21,-1.54,1.88)],[(601,540),(632,563),(608,606),(576,585)])
    hose('Neck braided conduit',[(s*.33,-1.94,1.79),(s*.30,-1.84,1.53),(s*.49,-1.33,1.60),(s*.70,-.66,1.89)],.043)
    box('Chin metal tab',(s*.34,-2.0,1.82),(.15,.09,.24),PLATE,.023,rotation=(-.25,0,0))
    uv('Forehead recessed rivet',(s*.395,-1.80,2.83),(.09,.035,.09),STEEL)
    torus('Forehead rivet surround',(s*.395,-1.805,2.83),.09,.019,GRAPHITE,(0,-.8,.6))
# Large central lens sits forward of the two smaller side lenses.
optic('Central luminous mint optic',(0,-2.19,2.30),.342,.377,.230,(math.radians(-12),0,0))
# Stencil lies on the sloped right rail, running lengthwise.
text_u=Vector((0,1,.43)).normalized();text_v=Vector((-1,0,0));text_n=text_u.cross(text_v)
text_rot=Matrix((text_u,text_v,text_n)).transposed().to_euler()
label('SHIPWRIGHT',(.72,-1.44,2.985),.14,WHITE,text_rot)
label('FIELD MAINTENANCE / SR-09',(.79,-1.40,3.003),.034,WHITE,text_rot)
ribbon('Narrow central head access saddle',[(0,-1.72,2.69,.45),(0,-1.09,3.05,.52),(0,-.44,3.235,.44)],GRAPHITE,.055)
for s in (-1,1):
    for yy,zz in ((-1.42,2.87),(-.83,3.11)):
        bolt((s*.20,yy,zz),(0,-.35,1),.023)
camera_parts_before=set(active_collection.objects)
box('Forehead auxiliary camera',(-.07,-.64,3.245),(.37,.43,.19),PLATE,.025)
box('Camera dark recessed face',(-.07,-.866,3.24),(.27,.025,.135),GRAPHITE,.01)
box('Camera square service port',(-.095,-.883,3.24),(.071,.012,.065),BLACK,.008)
bolt((-.16,-.891,3.29),(0,-1,0),.013)
bolt((.025,-.891,3.19),(0,-1,0),.013)
cyl('Camera lateral silver rotor',(.12,-.71,3.26),(.22,-.71,3.26),.098,STEEL)
torus('Camera lateral rotor ring',(.23,-.71,3.26),.072,.017,GRAPHITE,(1,0,0))
for obj in set(active_collection.objects)-camera_parts_before:
    obj.location+=Vector((0,-.68,-.245))
cyl('Antenna base',(-.49,-.38,3.27),(-.49,-.38,3.44),.09,BLUE_LIGHT)
cyl('Telescopic aerial sleeve',(-.49,-.38,3.40),(-.49,-.38,3.62),.052,STEEL)
cyl('Telescopic aerial tip',(-.49,-.38,3.60),(-.49,-.38,3.80),.035,EDGE)
torus('Aerial cap',(-.49,-.38,3.81),.035,.009,GRAPHITE,(0,0,1))
for z in (3.44,3.60,3.76):torus('Aerial sleeve joint',(-.49,-.38,z),.047,.009,GRAPHITE,(0,0,1))
for y,z in ((-.42,3.265),(-.97,2.982)):
    box('Central forehead access plate',(0,y,z),(.26,.18,.06),PLATE,.02,rotation=(.34,0,0))
    bolt((0,y-.055,z+.044),(0,-.35,1),.023)

# Compress the face about its neck attachment, retaining the assembled details.
# A modest width increase and shorter depth/height bring the broad concept face
# closer to the source silhouette while leaving the upper neck connection fixed.
head_anchor=Vector((0,.11,3.36))
head_transform=Matrix.Translation(head_anchor)@Matrix.Diagonal((1.08,.90,.90,1))@Matrix.Translation(-head_anchor)
bpy.context.view_layer.update()
for obj in active_collection.objects:
    obj.matrix_world=head_transform@obj.matrix_world

# Four splayed load-bearing legs with dark understructure and blue frontal shin blades.
for s in (-1,1):
    for rear in (False,True):
        group(('03' if not rear else '04')+(' | left' if s<0 else ' | right')+(' fore leg' if not rear else ' rear leg'))
        y0=.0 if not rear else 1.10
        hip=Vector((s*.98,y0,2.25 if not rear else 2.72))
        knee=Vector((s*1.72,-.36 if not rear else 1.22,2.08 if not rear else 2.28))
        ankle=Vector((s*2.58,-1.07 if not rear else 1.86,.39))
        joint('Hip pivot',hip,.29)
        cyl('Leg upper structural spar',hip,knee,.19,GRAPHITE)
        segment('Upper link grey armored block',hip,knee,.58,.46,PLATE)
        joint('Large circular knee pivot',knee,.34)
        joint('Forward visible knee bearing',knee+Vector((-s*.18,-.29,-.04)),.272,(0,-1,0))
        if not rear:
            plate('Broad inner knee triangular support',[(s*1.04,-.36,2.36),(s*1.58,-.51,2.48),(s*1.76,-.56,1.91),(s*1.35,-.45,1.69)],(0,.12,0),PLATE)
            for xx,zz in ((1.27,2.22),(1.50,2.29),(1.46,1.97)):
                cyl('Thigh plate round recessed port',(s*xx,-.52,zz),(s*xx,-.55,zz),.077,GRAPHITE)
        cyl('Long dark leg load spar',knee,ankle,.19,GRAPHITE)
        # Knee shock absorber behind the leading blue armor.
        rear_offset=Vector((s*-.18,.18,0))
        p0=knee+rear_offset+Vector((0,0,-.14));p1=ankle+rear_offset+Vector((0,0,.33))
        mid=p0.lerp(p1,.58)
        cyl('Hydraulic dark cylinder',p0,mid,.105,GRAPHITE)
        cyl('Hydraulic chrome piston',mid,p1,.059,EDGE)
        for q in (p0,mid):torus('Piston collar',q,.11,.018,STEEL,p1-p0)
        a=knee+Vector((s*.16,-.19,-.02));b=ankle+Vector((s*.08,-.18,.12))
        segment('Dark shin underplate',a+Vector((0,.10,0)),b+Vector((0,.10,0)),.83 if rear else .92,.38,GRAPHITE)
        segment('Long tapered cobalt shin armor',a,b,.72 if rear else .81,.30,BLUE)
        segment('Blue shin bevel highlight',a+Vector((s*-.23,-.055,0)),b+Vector((s*-.09,-.055,0)),.18,.06,BLUE_LIGHT)
        segment('Exposed lower steel armor rail',knee+Vector((s*-.28,-.17,-.1)),ankle+Vector((s*-.22,-.16,.24)),.24,.13,PLATE)
        # Segmented inner shin insert, a small service plate and visible piston slot.
        ia=a.lerp(b,.20)+Vector((-s*.20,-.18,0));ib=a.lerp(b,.57)+Vector((-s*.17,-.18,0))
        segment('Inset grey shin reinforcement',ia,ib,.30,.07,PLATE)
        for f in (.2,.72):bolt(ia.lerp(ib,f)+Vector((0,-.065,0)),(0,-1,0),.021)
        wa=a.lerp(b,.66)+Vector((-s*.11,-.175,0));wb=a.lerp(b,.94)+Vector((-s*.085,-.175,0))
        segment('Shin piston recessed slot',wa,wb,.175,.035,BLACK)
        cyl('Visible shin chrome ram',wa+Vector((0,-.044,0)),wb+Vector((0,-.044,0)),.032,STEEL)
        cyl('Visible shin ram blue sleeve',wa+Vector((0,-.048,0)),wa.lerp(wb,.37)+Vector((0,-.048,0)),.05,BLUE_DARK)
        cross=a.lerp(b,.52)+Vector((-s*.17,-.237,0))
        plate('Shin tiny red caution triangle',[cross+Vector((-.042,0,-.025)),cross+Vector((.042,0,-.025)),cross+Vector((0,0,.053))],(0,-.008,0),RED)
        # Dark armor outline and machined seam along leading edge.
        hose('Shin edge panel seam',[a+Vector((s*.23,-.174,-.13)),a.lerp(b,.46)+Vector((s*.22,-.19,0)),b+Vector((s*.07,-.174,.06))],.012,BLUE_DARK)
        joint('Ankle hinge',ankle,.215)
        foot=ankle+Vector((s*.03,-.03,-.21))
        box('Rubber stabilized foot',foot,(.52,.63,.30),BLACK,.12,rotation=(0,s*-.22,0))
        box('Armored foot cap',foot+Vector((0,-.07,.17)),(.59,.55,.38),GRAPHITE,.09,rotation=(0,s*-.22,0))
        box('Foot contact insert',foot+Vector((0,-.27,-.025)),(.33,.16,.11),PLATE,.025)
        for f in (.13,.46,.84):
            p=a.lerp(b,f)+Vector((0,-.14,0));bolt(p,(0,-1,0),.031)
        for k in range(3):
            p=hip.lerp(knee,.35)+Vector((s*.08,-.28,.16-k*.2))
            cyl('Upper link recessed circular port',p,p+Vector((0,-.05,0)),.085,GRAPHITE)
        hose('Leg flex hydraulic feed',[hip+Vector((0,-.3,0)),hip.lerp(knee,.5)+Vector((0,-.28,-.12)),knee+Vector((s*-.2,-.1,-.4))],.047)
        # Rearward triangular dark knee guard.
        segment('Knee crown armor',knee+Vector((0,0,.36)),knee+Vector((s*.21,.05,-.19)),.52,.26,GRAPHITE)

# Compact paired front manipulating arms and three articulated fingers.
for s in (-1,1):
    group('05 | '+('left' if s<0 else 'right')+' three finger manipulator')
    shoulder=Vector((s*.79,-1.32,1.61));elbow=Vector((s*1.15,-1.72,1.07));wrist=Vector((s*1.02,-2.30,.94))
    joint('Arm shoulder',shoulder,.23)
    cyl('Arm upper internal link',shoulder,elbow,.13,GRAPHITE)
    molded_forearm(shoulder,wrist+Vector((0,.11,.03)))
    box('Forearm small blue service tab',(s*1.05,-2.02,1.34),(.19,.21,.08),BLUE_LIGHT,.025,rotation=(.55,0,0))
    joint('Arm elbow axis',elbow,.19)
    cyl('Wrist chrome collar',wrist+Vector((0,.12,.02)),wrist-Vector((0,.09,.02)),.238,STEEL)
    cyl('Wrist rubber bearing',wrist-Vector((0,.09,.02)),wrist-Vector((0,.19,.04)),.19,BLACK)
    palm=wrist+Vector((0,-.26,-.04))
    uv('Dark articulated palm',palm,(.21,.25,.15),GRAPHITE)
    for dx in (-.15,.15):
        p0=palm+Vector((dx,-.12,-.02))
        p1=p0+Vector((dx*.30,-.14 if s>0 else -.25,-.26 if s>0 else -.14))
        p2=p1+Vector((-dx*.18,.055 if s>0 else .09,-.17 if s>0 else -.12))
        segment('Finger proximal phalanx',p0,p1,.19,.155,GRAPHITE)
        uv('Finger knuckle',p0,(.09,.10,.085),GRAPHITE)
        cyl('Finger knuckle metal pivot',p0-Vector((.09,0,0)),p0+Vector((.09,0,0)),.043,STEEL)
        uv('Finger middle joint',p1,(.087,.09,.085),BLACK)
        segment('Finger tapered tip',p1,p2,.17,.13,GRAPHITE)
    p0=palm+Vector((-s*.22,0,0));p1=p0+Vector((-s*.15,-.15,-.08));p2=p1+Vector((s*.06,-.14,-.16))
    segment('Opposing thumb',p0,p1,.17,.14,GRAPHITE)
    segment('Thumb tip',p1,p2,.15,.12,GRAPHITE)
    cyl('Thumb hinge steel pivot',p0-Vector((.08,0,0)),p0+Vector((.08,0,0)),.034,STEEL)
    hose('Hand control conduit',[shoulder+Vector((0,.03,-.1)),elbow+Vector((s*.2,0,-.1)),wrist+Vector((s*.1,.1,-.1))],.035)
    for k in range(3):bolt((s*1.07,-1.95+k*.12,1.40+k*.08),(0,-.7,.7),.021)

# Belly rotary spindle and fine point tools. Broad industrial details from reference.
group('06 | central rotary tool and precision probes')
loft('Ventral gimbal shroud',[(-1.79,1.79,.55,.20),(-1.27,1.82,.74,.25),(-.83,1.88,.62,.27)],GRAPHITE)
box('Ventral shroud lower gasket',(0,-1.805,1.70),(1.02,.055,.075),BLACK,.018)
for s in (-1,1):
    cyl('Arm root flexible bellows',(s*.62,-1.37,1.72),(s*.79,-1.32,1.61),.18,BLACK)
    hose('Jaw to tool cradle control conduit',[(s*.38,-1.76,1.92),(s*.43,-1.79,1.72),(s*.39,-1.45,1.58)],.038,BLACK)
box('Ventral tool mounting cradle',(0,-1.30,1.49),(1.02,.58,.35),GRAPHITE,.065,rotation=(.2,0,0))
a=Vector((0,-1.64,1.54));b=Vector((0,-2.80,1.12));n=(b-a).normalized()
cyl('Rotary spindle motor',a,a.lerp(b,.43),.255,STEEL)
cyl('Rotary tool fluted housing',a.lerp(b,.38),b,.205,GRAPHITE)
for f in (.46,.59,.73,.92):torus('Rotary spindle rib',a.lerp(b,f),.208,.032,BLACK,n)
cyl('Rotary spindle front cap',b,b+n*.055,.22,PLATE)
u=Vector((1,0,0));v=n.cross(u)
for ang in range(0,360,60):
    off=(u*math.cos(math.radians(ang))+v*math.sin(math.radians(ang)))*.133
    cyl('Rotary spindle dark socket',b+off+n*.055,b+off+n*.063,.043,BLACK)
    torus('Socket machined edge',b+off+n*.068,.043,.008,GRAPHITE,n)
cyl('Spindle center recess',b+n*.055,b+n*.062,.041,BLACK)
hose('Spindle safety handle',[(-.22,-1.76,1.61),(-.24,-1.78,1.92),(.22,-1.78,1.92),(.23,-1.82,1.61)],.025,STEEL)
for s in (-1,1):
    p=Vector((s*.48,-1.56,1.36));q=Vector((s*.52,-2.77,.94));n2=(q-p).normalized()
    cyl('Precision tool motor',p,p.lerp(q,.36),.116,PLATE)
    cyl('Precision tool black sleeve',p.lerp(q,.3),p.lerp(q,.69),.077,GRAPHITE)
    torus('Precision tool brass collar',p.lerp(q,.55),.08,.02,GOLD,n2)
    cyl('Fine silver probe',p.lerp(q,.67),q,.042,STEEL,r2=.019)
    cyl('Precision probe needle',q,q+n2*.18,.020,EDGE,r2=.002)
    if s<0:torus('Welder cyan status ring',p.lerp(q,.76),.045,.013,GLOW,n2)

# Extra folding tools attached to the outer front legs.
for s in (-1,1):
    group('07 | '+('port shielded welding tool' if s<0 else 'starboard circular saw arm'))
    p0=Vector((s*1.59,-.57,2.04));p1=Vector((s*1.85,-1.15,1.35));p2=Vector((s*1.99,-2.03,.60))
    cyl('Folding tool upper link',p0,p1,.08,STEEL)
    segment('Folding tool flat upper link',p0,p1,.25,.13,PLATE)
    segment('Folding tool flat lower link',p1,p2,.22,.12,PLATE)
    for p in (p0,p1,p2):joint('Folding tool knuckle',p,.10)
    hose('Tool hose loop',[p0+Vector((0,.1,.15)),p1+Vector((s*.20,-.14,.22)),p2+Vector((s*.13,-.01,.18))],.032)
    hose('Tool secondary cable',[p0+Vector((0,.12,.1)),p1+Vector((s*.28,-.04,.23)),p2+Vector((s*.20,.02,.20))],.022,GRAPHITE)
    if s>0:
        center=p2+Vector((.025,-.12,-.13))
        # Actual toothed saw mesh in YZ plane, with alternating tooth shoulders.
        teeth=28;verts=[]
        for x in (-.019,.019):
            for i in range(teeth*3):
                ang=i*2*math.pi/(teeth*3);rad=.355 if i%3==0 else .302
                verts.append(tuple(center+Vector((x,math.cos(ang)*rad,math.sin(ang)*rad))))
        nn=teeth*3
        faces=[tuple(reversed(range(nn))),tuple(range(nn,nn*2))]+[(i,(i+1)%nn,(i+1)%nn+nn,i+nn) for i in range(nn)]
        mesh('28 tooth circular cutting blade',verts,faces,STEEL,.002)
        cyl('Saw drive hub',center-Vector((.09,0,0)),center+Vector((.09,0,0)),.102,GRAPHITE)
        torus('Saw etched ring',center+Vector((.023,0,0)),.231,.007,GRAPHITE,(1,0,0))
        for k in range(6):
            ang=k*math.pi/3;pos=center+Vector((.024,.20*math.cos(ang),.20*math.sin(ang)))
            cyl('Saw radial perforation dark mark',pos,pos+Vector((.005,0,0)),.026,BLACK)
        box('Saw motor blue shield',p2+Vector((-.02,.07,.15)),(.22,.44,.25),BLUE,.04,rotation=(-.4,0,0))
    else:
        cyl('Welder ceramic nozzle',p2,p2+Vector((0,-.18,-.20)),.09,PLATE,r2=.045)
        cyl('Welder brass terminal',p2+Vector((0,-.18,-.20)),p2+Vector((0,-.26,-.33)),.045,GOLD,r2=.020)
        cyl('Welder fine needle',p2+Vector((0,-.26,-.33)),p2+Vector((0,-.33,-.42)),.015,EDGE,r2=.002)
        plate('Welder folded protective shield',[(s*2.35,-2.22,1.02),(s*2.08,-2.34,.84),(s*2.10,-2.43,.44),(s*2.31,-2.32,.72)],(0,.045,0),BLUE_DARK)
        plate('Welder inner shield facet',[(s*2.08,-2.34,.84),(s*1.83,-2.22,.90),(s*1.89,-2.36,.45),(s*2.10,-2.43,.44)],(0,.045,0),PLATE)
        hose('Welder shield rolled rim',[(s*2.35,-2.25,1.02),(s*2.08,-2.37,.84),(s*1.83,-2.25,.90)],.018,GRAPHITE)
        box('Welder cyan status light',p2+Vector((-.03,-.40,-.08)),(.12,.022,.055),GLOW,.01)

# Rear powerpack detailing: continuation of visible construction, hidden design inferred.
group('08 | rear service pack and cooling')
box('Rear removable battery pack',(0,1.55,2.89),(1.36,.36,1.25),BLUE,.10)
box('Rear inset grey service hatch',(0,1.755,2.98),(.93,.08,.88),PLATE,.05)
plate('Rear upper grey spine continuation',[(-.34,1.54,4.04),(.34,1.54,4.04),(.40,1.76,3.54),(-.40,1.76,3.54)],(0,.055,0),PLATE)
box('Rear spine dark recessed connector',(0,1.80,3.62),(.30,.045,.13),GRAPHITE,.012)
for s in (-1,1):
    box('Rear blue shoulder wrap',(s*.84,1.55,3.33),(.39,.32,.74),BLUE,.09)
    box('Rear vertical taillight housing',(s*.86,1.73,3.31),(.18,.10,.40),GRAPHITE,.025)
    box('Rear cyan indicator',(s*.86,1.787,3.34),(.09,.01,.24),GLOW,.01)
    for z in (2.62,3.33):bolt((s*.38,1.809,z),(0,1,0))
    hose('Rear exposed curved coolant pipe',[(s*.74,1.45,2.18),(s*.80,1.86,2.3),(s*.41,1.91,2.43)],.058,GRAPHITE)
    cyl('Rear coolant connector',(s*.41,1.68,2.43),(s*.41,1.92,2.43),.085,STEEL,12)
    torus('Rear coolant connector gasket',(s*.41,1.87,2.43),.085,.016,BLACK,(0,1,0))
for k in range(6):box('Rear horizontal radiator louvre',(0,1.812,2.77+k*.07),(.64,.05,.029),BLACK,.005)
label('SR-09',(.27,1.815,3.33),.11,WHITE,(math.pi/2,0,math.pi))
cyl('Rear belly exhaust',(-.30,1.54,2.20),(-.30,1.93,2.20),.13,STEEL)
cyl('Rear belly exhaust dark bore',(-.30,1.934,2.20),(-.30,1.94,2.20),.10,BLACK)

# Open service trays with real wrenches, socket tubes and hinged blue lids.
group('09 | open tool trays and service tools')
def wrench(name,base,height,lean=0):
    base=Vector(base);top=base+Vector((lean,0,height))
    cyl(name+' handle',base,top,.035,STEEL,12)
    torus(name+' ring end',base,.062,.018,STEEL,(0,-1,0))
    # Open-end jaws made from a single extruded U outline.
    x,y,z=top;w=.085
    pts=[(x-w,y,z-.07),(x-w*1.28,y,z+.06),(x-w*.72,y,z+.14),(x-w*.45,y,z+.03),(x+w*.45,y,z+.03),(x+w*.72,y,z+.14),(x+w*1.28,y,z+.06),(x+w,y,z-.07)]
    plate(name+' open jaw',pts,(0,.038,0),STEEL)

for s in (-1,1):
    x=s*1.19;y=1.00;z=3.57
    box('Tool tray base',(x,y,z),(.59,1.02,.14),GRAPHITE,.05)
    box('Tool tray lower rounded enclosure',(x,y+.06,z-.14),(.58,.66,.38),GRAPHITE,.08)
    box('Tool tray foam insert',(x,y,z+.09),(.47,.88,.065),BLACK,.025)
    for yy in (y-.48,y+.48):
        box('Tool tray end wall',(x,yy,z+.20),(.58,.08,.32),GRAPHITE,.025)
        box('Tray rolled metal lip',(x,yy,z+.365),(.59,.095,.035),PLATE,.01)
        for xx in (-.21,.21):bolt((x+xx,yy-.045,z+.21),(0,-1,0),.023)
    box('Tray outer wall',(x+s*.27,y,z+.20),(.08,.94,.31),GRAPHITE,.025)
    # Lid hinged outward and raised.
    plate('Open cobalt tool tray lid',[(x+s*.28,y-.49,z+.09),(x+s*.67,y-.47,z+.42),(x+s*.68,y+.48,z+.48),(x+s*.31,y+.51,z+.16)],(0,0,.065),BLUE)
    plate('Lid inset liner',[(x+s*.34,y-.35,z+.18),(x+s*.58,y-.34,z+.39),(x+s*.59,y+.37,z+.44),(x+s*.36,y+.38,z+.23)],(0,0,.015),BLUE_DARK)
    cyl('Tray hinge axle',(x+s*.27,y-.42,z+.10),(x+s*.27,y+.42,z+.10),.044,STEEL)
    plate('Upright rear tool bin lid',[(x-s*.26,y+.43,z+.18),(x+s*.32,y+.43,z+.18),(x+s*.36,y+.58,z+.67),(x+s*.30,y+.62,z+.78),(x-s*.16,y+.62,z+.78),(x-s*.26,y+.57,z+.70)],(0,.065,0),GRAPHITE)
    plate('Tool bin lid grey inner inset',[(x-s*.20,y+.409,z+.25),(x+s*.25,y+.409,z+.25),(x+s*.29,y+.555,z+.65),(x+s*.23,y+.59,z+.71),(x-s*.12,y+.59,z+.71),(x-s*.20,y+.54,z+.65)],(0,.024,0),PLATE)
    for xx in (-.15,.18):
        cyl('Tool bin lid short hinge',(x+xx-.07,y+.43,z+.20),(x+xx+.07,y+.43,z+.20),.035,STEEL)
    box('Tool bin small red warning stripe',(x+s*.12,y+.427,z+.35),(.065,.012,.025),RED,.002)
    if s<0:
        wrench('Tall open end spanner',(x-s*.08,y+.11,z+.11),.63,s*.04)
        wrench('Short open end spanner',(x+s*.05,y-.23,z+.12),.39,-s*.08)
    else:
        wrench('Short open end spanner',(x-s*.08,y-.12,z+.11),.39,s*.03)
        cyl('Screwdriver steel shank',(x+s*.06,y+.19,z+.13),(x+s*.14,y+.19,z+.52),.025,STEEL)
        cyl('Screwdriver black grip',(x+s*.14,y+.19,z+.49),(x+s*.18,y+.19,z+.70),.039,GRAPHITE)
    for yy,hh in ((y+.33,.28),(y-.37,.24)):
        cyl('Socket extension',(x+s*.09,yy,z+.13),(x+s*.09,yy,z+hh+.13),.072,STEEL)
        cyl('Socket dark open center',(x+s*.09,yy,z+hh+.132),(x+s*.09,yy,z+hh+.139),.047,BLACK)
    cyl('Tray side swiveling joint',(x+s*.31,y+.12,z-.14),(x+s*.44,y+.12,z-.14),.18,PLATE)
    cyl('Tray side dome retaining housing',(x+s*.27,y+.12,z-.14),(x+s*.41,y+.12,z-.14),.235,GRAPHITE)
    torus('Tray side dome steel surround',(x+s*.405,y+.12,z-.14),.208,.025,STEEL,(s,0,0))
    uv('Tray side rounded cap',(x+s*.45,y+.12,z-.14),(.16,.16,.16),STEEL)

# Raised rugged diagnostic terminal. Actual screen graphic built as editable curves.
group('10 | hinged diagnostic terminal')
box('Terminal pedestal',(0,1.30,4.06),(.71,.31,.15),GRAPHITE,.035)
cyl('Terminal hinge pin',(-.44,1.26,4.16),(.44,1.26,4.16),.080,STEEL)
# Screen face points toward -Y; mild backwards tilt, all graphic children transformed together.
screen_parts=[]
before=set(bpy.data.objects)
box('Rugged monitor outer case',(0,1.26,4.59),(1.05,.18,.91),GRAPHITE,.06)
box('Monitor silver inset bevel',(0,1.154,4.59),(.92,.035,.76),PLATE,.025)
box('Diagnostic teal screen',(0,1.129,4.59),(.85,.018,.68),SCREEN,.013)
box('Monitor rear access panel',(0,1.363,4.60),(.64,.035,.52),PLATE,.025)
for xx in (-.27,.27):
    for zz in (4.40,4.80):bolt((xx,1.39,zz),(0,1,0),.019)
plate('Monitor rear caution marking',[(-.056,1.388,4.60),(.056,1.388,4.60),(0,1.388,4.69)],(0,.004,0),RED)
for s in (-1,1):
    for z in (4.23,4.96):
        box('Monitor protective corner',(s*.48,1.23,z),(.15,.21,.17),GRAPHITE,.035)
        bolt((s*.47,1.11,z),(0,-1,0),.018)
label('SYSTEM / SR-09',(-.385,1.115,4.84),.046,UI)
label('HULL SERVICE',(-.385,1.115,4.33),.039,UI)
label('ONLINE',(.20,1.115,4.36),.035,UI)
for k in range(3):box('Display status bar',(-.28,1.112,4.41+k*.04),(.20-k*.025,.007,.013),UI,.001)
# Wireframe mech schematic on display.
for z,w in ((4.73,.14),(4.57,.21)):
    hose('Display wireframe body',[(-w,1.108,z-.08),(-w,1.108,z+.07),(w,1.108,z+.07),(w,1.108,z-.08),(-w,1.108,z-.08)],.005,UI)
for s in (-1,1):
    for z in (4.59,4.74):
        hose('Display wireframe legs',[(s*.15,1.108,z),(s*.28,1.108,z+.015),(s*.34,1.108,z-.12),(s*.28,1.108,z-.13)],.005,UI)
    torus('Display eye outline',(s*.09,1.104,4.59),.045,.005,UI,(0,-1,0))
for k in range(5):box('Display tiny telemetry',(.26,1.111,4.47+k*.068),(.16,.005,.012),UI,.001)
# Replace the provisional screen drawing with the exact visible source micrographic.
for obj in list(set(bpy.data.objects)-before):
    if obj.type=='FONT' or obj.name.startswith('Display '):bpy.data.objects.remove(obj,do_unlink=True)
reference_decal('Source diagnostic screen artwork',[(-.425,1.10,4.93),(.425,1.10,4.93),(.425,1.10,4.25),(-.425,1.10,4.25)],[(662,164),(739,170),(731,221),(652,214)],.75)
pivot=Vector((0,1.26,4.15));rot=Matrix.Rotation(math.radians(-12),4,'X')@Matrix.Diagonal((1.13,1,.88,1))
for obj in set(bpy.data.objects)-before:obj.matrix_world=Matrix.Translation(pivot)@rot@Matrix.Translation(-pivot)@obj.matrix_world

# Reference image empties are packed into the blend and kept off the render.
group('11 | packed concept and turnaround references')
for name,filename,location,rotation in (
    ('Original authoritative concept','original_concept.png',(-6,1,3),(math.pi/2,0,0)),
    ('Generated orthographic interpretation','concept_turnaround.png',(7,1,3),(math.pi/2,0,0)),
):
    path=OUT/'references'/filename
    if path.exists():
        image=bpy.data.images.load(str(path),check_existing=True);image.pack()
        obj=bpy.data.objects.new(name,None);active_collection.objects.link(obj)
        obj.empty_display_type='IMAGE';obj.data=image;obj.empty_display_size=5;obj.location=location;obj.rotation_euler=rotation
        obj.hide_render=True;obj.hide_viewport=True

# Studio and model cameras.
active_collection=bpy.data.collections.new('STUDIO | cameras and lighting')
scene.collection.children.link(active_collection)
FLOOR=mat('Studio warm off white',(.83,.85,.86),0,.75)
ground=box('Studio shadow ground',(0,0,-.07),(200,200,.1),FLOOR,0)
scene.world.color=(.6,.6,.6)
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.65,.72,.8,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.45
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.25
for name,loc,power,size in (('Large softbox',(-5,-6,10),1200,7),('Front fill',(6,-4,6),550,5),('Rear rim',(2,6,9),1400,5)):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;track(o);o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()
def camera(name,loc,target,scale):
    bpy.ops.object.camera_add(location=loc);o=bpy.context.object;track(o);o.name=name
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=scale;o.data.lens=50
    return o
cameras={
    'hero':camera('CAM 01 | original concept angle',(8,-12,8.3),(0,-.05,2.35),7.40),
    'front':camera('CAM 02 | FRONT orthographic',(0,-15,2.48),(0,0,2.48),6.65),
    'right':camera('CAM 03 | RIGHT orthographic',(15,0,2.48),(0,0,2.48),6.65),
    'back':camera('CAM 04 | BACK orthographic',(0,15,2.48),(0,0,2.48),6.65),
    'detail':camera('CAM 05 | face and equipment detail',(5,-10,7),(0,-.70,2.95),4.55),
}
scene.render.engine='CYCLES';scene.cycles.samples=24 if PREVIEW else 48;scene.cycles.use_denoising=True
scene.cycles.device='CPU'
# CPU is deliberate: this installed Blender build fails to load its OptiX kernel.
scene.render.resolution_x=850 if PREVIEW else 1600;scene.render.resolution_y=scene.render.resolution_x;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.use_freestyle=not PREVIEW
scene.render.line_thickness=.85
line_style=scene.view_layers[0].freestyle_settings.linesets[0].linestyle
line_style.color=(.018,.026,.04);line_style.alpha=.85;line_style.thickness=1.15
scene.view_layers[0].freestyle_settings.crease_angle=math.radians(130)
line_exclusions=bpy.data.collections.new('STUDIO | no ink on stencils and display graphics')
scene.collection.children.link(line_exclusions)
for obj in model.all_objects:
    if obj.type=='FONT' or obj.name.startswith(('Display ','Diagnostic teal','Source ')):
        line_exclusions.objects.link(obj)
line_set=scene.view_layers[0].freestyle_settings.linesets[0]
line_set.select_by_collection=True;line_set.collection=line_exclusions;line_set.collection_negation='EXCLUSIVE'
scene.camera=cameras['hero']
scene.render.filepath=str(OUT/'renders'/'hero.png')
scene['design_source']='references/original_concept.png'
scene['reconstruction_note']='Visible design reconstructed from single concept; hidden rear surfaces are inferred. Orthographic source sheet is interpretive, not ground truth.'
scene['units_note']='Meters; full height approximately 5.1 m including monitor. Source supplied no physical scale.'
scene.unit_settings.system='METRIC'
# Open in a useful material preview camera view.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT')
mesh_objects=[o for o in model.all_objects if o.type=='MESH']
for obj in mesh_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=mesh_objects[0]
report={'blender':bpy.app.version_string,'mesh_objects':len(mesh_objects),'vertices_base':sum(len(o.data.vertices) for o in mesh_objects),'collections':list(groups),'status':'visual review pending','rear_design':'inferred from single concept'}
(OUT/'build_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'shipwright.blend'))
if not PREVIEW:
    # Export a converted copy in memory; the saved native file retains editable curves/text.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in model.all_objects:
        if obj.type in {'MESH','CURVE','FONT'}:obj.select_set(True)
    bpy.context.view_layer.objects.active=mesh_objects[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'shipwright.glb'),export_format='GLB',use_selection=True,export_apply=True)
for key in (['hero'] if PREVIEW else ['hero','front','right','back','detail']):
    scene.camera=cameras[key];scene.render.filepath=str(OUT/'renders'/f'{key}.png')
    orthographic_sheet=key in {'front','right','back'}
    ground.hide_render=orthographic_sheet
    scene.render.film_transparent=orthographic_sheet
    scene.render.image_settings.color_mode='RGBA'
    bpy.ops.render.render(write_still=True)
print('SHIPWRIGHT_BUILD_OK',OUT)
