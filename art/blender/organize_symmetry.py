"""Organize the current user-edited v2 with live X mirrors, without rebuilding.
blender --background --factory-startup --python organize_symmetry.py
Final: monolith_v2_symmetry.blend; original v2 remains untouched.
--model-only: organize/check/save without rendering.
--render-only: render the saved symmetry model without rebuilding or saving it.
"""
from pathlib import Path
import sys
import math
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from bpy_extras.object_utils import world_to_camera_view

HERE=Path(__file__).resolve().parent
FINAL=HERE/'monolith_v2_symmetry.blend'
render_only='--render-only' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(FINAL if render_only else HERE/'monolith_v2.blend'))
scene=bpy.context.scene
F=bpy.data.objects['Monolith_Foundation']
T=bpy.data.objects['Monolith_Turret']
B=bpy.data.objects['Monolith_Barrel']
initial_pose=B.rotation_euler.copy()
initial_camera=scene.camera

def subcollection(parent,name):
    c=bpy.data.collections.new(name)
    parent.children.link(c)
    return c

def move_collection(o,c):
    for previous in list(o.users_collection):previous.objects.unlink(o)
    c.objects.link(o)

def symmetry_error(o,root):
    deps=bpy.context.evaluated_depsgraph_get()
    evaluated=o.evaluated_get(deps)
    mesh=evaluated.to_mesh()
    transform=root.matrix_world.inverted()@evaluated.matrix_world
    coords=[transform@v.co for v in mesh.vertices]
    tree=KDTree(len(coords))
    for i,co in enumerate(coords):tree.insert(co,i)
    tree.balance()
    error=max((tree.find(Vector((-v.x,v.y,v.z)))[2] for v in coords),default=0)
    evaluated.to_mesh_clear()
    return error

