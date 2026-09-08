"""Revise the EXISTING monolith.blend; preserve the original and its cameras.
blender --background --factory-startup --python revise_monolith.py
Outputs monolith_v2.blend and review_v2/*.png. --model-only skips rendering.
Geometry helpers are loaded as function definitions only from build_monolith.py;
the original build script is never executed and the original model is not rebuilt.
"""
import ast
import bpy
import math
import os
import sys
from pathlib import Path
from math import sin, cos, pi
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(HERE/'monolith.blend'))
F=bpy.data.objects['Monolith_Foundation']
T=bpy.data.objects['Monolith_Turret']
B=bpy.data.objects['Monolith_Barrel']
FC,TC,BC=(o.users_collection[0] for o in (F,T,B))
SC=bpy.data.collections['90 Studio | review only']
main=bpy.data.collections['MONOLITH | design model']
original_count=len(bpy.data.objects)
B.rotation_euler.x=0
bpy.context.view_layer.update()

def weather(material, color, metallic, roughness):
    """Subtle casting variation, patchy grime and sparse edge wear; no maps."""
    material.diffuse_color=(*color,1)
    nt=material.node_tree
    nt.nodes.clear()
    out=nt.nodes.new('ShaderNodeOutputMaterial')
    bs=nt.nodes.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Metallic'].default_value=metallic
    nt.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    coords=nt.nodes.new('ShaderNodeTexCoord')
    obj=nt.nodes.new('ShaderNodeObjectInfo')
    noise=nt.nodes.new('ShaderNodeTexNoise')
    noise.noise_dimensions='4D'
    noise.inputs['Scale'].default_value=5
    noise.inputs['Detail'].default_value=3
    nt.links.new(coords.outputs['Generated'],noise.inputs['Vector'])
    nt.links.new(obj.outputs['Random'],noise.inputs['W'])
    ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.24
    ramp.color_ramp.elements[0].color=(*(v*.43 for v in color),1)
    ramp.color_ramp.elements[1].position=.77
    ramp.color_ramp.elements[1].color=(*(v*1.18 for v in color),1)
    nt.links.new(noise.outputs['Fac'],ramp.inputs[0])
    geom=nt.nodes.new('ShaderNodeNewGeometry')
    wear=nt.nodes.new('ShaderNodeValToRGB')
    wear.color_ramp.elements[0].position=.51
    wear.color_ramp.elements[1].position=.61
    wear.color_ramp.elements[1].color=(.22,.22,.22,1)
    nt.links.new(geom.outputs['Pointiness'],wear.inputs[0])
    mix=nt.nodes.new('ShaderNodeMixRGB')
    nt.links.new(wear.outputs[0],mix.inputs[0])
    nt.links.new(ramp.outputs[0],mix.inputs[1])
    mix.inputs[2].default_value=(*(min(.16,v*1.8) for v in color),1)
    nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    rough=nt.nodes.new('ShaderNodeMapRange')
    rough.inputs['To Min'].default_value=roughness-.1
    rough.inputs['To Max'].default_value=min(.95,roughness+.12)
    nt.links.new(noise.outputs['Fac'],rough.inputs['Value'])
    nt.links.new(rough.outputs[0],bs.inputs['Roughness'])
    fine=nt.nodes.new('ShaderNodeTexNoise')
    fine.inputs['Scale'].default_value=95
    nt.links.new(coords.outputs['Generated'],fine.inputs['Vector'])
    bump=nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=.16
    bump.inputs['Distance'].default_value=.025
    nt.links.new(fine.outputs['Fac'],bump.inputs['Height'])
    nt.links.new(bump.outputs[0],bs.inputs['Normal'])
    return material

