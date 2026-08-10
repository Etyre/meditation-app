"""Generate the app's audio assets: a synthesized gong and four short bell tones.

Pure-stdlib (wave/struct/math) so it runs on any python3.
Output: 16-bit mono WAV files at 44.1 kHz.
"""
import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio_assets")
os.makedirs(OUT, exist_ok=True)


def write_wav(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak  # normalize with headroom
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
            for s in samples
        )
        w.writeframes(frames)
    print("wrote", name, f"{len(samples)/SR:.2f}s")


def gong(duration=9.0, fundamental=82.0):
    """Gong: inharmonic partials, slow bloom, very long decay, slight beating."""
    # (ratio, amplitude, decay seconds) — inharmonic ratios typical of tam-tam/gong
    partials = [
        (1.00, 1.00, 6.5),
        (1.52, 0.62, 5.5),
        (2.01, 0.38, 4.5),
        (2.66, 0.30, 4.0),
        (3.43, 0.22, 3.2),
        (4.27, 0.16, 2.6),
        (5.13, 0.10, 2.0),
        (6.24, 0.07, 1.6),
        (8.05, 0.045, 1.2),
    ]
    n = int(duration * SR)
    out = [0.0] * n
    for ratio, amp, decay in partials:
        f = fundamental * ratio
        # slight detuned pair for shimmer/beating
        for detune in (0.0, 0.35):
            phase = 0.0
            for i in range(n):
                t = i / SR
                env = math.exp(-t / decay) * (1.0 - math.exp(-t / 0.02))
                # subtle pitch settle after the strike
                fi = (f + detune) * (1.0 + 0.004 * math.exp(-t / 0.15))
                phase += 2 * math.pi * fi / SR
                out[i] += amp * 0.5 * env * math.sin(phase)
    # strike transient: short burst of filtered noise-ish high partials
    import random
    rnd = random.Random(7)
    lp = 0.0
    for i in range(int(0.05 * SR)):
        t = i / SR
        lp += 0.25 * (rnd.uniform(-1, 1) - lp)
        out[i] += 0.35 * lp * math.exp(-t / 0.012)
    return out


def bell(freq, duration=0.5):
    """Short clean bell tone for the metronome."""
    harmonics = [(1.0, 1.0), (2.0, 0.35), (3.0, 0.12), (4.2, 0.05)]
    n = int(duration * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.13) * (1.0 - math.exp(-t / 0.004))
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(s * env)
    return out


write_wav("gong.wav", gong())
write_wav("tone1.wav", bell(440.00))   # A4
write_wav("tone2.wav", bell(554.37))   # C#5
write_wav("tone3.wav", bell(659.25))   # E5
write_wav("tone4.wav", bell(880.00))   # A5
# a soft low "tick" as a 5th option for the metronome's quieter beats
write_wav("tick.wav", bell(220.0, 0.25))
