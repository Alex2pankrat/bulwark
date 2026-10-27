#!/usr/bin/env python3
"""Procedural music generator for Bulwark.

The soundtrack is generated from scratch (no third-party samples) so the project can keep a
single permissive licence for everything it ships. Two seamless ambient loops are produced:

  * ``calm``   – menu / preparation: slow pads, sparse bell tones.
  * ``battle`` – in-level: pulsing bass, arpeggio, soft percussive ticks.

Both loops are rendered with numpy, wrapped (the tail is folded back into the head) so they
loop without a click, then encoded to Ogg Vorbis with ffmpeg.

Usage:
    python3 tools/make_music.py            # writes assets/audio/music/*.ogg
"""

from __future__ import annotations

import math
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"

# Note frequencies (equal temperament, A4 = 440 Hz).
def hz(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def _adsr(n: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    """Linear ADSR envelope of ``n`` samples (times in seconds)."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    s = max(1, n - a - d - r)
    env = np.concatenate([
        np.linspace(0.0, 1.0, a, endpoint=False),
        np.linspace(1.0, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r, endpoint=False),
    ])
    return np.pad(env, (0, max(0, n - env.size)))[:n]


def _pad(freqs: list[float], dur: float, amp: float) -> np.ndarray:
    """Soft detuned pad: three slightly spaced voices per note with a slow swell."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune, weight in ((0.997, 0.5), (1.0, 0.7), (1.004, 0.5)):
            phase = 2.0 * math.pi * f * detune * t
            # Sine + quiet odd harmonic = warm, non-harsh timbre.
            out += weight * (np.sin(phase) + 0.18 * np.sin(3.0 * phase))
    swell = np.sin(np.linspace(0.0, math.pi, n)) ** 1.5  # breathe in and out
    return out * swell * amp / (len(freqs) * 3.0)


def _bell(freq: float, dur: float, amp: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 3.2)
    tone = np.sin(2 * math.pi * freq * t) + 0.4 * np.sin(2 * math.pi * freq * 2.01 * t)
    return tone * env * amp


def _tick(dur: float, amp: float, seed: int) -> np.ndarray:
    """Filtered noise blip used as a soft percussive pulse."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    # One-pole low-pass to keep it soft.
    out = np.zeros(n)
    prev = 0.0
    for i, x in enumerate(noise):
        prev += 0.28 * (x - prev)
        out[i] = prev
    return out * np.exp(-np.arange(n) / (0.02 * SR)) * amp


def _bass(freq: float, dur: float, amp: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = _adsr(n, 0.01, 0.08, 0.55, 0.12)
    wave_ = np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(4 * math.pi * freq * t)
    return wave_ * env * amp


def _place(buf: np.ndarray, clip: np.ndarray, start: float) -> None:
    """Add ``clip`` into ``buf`` at ``start`` seconds, wrapping around the loop point."""
    i = int(start * SR)
    n = buf.size
    if i >= n:
        return
    end = min(n, i + clip.size)
    buf[i:end] += clip[: end - i]
    overflow = clip.size - (end - i)
    if overflow > 0:  # fold the tail back to the head -> seamless loop
        buf[:overflow] += clip[clip.size - overflow:]


def render_calm(bars: int = 8) -> np.ndarray:
    bpm = 72.0
    beat = 60.0 / bpm
    bar = beat * 4
    total = bars * bar
    buf = np.zeros(int(total * SR))

    # i - VI - III - VII  in A minor, one chord per bar.
    chords = [
        [hz(45), hz(57), hz(60), hz(64)],  # Am
        [hz(41), hz(53), hz(57), hz(60)],  # F
        [hz(48), hz(55), hz(60), hz(64)],  # C
        [hz(43), hz(55), hz(59), hz(62)],  # G
    ]
    melody_degrees = [72, 76, 79, 76, 74, 72, 69, 72]

    for b in range(bars):
        chord = chords[b % len(chords)]
        _place(buf, _pad(chord, bar * 1.05, 0.34), b * bar)
        if b % 2 == 0:
            _place(buf, _bass(chord[0] / 2.0, bar * 0.5, 0.22), b * bar)
        # Sparse bell melody on beats 1 and 3.
        for k in (0, 2):
            note = melody_degrees[(b * 2 + k) % len(melody_degrees)]
            _place(buf, _bell(hz(note), beat * 2.4, 0.16), b * bar + k * beat)
    return buf


def render_battle(bars: int = 16) -> np.ndarray:
    bpm = 104.0
    beat = 60.0 / bpm
    bar = beat * 4
    total = bars * bar
    buf = np.zeros(int(total * SR))

    roots = [hz(38), hz(38), hz(36), hz(34)]  # Dm, Dm, C, Bb
    scale = [62, 65, 69, 72, 74, 77]  # D minor pentatonic-ish

    for b in range(bars):
        root = roots[b % len(roots)]
        _place(buf, _pad([root * 2, root * 3, root * 4], bar, 0.16), b * bar)
        # Driving eighth-note bass.
        for e in range(8):
            amp = 0.20 if e % 2 == 0 else 0.12
            _place(buf, _bass(root if e % 4 else root / 2.0, beat * 0.45, amp),
                   b * bar + e * beat * 0.5)
        # Sparse arpeggio in the second half of each 4-bar phrase.
        if b % 4 in (2, 3):
            for e in range(8):
                if (b * 8 + e) % 3 == 0:
                    note = scale[(b + e) % len(scale)]
                    _place(buf, _bell(hz(note), beat * 0.9, 0.10),
                           b * bar + e * beat * 0.5)
        # Soft percussive ticks on the backbeat.
        for k in (1, 3):
            _place(buf, _tick(0.09, 0.10, seed=b * 7 + k), b * bar + k * beat)
    return buf


def _normalise(buf: np.ndarray, peak: float = 0.72) -> np.ndarray:
    m = float(np.max(np.abs(buf))) or 1.0
    return buf * (peak / m)


def _write_ogg(name: str, mono: np.ndarray) -> pathlib.Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    mono = _normalise(mono)
    # Gentle stereo width: a few milliseconds of delay on the right channel.
    delay = int(0.012 * SR)
    right = np.concatenate([np.zeros(delay), mono[:-delay]])
    stereo = np.stack([mono, 0.85 * mono + 0.15 * right], axis=1)
    pcm = np.clip(stereo * 32767.0, -32768, 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = pathlib.Path(tmp.name)
    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    out = OUT_DIR / f"{name}.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
                    "-c:a", "libvorbis", "-q:a", "4", str(out)], check=True)
    wav_path.unlink()
    return out


def main() -> None:
    for name, buf in (("calm", render_calm()), ("battle", render_battle())):
        path = _write_ogg(name, buf)
        print(f"wrote {path} ({path.stat().st_size / 1024:.0f} KiB)")


if __name__ == "__main__":
    main()