steel=weather(bpy.data.materials['Steel | warm dark cast alloy'],(.034,.041,.042),.48,.72)
armor=weather(bpy.data.materials['Armor | muted graphite olive'],(.064,.071,.054),.42,.77)
edge=weather(bpy.data.materials['Edges | machined steel'],(.075,.085,.08),.55,.63)
dark=weather(bpy.data.materials['Machinery | oily charcoal'],(.014,.019,.02),.46,.59)
yellow=weather(bpy.data.materials['Safety | aged ochre'],(.36,.20,.031),.3,.78)
copper=weather(bpy.data.materials['Busbars | aged copper'],(.14,.067,.031),.5,.65)
concrete=weather(bpy.data.materials['Foundation | reinforced mineral composite'],(.075,.078,.068),.05,.88)
black=bpy.data.materials['Bore | soot']
oil=weather(steel.copy(),(.009,.012,.01),.25,.29)
oil.name='Wear | grease and oil seepage'
soot=weather(steel.copy(),(.018,.016,.013),.26,.85)
soot.name='Wear | muzzle heat scale and soot'

# Reuse construction utilities, without running any original scene creation.
source=ast.parse((HERE/'build_monolith.py').read_text(encoding='utf-8'))
names={'finish','box','cyl','beam','pipe','ring','radial_box'}
module=ast.Module(body=[n for n in source.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[])
exec(compile(module,'monolith_geometry_helpers','exec'),globals())

def remove_prefixes(prefixes):
    for o in list(bpy.data.objects):
        if any(o.name.startswith(s) for s in prefixes):
            bpy.data.objects.remove(o,do_unlink=True)

def assign(o,m):
    o.data.materials.clear()
    o.data.materials.append(m)

def tube(name,y,ri,ro,length,m=steel,n=16):
    o=ring(name,ri,ro,0,length,m,B,n=n)
    o.location.y=y
    o.rotation_euler.x=pi/2
    return o

# Expand two existing peripheral equipment sites, retaining the foundation drum.
remove_prefixes(['Foundation_Machinery | shell forge','Forge |',
                 'Foundation | cooling station','Cooling |'])
box('V2 Factory | common heavy bed',(-5.35,-4.75,.89),(3.35,3.95,.62),dark)
box('V2 Factory | armored forming chamber',(-5.35,-4.25,1.79),(3.0,2.65,1.66),armor)
box('V2 Factory | press crown',(-5.35,-4.25,2.78),(3.24,2.8,.45),steel)
for x in (-6.54,-4.16):
    box('V2 Factory | load column',(x,-4.25,1.89),(.42,2.4,2.0),steel)
    box('V2 Factory | column cap',(x,-4.25,2.95),(.55,2.6,.16),edge)
    cyl('V2 Factory | hydraulic head',(x,-4.25,3.14),.25,.4,dark)
box('V2 Factory | die access recess',(-5.35,-5.59,1.81),(1.97,.1,1.11),dark)
for x in (-5.91,-4.79):
    box('V2 Factory | split die block',(x,-5.67,1.8),(.92,.19,.94),steel)
box('V2 Factory | safety lintel',(-5.35,-5.77,2.42),(2.19,.1,.16),yellow)
box('V2 Factory | shell transfer bed',(-5.35,-6.14,1.15),(2.30,1.09,.34),steel)
for y in (-6.52,-6.25,-5.98,-5.71):
    cyl('V2 Factory | transfer roller',(-5.35,y,1.43),.13,1.9,edge,F,'X')
cyl('V2 Factory | shell blank in die',(-5.35,-5.92,1.91),.36,1.48,armor,F,'Y',16)
for x in (-6.15,-5.35,-4.55):
    box('V2 Factory | top manifold saddle',(x,-4.25,3.12),(.26,2.14,.17),dark)
    pipe('V2 Factory | formed pressure main',[(x,-5.22,3.19),(x,-3.62,3.19),(x,-3.45,2.88)],.115,copper)
for z in (1.35,1.72,2.09,2.46):
    box('V2 Factory | heat exchanger fin',(-6.89,-4.27,z),(.18,2.15,.14),edge)
pipe('V2 Factory | feed into foundation',[(-4.1,-3.5,1.2),(-3.55,-3.5,1.2),(-3.55,-3.1,1.7)],.19,steel)

# Six visibly large storage columns grouped by a structural cage and busbars.
box('V2 Capacitor | energy bank plinth',(5.45,4.5,.93),(3.16,4.2,.64),dark)
for x in (4.65,6.12):
    for y in (3.15,4.5,5.85):
        cyl('V2 Capacitor | large storage column',(x,y,2.02),.55,2.02,dark)
        for z in (1.13,2.08,2.97):
            cyl('V2 Capacitor | vessel band',(x,y,z),.59,.16,steel)
        cyl('V2 Capacitor | dished top',(x,y,3.15),.53,.26,armor,r2=.3)
        cyl('V2 Capacitor | insulating terminal',(x,y,3.38),.17,.24,dark)
    box('V2 Capacitor | copper bus trunk',(x,4.5,3.59),(.19,3.25,.14),copper)
for y in (2.56,6.45):
    box('V2 Capacitor | protective end bulkhead',(5.45,y,1.96),(3.08,.24,2.2),armor)
    box('V2 Capacitor | bulkhead shoulder',(5.45,y,3.11),(3.22,.32,.19),steel)
    box('V2 Capacitor | access panel',(5.45,y+(-.14 if y<4 else .14),2.02),(1.97,.055,1.2),dark)
    box('V2 Capacitor | caution panel',(5.45,y+(-.18 if y<4 else .18),2.63),(.79,.04,.13),yellow)
for z in (1.40,2.38):
    box('V2 Capacitor | outer cage rail',(6.94,4.5,z),(.18,3.67,.22),steel)
pipe('V2 Capacitor | heavy power feed',[(4.65,2.83,3.58),(4.2,2.83,3.58),(4.1,2.8,2.42),(3.95,2.5,2.34)],.13,copper)

# Enlarge the existing loading gantry rather than adding another small station.
for o in list(F.children):
    if o.name.startswith('Loading | gantry'):
        o.scale.x*=1.65
        o.scale.y*=1.6
box('V2 Loading | rammer housing',(5.8,-3.83,2.12),(1.74,.9,1.42),armor)
cyl('V2 Loading | rammer drive',(5.8,-4.55,2.08),.38,.8,dark,F,'Y')
for x in (5.08,6.52):
    beam('V2 Loading | diagonal brace',(x,-5.7,1),(x,-3.8,2.5),.24,.26,steel)

# Thicken the retained A-frame externally; keep both pivot locations unchanged.
for o in list(T.children):
    if o.type!='MESH':continue
    n=o.name
    if n.startswith('Turret_Support | A-frame main spar'):
        o.scale.x*=1.5
        o.scale.y*=1.38
    elif n.startswith('Turret_Support | longitudinal foot'):
        o.scale.x*=1.25
        o.scale.z*=1.5
    elif n.startswith('Turret | anchor shoe'):
        o.scale.x*=1.22
        o.scale.y*=1.35
    elif n.startswith('Turret | large bearing housing'):
        o.scale.x*=1.23
        o.scale.y*=1.23
    elif n.startswith('Turret | machined bearing rim'):
        o.scale.x*=1.2
        o.scale.y*=1.2
for x in (-2.48,2.48):
    side=1 if x>0 else -1
    for y in (-2.35,2.35):
        beam('V2 Turret | outer box girder',(x+side*.30,y,3.45),(x+side*.30,0,7.3),.34,.95,armor,T)
        box('V2 Turret | heavy root block',(x,y,3.48),(1.32,1.1,.51),steel,T)
    beam('V2 Turret | deep side crossmember',(x,-1.58,4.7),(x,1.58,4.7),.48,.61,steel,T)
    beam('V2 Turret | upper side crossmember',(x,-.94,5.74),(x,.94,5.74),.45,.37,armor,T)
    cyl('V2 Turret | reduction gear casing',(x+side*.23,.65,6.74),.64,.47,dark,T,'X')
    pipe('V2 Turret | oil return',[(x+side*.30,.65,6.4),(x+side*.30,1.08,5.5),(x+side*.30,1.72,3.65)],.12,copper,T)

# Expand retained breech parts as a coherent assembly around the same axle.
for o in list(B.children):
    if o.type!='MESH':continue
    if o.name.startswith(('Barrel_Breech |','Breech |')):
        for v in o.data.vertices:
            co=o.matrix_basis @ v.co
            co.x*=1.16
            co.z*=1.16
            v.co=o.matrix_basis.inverted() @ co
        o.data.update()
    if o.name.startswith(('Barrel | open muzzle crown','Barrel | muzzle longitudinal lug')):
        assign(o,soot)
    elif o.name.startswith('Barrel | band flange'):
        assign(o,steel)

# Distinct silhouette zones: reinforced root, midspan coupling, slender foretube.
tube('V2 Barrel | root pressure sleeve',3.4,1.0,1.31,3.8,steel)
for y in (1.64,4.88):
    tube('V2 Barrel | root sleeve shoulder',y,1.0,1.41,.30,armor)
for x in (-1.28,1.28):
    box('V2 Barrel | root armor cheek',(x,3.3,0),(.25,3.65,1.04),armor,B)
    box('V2 Barrel | recoil cradle rail',(x,2.4,-.68),(.25,5.3,.34),steel,B)
tube('V2 Barrel | midspan reinforced sleeve',12.7,.78,1.18,3.35,dark)
for y,rad,thick in [(10.93,1.05,.30),(11.30,1.25,.32),(14.08,1.25,.32),(14.52,1.02,.28)]:
    tube('V2 Barrel | stepped midspan collar',y,.77,rad,thick,steel)
for a in (0,pi/2,pi,3*pi/2):
    o=box('V2 Barrel | midspan armor cassette',(1.16*cos(a),12.7,1.16*sin(a)),(.21,2.5,.81),armor,B)
    o.rotation_euler.y=-a
    o=box('V2 Barrel | sleeve edge strap',(1.30*cos(a),12.7,1.30*sin(a)),(.065,2.25,.09),edge,B)
    o.rotation_euler.y=-a
tube('V2 Barrel | foretube step',20.2,.60,.89,.45,armor)
for y,rad,depth in [(27.50,.81,.30),(28.30,.88,1.03),(29.08,.82,.48)]:
    tube('V2 Barrel | heat shield collar',y,.44,rad,depth,soot)
for a in (pi/4,3*pi/4,5*pi/4,7*pi/4):
    o=box('V2 Barrel | muzzle cooling shield',(.83*cos(a),28.34,.83*sin(a)),(.18,1.48,.42),steel,B)
    o.rotation_euler.y=-a
tube('V2 Barrel | soot-black muzzle lip',29.36,.43,.75,.14,black,48)

# Few broad wear cues placed at operational locations rather than tiny clutter.
for i in (0,3,7,12,17,21):
    a=i*2*pi/24
    ring('V2 Wear | seepage on annular deck',4.5,5.01,2.308,.012,oil,F,n=4,start=a+.02,end=a+.20)
for x in (-2.91,2.91):
    cyl('V2 Wear | bearing grease seal',(x,0,7.3),.83,.035,oil,T,'X',48)
for y in (1.48,11.12,14.26):
    tube('V2 Wear | lubricant at coupling',y,.9,1.29,.075,oil)

scene=bpy.context.scene
scene['revision']='v2 | existing model revised: industrial groups, reinforced cradle, stepped barrel, worn materials'
B['revision']='Breech expanded radially 16%; root and midspan sleeves; soot-dark muzzle. Original elevation pivot retained.'
notes=bpy.data.texts.get('MODEL_README')
notes.write('\nV2: revised directly from monolith.blend; original review cameras retained.\nFactory press and capacitor bank replace two small peripheral units.\nA-frame spars, roots and side bracing reinforced. Barrel gains distinct mass zones.\nProcedural casting variation, light edge wear, grease and muzzle heat scale.\n')

def geometry(objects,local=None):
    vs,fs,owners=[],[],[]
    for o in objects:
        if o.type!='MESH':continue
        matrix=o.matrix_world if local is None else local.inverted()@o.matrix_world
        offset=len(vs)
        vs.extend(matrix@v.co for v in o.data.vertices)
        fs.extend(tuple(offset+i for i in p.vertices) for p in o.data.polygons)
        owners.extend([o.name]*len(o.data.polygons))
    return vs,fs,owners

# Actual posed mesh surface check at every integer elevation; axle is a joint.
bpy.context.view_layer.update()
fv,ff,fn=geometry(F.children)
tv,tf,tn=geometry(T.children)
bv,bf,bn=geometry([o for o in B.children if 'trunnion axle' not in o.name],B.matrix_world)
foundation=BVHTree.FromPolygons(fv,ff)
turret=BVHTree.FromPolygons(tv,tf)
collisions=set()
for degree in range(61):
    B.rotation_euler.x=math.radians(degree)
    bpy.context.view_layer.update()
    tree=BVHTree.FromPolygons([B.matrix_world@v for v in bv],bf)
    for other,names in [(foundation,fn),(turret,tn)]:
        for a,b in tree.overlap(other):collisions.add((degree,bn[a],names[b]))
print('V2_SWEEP_INTERSECTIONS',len(collisions),flush=True)
for entry in sorted(collisions)[:30]:print(entry,flush=True)
assert not collisions,'Unexpected barrel contact: revise before rendering.'

try:
    preferences=bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type='OPTIX'
    preferences.get_devices()
    if any(d.type=='OPTIX' for d in preferences.devices):
        for d in preferences.devices:d.use=d.type=='OPTIX'
        scene.cycles.device='GPU'
except Exception:
    scene.cycles.device='CPU'
scene.cycles.samples=40
scene.cycles.use_denoising=True
output=HERE/'review_v2'
output.mkdir(exist_ok=True)
cameras=sorted([o for o in bpy.data.objects if o.type=='CAMERA'],key=lambda o:o.name)
from bpy_extras.object_utils import world_to_camera_view
for camera in cameras:
    B.rotation_euler.x=math.radians(camera['barrel_elevation_degrees'])
    bpy.context.view_layer.update()
    points=[world_to_camera_view(scene,camera,o.matrix_world@Vector(c))
            for root in (F,T,B) for o in root.children if o.type in {'MESH','CURVE'} for c in o.bound_box]
    assert min(v.x for v in points)>.03 and max(v.x for v in points)<.97
    assert min(v.y for v in points)>.03 and max(v.y for v in points)<.97
print('V2_ORIGINAL_CAMERA_FRAMING_OK',flush=True)
B.rotation_euler.x=math.radians(18)
bpy.context.view_layer.update()
scene.camera=bpy.data.objects['01_overall']
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'monolith_v2.blend'))
if '--model-only' not in sys.argv:
    for camera in cameras:
        B.rotation_euler.x=math.radians(camera['barrel_elevation_degrees'])
        bpy.context.view_layer.update()
        scene.camera=camera
        scene.render.filepath=str(output/(camera.name+'.png'))
        bpy.ops.render.render(write_still=True)
        print('V2_RENDER_COMPLETE',camera.name,flush=True)
B.rotation_euler.x=math.radians(18)
bpy.context.view_layer.update()
scene.camera=bpy.data.objects['01_overall']
scene.render.filepath=str(output/'01_overall.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'monolith_v2.blend'))
print('V2_COMPLETE',original_count,len(bpy.data.objects),flush=True)
