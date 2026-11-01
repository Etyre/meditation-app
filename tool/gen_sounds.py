"""Generate the app's audio assets: the gong/chime bank and the metronome tones.

Pure-stdlib (wave/struct/math) so it runs on any python3; takes about a
minute. Output: 16-bit mono WAV files at 44.1 kHz, written straight into
assets/audio/ (the filenames are what the app references, so keep them).

Gong bank (index order matches GongSounds.names in lib/core/models/gong_config.dart
and the asset list in lib/infra/audio/player_audio_service.dart):
  gong.wav          Gong            one clean strike that rings and dies out
  gong_deep.wav     Deep gong       lower, slower, longer
  gong_shimmer.wav  Shimmering gong detuned partials → slow beating "waves"
  bowl.wav          Singing bowl    harmonic-ish partials, soft attack
  bell.wav          Bell            minor-third bell partials
  chime.wav         Chime           bright, short, high
silence.wav is the near-silent loop that keeps the app running (and so the
gongs on time) while the screen is locked; see PlayerAudioService.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)


def write_wav(name, samples, normalize=True):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak if normalize else 1.0  # normalize with headroom
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


def additive(partials, fundamental, duration, attack=0.02, detune=0.0,
             settle=0.0, strike=0.0, seed=7):
    """Sum of exponentially decaying sine partials.

    partials: list of (ratio, amplitude, decay_seconds).
    detune:   if non-zero, every partial is doubled with a copy this many Hz
              higher; the pair beats at `detune` Hz (slow amplitude "waves").
              Zero gives a single clean strike with a smooth decay.
    settle:   relative pitch drop right after the strike (0.004 = 0.4%).
    strike:   amplitude of a short noise burst at the onset (the mallet hit).
    """
    n = int(duration * SR)
    out = [0.0] * n
    detunes = (0.0, detune) if detune else (0.0,)
    for ratio, amp, decay in partials:
        f = fundamental * ratio
        for d in detunes:
            phase = 0.0
            a = amp / len(detunes)
            for i in range(n):
                t = i / SR
                env = math.exp(-t / decay) * (1.0 - math.exp(-t / attack))
                fi = (f + d) * (1.0 + settle * math.exp(-t / 0.15))
                phase += 2 * math.pi * fi / SR
                out[i] += a * env * math.sin(phase)
    if strike:
        rnd = random.Random(seed)
        lp = 0.0
        for i in range(int(0.05 * SR)):
            t = i / SR
            lp += 0.25 * (rnd.uniform(-1, 1) - lp)
            out[i] += strike * lp * math.exp(-t / 0.012)
    return out


# Inharmonic partial ratios typical of a tam-tam / gong.
GONG_PARTIALS = [
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


def gong():
    """Default: a single strike with a smooth, monotonic decay (no beating)."""
    return additive(GONG_PARTIALS, 82.0, 8.0, settle=0.004, strike=0.35)


def gong_deep():
    """Lower and slower, with more weight on the fundamental."""
    partials = [(r, a * (1.15 if r < 2 else 0.8), d * 1.5) for r, a, d in GONG_PARTIALS]
    return additive(partials, 55.0, 12.0, attack=0.03, settle=0.005, strike=0.3)


def gong_shimmer():
    """The original gong: every partial doubled 0.35 Hz apart, so the sound
    swells and fades in slow waves as it decays."""
    return additive(GONG_PARTIALS, 82.0, 9.0, detune=0.35, settle=0.004,
                    strike=0.35)


def bowl():
    """Singing bowl: widely spaced near-harmonic partials, soft onset, with
    the gentle slow wobble real bowls have on the fundamental only."""
    partials = [
        (1.00, 1.00, 8.0),
        (2.71, 0.45, 5.0),
        (5.10, 0.18, 3.0),
        (7.90, 0.08, 2.0),
        (11.1, 0.03, 1.2),
    ]
    base = additive(partials, 196.0, 10.0, attack=0.04, strike=0.08)
    # Slow, mild wobble on the fundamental (pair 0.7 Hz apart, 30% depth).
    wobble = additive([(1.00, 0.3, 8.0)], 196.0, 10.0, attack=0.04, detune=0.7)
    return [b + w for b, w in zip(base, wobble)]


def bell():
    """Minor-third bell: hum, prime, tierce, quint, nominal + upper partials."""
    partials = [
        (0.50, 0.55, 5.5),   # hum
        (1.00, 1.00, 4.0),   # prime
        (1.20, 0.60, 3.2),   # tierce (minor third)
        (1.50, 0.35, 2.8),   # quint
        (2.00, 0.50, 2.2),   # nominal
        (2.51, 0.22, 1.5),
        (3.00, 0.15, 1.1),
        (4.17, 0.08, 0.7),
    ]
    return additive(partials, 440.0, 6.5, attack=0.004, strike=0.12)


def chime():
    """Bright chime: free-bar modes of a single metal tube, short ring."""
    partials = [
        (1.00, 1.00, 2.2),
        (2.76, 0.40, 1.3),
        (5.40, 0.15, 0.7),
        (8.93, 0.05, 0.4),
    ]
    return additive(partials, 1046.5, 3.5, attack=0.002, strike=0.05)


def silence(duration=10.0):
    """Near-silence for the background keep-alive loop: +/-1 LSB dither
    (about -90 dBFS, inaudible) rather than pure zeros so the audio hardware
    has a real signal to render. Written un-normalized."""
    rnd = random.Random(11)
    return [rnd.choice((-1, 1)) / 32767.0 for _ in range(int(duration * SR))]


def metronome_tone(freq, duration=0.5):
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


if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:])  # optionally: names of files to (re)generate

    def want(name):
        return not only or name in only

    if want("gong.wav"):
        write_wav("gong.wav", gong())
    if want("gong_deep.wav"):
        write_wav("gong_deep.wav", gong_deep())
    if want("gong_shimmer.wav"):
        write_wav("gong_shimmer.wav", gong_shimmer())
    if want("bowl.wav"):
        write_wav("bowl.wav", bowl())
    if want("bell.wav"):
        write_wav("bell.wav", bell())
    if want("chime.wav"):
        write_wav("chime.wav", chime())
    if want("silence.wav"):
        write_wav("silence.wav", silence(), normalize=False)
    if want("tone1.wav"):
        write_wav("tone1.wav", metronome_tone(440.00))   # A4
    if want("tone2.wav"):
        write_wav("tone2.wav", metronome_tone(554.37))   # C#5
    if want("tone3.wav"):
        write_wav("tone3.wav", metronome_tone(659.25))   # E5
    if want("tone4.wav"):
        write_wav("tone4.wav", metronome_tone(880.00))   # A5
    if want("tick.wav"):
        # a soft low "tick" as a 5th option for the metronome's quieter beats
        write_wav("tick.wav", metronome_tone(220.0, 0.25))
