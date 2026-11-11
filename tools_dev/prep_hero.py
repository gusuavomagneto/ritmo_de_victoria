"""Normaliza las poses de un héroe para el juego.

Uso: python3 -I prep_hero.py <carpeta_poses> <carpeta_destino> <nombre>
- Iguala la escala entre poses midiendo el área del pelo (referencia: pose quieto/idle).
- Ancla cada pose: pies abajo y cabeza centrada en X, así el personaje no "salta" al cambiar de pose.
- Exporta al 40 % para que pese poco.
"""
import sys, os, glob
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, DST, NAME = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(DST, exist_ok=True)
OUT_SCALE = 0.4


def hair_metrics(a):
    r, g, b, al = (a[..., i].astype(int) for i in range(4))
    hair = (al > 200) & (r > 90) & (r < 175) & (g > 45) & (g < 110) & (b < 70) & (r - g > 35)
    lab, n = ndimage.label(hair)
    sizes = ndimage.sum(hair, lab, range(1, n + 1))
    k = 1 + int(np.argmax(sizes))
    ys, xs = np.where(lab == k)
    return float(sizes.max()), float(xs.mean())


files = sorted(glob.glob(f"{SRC}/*.png"))
ref_file = next(f for f in files if "idle" in f or "quieto" in f)
ref_area, _ = hair_metrics(np.array(Image.open(ref_file).convert("RGBA")))

poses = []
for f in files:
    a = np.array(Image.open(f).convert("RGBA"))
    m = a[..., 3] > 20
    lab, nlab = ndimage.label(m)
    if nlab > 1:   # borra restos sueltos de otras figuras
        sizes = ndimage.sum(m, lab, range(1, nlab + 1))
        main = 1 + int(np.argmax(sizes))
        keep = []
        for i, sz in enumerate(sizes):
            if i + 1 == main:
                keep.append(main); continue
            if sz < 0.003 * sizes.max():
                continue
            ys, xs = np.where(lab == i + 1)
            # resto cortado por el borde de otra figura: su columna extrema es una línea recta larga
            cut = max((xs == xs.max()).sum(), (xs == xs.min()).sum()) >= 40
            if not cut:
                keep.append(i + 1)   # p. ej. la piedra de la honda
        a[~np.isin(lab, keep)] = 0
    im = Image.fromarray(a)
    area, cx = hair_metrics(a)
    s = (ref_area / area) ** 0.5
    if abs(s - 1) < 0.06:
        s = 1.0
    bbox = im.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    crop = im.crop(bbox)
    k = s * OUT_SCALE
    crop = crop.resize((max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.LANCZOS)
    anchor_x = (cx - bbox[0]) * k
    poses.append((os.path.basename(f), crop, anchor_x, s))

for fname, crop, ax, s in poses:
    half = int(max(ax, crop.width - ax)) + 4
    canvas = Image.new("RGBA", (half * 2, crop.height + 4), (0, 0, 0, 0))
    canvas.alpha_composite(crop, (int(half - ax), 2))
    out = fname.replace(".png", "").replace(NAME + "_", "")
    canvas.save(os.path.join(DST, out + ".png"))
    print(f"{out:28s} escala x{s:.2f}  {canvas.size}")