if not render_only:
    counts={'mirrored':0,'removed_negative':0,'retained_ring':0,'independent_curves':0,'removed_internal_faces':0}
    mirrored=[]
    groups={}
    for root in (T,B):
        col=root.users_collection[0]
        groups[root.name]={
            'structure':subcollection(col,'T01 Mirrored supports +X' if root==T else 'B01 Mirrored barrel and breech +X'),
            'details':subcollection(col,'T02 Mirrored bearings and drives +X' if root==T else 'B02 Mirrored reinforcement and details +X'),
            'independent':subcollection(col,'T03 Independent service pipes' if root==T else 'B03 Independent service pipes'),
        }
        if root==T:groups[root.name]['ring']=subcollection(col,'T00 Existing slew ring')
        root['symmetry_plane']='Local X = 0; Y is barrel direction; +X is editable master side.'
        root['symmetry_editing']='Edit the +X half mesh. Live Mirror precedes Bevel; do not apply it for ordinary edits.'
        root['pivot_policy']='Original root transform retained. Turret rotates local Z; Barrel elevates local X.'

    for root in (T,B):
        for o in list(root.children):
            if o.type=='EMPTY':continue
            if o.type=='CURVE':
                move_collection(o,groups[root.name]['independent'])
                o['symmetry_exception']='Independent service pipe; intentionally kept editable and unmirrored.'
                counts['independent_curves']+=1
                continue
            assert o.type=='MESH',('Unhandled object',o.name,o.type)
            if root==T and o.name.startswith(('Turret_Ring |','Turret | deck segment')):
                move_collection(o,groups[root.name]['ring'])
                counts['retained_ring']+=1
                continue
            assert all(m.type=='BEVEL' for m in o.modifiers),('Unexpected modifier',o.name)
            assert not o.data.shape_keys,('Shape keys require explicit preservation',o.name)
            # Preserve root pivots and actual geometry, while normalizing part
            # coordinates to the root. A local Mirror avoids world-space plane
            # roundoff changing the bevel topology as the assembly rotates.
            to_root=root.matrix_world.inverted()@o.matrix_world
            xx=[(to_root@v.co).x for v in o.data.vertices]
            if max(xx)<1e-6:
                bpy.data.objects.remove(o,do_unlink=True)
                counts['removed_negative']+=1
                continue
            if o.data.users>1:o.data=o.data.copy()
            o.data.transform(to_root)
            o.matrix_parent_inverse=Matrix.Identity(4)
            o.matrix_basis=Matrix.Identity(4)
            to_root=Matrix.Identity(4)
            # Full annular meshes in the source have coincident start/end caps.
            # Remove both internal faces and weld that seam before mirroring.
            bm=bmesh.new()
            bm.from_mesh(o.data)
            face_groups={}
            for face in bm.faces:
                key=tuple(sorted(tuple(round(c,5) for c in vertex.co) for vertex in face.verts))
                face_groups.setdefault(key,[]).append(face)
            duplicate_faces=[face for group in face_groups.values() if len(group)>1 for face in group]
            if duplicate_faces:
                counts['removed_internal_faces']+=len(duplicate_faces)
                bmesh.ops.delete(bm,geom=duplicate_faces,context='FACES_ONLY')
                bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
                bm.to_mesh(o.data)
                o.data.update()
            bm.free()
            if min(xx)<-1e-6:
                bm=bmesh.new()
                bm.from_mesh(o.data)
                plane_co=to_root.inverted()@Vector((0,0,0))
                plane_no=(to_root.to_3x3().transposed()@Vector((1,0,0))).normalized()
                bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                    dist=1e-7,plane_co=plane_co,plane_no=plane_no,clear_inner=True,clear_outer=False)
                # Snap numerical remnants to the true root plane; do not fill
                # the open seam, since Mirror should weld it without inner faces.
                for vertex in bm.verts:
                    co=to_root@vertex.co
                    if abs(co.x)<1e-6:
                        co.x=0
                        vertex.co=to_root.inverted()@co
                bm.to_mesh(o.data)
                bm.free()
                o.data.update()
            assert len(o.data.polygons)>0,('Empty half',o.name)
            assert min((to_root@v.co).x for v in o.data.vertices)>-2e-6
            mirror=o.modifiers.new('Symmetry X | edit +X half','MIRROR')
            mirror.use_axis=(True,False,False)
            mirror.use_clip=True
            mirror.use_mirror_merge=True
            mirror.merge_threshold=.00001
            with bpy.context.temp_override(object=o,active_object=o):
                bpy.ops.object.modifier_move_to_index(modifier=mirror.name,index=0)
            o['symmetry_master']='+X'
            o['symmetry_reference']=root.name
            o['original_v2_object_name']=o.name
            o.data.name=o.name+' | editable +X mesh'
            if root==T:
                key='structure' if any(s in o.name for s in ('Support','spar','root block','box girder','crossmember','brace','anchor shoe')) else 'details'
            else:
                key='structure' if any(s in o.name for s in ('Barrel_Main','Barrel_Breech','Breech |','sleeve','crown','bore','muzzle lip')) else 'details'
            move_collection(o,groups[root.name][key])
            counts['mirrored']+=1
            mirrored.append((o,root))

    bpy.context.view_layer.update()
    maximum=max(symmetry_error(o,root) for o,root in mirrored)
    print('SYMMETRY_COUNTS',counts,flush=True)
    print('EVALUATED_MIRROR_MAX_ERROR',maximum,flush=True)
    assert maximum<.0001,'Evaluated geometry is not symmetric.'

    # The reference planes must travel with the proper pivot at every pose.
    original_yaw=T.rotation_euler.copy()
    for yaw,angle in ((0,0),(0,60),(67,30)):
        T.rotation_euler.z=math.radians(yaw)
        B.rotation_euler.x=math.radians(angle)
        bpy.context.view_layer.update()
        errors=sorted([(symmetry_error(o,root),o.name) for o,root in mirrored],reverse=True)
        print('POSE_SYMMETRY_ERROR',yaw,angle,errors[:5],flush=True)
        assert errors[0][0]<.00015
    T.rotation_euler=original_yaw
    B.rotation_euler=initial_pose
    bpy.context.view_layer.update()
    print('PIVOT_POSES_SYMMETRIC_0_60_YAW67',flush=True)

    # Front-quarter inspection view: full model, both supports and open muzzle.
    camera=bpy.data.objects['02_reverse'].copy()
    camera.data=camera.data.copy()
    camera.name='02_front_quarter'
    bpy.data.collections['90 Studio | review only'].objects.link(camera)
    camera.location=(16,55,22)
    camera.rotation_euler=(Vector((0,5,6))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera['barrel_elevation_degrees']=18
    B.rotation_euler.x=math.radians(18)
    bpy.context.view_layer.update()
    inverse=camera.matrix_world.inverted()
    points=[inverse@o.matrix_world@Vector(corner) for root in (F,T,B)
            for o in root.children if o.type in {'MESH','CURVE'} for corner in o.bound_box]
    xmin,xmax=min(p.x for p in points),max(p.x for p in points)
    ymin,ymax=min(p.y for p in points),max(p.y for p in points)
    camera.location+=camera.rotation_euler.to_quaternion()@Vector(((xmin+xmax)/2,(ymin+ymax)/2,100))
    camera.data.ortho_scale=max(xmax-xmin,(ymax-ymin)*scene.render.resolution_x/scene.render.resolution_y)*1.15
    B.rotation_euler=initial_pose
    bpy.context.view_layer.update()

    text=bpy.data.texts.new('SYMMETRY_EDITING')
    text.write('FINAL MODEL: monolith_v2_symmetry.blend\n\n'
        'Source: the current manually edited monolith_v2.blend, preserved unchanged.\n'
        'Both assemblies use their own LOCAL X=0 symmetry plane; edit +X vertices.\n'
        'Each mirrored mesh origin and axes match its assembly root; local Mirror precedes Bevel.\n'
        'Clipping and merge are enabled. Keep Mirror live for normal editing.\n'
        'Local Y is the barrel centreline. Top/bottom and front/back remain distinct.\n'
        'Original turret local Z yaw and barrel local X elevation pivots are preserved.\n'
        'Opposite-side duplicate meshes removed; centre-crossing meshes retain +X only.\n'
        'Coincident internal annular end caps removed and their original seams welded.\n'
        'Collections group supports, bearings/drives, barrel/breech, reinforcement, pipes.\n'
        'Six small service curves remain independent. Foundation and slew ring unchanged.\n'
        'Material slots and existing edge bevel settings retained.\n'
        'Render again with organize_symmetry.py -- --render-only to preserve later edits.\n')
    scene['final_model']='monolith_v2_symmetry.blend'
    scene['symmetry_summary']=str(counts)

names=['01_overall','03_low_side','02_front_quarter','04_elevation_00','05_elevation_60']
for name in names:
    camera=bpy.data.objects[name]
    B.rotation_euler.x=math.radians(camera['barrel_elevation_degrees'])
    bpy.context.view_layer.update()
    pts=[world_to_camera_view(scene,camera,o.matrix_world@Vector(c))
         for root in (F,T,B) for o in root.children if o.type in {'MESH','CURVE'} for c in o.bound_box]
    assert min(p.x for p in pts)>.025 and max(p.x for p in pts)<.975,(name,'horizontal crop')
    assert min(p.y for p in pts)>.025 and max(p.y for p in pts)<.975,(name,'vertical crop')
print('ALL_REVIEW_CAMERAS_FIT',flush=True)
B.rotation_euler=initial_pose
scene.camera=initial_camera
bpy.context.view_layer.update()
output=HERE/'review_symmetry'
output.mkdir(exist_ok=True)
if not render_only:
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(FINAL))

if '--model-only' not in sys.argv:
    scene.cycles.device='CPU'
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type='OPTIX'
        prefs.get_devices()
        if any(d.type=='OPTIX' for d in prefs.devices):
            for d in prefs.devices:d.use=d.type=='OPTIX'
            scene.cycles.device='GPU'
    except Exception as error:print('CPU fallback:',error,flush=True)
    for name in names:
        camera=bpy.data.objects[name]
        B.rotation_euler.x=math.radians(camera['barrel_elevation_degrees'])
        bpy.context.view_layer.update()
        scene.camera=camera
        scene.render.filepath=str(output/(name+'.png'))
        bpy.ops.render.render(write_still=True)
        print('SYMMETRY_REVIEW_COMPLETE',name,flush=True)
print('SYMMETRY_TASK_COMPLETE',flush=True)
