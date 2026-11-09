"""Genera el tema de prueba (OGG) y su MIDI de enemigos para el prototipo.

Convención de notas (cualquier octava):
  C = enemigo tipo A (honda)
  D = enemigo tipo B (arpa)
  E = piedra contra Goliat (honda, sección de jefe)
"""
import struct, sys, subprocess
import numpy as np

OUT_DIR = sys.argv[1]
SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 34
LEN = BARS * BAR + 2.0

t = np.arange(int(LEN * SR)) / SR
mix = np.zeros_like(t)


def add(sig, start):
    i = int(start * SR)
    j = min(len(mix), i + len(sig))
    mix[i:j] += sig[: j - i]


def env(n, a=0.002, d=0.2):
    x = np.arange(n) / SR
    return np.minimum(1, x / a) * np.exp(-x / d)


def kick(strong=False):
    n = int(0.35 * SR); x = np.arange(n) / SR
    f = 50 + 120 * np.exp(-x * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, d=0.18) * (1.0 if strong else 0.9)


def snare():
    n = int(0.25 * SR)
    return (np.random.randn(n) * 0.5 + np.sin(2 * np.pi * 190 * np.arange(n) / SR) * 0.4) * env(n, d=0.08) * 0.6


def hat():
    n = int(0.06 * SR)
    noise = np.diff(np.random.randn(n), prepend=0)
    return noise * env(n, d=0.015) * 0.18


def tone(freq, dur, vol=0.25, kind="saw", d=0.3):
    n = int(dur * SR); x = np.arange(n) / SR
    if kind == "saw":
        s = 2 * ((x * freq) % 1) - 1
        s = np.convolve(s, np.ones(8) / 8, mode="same")
    elif kind == "square":
        s = np.sign(np.sin(2 * np.pi * freq * x)) * 0.6
    else:
        s = np.sin(2 * np.pi * freq * x) + 0.3 * np.sin(4 * np.pi * freq * x)
    return s * env(n, a=0.005, d=d) * vol


def click(high):
    n = int(0.05 * SR); x = np.arange(n) / SR
    return np.sin(2 * np.pi * (1500 if high else 1000) * x) * env(n, d=0.01) * 0.4


def midi_hz(m):
    return 440 * 2 ** ((m - 69) / 12)


roots = [38, 34, 41, 36]  # Dm - Bb - F - C
scale = [62, 65, 67, 69, 72, 74]
rng = np.random.default_rng(7)
np.random.seed(7)
for bar in range(BARS):
    b0 = bar * BAR
    if bar < 2:
        for k in range(4):
            add(click(k == 0), b0 + k * BEAT)
        continue
    boss = bar >= 26
    root = roots[(bar - 2) % 4]
    for k in range(4):
        bt = b0 + k * BEAT
        add(hat(), bt)
        add(hat() * 0.6, bt + BEAT / 2)
        for h in range(2):
            add(tone(midi_hz(root), BEAT / 2, 0.3 if boss else 0.22, "square" if boss else "saw", d=0.15), bt + h * BEAT / 2)
    if bar >= 10:
        for k in range(4):
            if rng.random() < 0.7:
                add(tone(midi_hz(scale[rng.integers(len(scale))]), BEAT * 0.9, 0.12, "sine", d=0.35), b0 + k * BEAT)
    for m in (root + 24, root + 27, root + 31):
        add(tone(midi_hz(m), BAR, 0.035, "sine", d=2.0), b0)

mix = mix / np.max(np.abs(mix)) * 0.9
pcm = (mix * 32767).astype(np.int16)
wav = f"{OUT_DIR}/tmp_song.wav"
with open(wav, "wb") as f:
    data = pcm.tobytes()
    f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16) + b"data" + struct.pack("<I", len(data)) + data)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", f"{OUT_DIR}/david_prueba.ogg"], check=True)
subprocess.run(["rm", wav])

# ---------- MIDI de enemigos ----------
TPQ = 480
KICK, SNARE, BOSS = 36, 38, 40   # General MIDI: kick=C1(36) oscuro, snare=D1(38) claro, E1(40) jefe
events = []


