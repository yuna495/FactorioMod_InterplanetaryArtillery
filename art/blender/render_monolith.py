"""Repeatable model-state export (run with Blender, not system Python).

blender --background --factory-startup --python art/blender/render_monolith.py -- --preview
blender --background --factory-startup --python art/blender/render_monolith.py -- --output graphics/entity/monolith

Options: --directions 24 --elevations low:0,low-mid:15,mid:30,high-mid:45,high:60
         --resolution 768 --samples 16 --frames 1,49 --verify-only
The source is never overwritten. All paths default relative to this repository.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, default=HERE/'monolith_v2_symmetry.blend')
p.add_argument('--output', type=Path)
p.add_argument('--preview', action='store_true')
p.add_argument('--verify-only', action='store_true')
p.add_argument('--directions', type=int, default=24)
p.add_argument('--elevations', default='low:0,low-mid:15,mid:30,high-mid:45,high:60')
p.add_argument('--resolution', type=int, default=768)
p.add_argument('--samples', type=int, default=16)
p.add_argument('--frames', default='')
a = p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
elevations = [(s.split(':')[0], float(s.split(':')[1])) for s in a.elevations.split(',')]
assert a.directions > 0 and a.resolution >= 64 and a.samples > 0
assert len(set(n for n,e in elevations)) == len(elevations)
assert all(0 <= e <= 60 and n and all(c.isalnum() or c in '-_' for c in n) for n,e in elevations)
out = (a.output or (HERE/'preview_export' if a.preview else ROOT/'graphics/entity/monolith')).resolve()
assert a.source.resolve() != (HERE/'monolith_render.blend').resolve(), 'Use the editable symmetry source, not the generated render file.'
out.mkdir(parents=True, exist_ok=True)
source_hash = hashlib.sha256(a.source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()))
scene = bpy.context.scene
F,T,B = [bpy.data.objects[n] for n in ('Monolith_Foundation','Monolith_Turret','Monolith_Barrel')]
assert B.parent == T
foundation = {F, *F.children_recursive}
upper = {T, *T.children_recursive}
model = foundation | upper
for o in model:
    if o.type in {'MESH','CURVE'}:
        o.hide_render = False
for o in scene.objects:
    if o.type in {'MESH','CURVE'} and o not in model:
        o.hide_render = True
T.animation_data_clear()
B.animation_data_clear()
T.rotation_mode = B.rotation_mode = 'XYZ'
states = []
for ei,(label,elevation) in enumerate(elevations):
    for di in range(a.directions):
        frame = ei*a.directions+di+1
        yaw = di*360/a.directions
        T.rotation_euler = (0,0,math.radians(yaw))
        B.rotation_euler = (math.radians(elevation),0,0)
        T.keyframe_insert(data_path='rotation_euler', index=2, frame=frame)
        B.keyframe_insert(data_path='rotation_euler', index=0, frame=frame)
        states.append(dict(frame=frame,direction=di,yaw_degrees=yaw,elevation=label,
                           elevation_degrees=elevation,path=f'upper/{label}/monolith-upper-{label}-{di:02d}.png'))
for o in (T,B):
    for layer in o.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for k in curve.keyframe_points:
                        k.interpolation = 'CONSTANT'
scene.frame_start, scene.frame_end = 1,len(states)
scene.timeline_markers.clear()
for i,(label,e) in enumerate(elevations):
    scene.timeline_markers.new(f'{label} | {e:g} degrees',frame=i*a.directions+1)

# A single camera is fitted to the union of ALL states, never per image.
cam_data = bpy.data.cameras.new('Monolith export orthographic')
cam = bpy.data.objects.new('Monolith_Export_Camera',cam_data)
scene.collection.objects.link(cam)
cam_data.type = 'ORTHO'
cam_data.clip_end = 1000
cam.location = (0,-120,120)
cam.rotation_euler = (Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.camera = cam
rotation_inverse = cam.rotation_euler.to_matrix().transposed()
lo = Vector((1e9,1e9,1e9)); hi = -lo
for state in states:
    scene.frame_set(state['frame'])
    dg = bpy.context.evaluated_depsgraph_get()
    for o in model:
        if o.type not in {'MESH','CURVE'}: continue
        evaluated = o.evaluated_get(dg)
        for corner in evaluated.bound_box:
            q = rotation_inverse @ (evaluated.matrix_world @ Vector(corner))
            for j in range(3):
                lo[j] = min(lo[j],q[j]); hi[j] = max(hi[j],q[j])
center = (lo+hi)/2
offset = cam.rotation_euler.to_matrix() @ Vector((center.x,center.y,0))
cam.location += offset
cam_data.ortho_scale = max(hi.x-lo.x,hi.y-lo.y)*1.12
scene.render.engine = 'CYCLES'
scene.cycles.samples = a.samples
scene.cycles.use_denoising = True
scene.cycles.seed = 0
scene.cycles.use_animated_seed = False
scene.cycles.device = 'CPU'
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'
    prefs.get_devices()
    if any(d.type == 'OPTIX' for d in prefs.devices):
        for d in prefs.devices: d.use = d.type == 'OPTIX'
        scene.cycles.device = 'GPU'
except Exception as error:
    print('CPU fallback:',error,flush=True)
scene.render.resolution_x = scene.render.resolution_y = a.resolution
scene.render.resolution_percentage = 100
scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.use_compositing = False
scene.render.use_sequencer = False

# Saved view layers expose the same isolation in Blender's render interface.
def exclude_tree(lc, collection):
    if lc.collection == collection: lc.exclude = True
    for child in lc.children: exclude_tree(child,collection)
for old in list(scene.view_layers)[1:]: scene.view_layers.remove(old)
combined = scene.view_layers[0]
combined.name = 'Model review'
fl = scene.view_layers.new('Foundation export')
ul = scene.view_layers.new('Upper export')
for root in (T,B):
    for col in root.users_collection: exclude_tree(fl.layer_collection,col)
for col in F.users_collection: exclude_tree(ul.layer_collection,col)
for vl in scene.view_layers: vl.use = vl == combined
scene['export_frame_formula'] = '1 + elevation_index * direction_count + direction_index'
scene['export_direction_convention'] = '0 = +Y; positive yaw around +Z; 90 = -X'
scene['export_source'] = str(a.source.resolve())
scene['export_direction_count'] = a.directions
scene['export_elevations'] = a.elevations
help_text = bpy.data.texts.get('MONOLITH_EXPORT_README') or bpy.data.texts.new('MONOLITH_EXPORT_README')
help_text.clear()
help_text.write('''Monolith PNG export
Editable source: monolith_v2_symmetry.blend (not this generated file).
Timeline: each elevation is a block of direction_count frames.
Default blocks: 1 low / 25 low-mid / 49 mid / 73 high-mid / 97 high.
Turret local Z = azimuth. Barrel local X = elevation. Live Mirrors remain.
View layers: Model review / Foundation export / Upper export.
Camera and transparent canvas are shared across all images; do not crop independently.
From the repository directory, run in PowerShell:
& 'D:\\Games\\steam\\steamapps\\common\\Blender\\blender.exe' --background --factory-startup --python art/blender/render_monolith.py
Append -- --preview for seven previews, or -- --output PATH for another destination.
Other options: --directions 24 --elevations low:0,mid:30,high:60 --resolution 1024 --samples 32
Full default export: Foundation 1 PNG + Upper Assembly 120 PNGs.
manifest.json records frame states, camera, alignment and image bounds.
''')
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'monolith_render.blend'))

def inspect(path):
    im = bpy.data.images.load(str(path),check_existing=False)
    pixels = np.empty(len(im.pixels),dtype=np.float32)
    im.pixels.foreach_get(pixels)
    rgba = pixels.reshape(im.size[1],im.size[0],4)
    alpha = rgba[:,:,3]
    ys,xs = np.where(alpha > 0)
    assert len(xs), f'Empty image: {path}'
    assert alpha.min() == 0 and alpha.max() > .9, f'Alpha invalid: {path}'
    assert not (alpha[0].any() or alpha[-1].any() or alpha[:,0].any() or alpha[:,-1].any()), f'Clipping: {path}'
    result = dict(size=list(im.size),bbox=[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())],
                  pixel_sha256=hashlib.sha256(pixels.tobytes()).hexdigest())
    bpy.data.images.remove(im)
    return result

selected = states
if a.preview:
    selected = [s for s in states if (s['direction']==0 and s['elevation_degrees'] in (0,30,60)) or
                (s['elevation_degrees']==30 and s['yaw_degrees'] in (90,180,270))]
elif a.frames:
    requested = {int(f) for f in a.frames.split(',')}
    assert requested <= {s['frame'] for s in states}
    selected = [s for s in states if s['frame'] in requested]
jobs = [dict(frame=1,path='foundation/monolith-foundation.png',layer=fl.name)] + [dict(s,layer=ul.name) for s in selected]
records = []
for i,job in enumerate(jobs):
    path = out/job['path']
    path.parent.mkdir(parents=True,exist_ok=True)
    scene.frame_set(job['frame'])
    if 'yaw_degrees' in job:
        assert abs(T.rotation_euler.z-math.radians(job['yaw_degrees'])) < 1e-5
        assert abs(B.rotation_euler.x-math.radians(job['elevation_degrees'])) < 1e-5
    for vl in scene.view_layers: vl.use = vl.name == job['layer']
    if not a.verify_only:
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True,layer=job['layer'])
    records.append(dict(job,**inspect(path)))
    print(f'EXPORT_OK {i+1}/{len(jobs)} {job["path"]}',flush=True)
assert hashlib.sha256(a.source.read_bytes()).hexdigest() == source_hash
manifest = dict(source=str(a.source.resolve()),source_sha256=source_hash,
    direction_count=a.directions,elevations=elevations,frame_count=len(states),
    camera=dict(location=list(cam.location),rotation=list(cam.rotation_euler),ortho_scale=cam_data.ortho_scale),
    resolution=a.resolution,samples=a.samples,seed=0,records=records)
anchor = world_to_camera_view(scene,cam,Vector((0,0,0)))
manifest['origin_pixel_top_left'] = [anchor.x*a.resolution,(1-anchor.y)*a.resolution]
manifest['direction_convention'] = '0 = model +Y; positive yaw about +Z; 90 degrees = model -X'
manifest['frame_formula'] = '1 + elevation_index * direction_count + direction_index'
manifest_name = 'manifest_subset.json' if a.frames else 'manifest.json'
(out/manifest_name).write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('EXPORT_COMPLETE',len(records),'SOURCE_UNCHANGED',flush=True)
