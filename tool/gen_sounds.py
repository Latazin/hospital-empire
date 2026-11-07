"""Gera os efeitos sonoros e a música (WAV) do Hospital Empire."""
import os, wave
import numpy as np
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
def save(name, sig):
    sig = np.clip(sig, -1, 1); d = (sig * 30000).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def tone(f, d, vol=0.3, kind='square', slide=None, att=0.006):
    n = int(SR * d); t = np.arange(n) / SR
    fr = f * (slide / f) ** (t / d) if slide else np.full(n, f)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    s = {'square': np.sign(np.sin(ph)) * 0.5, 'tri': 2 / np.pi * np.arcsin(np.sin(ph)), 'sine': np.sin(ph), 'saw': ((ph / np.pi) % 2) - 1}[kind]
    env = np.minimum(1, t / att) * np.exp(-t * 3 / d)
    return s * env * vol
def noise(d, vol=0.3):
    n = int(SR * d); return (np.random.rand(n) * 2 - 1) * np.linspace(1, 0, n) * vol
def mixat(parts):
    L = max(int(SR * o) + len(s) for o, s in parts); out = np.zeros(L)
    for o, s in parts: i = int(SR * o); out[i:i + len(s)] += s
    return out
save('click', tone(880, 0.05, 0.35, 'tri'))
save('nope', tone(220, 0.16, 0.25, 'square', 140))
save('coin', mixat([(0, tone(988, 0.07, 0.22)), (0.055, tone(1319, 0.16, 0.22))]))
save('tick', tone(1320, 0.05, 0.18, 'square'))
save('cash', mixat([(i * 0.06, tone(f, 0.22, 0.35, 'tri')) for i, f in enumerate([784, 988, 1175, 1568])]))
save('up', mixat([(0, tone(523, 0.08, 0.28)), (0.06, tone(784, 0.16, 0.3, 'tri'))]))
save('level', mixat([(i * 0.1, tone(f, 0.42 if i > 3 else 0.16, 0.3, 'tri' if i % 2 else 'square')) for i, f in enumerate([523, 659, 784, 1047, 784, 1047])]))
save('build', mixat([(i * 0.13, noise(0.07, 0.5)) for i in range(4)] + [(0.55 + i * 0.08, tone(f, 0.26, 0.35, 'tri')) for i, f in enumerate([392, 523, 659, 784])]))
save('alert', mixat([(i * 0.34, tone(880, 0.16, 0.2)) for i in range(3)] + [(i * 0.34 + 0.17, tone(660, 0.16, 0.2)) for i in range(3)]))
save('pop', mixat([(0, tone(260, 0.14, 0.6, 'sine', 900)), (0, noise(0.08, 0.3))]))
save('gift', mixat([(0, tone(260, 0.14, 0.6, 'sine', 900)), (0, noise(0.08, 0.3))] + [(0.1 + i * 0.05, tone(f, 0.16, 0.25, 'tri')) for i, f in enumerate([1047, 1319, 1568, 2093])]))
save('boost', tone(400, 0.1, 0.18, 'saw', 1200))
save('whoosh', noise(0.4, 0.35) * np.sin(np.linspace(0, np.pi, int(SR * 0.4))))
# música: loop alegre
mid = lambda n: 440 * 2 ** ((n - 69) / 12)
MEL = [76, 74, 72, 74, 76, 76, 76, 0, 74, 74, 74, 0, 76, 79, 79, 0, 76, 74, 72, 74, 76, 76, 76, 76, 74, 74, 76, 74, 72, 0, 0, 0]
CH = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
beat = 60 / 104 / 2; parts = []
for s in range(64 * 2):
    t = s * beat; ch = CH[(s // 16) % 4]
    if s % 4 == 0: parts.append((t, tone(mid(ch[0] - 12), beat * 1.8, 0.22, 'tri')))
    if s % 4 == 2: parts += [(t, tone(mid(n), beat * 0.9, 0.06, 'sine')) for n in ch]
    m = MEL[(s >> 1) % 32]
    if s % 2 == 0 and m: parts.append((t, tone(mid(m), beat * 1.6, 0.07, 'square')))
    if s % 8 == 4: parts.append((t, noise(0.03, 0.08)))
mus = mixat(parts)[:int(SR * beat * 128)]
save('music', mus * 0.8)
print('ok')