def q(bar, beat):
    return int((bar * 4 + beat) * TPQ)

for bar in range(2, 10):          # media tamborileada: kick 1 · snare 3
    events += [(q(bar, 0), KICK), (q(bar, 2), SNARE)]
for bar in range(10, 18):         # backbeat: kick 1,3 · snare 2,4
    events += [(q(bar, 0), KICK), (q(bar, 1), SNARE), (q(bar, 2), KICK), (q(bar, 3), SNARE)]
for i, bar in enumerate(range(18, 26)):   # groove con corcheas
    events += [(q(bar, 0), KICK), (q(bar, 1), SNARE), (q(bar, 1.5), KICK), (q(bar, 2), KICK), (q(bar, 3), SNARE)]
    if i % 2 == 1:
        events.append((q(bar, 3.5), SNARE))
for i, bar in enumerate(range(26, 34)):   # Goliat: piedras en 1 y 3, snare en 2 y 4
    events += [(q(bar, 0), BOSS), (q(bar, 1), SNARE), (q(bar, 2), BOSS), (q(bar, 3), SNARE)]
    if i >= 4:
        events.append((q(bar, 2.5), KICK))
events.sort()


def vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(out)

trk0 = vlq(0) + b"\xff\x51\x03" + int(60_000_000 / BPM).to_bytes(3, "big") + vlq(0) + b"\xff\x58\x04\x04\x02\x18\x08" + vlq(0) + b"\xff\x2f\x00"
seq = []
for tk, n in events:
    seq.append((tk, 0x90, n, 100))
    seq.append((tk + TPQ // 8, 0x80, n, 0))
seq.sort(key=lambda e: (e[0], e[1] == 0x90))
body, last = b"", 0
for tk, st, n, v in seq:
    body += vlq(tk - last) + bytes([st, n, v])
    last = tk
body = vlq(0) + b"\xff\x03\x08Enemigos" + body + vlq(0) + b"\xff\x2f\x00"
with open(f"{OUT_DIR}/david_prueba.mid", "wb") as f:
    f.write(b"MThd" + struct.pack(">IHHH", 6, 1, 2, TPQ))
    for tr in (trk0, body):
        f.write(b"MTrk" + struct.pack(">I", len(tr)) + tr)
def save_wav(path, sig):
    sig = sig / np.max(np.abs(sig)) * 0.95
    d = (sig * 32767).astype(np.int16).tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(d)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16) + b"data" + struct.pack("<I", len(d)) + d)

SFX = OUT_DIR.replace("music", "sfx")
import os; os.makedirs(SFX, exist_ok=True)
save_wav(f"{SFX}/kick.wav", kick(True))
save_wav(f"{SFX}/snare.wav", snare())
boom = np.zeros(int(0.6 * SR)); k = kick(True); boom[:len(k)] += k * 1.2
n = int(0.6 * SR); crash = np.diff(np.random.randn(n), prepend=0) * env(n, d=0.25) * 0.5
save_wav(f"{SFX}/golpe_jefe.wav", boom + crash)
print("notas:", len(events), "duración:", LEN)

# ---------- Stem de batería del jugador (kick/snare/golpe en los tiempos del MIDI) ----------
spb = 60 / BPM
stem = np.zeros(int(LEN * SR))
def add_stem(sig, start):
    i = int(start * SR); j = min(len(stem), i + len(sig)); stem[i:j] += sig[: j - i]
for tk, nnote in events:
    ts = tk / TPQ * spb
    add_stem(kick(True) if nnote == KICK else (snare() if nnote == SNARE else boom + crash), ts)
stem = stem / np.max(np.abs(stem)) * 0.9
save_wav(f"{OUT_DIR}/tmp_stem.wav", stem)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{OUT_DIR}/tmp_stem.wav", "-c:a", "libvorbis", "-q:a", "5", f"{OUT_DIR}/david_prueba_bateria.ogg"], check=True)
os.remove(f"{OUT_DIR}/tmp_stem.wav")
print("stem de batería ok")
