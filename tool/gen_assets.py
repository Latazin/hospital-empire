"""Gera os sons (WAV) e as imagens (ícone, splash) do Hospital Empire.
Uso: python3 tool/gen_assets.py   (requer numpy e pillow)"""
import os, wave, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUD = os.path.join(ROOT, 'assets', 'audio'); IMG = os.path.join(ROOT, 'assets', 'images')
os.makedirs(AUD, exist_ok=True); os.makedirs(IMG, exist_ok=True)
SR = 22050

def save(name, sig):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32000).astype(np.int16)
    with wave.open(os.path.join(AUD, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

def tone(f, dur, vol=0.5, kind='sine', decay=8.0):
    t = np.arange(int(SR * dur)) / SR
    if kind == 'square': s = np.sign(np.sin(2 * np.pi * f * t)) * 0.5
    elif kind == 'tri': s = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t))
    else: s = np.sin(2 * np.pi * f * t)
    env = np.exp(-t * decay) * np.minimum(1, t * 400)
    return s * env * vol

def seq(parts):
    return np.concatenate(parts)

save('click.wav', tone(1200, 0.05, 0.35, 'tri', 60))
save('coin.wav', seq([tone(988, 0.06, 0.4, 'square', 25), tone(1319, 0.18, 0.4, 'square', 14)]))
save('cash.wav', seq([tone(784, 0.05, 0.4, 'tri', 20), tone(1047, 0.05, 0.4, 'tri', 20), tone(1319, 0.05, 0.4, 'tri', 20), tone(1568, 0.25, 0.45, 'tri', 8)]))
save('upgrade.wav', seq([tone(523, 0.07, 0.4, 'square', 15), tone(659, 0.07, 0.4, 'square', 15), tone(784, 0.2, 0.4, 'square', 9)]))
b = seq([tone(392, 0.1, 0.45, 'tri', 10), tone(523, 0.1, 0.45, 'tri', 10), tone(659, 0.1, 0.45, 'tri', 10), tone(784, 0.35, 0.5, 'tri', 5)])
save('build.wav', b)
save('alert.wav', seq([tone(880, 0.12, 0.35, 'square', 6), tone(660, 0.12, 0.35, 'square', 6), tone(880, 0.12, 0.35, 'square', 6), tone(660, 0.2, 0.35, 'square', 5)]))

# Música ambiente: loop alegre de 16 compassos (acordes + melodia), ~19s
bpm = 100; beat = 60 / bpm
chords = [[262, 330, 392], [220, 262, 330], [175, 220, 262], [196, 247, 294]]
melody = [659, 587, 523, 587, 659, 659, 659, 0, 587, 587, 587, 0, 659, 784, 784, 0,
          659, 587, 523, 587, 659, 659, 659, 659, 587, 587, 659, 587, 523, 0, 0, 0]
total = int(SR * beat * 32)
music = np.zeros(total)
t_beat = int(SR * beat)
for bar in range(8):
    ch = chords[bar % 4]
    for b_ in range(4):
        start = (bar * 4 + b_) * t_beat
        for f in ch:
            seg = tone(f, beat * 0.95, 0.07, 'tri', 2.5)
            music[start:start + len(seg)] += seg[:total - start]
        bass = tone(ch[0] / 2, beat * 0.9, 0.12, 'sine', 3)
        music[start:start + len(bass)] += bass[:total - start]
for i, f in enumerate(melody):
    if f == 0: continue
    start = i * t_beat
    seg = tone(f, beat * 0.9, 0.12, 'square', 4) * 0.6 + tone(f * 2, beat * 0.5, 0.03, 'sine', 6)[:int(SR * beat * 0.9)].tolist().__len__() * 0
    music[start:start + len(seg)] += seg[:total - start]
# suaviza emenda
fade = int(SR * 0.05)
music[:fade] *= np.linspace(0, 1, fade); music[-fade:] *= np.linspace(1, 0, fade)
save('music.wav', music * 0.9)

# ---------------- Imagens ----------------
def font(size):
    for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf']:
        if os.path.exists(f): return ImageFont.truetype(f, size)
    return ImageFont.load_default()

