"""Prepara las poses de un ejército enemigo para el juego.

Uso: python3 -I prep_enemy.py <carpeta_poses> <carpeta_destino> <nombre> [--reforzar]
Entrada: <nombre>_<claro|oscuro>_<pose>.png mirando a la derecha.
- Borra restos sueltos (componentes chicos separados de la figura).
- Espeja (los enemigos miran a la izquierda).
- Ancla: pies abajo y cabeza centrada en X, para que la carrera no tiemble.
"""
import sys, os, glob
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, DST, NAME = sys.argv[1], sys.argv[2], sys.argv[3]
REFORZAR = "--reforzar" in sys.argv   # tiñe toda la figura para separar claro/oscuro


def tint(a, target, amount, keep_dark=45):
    out = a.astype(np.float32).copy()
    L = (out[..., 0] * 0.299 + out[..., 1] * 0.587 + out[..., 2] * 0.114)[..., None]
    w = np.clip((L - keep_dark) / 60.0, 0, 1) * amount
    tgt = np.array(target, np.float32) * (0.55 + 0.45 * L / 255.0)
    out[..., :3] = out[..., :3] * (1 - w) + tgt * w
    return np.clip(out, 0, 255).astype(np.uint8)
os.makedirs(DST, exist_ok=True)

for f in sorted(glob.glob(f"{SRC}/{NAME}_*.png")):
    a = np.array(Image.open(f).convert("RGBA"))
    mask = a[..., 3] > 20
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.02 * sizes.max()]
        a[~np.isin(lab, keep)] = 0
    a = a[:, ::-1]
    if REFORZAR:
        a = tint(a, (252, 250, 244), 0.55) if "_claro_" in f else tint(a, (105, 62, 32), 0.6)
    ys, xs = np.where(a[..., 3] > 20)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    top = a[: int(a.shape[0] * 0.35), :, 3] > 20
    ax = float(np.where(top)[1].mean())
    half = int(max(ax, a.shape[1] - ax)) + 4
    canvas = np.zeros((a.shape[0] + 4, half * 2, 4), np.uint8)
    x0 = int(half - ax)
    canvas[2:2 + a.shape[0], x0:x0 + a.shape[1]] = a
    out = os.path.basename(f).replace(NAME + "_", "")
    Image.fromarray(canvas).save(os.path.join(DST, out))
    print(out, canvas.shape[1::-1])
