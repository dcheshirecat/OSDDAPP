"""Crop raw full-body renders (written by gen_art.js) to 400x600 canvases, feet at the bottom.
Usage: python3 tools/crop_bodies.py game"""
import glob, json, os, sys
from PIL import Image
game = sys.argv[1]
al = {a['id']: a for a in json.load(open(os.path.join(game, 'data/alters.json')))}
for f in sorted(glob.glob(os.path.join(game, 'assets/bodies/*_raw.png'))):
    aid = os.path.basename(f)[:-8]
    im = Image.open(f).convert('RGBA')
    im = im.crop(im.getbbox())
    s = al[aid]['body'].get('scale', 1.0)
    im.thumbnail((int(400 * s), int(600 * s)), Image.LANCZOS)
    c = Image.new('RGBA', (400, 600), (0, 0, 0, 0))
    c.paste(im, ((400 - im.width) // 2, 600 - im.height), im)
    c.save(f.replace('_raw.png', '.png'))
    os.remove(f)
