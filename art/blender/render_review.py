"""Render five review views from the current, manually edited v2 model.
Run: blender --background --factory-startup --python render_review.py
Never rebuilds geometry or saves changes to the source .blend.
"""
from pathlib import Path
import math
import bpy

HERE = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(HERE / 'monolith_v2.blend'))
scene = bpy.context.scene
barrel = bpy.data.objects['Monolith_Barrel']
names = ['01_overall', '02_reverse', '03_low_side',
         '04_elevation_00', '05_elevation_60']
cameras = [bpy.data.objects[name] for name in names]
assert all(camera.type == 'CAMERA' for camera in cameras)
scene.render.engine = 'CYCLES'
scene.cycles.use_denoising = True
scene.cycles.device = 'CPU'
try:
    preferences = bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type = 'OPTIX'
    preferences.get_devices()
    if any(device.type == 'OPTIX' for device in preferences.devices):
        for device in preferences.devices:
            device.use = device.type == 'OPTIX'
        scene.cycles.device = 'GPU'
except Exception as error:
    print('Using CPU:', error, flush=True)
output = HERE / 'review_v2'
output.mkdir(exist_ok=True)
scene.render.image_settings.file_format = 'PNG'
for camera in cameras:
    barrel.rotation_euler.x = math.radians(camera['barrel_elevation_degrees'])
    bpy.context.view_layer.update()
    scene.camera = camera
    scene.render.filepath = str(output / (camera.name + '.png'))
    bpy.ops.render.render(write_still=True)
    print('REVIEW_UPDATED', camera.name, flush=True)
print('REVIEW_COMPLETE_SOURCE_BLEND_UNCHANGED', flush=True)
