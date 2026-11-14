"""Prepara un fondo en 4 capas (cielo, montañas, media, suelo) para el parallax del juego.

Uso: python3 -I prep_layers.py <carpeta_capas> <assets/backgrounds/NOMBRE>
Entrada: 01_cielo.png, 02_montanas.png, 03_media.png, 04_suelo.png (tiras horizontales).
- Quita la franja de la capa vecina pegada arriba y los márgenes laterales.
- Escala cada capa a su tamaño final (pantalla de 720 px de alto) y la corta en tramos de
  hasta 4096 px de ancho (límite seguro de textura en celulares).
- Escribe capas.json con la posición vertical de cada capa.
"""
import sys, os, json
import numpy as np
from PIL import Image

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(DST, exist_ok=True)
GROUND_Y = 545
SPEC = [  # archivo, nombre, escala, ancla, velocidad
    ("01_cielo.png", "cielo", 3.4, ("top", 0), 0.03),
    ("02_montanas.png", "montanas", 1.7, ("bottom", 472), 0.10),
    ("03_media.png", "media", 1.7, ("bottom", 528), 0.35),
    ("04_suelo.png", "suelo", 2.5, ("walk", GROUND_Y), 1.0),
]


def clean(a, is_sky):
    al = a[..., 3] > 20
    if is_sky:  # filas blancas arriba
        rows = np.where((a[..., :3].astype(int).sum(2) < 700).mean(1) > 0.5)[0]
        a = a[rows.min():]
    else:       # franja de otra capa pegada arriba: hasta la primera fila casi vacía
        cov = al.mean(1)
        gap = next((r for r in range(min(40, len(cov))) if cov[r] < 0.02), 0)
        a[:gap] = 0
    al = a[..., 3] > 20
    cols = np.where(al.mean(0) > 0.01)[0]
    return a[:, cols.min() + 1:cols.max()]


def walk_row(a):
    al = a[..., 3] > 20
    cov = al.mean(1)
    full = np.where(cov > 0.99)[0]
    return int(full.min()) + 6      # superficie del camino, apenas debajo del borde


out = {"layers": []}
for fname, name, sc, (anchor, val), speed in SPEC:
    a = clean(np.array(Image.open(os.path.join(SRC, fname)).convert("RGBA")), name == "cielo")
    im = Image.fromarray(a)
    im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
    if anchor == "top":
        y = val
    elif anchor == "bottom":
        y = val - im.height
    else:
        y = val - round(walk_row(a) * sc)
    tiles = []
    for k, x0 in enumerate(range(0, im.width, 4096)):
        t = im.crop((x0, 0, min(im.width, x0 + 4096), im.height))
        fn = f"{name}_{k}.png"
        t.save(os.path.join(DST, fn))
        tiles.append(fn)
    out["layers"].append({"name": name, "y": y, "speed": speed, "width": im.width, "tiles": tiles})
    print(f"{name:9s} {im.width}x{im.height}  y={y}  tramos={len(tiles)}")
m = np.array(Image.open(os.path.join(SRC, "02_montanas.png")).convert("RGBA")).astype(int)
base = m[-12:]
out["haze"] = (base[base[..., 3] > 200][:, :3].mean(0) / 255).round(3).tolist()
json.dump(out, open(os.path.join(DST, "capas.json"), "w"), indent=1)
print("bruma", out["haze"])
