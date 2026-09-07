"""Build the editable Monolith design model and five review images only.
Run: blender --background --factory-startup --python build_monolith.py
One Blender unit = one reference tile. No Factorio assets are exported.
"""
import bpy
import math
import os
import sys
from mathutils import Vector
from math import sin, cos, pi

HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection':
        bpy.data.collections.remove(c)
main = bpy.data.collections.get('Collection')
main.name = 'MONOLITH | design model'

def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

FC = collection('01 Foundation | fixed infrastructure')
TC = collection('02 Turret | azimuth Z')
BC = collection('03 Barrel | elevation X 0 to 60 degrees')
SC = collection('90 Studio | review only')

def mat(name, color, metallic=.7, rough=.4):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bs = nt.nodes.new('ShaderNodeBsdfPrincipled')
    output = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(bs.outputs['BSDF'], output.inputs['Surface'])
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = rough
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 7
    noise.inputs['Detail'].default_value = 2
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*(v*.74 for v in color), 1)
    ramp.color_ramp.elements[1].color = (*(v*1.12 for v in color), 1)
    nt.links.new(noise.outputs['Fac'], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bs.inputs['Base Color'])
    return m

steel = mat('Steel | warm dark cast alloy', (.065,.077,.081))
armor = mat('Armor | muted graphite olive', (.135,.145,.12), .65,.49)
edge = mat('Edges | machined steel', (.23,.26,.27), .85,.34)
dark = mat('Machinery | oily charcoal', (.037,.047,.05), .65,.34)
yellow = mat('Safety | aged ochre', (.56,.32,.065), .45,.5)
copper = mat('Busbars | aged copper', (.31,.135,.063), .78,.36)
concrete = mat('Foundation | reinforced mineral composite', (.14,.145,.14), .1,.76)
black = mat('Bore | soot', (.008,.011,.013), .15,.7)
studio = mat('Studio | slate', (.032,.042,.052), .05,.8)

def root(name, col, pos=(0,0,0), parent=None):
    o = bpy.data.objects.new(name, None)
    col.objects.link(o)
    o.empty_display_type = 'CIRCLE'
    o.empty_display_size = 1
    o.location = pos
    o.parent = parent
    return o

F = root('Monolith_Foundation', FC)
T = root('Monolith_Turret', TC, (0,0,2.65))
B = root('Monolith_Barrel', BC, (0,0,4.65), T)
F['reference_footprint_tiles'] = '15 x 15'
T['operation'] = 'Rotate local Z for horizontal azimuth; barrel follows.'
B['operation'] = 'Rotate local X from 0 to 60 degrees for elevation.'
B['length_tiles'] = 32.9
T.lock_rotation = (True,True,False)
B.lock_rotation = (False,True,True)
limit = B.constraints.new('LIMIT_ROTATION')
limit.name = 'Design elevation range | 0 to 60 degrees'
limit.owner_space = 'LOCAL'
limit.use_limit_x = True
limit.min_x = 0
limit.max_x = pi/3

def finish(o, name, material, parent, bevel=0):
    o.name = name
    col = FC if parent == F else TC if parent == T else BC if parent == B else SC
    for c in list(o.users_collection):
        c.objects.unlink(o)
    col.objects.link(o)
    if material:
        o.data.materials.append(material)
    if parent:
        o.parent = parent
        # Turret components are authored in foundation coordinates.
        if parent == T:
            o.location.z -= 2.65
    if bevel:
        mod = o.modifiers.new('Fabricated edge radii', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return o

def box(name, loc, size, m=steel, p=F, bevel=.055, rot=0):
    x,y,z=(v/2 for v in size)
    vertices=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    main.objects.link(o)
    o.location=loc
    o.rotation_euler.z = rot
    return finish(o,name,m,p,bevel)

def cyl(name, loc, radius, depth, m=steel, p=F, axis='Z', vertices=32, r2=None):
    n=vertices
    rr=radius if r2 is None else r2
    vs=[(r*cos(2*pi*i/n),r*sin(2*pi*i/n),z) for r,z in ((radius,-depth/2),(rr,depth/2)) for i in range(n)]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vs,[],fs)
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    main.objects.link(o)
    o.location=loc
    if axis == 'Y': o.rotation_euler.x = pi/2
    if axis == 'X': o.rotation_euler.y = pi/2
    return finish(o,name,m,p,.025)

