#!/usr/bin/env python3
"""Sintetiza os efeitos novos (risada, jumpscare, queda de energia).

Python puro, sem dependencias:  python tools/build_audio.py
Os arquivos sao gravados em assets/audio/. Para trocar por audios proprios
(ex.: a voz/meme da entidade no game over), basta substituir os .wav
mantendo os mesmos nomes.
"""
import math, random, struct, wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
random.seed(13)

def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    data = b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s / peak * 0.92)) * 32767)) for s in samples)
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(data)
    print(f'{name}: {len(samples) / RATE:.2f}s')

def echo(samples, delay, gain, repeats=3):
    out = samples + [0.0] * int(RATE * delay * repeats)
    step = int(RATE * delay)
    for r in range(1, repeats + 1):
        g = gain ** r
        for i, s in enumerate(samples):
            out[i + step * r] += s * g
    return out

def laugh():
    """Risada grave e lenta: silabas 'ha' com altura descendo e eco de corredor."""
    total = [0.0] * int(RATE * 2.3)
    start = 0.05
    for n in range(8):
        dur = 0.15 + n * 0.012
        f0 = 265.0 - n * 13.0 + random.uniform(-6, 6)
        amp = 1.0 - n * 0.07
        base = int(start * RATE)
        phase = 0.0
        for i in range(int(dur * RATE)):
            t = i / RATE
            env = min(1.0, t / 0.012) * math.exp(-t * 9.5)
            f = f0 * (1.0 + 0.10 * math.exp(-t * 30.0)) * (1.0 + 0.012 * math.sin(t * 38.0))
            phase += f / RATE
            voice = 0.0
            for h, w in ((1, 1.0), (2, 0.62), (3, 0.55), (4, 0.30), (5, 0.34), (7, 0.14), (9, 0.08)):
                voice += w * math.sin(2 * math.pi * phase * h)
            breath = random.uniform(-1, 1) * math.exp(-t * 45.0) * 0.8
            if base + i < len(total):
                total[base + i] += (voice * 0.33 + breath) * env * amp
        start += 0.20 + n * 0.018
    return echo(total, 0.23, 0.42)

def jumpscare():
    """Guincho dissonante com ataque seco, seguido de um ronco grave."""
    n = int(RATE * 1.7)
    out = []
    phases = [0.0] * 5
    freqs = (587.0, 622.0, 932.0, 1245.0, 311.0)
    for i in range(n):
        t = i / RATE
        gliss = 1.0 + 0.55 * min(1.0, t / 0.35) - 0.25 * max(0.0, t - 0.5)
        s = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * gliss * (1.0 + 0.02 * math.sin(t * (31 + k * 7))) / RATE
            s += 2.0 * (phases[k] % 1.0) - 1.0
        s = s / len(freqs) + random.uniform(-1, 1) * 0.55 * math.exp(-t * 3.0)
        env = min(1.0, t / 0.004) * (math.exp(-t * 2.4) + 0.15 * math.exp(-t * 0.8))
        rumble = math.sin(2 * math.pi * 52.0 * t) * 0.8 * math.exp(-t * 1.6)
        out.append(math.tanh((s * env + rumble * min(1.0, t / 0.01)) * 2.6))
    return out

def blackout():
    """Disjuntor caindo: estalo, zumbido eletrico morrendo e grave descendente."""
    n = int(RATE * 1.9)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        click = random.uniform(-1, 1) * math.exp(-t * 70.0) * 1.4
        f = 118.0 * math.exp(-t * 1.15) + 24.0
        phase += f / RATE
        hum = (2.0 * (phase % 1.0) - 1.0) * 0.5 + math.sin(2 * math.pi * phase * 0.5) * 0.7
        crackle = random.uniform(-1, 1) * 0.5 if random.random() < 0.02 * math.exp(-t * 2.2) * 8 else 0.0
        env = math.exp(-t * 1.9)
        out.append(click + (hum * env + crackle * math.exp(-t * 2.0)) * 0.9)
    return out

if __name__ == '__main__':
    save('laugh.wav', laugh())
    save('jumpscare.wav', jumpscare())
    save('blackout.wav', blackout())
