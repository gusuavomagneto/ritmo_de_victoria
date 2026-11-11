"""Prepara las poses de un enemigo animal (o cualquier enemigo de carpeta propia).

Uso: python3 -I prep_animals.py <carpeta_poses> <carpeta_assets_characters> <nombre> [alto_px=330]
Entrada: <nombre>_correr_1..4.png y <nombre>_derribado.png, mirando a la derecha.
Salida:  <assets>/<nombre>/correr_1..4.png y derrotado.png, mirando a la izquierda.
- Borra restos de figuras vecinas cortados en el borde y sombras chatas en el piso.
- Misma escala para todas las poses (la carrera media queda en alto_px).
- Ancla: pies abajo, cabeza centrada en X.
"""
import sys, os, glob
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, DST, NAME = sys.argv[1], sys.argv[2], sys.argv[3]
TARGET_H = int(sys.argv[4]) if len(sys.argv) > 4 else 330
out_dir = os.path.join(DST, NAME)
os.makedirs(out_dir, exist_ok=True)


def clean(path):
    a = np.array(Image.open(path).convert("RGBA"))
    # sombras: gris claro semitransparente
    rgb = a[..., :3].astype(int)
    sh = (a[..., 3] < 245) & (rgb.max(2) - rgb.min(2) < 28) & (rgb.mean(2) > 30) & (rgb.mean(2) < 230)
    sh |= (a[..., 3] < 130) & (rgb.mean(2) < 60)          # sombra oscura semitransparente
    a[sh] = 0
    m = a[..., 3] > 20
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    main = 1 + int(np.argmax(sizes))
    mys, mxs = np.where(lab == main)
    keep = [main]
    for i, sz in enumerate(sizes):
        lid = i + 1
        if lid == main or sz < 0.002 * sizes.max():
            continue
        ys, xs = np.where(lab == lid)
        edge_cut = max((xs == xs.max()).sum(), (xs == xs.min()).sum()) >= 30 or xs.max() >= a.shape[1] - 3 or xs.min() <= 2
        far = xs.min() > mxs.max() + 25 or xs.max() < mxs.min() - 25
        crgb = a[ys, xs, :3].astype(int)
        grey = (crgb.max(1) - crgb.min(1)).mean() < 20 and 50 < crgb.mean() < 220
        h, w = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
        floor_shadow = grey and w > 2.5 * h and ys.min() > mys.mean()
        if edge_cut or floor_shadow or (far and sz < 0.15 * sizes.max() and ys.mean() > mys.mean()):
            continue
        keep.append(lid)   # p. ej. estrellas de mareo, nubes de polvo
    a[~np.isin(lab, keep)] = 0
    return a[:, ::-1]


files = sorted(glob.glob(f"{SRC}/{NAME}_*.png"))
imgs = {}
for f in files:
    key = os.path.basename(f)[len(NAME) + 1:-4].replace("derribado", "derrotado")
    a = clean(f)
    ys, xs = np.where(a[..., 3] > 20)
    imgs[key] = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
run_h = np.median([v.shape[0] for k, v in imgs.items() if k.startswith("correr")])
scale = TARGET_H / run_h
for key, a in imgs.items():
    im = Image.fromarray(a)
    sc = TARGET_H / a.shape[0] if key.startswith("correr") else scale   # carrera: mismo alto en todos los cuadros
    im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)
    a = np.array(im)
    top = a[: max(1, int(a.shape[0] * 0.35)), :, 3] > 20
    ax = float(np.where(top)[1].mean()) if top.any() else a.shape[1] / 2
    half = int(max(ax, a.shape[1] - ax)) + 4
    canvas = np.zeros((a.shape[0] + 4, half * 2, 4), np.uint8)
    x0 = int(half - ax)
    canvas[2:2 + a.shape[0], x0:x0 + a.shape[1]] = a
    Image.fromarray(canvas).save(os.path.join(out_dir, key + ".png"))
    print(f"{NAME}/{key}.png  {canvas.shape[1]}x{canvas.shape[0]}")