def beam(name, a, b, width, depth, m=steel, p=F):
    a,b = Vector(a),Vector(b)
    o = box(name, (a+b)/2, (width,depth,(b-a).length),m,p)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def pipe(name, pts, radius=.07, m=copper, p=F):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=radius
    curve.bevel_resolution=2
    spline=curve.splines.new('POLY')
    spline.points.add(len(pts)-1)
    for pt,co in zip(spline.points,pts): pt.co=(*co,1)
    o=bpy.data.objects.new(name,curve)
    main.objects.link(o)
    return finish(o,name,m,p)

def ring(name, ri, ro, z, height, m=steel, p=F, n=64, start=0, end=2*pi):
    verts=[]
    for zz in (z-height/2,z+height/2):
        for r in (ri,ro):
            verts += [(r*cos(start+(end-start)*i/n),r*sin(start+(end-start)*i/n),zz) for i in range(n+1)]
    s=n+1
    faces=[]
    for i in range(n):
        faces += [(i,i+1,s+i+1,s+i), (2*s+i,3*s+i,3*s+i+1,2*s+i+1),
                  (i,2*s+i,2*s+i+1,i+1), (s+i,s+i+1,3*s+i+1,3*s+i)]
    faces += [(0,s,3*s,2*s),(n,2*s+n,3*s+n,s+n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    main.objects.link(o)
    return finish(o,name,m,p,.025)

def radial_box(name,r,a,z,size,m=steel,p=F):
    return box(name,(r*cos(a),r*sin(a),z),size,m,p,rot=a)

# Clipped-corner 15 x 15 structural raft.
outline=[(-5.8,-7.5),(5.8,-7.5),(7.5,-5.8),(7.5,5.8),(5.8,7.5),(-5.8,7.5),(-7.5,5.8),(-7.5,-5.8)]
verts=[(x,y,z) for z in (0,.4) for x,y in outline]
faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
mesh=bpy.data.meshes.new('Clipped structural slab')
mesh.from_pydata(verts,[],faces)
o=bpy.data.objects.new('Foundation_Structure | 15 tile raft',mesh)
main.objects.link(o)
finish(o,o.name,concrete,F,.08)
for x in range(-6,7,2):
    for y in range(-6,7,2):
        if x*x+y*y>28 and not(abs(x)==6 and abs(y)==6):
            box('Deck | removable service panel',(x,y,.46),(1.88,1.88,.12),armor)
            for dx in (-.72,.72):
                box('Deck lifting recess',(x+dx,y,.53),(.12,.42,.025),dark,bevel=.012)
for i,(a,b) in enumerate(zip(outline,outline[1:]+outline[:1])):
    beam('Perimeter | steel curb',(*a,.47),(*b,.47),.2,.22,steel)
    av,bv=Vector(a),Vector(b)
    for j in range(int((bv-av).length/.65)):
        v=av+(bv-av)*(j+.5)/int((bv-av).length/.65)
        ob=box('Perimeter | ochre safety inset',(*v,.6),(.30,.19,.025),yellow,bevel=.01)
        ob.rotation_euler.z=math.atan2(b[1]-a[1],b[0]-a[0])

cyl('Foundation | lower polygon drum',(0,0,.91),5.65,.95,dark,vertices=24)
cyl('Foundation | tapered armored drum',(0,0,1.48),5.5,.8,steel,vertices=24,r2=5.05)
ring('Foundation | lower structural collar',4.75,5.72,.74,.25,edge,n=48)
ring('Foundation | upper annular service deck',3.5,5.22,2.02,.3,armor,n=48)
ring('Foundation | deck outer lip',5.08,5.27,2.22,.15,edge)
ring('Foundation | inner ring trench',3.38,3.70,2.19,.25,dark)
cyl('Foundation | machinery floor',(0,0,1.99),3.4,.22,steel)
for i in range(24):
    a=2*pi*i/24
    ring('Foundation | segmented deck armor',3.76,5.06,2.23,.14,armor,n=3,start=a+.017,end=a+2*pi/24-.017)
    radial_box('Foundation | vertical armored cassette',5.22,a,1.28,(.22,.92,.82),armor)
    radial_box('Foundation | cassette inset',5.37,a,1.3,(.04,.65,.43),dark)
    for z in (1.12,1.32,1.52):
        radial_box('Foundation | cooling louvre',5.41,a,z,(.06,.64,.055),edge)
    for r in (3.92,4.91):
        cyl('Foundation | deck hold-down',(r*cos(a+.1),r*sin(a+.1),2.34),.055,.045,edge,vertices=6)
    if i%2==0:
        beam('Foundation | radial buttress',(5.85*cos(a),5.85*sin(a),.57),(5.10*cos(a),5.10*sin(a),1.97),.35,.43,steel)
        radial_box('Foundation | buttress foot',5.78,a,.61,(.65,.57,.18),armor)
        radial_box('Foundation | foot warning',5.82,a,.715,(.31,.48,.025),yellow)

# Shell manufacturing skid, roller loading bay and corner capacitor banks.
for x,y in [(-5.8,-4.6),(5.8,-4.6),(-5.8,4.7),(5.8,4.7)]:
    box('Machinery | isolated skid',(x,y,.71),(2.05,2.75,.32),dark)
    for dy in (-1.16,1.16):
        box('Machinery | mounting girder',(x,y+dy,.94),(2.02,.18,.25),edge)
for x in (-6.35,-5.5):
    for y in (3.9,4.7,5.5):
        cyl('Foundation_Accumulator | pressure can',(x,y,1.54),.32,1.2,dark)
        for z in (1.05,1.42,1.8,2.1):
            cyl('Accumulator | retaining collar',(x,y,z),.355,.10,edge)
        cyl('Accumulator | ceramic terminal',(x,y,2.23),.095,.22,armor)
        pipe('Accumulator | copper bus',[(x,y,2.37),(x+.38,y,2.37),(x+.38,3.55,2.37)],.06)
box('Accumulator | switching cabinet',(-6,6.35,1.31),(1.7,.72,1.3),armor)
for x in (-6.45,-6,-5.55):
    box('Accumulator | switch face',(x,5.973,1.35),(.3,.04,.62),dark)
    box('Accumulator | safety tag',(x,5.94,1.61),(.15,.02,.08),yellow)
box('Foundation_Machinery | shell forge',(-5.8,-4.6,1.36),(1.75,2.12,1.05),armor)
box('Forge | roof cover',(-5.8,-4.6,1.97),(1.87,2.22,.17),steel)
for y in (-5.3,-4.85,-4.4,-3.95):
    box('Forge | press rib',(-5.8,y,2.14),(1.5,.17,.24),edge)
for x in (-6.4,-5.2):
    cyl('Forge | hydraulic column',(x,-4.6,1.57),.12,1.5,dark)
box('Forge | transfer throat',(-4.8,-4.45,1.26),(.45,.9,.56),dark)
for y in (-5.4,-4.8,-4.2):
    pipe('Forge | external feed manifold',[(-6.73,y,.9),(-6.97,y,.9),(-6.97,y,1.75),(-6.55,y,1.75)],.09)
box('Foundation_Loading | roller bed',(5.8,-4.65,1.01),(1.55,2.4,.22),steel)
for y in (-5.6,-5.3,-5,-4.7,-4.4,-4.1,-3.8):
    cyl('Loading | conveyor roller',(5.8,y,1.2),.115,1.36,edge,axis='X')
for x in (5.05,6.55):
    box('Loading | side guide',(x,-4.65,1.37),(.12,2.4,.23),yellow)
cyl('Loading | unfinished shell',(5.8,-4.6,1.58),.29,1.5,steel,axis='Y')
box('Loading | armored hatch',(4.6,-3.9,1.77),(.52,1.25,.94),armor)
for x in (5.2,6.4):
    beam('Loading | gantry post',(x,-5.7,.9),(x,-5.7,2.65),.15,.19,steel)
beam('Loading | gantry crosshead',(5.2,-5.7,2.65),(6.4,-5.7,2.65),.22,.26,edge)
pipe('Loading | suspended hoist',[(5.8,-5.7,2.6),(5.8,-5.7,2.05)],.055,dark)
box('Foundation | cooling station',(5.8,4.7,1.34),(1.85,2.2,1.12),armor)
for y in (4.1,5.2):
    cyl('Cooling | fan housing',(5.8,y,1.96),.44,.17,dark)
    cyl('Cooling | fan hub',(5.8,y,2.07),.12,.08,edge)
    for j in range(8):
        radial=2*pi*j/8
        box('Cooling | fan grille',(5.8+.21*cos(radial),y+.21*sin(radial),2.09),(.44,.04,.035),edge,rot=radial)
for sign in (-1,1):
    for k in range(3):
        x=sign*(6.2+k*.24)
        pipe('Foundation_Pipes | service mains',[(x,-3.2,.75),(x,-2.8,.93),(x,2.5,.93),(sign*5.25,3.0,1.35)],.075,copper if k==0 else steel)
    # Walkways and railings stay outside the rotating machinery envelope.
    for y in (-2.5,-1.2,.1,1.4,2.7):
        box('Maintenance | walkway tread',(sign*6.85,y,.66),(.64,1.2,.1),dark)
        for dy in (-.4,-.2,0,.2,.4):
            box('Maintenance | tread slat',(sign*6.85,y+dy,.73),(.6,.045,.025),edge,bevel=.008)
    pipe('Maintenance | handrail',[(sign*7.2,-2.9,1.45),(sign*7.2,3.1,1.45)],.04,edge)
    for y in (-2.9,-.9,1.1,3.1):
        pipe('Maintenance | railing post',[(sign*7.2,y,.5),(sign*7.2,y,1.45)],.04,steel)
for j in range(6):
    box('Maintenance | access stair',(0,-6.6+j*.25,.52+j*.23),(1.45,.33,.15),armor)

# Exposed slew gear, turntable, tall paired A-frame bearing supports.
ring('Turret_Ring | fixed slew race',2.88,3.43,2.40,.25,edge,F)
cyl('Turret_Ring | rotating table',(0,0,2.68),3.26,.36,dark,T)
ring('Turret_Ring | armored turntable rim',2.98,3.32,2.92,.14,armor,T)
for i in range(80):
    a=2*pi*i/80
    radial_box('Turret_Ring | gear tooth',3.28,a,2.63,(.16,.15,.2),edge,T)
for i in range(16):
    a=2*pi*i/16
    radial_box('Turret | deck segment',2.75,a,2.96,(.54,.53,.12),armor,T)
for x in (-2.28,2.28):
    box('Turret_Support | longitudinal foot',(x,0,3.11),(1.12,5.85,.46),steel,T)
    for y in (-2.35,2.35):
        box('Turret | anchor shoe',(x,y,3.39),(1.25,.9,.25),armor,T)
        beam('Turret_Support | A-frame main spar',(x,y,3.40),(x,0,7.3),.72,.76,steel,T)
        beam('Turret_Support | armor face',(x+(.39 if x>0 else -.39),y,3.48),(x+(.39 if x>0 else -.39),0,7.27),.13,.58,armor,T)
        beam('Turret_Support | machined rib',(x+(.48 if x>0 else -.48),y,3.58),(x+(.48 if x>0 else -.48),0,7.13),.09,.12,edge,T)
        for t in (.18,.44,.70):
            yy=y*(1-t)
            zz=3.4+(7.3-3.4)*t
            box('Turret | spar splice plate',(x,yy,zz),(.87,.26,.22),armor,T)
    beam('Turret | lower lateral brace',(x,-1.9,4.15),(x,1.9,4.15),.34,.3,dark,T)
    cyl('Turret | large bearing housing',(x,0,7.3),.94,.85,armor,T,'X',48)
    cyl('Turret | machined bearing rim',(x+( .46 if x>0 else -.46),0,7.3),.72,.13,edge,T,'X',48)
    cyl('Turret_ElevationMechanism | drive hub',(x+(.57 if x>0 else -.57),0,7.3),.49,.18,dark,T,'X',32)
    for i in range(12):
        a=2*pi*i/12
        cyl('Turret | bearing cap bolt',(x+(.68 if x>0 else -.68),.60*cos(a),7.3+.60*sin(a)),.065,.07,edge,T,'X',6)
    box('Turret | elevation gearbox',(x,1.0,6.8),(.9,.95,.78),dark,T)
    cyl('Turret | drive motor',(x,1.25,5.98),.36,.85,steel,T)
    for z in (5.7,5.87,6.04,6.21):
        cyl('Turret | motor fin',(x,1.25,z),.41,.07,edge,T)
    pipe('Turret | hydraulic supply',[(x,1.4,3.45),(x,1.65,4.15),(x,1.45,5.4),(x,1.1,6.35)],.085,copper,T)

# All barrel parts use local elevation-axis coordinates; +Y is downrange.
cyl('Barrel | trunnion axle',(0,0,0),.48,4.7,edge,B,'X')
cyl('Barrel_Breech | faceted receiver',(0,-.65,0),1.23,4.7,dark,B,'Y',12)
cyl('Barrel_Breech | aft lock collar',(0,-3.0,0),1.30,.55,steel,B,'Y',12)
cyl('Barrel_Breech | locking face',(0,-3.32,0),1.08,.15,armor,B,'Y',12)
cyl('Barrel_Breech | rammer socket',(0,-3.43,0),.55,.1,black,B,'Y',12)
for i in range(8):
    a=2*pi*i/8
    box('Breech | radial locking dog',(.84*cos(a),-3.46,.84*sin(a)),(.25,.20,.25),edge,B)
for x in (-.99,.99):
    box('Breech | side armor',(x,-.6,0),(.34,4.3,1.16),armor,B)
    for y in (-2.3,-1.3,-.3,.7,1.4):
        box('Breech | side reinforcing rib',(x*1.18,y,0),(.18,.15,1.22),steel,B)
box('Breech | upper armored spine',(0,-.5,1.1),(1.1,4.25,.32),armor,B)
for y in (-2,-1,0,1):
    box('Breech | top locking plate',(0,y,1.30),(.85,.22,.09),edge,B)

# Long tapered jacket, inset channels, structural rails and flanged modules.
sections=[(1.65,6.0,1.02,.94),(6.0,10.5,.94,.84),(10.5,15,.84,.76),(15,19.5,.76,.69),(19.5,24,.69,.62),(24,28.9,.62,.57)]
for idx,(lo,hi,ra,rb) in enumerate(sections):
    # Cone rotated +90 about X: radius1 lies at positive Y.
    if idx == 5:
        jacket=ring('Barrel_Main | hollow muzzle jacket',.43,ra,0,hi-lo,steel,B,n=48)
        jacket.location.y=(lo+hi)/2
        jacket.rotation_euler.x=pi/2
    else:
        cyl('Barrel_Main | tapered jacket %02d'%idx,(0,(lo+hi)/2,0),rb,hi-lo,steel,B,'Y',12,r2=ra)
    for a in (0,pi/2,pi,3*pi/2):
        r=(ra+rb)/2
        o=box('Barrel | longitudinal armor panel',(r*cos(a),(lo+hi)/2,r*sin(a)),(.16,hi-lo-.3,.64 if idx<3 else .45),armor,B)
        o.rotation_euler.y=-a
        # A dark seam and repeated visible retaining plates provide medium-scale detail.
        for yy in (lo+.6,(lo+hi)/2,hi-.6):
            o=box('Barrel | jacket panel clamp',((r+.1)*cos(a),yy,(r+.1)*sin(a)),(.09,.17,.69 if idx<3 else .49),edge,B)
            o.rotation_euler.y=-a
    for y in (lo+.12,hi-.12):
        rr=ra if y<(lo+hi)/2 else rb
        for nm,thick,rad,dy,material in [('reinforcing band',.18,rr+.10,0,dark),('band flange',.06,rr+.135,.08,edge)]:
            band=ring('Barrel | '+nm,.43,rad,0,thick,material,B,n=24)
            band.location.y=y+dy
            band.rotation_euler.x=pi/2
    if idx in (0,2,4):
        box('Barrel | ochre service marking',(0,lo+.75,ra+.13),(.48,.32,.025),yellow,B)
for x in (-.65,.65):
    beam('Barrel | dorsal reinforcement rail',(x,1.5,.87),(x*.63,28.4,.49),.12,.18,dark,B)
    beam('Barrel | ventral reinforcement rail',(x,1.5,-.87),(x*.63,28.4,-.49),.12,.18,dark,B)
for x in (-1.22,1.22):
    cyl('Barrel_RecoilMechanism | hydraulic recuperator',(x,1.55,.4),.25,5.35,dark,B,'Y')
    cyl('Barrel_RecoilMechanism | polished piston',(x,5.02,.4),.13,1.6,edge,B,'Y')
    for y in (-1,1,3.8,5.7):
        cyl('Recoil | rod collar',(x,y,.4),.30,.19,steel,B,'Y',16)
    box('Recoil | forward yoke',(x,5.83,.25),(.45,.34,.7),armor,B)
    pipe('Recoil | return line',[(x,-1.3,.4),(x,-1.7,.7),(x*.6,-2.1,1.12)],.055,copper,B)

# True open muzzle: concentric annular mesh with recessed dark bore.
mu=ring('Barrel | open muzzle crown',.43,.72,0,.72,edge,B,n=48)
mu.location.y=29.08
mu.rotation_euler.x=pi/2
liner=ring('Barrel | bore liner',.43,.50,0,2.8,black,B,n=48)
liner.location.y=27.98
liner.rotation_euler.x=pi/2
cyl('Barrel | deep bore termination',(0,26.53,0),.432,.025,black,B,'Y')
for a in (0,pi/2,pi,3*pi/2):
    box('Barrel | muzzle longitudinal lug',(.64*cos(a),28.7,.64*sin(a)),(.19,1.10,.19),steel,B)

# Studio and five deliberately limited model review cameras.
box('Studio ground',(0,8,-.22),(20000,20000,.25),studio,None,0)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
try:
    preferences=bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type='OPTIX'
    preferences.get_devices()
    gpu_devices=[d for d in preferences.devices if d.type=='OPTIX']
    if gpu_devices:
        for d in preferences.devices: d.use=d.type=='OPTIX'
        scene.cycles.device='GPU'
except Exception:
    pass  # CPU remains a portable fallback.
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world.color=(.22,.22,.22)
scene.world.use_nodes=True
world_nodes=scene.world.node_tree.nodes
world_nodes.clear()
background=world_nodes.new('ShaderNodeBackground')
world_output=world_nodes.new('ShaderNodeOutputWorld')
scene.world.node_tree.links.new(background.outputs[0],world_output.inputs['Surface'])
background.inputs[0].default_value=(.30,.36,.43,1)
background.inputs[1].default_value=.3
scene.view_settings.view_transform='AgX'

def aim(o,point):
    o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()

def area(name,loc,power,color,size,target):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color
    o=bpy.data.objects.new(name,data)
    SC.objects.link(o)
    o.location=loc
    aim(o,target)

area('Key | warm softbox',(2,5,32),14000,(1,.87,.7),18,(0,8,3))
area('Fill | cool softbox',(-20,3,16),6000,(.65,.79,1),15,(0,5,4))
area('Rim | long barrel',(12,26,23),13000,(1,.94,.83),13,(0,13,5))
area('Front | foundation',(10,-15,12),6000,(.86,.91,1),12,(0,0,3))

views=[
 ('01_overall',(45,-20,30),(0,9,6),40,18),
 ('02_reverse',(-36,42,30),(0,9,5),40,18),
 ('03_low_side',(42,13,13),(0,10,7),40,18),
 ('04_elevation_00',(42,12,10),(0,10,4),40,0),
 ('05_elevation_60',(40,12,20),(0,4,13),40,60),
]
for name,loc,target,scale,angle in views:
    data=bpy.data.cameras.new(name)
    data.type='ORTHO'
    data.ortho_scale=scale
    o=bpy.data.objects.new(name,data)
    SC.objects.link(o)
    o.location=loc
    aim(o,target)
    o['barrel_elevation_degrees']=angle

notes=bpy.data.texts.new('MODEL_README')
notes.write('MONOLITH | editable design model\n\nReference: repository graphic concept and graphic specification.\n1 unit = 1 tile; foundation envelope 15 x 15; barrel assembly 32.9 units.\nMonolith_Foundation: fixed assembly root.\nMonolith_Turret: local Z azimuth, pivot (0, 0, 2.65).\nMonolith_Barrel: local X elevation 0..60 degrees, world pivot (0, 0, 7.30).\nAll recoil parts are static geometry; no animation or effects.\nSelect a root and Select Hierarchy to manipulate or isolate its assembly.\nStudio collection is for review only. Five cameras carry their elevation as a custom property.\nSaved model opens at 18 degrees. Render images are model reviews, not sprites.\n')

def set_pose(degrees):
    B.rotation_euler.x=math.radians(degrees)
    bpy.context.view_layer.update()

def frame_model(camera):
    """Fit actual posed geometry with a margin, excluding the review studio."""
    inverse=camera.matrix_world.inverted()
    points=[inverse @ o.matrix_world @ Vector(corner)
            for col in (FC,TC,BC) for o in col.objects
            if o.type in {'MESH','CURVE'} for corner in o.bound_box]
    xmin,xmax=min(v.x for v in points),max(v.x for v in points)
    ymin,ymax=min(v.y for v in points),max(v.y for v in points)
    camera.location += camera.rotation_euler.to_quaternion() @ Vector(((xmin+xmax)/2,(ymin+ymax)/2,0))
    aspect=scene.render.resolution_x/scene.render.resolution_y
    camera.data.ortho_scale=max(xmax-xmin,(ymax-ymin)*aspect)*1.14
    # Keep every orthographic ray origin above the studio floor at low angles.
    camera.location += camera.rotation_euler.to_quaternion() @ Vector((0,0,100))
    bpy.context.view_layer.update()

for name,loc,target,scale,angle in views:
    set_pose(angle)
    frame_model(bpy.data.objects[name])

set_pose(18)
scene.camera=bpy.data.objects['01_overall']
scene.unit_settings.system='METRIC'
scene['reference_scale']='1 Blender unit = 1 tile (design proportions, not physical metres)'
scene['scope']='3D design review only; no Factorio sprites or gameplay changes'
bpy.ops.object.select_all(action='DESELECT')
B.select_set(True)
bpy.context.view_layer.objects.active=B
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.color_type='MATERIAL'
            a.spaces.active.clip_end=1000
os.makedirs(os.path.join(HERE,'review'),exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE,'monolith.blend'))
if '--model-only' not in sys.argv:
    for name,loc,target,scale,angle in views:
        set_pose(angle)
        scene.camera=bpy.data.objects[name]
        scene.render.filepath=os.path.join(HERE,'review',name+'.png')
        bpy.ops.render.render(write_still=True)
        print('REVIEW_COMPLETE',name,flush=True)
set_pose(18)
scene.camera=bpy.data.objects['01_overall']
scene.render.filepath=os.path.join(HERE,'review','01_overall.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE,'monolith.blend'))
print('MONOLITH_COMPLETE',len(FC.objects),len(TC.objects),len(BC.objects),flush=True)
