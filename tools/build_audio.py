#!/usr/bin/env python3
"""Sintetiza os efeitos novos (risada, jumpscare, queda de energia, coracao, sussurro).

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

def heartbeat():
    """Duas pancadas graves e abafadas (tum-tum)."""
    n = int(RATE * 0.42)
    out = [0.0] * n
    for start, amp, f0 in ((0.0, 1.0, 62.0), (0.15, 0.72, 54.0)):
        base = int(start * RATE)
        for i in range(n - base):
            t = i / RATE
            f = f0 * (1.0 + 0.9 * math.exp(-t * 38.0))
            env = min(1.0, t / 0.006) * math.exp(-t * 19.0)
            out[base + i] += amp * env * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t))
    return out

def whisper():
    """Sussurro sem palavras: sopro filtrado em silabas, com eco de corredor."""
    n = int(RATE * 1.5)
    out = []
    low = band = 0.0
    for i in range(n):
        t = i / RATE
        # Filtro de estado variavel varrendo como vogais cochichadas.
        cutoff = 1500.0 + 900.0 * math.sin(t * 9.0) + 500.0 * math.sin(t * 23.0)
        f = 2.0 * math.sin(math.pi * cutoff / RATE)
        high = random.uniform(-1, 1) - low - 0.35 * band
        band += f * high
        low += f * band
        syllable = max(0.0, math.sin(t * 2 * math.pi * 3.4 + 0.6)) ** 1.6
        env = min(1.0, t / 0.05) * min(1.0, (1.5 - t) / 0.4)
        out.append(band * syllable * env)
    return echo(out, 0.19, 0.38, 2)

def midi(n, cents=0.0):
    return 440.0 * 2.0 ** ((n - 69 + cents / 100.0) / 12.0)

def lullaby():
    """Tema de fundo ORIGINAL: caixinha de musica aguda em 6/8, repetitiva e
    levemente desafinada (duas vozes batendo), sobre um bordao grave.
    Composto para este projeto; o fim emenda no comeco (laco perfeito)."""
    step = 0.30
    bars = [
        (81, 88, 89, 88, 84, 83), (81, 88, 89, 88, 84, 83),
        (77, 84, 85, 84, 81, 80), (77, 84, 85, 84, 81, 80),
        (75, 81, 82, 81, 78, 77), (75, 81, 82, 81, 78, 77),
        (76, 83, 84, 83, 80, 79), (76, 83, 84, 83, 80, 79),
    ] * 2
    roots = [45, 45, 41, 41, 39, 39, 40, 40] * 2
    lead = [None] * 8 + [100, 100, 101, 101, 99, 99, 95, 96]
    n = int(len(bars) * 6 * step * RATE)
    out = [0.0] * n

    def box(start, note, amp, cents=0.0, decay=3.4):
        f = midi(note, cents)
        base = int(start * RATE)
        for i in range(int(1.9 * RATE)):
            t = i / RATE
            env = min(1.0, t / 0.003) * math.exp(-t * decay)
            v = math.sin(2 * math.pi * f * t) + 0.42 * math.sin(2 * math.pi * f * 3.01 * t) * math.exp(-t * 9.0) \
                + 0.16 * math.sin(2 * math.pi * f * 5.43 * t) * math.exp(-t * 16.0)
            out[(base + i) % n] += v * env * amp

    for b, figure in enumerate(bars):
        for k, note in enumerate(figure):
            when = (b * 6 + k) * step
            accent = 1.0 if k == 0 else (0.78 if k == 3 else 0.6)
            box(when, note, 0.30 * accent)
            box(when + 0.012, note, 0.20 * accent, 17.0)          # voz desafinada: batimento
            if b >= 8 and k in (1, 4):
                box(when + step * 0.5, note + 12, 0.07, -22.0, 5.0)  # eco fantasma
    for b, root in enumerate(roots):
        f = midi(root)
        base = int(b * 6 * step * RATE)
        length = int(6 * step * RATE)
        for i in range(length + int(0.5 * RATE)):
            t = i / RATE
            env = min(1.0, t / 0.5) * min(1.0, max(0.0, (length / RATE + 0.5 - t) / 0.5))
            out[(base + i) % n] += (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.006 * t)) * env * 0.16
    for b, note in enumerate(lead):
        if note is None:
            continue
        f = midi(note, -19.0)                                      # sempre um pouco baixa
        base = int(b * 6 * step * RATE)
        length = int(6 * step * RATE)
        phase = 0.0
        for i in range(length):
            t = i / RATE
            phase += f * (1.0 + 0.006 * math.sin(2 * math.pi * 5.1 * t) * min(1.0, t)) / RATE
            env = min(1.0, t / 0.35) * min(1.0, (length / RATE - t) / 0.4)
            out[(base + i) % n] += math.sin(2 * math.pi * phase) * env * 0.055
    return out

def creak():
    """Porta rangendo devagar: atrito aos trancos com ressonancia de madeira."""
    n = int(RATE * 1.5)
    out = []
    phase = 0.0
    r1 = r2 = 0.0
    for i in range(n):
        t = i / RATE
        f = 150.0 + 110.0 * (t / 1.5) ** 1.7 + 14.0 * math.sin(t * 31.0)
        phase += f / RATE
        stick = (phase % 1.0) ** 3                                 # dente de serra "preso-solto"
        src = stick * 2.0 - 0.5 + random.uniform(-1, 1) * 0.08
        r1 += 0.22 * (src - r1)
        r2 += 0.05 * (r1 - r2)
        env = min(1.0, t / 0.12) * min(1.0, (1.5 - t) / 0.3) * (0.7 + 0.3 * math.sin(t * 7.0))
        out.append((r1 - r2) * env)
    return echo(out, 0.21, 0.3, 2)

def knock():
    """Tres batidas secas vindas de dentro da parede."""
    n = int(RATE * 1.3)
    out = [0.0] * n
    for start, amp in ((0.0, 1.0), (0.30, 0.85), (0.60, 0.95)):
        base = int(start * RATE)
        for i in range(int(0.3 * RATE)):
            t = i / RATE
            v = math.sin(2 * math.pi * (96.0 + 60.0 * math.exp(-t * 60.0)) * t) * math.exp(-t * 22.0)
            v += random.uniform(-1, 1) * math.exp(-t * 90.0) * 0.5
            out[base + i] += v * amp
    return echo(out, 0.16, 0.35, 2)

def scrape():
    """Algo pesado sendo arrastado pelo assoalho."""
    n = int(RATE * 1.7)
    out = []
    low = 0.0
    for i in range(n):
        t = i / RATE
        low += 0.06 * (random.uniform(-1, 1) - low)
        grit = random.uniform(-1, 1) * 0.12 * (0.5 + 0.5 * math.sin(t * 43.0)) ** 2
        ring = math.sin(2 * math.pi * 870.0 * t) * 0.02 * (0.5 + 0.5 * math.sin(t * 5.0))
        env = min(1.0, t / 0.25) * min(1.0, (1.7 - t) / 0.45) * (0.6 + 0.4 * math.sin(t * 3.3 + 1.0) ** 2)
        out.append((low * 3.0 + grit + ring) * env)
    return out

def breath():
    """Uma respiracao lenta e umida, colada no ouvido."""
    n = int(RATE * 2.3)
    out = []
    low = band = 0.0
    for i in range(n):
        t = i / RATE
        inhale = t < 1.0
        cutoff = (1300.0 if inhale else 620.0) + 200.0 * math.sin(t * 5.0)
        f = 2.0 * math.sin(math.pi * cutoff / RATE)
        high = random.uniform(-1, 1) - low - 0.6 * band
        band += f * high
        low += f * band
        env = math.sin(math.pi * t / 1.0) ** 1.5 * 0.6 if inhale else math.sin(math.pi * (t - 1.0) / 1.3) ** 1.2
        rattle = 1.0 if inhale else (0.75 + 0.25 * math.sin(t * 2 * math.pi * 27.0))
        out.append(band * max(0.0, env) * rattle)
    return out

def sting():
    """Golpe de susto: sopro invertido que cresce e estoura num acorde podre."""
    swell = int(RATE * 0.45)
    n = int(RATE * 1.9)
    out = []
    phases = [0.0] * 6
    freqs = (49.0, 51.9, 98.0, 138.6, 147.0, 1975.0)
    for i in range(n):
        t = i / RATE
        if i < swell:
            out.append(random.uniform(-1, 1) * (t / 0.45) ** 3 * 0.55)
            continue
        u = t - 0.45
        v = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * (1.0 - 0.04 * min(1.0, u)) / RATE
            saw = 2.0 * (phases[k] % 1.0) - 1.0
            v += saw * (0.12 if k == 5 else 0.55) * (math.exp(-u * 7.0) if k == 5 else 1.0)
        v += random.uniform(-1, 1) * math.exp(-u * 30.0) * 1.2
        out.append(math.tanh(v * 0.9) * min(1.0, u / 0.003) * math.exp(-u * 2.6))
    return out

if __name__ == '__main__':
    save('laugh.wav', laugh())
    save('jumpscare.wav', jumpscare())
    save('blackout.wav', blackout())
    save('heartbeat.wav', heartbeat())
    save('whisper.wav', whisper())
    theme = lullaby()
    save('lullaby.wav', theme)
    save('lullaby_reverse.wav', theme[::-1])   # a mesma caixinha, tocada de tras para frente
    save('creak.wav', creak())
    save('knock.wav', knock())
    save('scrape.wav', scrape())
    save('breath.wav', breath())
    save('sting.wav', sting())
