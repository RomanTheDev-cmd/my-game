# Original game audio

All WAV files were created specifically for this project by `tools/generate_audio.py`, using deterministic mathematical synthesis and noise. No recordings, external samples, voices or third-party music are included. The generator uses only the Python standard library. Rebuild with `python3 tools/generate_audio.py`.

Mono, signed 16-bit PCM, 22050 Hz. Ambience is circular and loops over eight seconds; foley has attack/release envelopes. Runtime playback includes separate Master, Effects and Ambience volume controls and a limiter. These are initial sound assets, not a completed soundtrack. Listening and level calibration on target Mac speakers/headphones remain necessary.
