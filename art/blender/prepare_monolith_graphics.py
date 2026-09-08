"""Prepare exported runtime assets: fit Foundation vertically and remove mirrored directions.

Run with Python + Pillow from any directory. No mirrored PNGs are generated.
After a fresh Blender export, pass --fresh-foundation to replace the preserved source.
"""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = ROOT / 'graphics/entity/monolith'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--fresh-foundation', action='store_true')
args = p.parse_args()
source = HERE / 'monolith-foundation-original.png'
destination = OUT / 'foundation/monolith-foundation.png'
if args.fresh_foundation or not source.exists():
    shutil.copyfile(destination, source)
scale = 65.94560241699219 * 32 / 768
with Image.open(source) as original:
    original = original.convert('RGBA')
    x0, y0, x1, y1 = original.getbbox()
    height = round(15 * 32 / scale)
    top = round(491.27840423584 - height / 2)
    # Premultiplied alpha prevents dark fringes when resampling transparent edges.
    fitted = original.crop((x0, y0, x1, y1)).convert('RGBa').resize(
        (x1-x0, height), Image.Resampling.BICUBIC).convert('RGBA')
    canvas = Image.new('RGBA', original.size)
    canvas.paste(fitted, (x0, top))
    canvas.save(destination)
    foundation_bbox = canvas.getbbox()
anchor_y = top + height / 2
assert anchor_y == 491.5, 'Update graphics.foundation() anchor for changed export dimensions.'

removed = 0
for label in ('low', 'low-mid', 'mid', 'high-mid', 'high'):
    for d in range(13, 24):
        if label == 'low' and d == 18:
            continue  # Native east-facing placement preview still needs this PNG.
        path = OUT / f'upper/{label}/monolith-upper-{label}-{d:02d}.png'
        assert path.resolve().is_relative_to(OUT.resolve())
        if path.exists():
            path.unlink()
            removed += 1

manifest_path = OUT / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['records'] = [r for r in manifest['records'] if (OUT / r['path']).exists()]
for r in manifest['records']:
    if r['path'] == 'foundation/monolith-foundation.png':
        r.pop('pixel_sha256', None)  # Blender float-pixel hash no longer describes fitted PNG.
        r['bbox'] = [foundation_bbox[0], 768-foundation_bbox[3], foundation_bbox[2]-1, 767-foundation_bbox[1]]
        r['origin_pixel_top_left'] = [384, anchor_y]
        r['vertical_fit_tiles'] = height * scale / 32
manifest['runtime_mirroring'] = {
    'source_directions': list(range(13)), 'mirrored_directions': list(range(13,24)),
    'source_formula': '24 - direction', 'x_scale': -1,
    'placement_exception': 'upper/low/monolith-upper-low-18.png',
    'upper_png_count': 66,
}
manifest_path.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
print(f'Foundation: {height * scale / 32:.3f} tiles high; removed {removed} PNGs; Upper PNGs: 66')
