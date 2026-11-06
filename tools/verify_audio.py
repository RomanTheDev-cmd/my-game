"""Check shipped PCM assets for silence, clipping and damaged loop boundaries."""
from array import array
import math
from pathlib import Path
import sys
import wave

root = Path(__file__).resolve().parents[1] / 'assets/audio'
paths = sorted(root.glob('*.wav'))
assert len(paths) >= 16, 'Missing initial audio library'
for path in paths:
    with wave.open(str(path), 'rb') as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 2
        assert source.getframerate() == 22050 and source.getcomptype() == 'NONE'
        frames = source.getnframes()
        assert 1000 < frames <= 22050 * 10, f'{path.name}: invalid duration'
        samples = array('h', source.readframes(frames))
        if sys.byteorder != 'little':
            samples.byteswap()
    peak = max(abs(s) for s in samples) / 32768
    rms = math.sqrt(sum((s / 32768) ** 2 for s in samples) / len(samples))
    assert 0.1 < peak < 0.7 and rms > 0.01, f'{path.name}: silence or clipping'
    if path.stem in ('wind', 'rain', 'room', 'fire'):
        assert frames == 22050 * 8
        assert abs(samples[0] - samples[-1]) / 32768 < 0.15, f'{path.name}: discontinuous loop seam'
    else:
        assert abs(samples[0]) < 50 and abs(samples[-1]) < 50, f'{path.name}: missing envelope'
print(f'Audio assets: {len(paths)} PCM files; non-silent, headroom and loop boundaries OK')