def hospital_art(size, bg=True):
    S = size * 4
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if bg:
        d.rounded_rectangle([0, 0, S, S], radius=S // 5, fill=(25, 181, 165, 255))
        d.ellipse([-S * 0.2, S * 0.62, S * 1.2, S * 1.4], fill=(95, 174, 87, 255))
    cx = S / 2
    def iso(x, y, z=0):
        u = S * 0.085
        return (cx + (x - y) * u, S * 0.64 + (x + y) * u / 2 - z * u)
    def box(x, y, w, dd, h, col, top, z=0):
        a1, b1, c1, d1 = iso(x, y, z + h), iso(x + w, y, z + h), iso(x + w, y + dd, z + h), iso(x, y + dd, z + h)
        b0, c0, d0 = iso(x + w, y, z), iso(x + w, y + dd, z), iso(x, y + dd, z)
        dark = tuple(int(c * 0.8) for c in col[:3]) + (255,)
        darker = tuple(int(c * 0.65) for c in col[:3]) + (255,)
        d.polygon([d0, c0, c1, d1], fill=dark, outline=(35, 49, 77, 255))
        d.polygon([b0, c0, c1, b1], fill=darker, outline=(35, 49, 77, 255))
        d.polygon([a1, b1, c1, d1], fill=top, outline=(35, 49, 77, 255))
    box(-2.2, -2.2, 4.4, 4.4, 2.6, (242, 235, 221), (38, 166, 154, 255))
    box(-1.0, -1.0, 2.0, 2.0, 1.6, (255, 255, 255), (255, 90, 95, 255), z=2.6)
    # janelas
    for i in range(3):
        x0, y0 = iso(-2.2 + 0.6 + i * 1.3, 2.2, 1.9); x1, y1 = iso(-2.2 + 1.3 + i * 1.3, 2.2, 0.9)
        d.polygon([iso(-1.6 + i * 1.3, 2.2, 1.9), iso(-0.9 + i * 1.3, 2.2, 1.9), iso(-0.9 + i * 1.3, 2.2, 0.9), iso(-1.6 + i * 1.3, 2.2, 0.9)], fill=(158, 216, 240, 255))
    # cruz
    px, py = iso(0, 0, 5.6)
    r = S * 0.13
    d.rounded_rectangle([px - r * 0.33, py - r, px + r * 0.33, py + r], radius=r * 0.15, fill=(229, 57, 53, 255), outline=(255, 255, 255, 255), width=S // 120)
    d.rounded_rectangle([px - r, py - r * 0.33, px + r, py + r * 0.33], radius=r * 0.15, fill=(229, 57, 53, 255), outline=(255, 255, 255, 255), width=S // 120)
    d.rounded_rectangle([px - r * 0.33 + S // 120, py - r * 0.33 + S // 120, px + r * 0.33 - S // 120, py + r * 0.33 - S // 120], radius=2, fill=(229, 57, 53, 255))
    # moeda
    mx, my, mr = S * 0.80, S * 0.22, S * 0.11
    d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=(255, 200, 61, 255), outline=(35, 49, 77, 255), width=S // 80)
    d.text((mx, my), '$', font=font(int(mr * 1.4)), fill=(201, 138, 0, 255), anchor='mm')
    return im.resize((size, size), Image.LANCZOS)

hospital_art(1024).save(os.path.join(IMG, 'icon.png'))
fg = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
art = hospital_art(660, bg=False); fg.paste(art, (182, 170), art)
fg.save(os.path.join(IMG, 'icon_fg.png'))
sp = Image.new('RGBA', (768, 768), (0, 0, 0, 0))
art = hospital_art(560, bg=False); sp.paste(art, (104, 40), art)
d = ImageDraw.Draw(sp)
d.text((384, 650), 'HOSPITAL EMPIRE', font=font(60), fill=(255, 255, 255, 255), anchor='mm', stroke_width=5, stroke_fill=(13, 94, 86, 255))
sp.save(os.path.join(IMG, 'splash.png'))
# Arte para a loja (feature graphic 1024x500)
fgph = Image.new('RGB', (1024, 500), (25, 181, 165))
dd = ImageDraw.Draw(fgph)
dd.ellipse([-200, 330, 1224, 900], fill=(95, 174, 87))
art = hospital_art(440, bg=False); fgph.paste(art, (560, 30), art)
dd.text((60, 170), 'HOSPITAL', font=font(92), fill='white', stroke_width=6, stroke_fill=(13, 94, 86))
dd.text((60, 270), 'EMPIRE', font=font(92), fill=(255, 200, 61), stroke_width=6, stroke_fill=(13, 94, 86))
dd.text((64, 380), 'Idle Tycoon', font=font(40), fill='white', stroke_width=3, stroke_fill=(13, 94, 86))
fgph.save(os.path.join(IMG, 'feature_graphic.png'))
print('ok')
