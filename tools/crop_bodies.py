"""Turn raw full-body renders (written by gen_art.js) into:
  assets/bodies/<id>.png     400x600 full body, transparent, feet at the bottom
  assets/portraits/<id>.png  256x256 headshot cropped from the SAME body, on the alter's bg color
Usage: python3 tools/crop_bodies.py game

Head finding: the head is the top of the figure. We take the top band of the
figure, find the horizontal run of pixels around the head's middle, and build a
square around it. Per-alter tweaks live in alters.json "body.head" as
{"dx": .., "dy": .., "zoom": ..} (fractions of the crop size).
"""
import glob, json, os, sys
from PIL import Image

game = sys.argv[1]
defs = {a['id']: (a['body'], a['art']['bg']) for a in json.load(open(os.path.join(game, 'data/alters.json')))}
looks_path = os.path.join(game, 'data/looks.json')
if os.path.exists(looks_path):
    for l in json.load(open(looks_path)):
        defs[l['id']] = (l['body'], l['bg'])


def head_box(im, tweak):
    a = im.getchannel('A')
    w, h = im.size
    px = a.load()

    def runs(y):
        out, start = [], None
        for x in range(w):
            on = px[x, y] > 40
            if on and start is None:
                start = x
            elif not on and start is not None:
                out.append((start, x)); start = None
        if start is not None:
            out.append((start, w))
        return out

    # head height estimate: ~ the widest of (width-based, height-based) guesses
    base = 0.17 * h if w / h < 0.7 else 0.26 * h      # standing vs sitting/crouching
    y_mid = int(base * 0.45)
    rs = runs(min(y_mid, h - 1)) or [(0, w)]
    # the head sits above the torso: pick the run nearest the torso's centre
    # (so a streaming ponytail or raised arm isn't mistaken for the head)
    tr = runs(min(int(base * 1.6), h - 1)) or [(0, w)]
    t0, t1 = max(tr, key=lambda r: r[1] - r[0])
    tc = (t0 + t1) / 2
    x0, x1 = min(rs, key=lambda r: abs((r[0] + r[1]) / 2 - tc) - 0.3 * (r[1] - r[0]))
    head_w = x1 - x0
    side = max(base * 1.45, head_w * 1.55) * tweak.get('zoom', 1.0)
    cx = (x0 + x1) / 2 + tweak.get('dx', 0) * side
    top = -0.10 * side + tweak.get('dy', 0) * side
    return (int(cx - side / 2), int(top), int(cx + side / 2), int(top + side))


for f in sorted(glob.glob(os.path.join(game, 'assets/bodies/*_raw.png'))):
    aid = os.path.basename(f)[:-8]
    body, bg = defs[aid]
    im = Image.open(f).convert('RGBA')
    im = im.crop(im.getbbox())
    # headshot
    box = head_box(im, body.get('head', {}))
    side = box[2] - box[0]
    canvas = Image.new('RGBA', (side, side), '#' + bg)
    piece = im.crop(box)  # areas outside the image come back transparent
    canvas.paste(piece, (0, 0), piece)
    os.makedirs(os.path.join(game, 'assets/portraits'), exist_ok=True)
    canvas.convert('RGB').resize((256, 256), Image.LANCZOS).save(os.path.join(game, 'assets/portraits', aid + '.png'))
    # full body
    s = body.get('scale', 1.0)
    b = im.copy()
    b.thumbnail((int(400 * s), int(600 * s)), Image.LANCZOS)
    c = Image.new('RGBA', (400, 600), (0, 0, 0, 0))
    c.paste(b, ((400 - b.width) // 2, 600 - b.height), b)
    c.save(f.replace('_raw.png', '.png'))
    os.remove(f)
