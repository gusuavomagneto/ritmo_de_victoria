"""Limpia los PNG de personajes y genera variantes para el juego.

Uso: python3 -I prep_characters.py <carpeta_origen> <carpeta_destino>
- Deja solo la figura principal (borra restos de figuras vecinas) y recorta al contenido.
- Héroes: mirando a la derecha (como vienen).
- Enemigos: espejados (mirando a la izquierda) + variantes _claro y _oscuro.
- Goliat: filisteo en tono bronce.
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(DST, exist_ok=True)
HEROES = ["david", "sanson", "gedeon", "josue", "elias", "eliseo"]
ENEMIES = ["filisteo", "egipcio", "amalecita", "cananeo", "amorreo", "soldado_generico"]


def clean(path):
    a = np.array(Image.open(path).convert("RGBA"))
    mask = a[..., 3] > 20
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        a[lab != keep] = 0
    ys, xs = np.where(a[..., 3] > 20)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def tint(a, target, amount, keep_dark=60):
    """Mezcla los colores hacia un tono, respetando contornos oscuros."""
    out = a.astype(np.float32).copy()
    L = lum(out)[..., None]
    w = np.clip((L - keep_dark) / 60.0, 0, 1) * amount
    tgt = np.array(target, np.float32) * (0.55 + 0.45 * L / 255.0)
    out[..., :3] = out[..., :3] * (1 - w) + tgt * w
    return np.clip(out, 0, 255).astype(np.uint8)


def save(a, name):
    Image.fromarray(a).save(os.path.join(DST, name + ".png"))

for h in HEROES:
    save(clean(f"{SRC}/{h}.png"), h)
for e in ENEMIES:
    a = clean(f"{SRC}/{e}.png")[:, ::-1]
    save(a, e)
    save(tint(a, (252, 250, 244), 0.8, keep_dark=45), e + "_claro")
    save(tint(a, (105, 62, 32), 0.85, keep_dark=45), e + "_oscuro")
save(tint(clean(f"{SRC}/filisteo.png")[:, ::-1], (205, 160, 80), 0.45), "goliat")
print(sorted(os.listdir(DST)))
