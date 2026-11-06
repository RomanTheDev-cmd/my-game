"""Generate original mono PCM foley and ambience; standard library only."""
from array import array
import math
from pathlib import Path
import random
import sys
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'


def write(name, samples, peak):
    maximum = max(abs(x) for x in samples) or 1
    pcm = array('h', (round(x / maximum * peak * 32767) for x in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(pcm.tobytes())


def tone(name, duration, seed, kind):
    rng = random.Random(seed)
    values = []
    low = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        x = t / duration
        low += (rng.uniform(-1, 1) - low) * 0.18
        attack = min(1, t / 0.008)
        if kind == 'step':
            value = (low + 0.25 * math.sin(2 * math.pi * 110 * t)) * math.exp(-x * 8)
        elif kind in ('swing', 'dodge', 'arrow'):
            value = low * math.sin(math.pi * x) ** 2 + 0.12 * math.sin(2 * math.pi * (180 * t - 90 * t * t)) * math.sin(math.pi * x)
        elif kind == 'impact':
            value = (low + 0.45 * math.sin(2 * math.pi * 74 * t) + 0.12 * math.sin(2 * math.pi * 187 * t)) * math.exp(-x * 7)
        elif kind == 'block':
            value = (0.15 * low + sum(math.sin(2 * math.pi * f * t) for f in (410, 617, 1041)) / 3) * math.exp(-x * 6)
        elif kind == 'magic':
            value = (0.3 * low + math.sin(2 * math.pi * (420 * t + 170 * t * t)) * 0.6) * math.sin(math.pi * x) ** 2
        else:
            notes = (392, 493.88, 587.33) if kind == 'heal' else ((659.25, 987.77) if kind == 'collect' else (740, 1110))
            value = sum(math.sin(2 * math.pi * f * t) for f in notes) / len(notes) * math.sin(math.pi * x) ** 2 * math.exp(-x * 2)
        values.append(value * attack * min(1, (duration - t) / 0.015))
    write(name, values, 0.45 if kind == 'step' else 0.6)


def atmosphere(name, seed, kind):
    rng = random.Random(seed)
    count = RATE * 8
    noise = [rng.uniform(-1, 1) for _ in range(count)]
    # Circular smoothing keeps the loop boundary equivalent to any interior sample.
    for _ in range(3 if kind != 'rain' else 1):
        noise = [(noise[i - 1] + noise[i] + noise[(i + 1) % count]) / 3 for i in range(count)]
    values = []
    for i, n in enumerate(noise):
        phase = i / count * 2 * math.pi
        if kind == 'rain':
            value = n * (0.6 + 0.12 * math.sin(phase * 3))
        elif kind == 'room':
            value = n * 0.1 + 0.12 * math.sin(phase * 352) + 0.08 * math.sin(phase * 469)
        else:
            value = n * (0.4 + 0.2 * math.sin(phase)) + 0.06 * math.sin(phase * 83)
        values.append(value)
    if kind == 'fire':
        for _ in range(60):
            start = rng.randrange(count)
            for j in range(600):
                values[(start + j) % count] += rng.uniform(-1, 1) * math.exp(-j / 70) * 0.3
    write(name, values, 0.23)


def main():
    ROOT.mkdir(exist_ok=True)
    for index in range(3):
        tone(f'step_{index}', 0.13, 400 + index, 'step')
    for index, (name, duration) in enumerate((('swing', 0.2), ('dodge', 0.25), ('arrow', 0.15), ('impact', 0.24), ('block', 0.38), ('magic', 0.4), ('heal', 0.85), ('collect', 0.35), ('ui', 0.07))):
        tone(name, duration, 500 + index, name)
    for index, name in enumerate(('wind', 'rain', 'room', 'fire')):
        atmosphere(name, 700 + index, name)
    print('Generated 16 original PCM audio assets')


if __name__ == '__main__':
    main()
