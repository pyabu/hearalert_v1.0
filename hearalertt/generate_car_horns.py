#!/usr/bin/env python3
"""
generate_car_horns.py
=====================
Generates 800 highly diverse car horn audio samples using synthesis.

Variation axes:
  - Tone pattern (single toot, double honk, long lean, SOS pattern, impatient repeat)
  - Fundamental frequency (250–700 Hz, full range of real horns)
  - Harmonics richness (pure sine → saw-wave-like multi-harmonic)
  - Doppler effect (approaching / passing / receding)
  - Distance (near vs. far)
  - Environmental reverb (open road, tunnel, parking garage)
  - Background noise (street traffic, crowd, rain)
  - Pitch drift / slight detuning (aging horn)
"""

import os, sys, random, struct, wave, math
from pathlib import Path

def _ensure(*pkgs):
    import subprocess
    for pkg in pkgs:
        mod = pkg.split("[")[0].replace("-", "_")
        try:
            __import__(mod)
        except ImportError:
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=True)

_ensure("numpy", "scipy")

import numpy as np
from scipy.signal import lfilter

SR = 16000
OUTPUT_DIR = Path(__file__).parent / "training_data" / "car_horn"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
N_SAMPLES = 800

# ── Synthesis primitives ─────────────────────────────────────────────────────

def sine(freq, duration, sr=SR, phase=0.0):
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    return np.sin(2 * np.pi * freq * t + phase).astype(np.float32)

def multi_harmonic(freq, duration, harmonics, sr=SR):
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    sig = np.zeros(len(t), dtype=np.float32)
    for k, amp in harmonics:
        sig += amp * np.sin(2 * np.pi * freq * k * t)
    return sig / (max(abs(sig.max()), abs(sig.min())) + 1e-6)

def envelope(sig, attack_s=0.02, decay_s=0.02, sr=SR):
    """Apply smooth attack and decay."""
    n = len(sig)
    a = int(attack_s * sr)
    d = int(decay_s * sr)
    env = np.ones(n, dtype=np.float32)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if d > 0 and d <= n:
        env[-d:] = np.linspace(1, 0, d)
    return sig * env

def butter_lowpass(sig, cutoff=4000, sr=SR):
    """Simple first-order IIR lowpass to soften harsh synthesis."""
    alpha = 1 - math.exp(-2 * math.pi * cutoff / sr)
    b, a = [alpha], [1, -(1 - alpha)]
    return lfilter(b, a, sig).astype(np.float32)

def add_noise(sig, snr_db=20):
    sig_power = np.mean(sig**2) + 1e-9
    noise_power = sig_power / (10 ** (snr_db / 10))
    noise = np.random.normal(0, math.sqrt(noise_power), len(sig)).astype(np.float32)
    return sig + noise

def reverb(sig, decay=0.3, delay_ms=60, sr=SR):
    delay_samples = int(delay_ms * sr / 1000)
    out = sig.copy()
    if delay_samples < len(sig):
        out[delay_samples:] += decay * sig[:-delay_samples]
    return out.astype(np.float32)

def doppler_shift(sig, start_ratio=1.12, end_ratio=0.90, sr=SR):
    """Simulate a passing car by resampling frequency dynamically."""
    n = len(sig)
    ratios = np.linspace(start_ratio, end_ratio, n)
    new_indices = np.cumsum(ratios)
    new_indices = new_indices / new_indices[-1] * (n - 1)
    return np.interp(new_indices, np.arange(n), sig).astype(np.float32)

def normalize(sig, peak=0.85):
    peak_val = max(abs(sig.max()), abs(sig.min())) + 1e-9
    return (sig / peak_val * peak).astype(np.float32)

def to_wav_bytes(sig, sr=SR):
    pcm = np.clip(sig, -1, 1)
    pcm_int = (pcm * 32767).astype(np.int16)
    return pcm_int.tobytes()

def save_wav(path, sig, sr=SR):
    data = to_wav_bytes(sig)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(data)

# ── Horn patterns ─────────────────────────────────────────────────────────────

def make_horn_segment(freq, duration, harmonic_weight=None, sr=SR):
    """Generate one horn blast at given frequency."""
    if harmonic_weight is None:
        # Random harmonic richness
        harmonic_weight = random.choice([
            [(1, 1.0)],                              # pure sine
            [(1, 1.0), (2, 0.4)],                   # one harmonic
            [(1, 1.0), (2, 0.5), (3, 0.25)],        # two harmonics
            [(1, 1.0), (2, 0.6), (3, 0.3), (4, 0.1)],  # rich
        ])
    seg = multi_harmonic(freq, duration, harmonic_weight, sr)
    seg = envelope(seg, attack_s=random.uniform(0.01, 0.04), decay_s=random.uniform(0.01, 0.04), sr=sr)
    seg = butter_lowpass(seg, cutoff=random.uniform(2500, 5000), sr=sr)
    return seg

def honk_pattern(freq, sr=SR):
    """Choose a random horn timing pattern."""
    pattern_type = random.choice([
        "single",
        "double",
        "long",
        "impatient",
        "sos",
        "triple",
        "two_short_long",
    ])

    silence = lambda ms: np.zeros(int(ms * sr / 1000), dtype=np.float32)

    if pattern_type == "single":
        dur = random.uniform(0.3, 1.2)
        parts = [make_horn_segment(freq, dur, sr=sr)]

    elif pattern_type == "double":
        d1 = random.uniform(0.2, 0.5)
        d2 = random.uniform(0.2, 0.7)
        gap = random.uniform(0.05, 0.2)
        parts = [make_horn_segment(freq, d1), silence(gap * 1000), make_horn_segment(freq, d2)]

    elif pattern_type == "long":
        dur = random.uniform(1.0, 2.5)
        parts = [make_horn_segment(freq, dur)]

    elif pattern_type == "impatient":
        n = random.randint(3, 6)
        parts = []
        for i in range(n):
            parts.append(make_horn_segment(freq, random.uniform(0.1, 0.25)))
            if i < n - 1:
                parts.append(silence(random.uniform(60, 150)))

    elif pattern_type == "sos":
        short = 0.15
        long_ = 0.4
        gap_s = 0.08
        gap_l = 0.15
        seq = [short, short, short, long_, long_, long_, short, short, short]
        parts = []
        for i, d in enumerate(seq):
            parts.append(make_horn_segment(freq, d))
            if i < len(seq) - 1:
                gap = gap_l if i == 2 or i == 5 else gap_s
                parts.append(silence(gap * 1000))

    elif pattern_type == "triple":
        parts = []
        for i in range(3):
            parts.append(make_horn_segment(freq, random.uniform(0.15, 0.4)))
            if i < 2:
                parts.append(silence(random.uniform(80, 200)))

    else:  # two_short_long
        s1 = random.uniform(0.12, 0.2)
        s2 = random.uniform(0.12, 0.2)
        long_ = random.uniform(0.6, 1.2)
        parts = [
            make_horn_segment(freq, s1), silence(100),
            make_horn_segment(freq, s2), silence(150),
            make_horn_segment(freq, long_)
        ]

    return np.concatenate(parts)

# ── Main generator ────────────────────────────────────────────────────────────

def generate_sample(idx):
    # Random fundamental frequency (real horns: 300-600 Hz range, buses/trucks: 250-400)
    freq_profile = random.choice([
        "compact",   # 400-600 Hz — small car
        "sedan",     # 350-500 Hz
        "suv",       # 300-450 Hz
        "truck",     # 250-380 Hz
        "bus",       # 260-350 Hz
        "sports",    # 450-700 Hz
    ])

    freq_ranges = {
        "compact": (400, 600),
        "sedan": (350, 500),
        "suv": (300, 450),
        "truck": (250, 380),
        "bus": (260, 350),
        "sports": (450, 700),
    }
    lo, hi = freq_ranges[freq_profile]
    freq = random.uniform(lo, hi)

    # Add slight pitch drift (old/unsealed horn)
    if random.random() < 0.3:
        freq *= random.uniform(0.97, 1.03)

    # Build horn audio
    sig = honk_pattern(freq)

    # Distance simulation (far = quieter + more reverb)
    distance = random.choice(["near", "mid", "far"])
    if distance == "near":
        vol = random.uniform(0.7, 1.0)
        sig = reverb(sig, decay=random.uniform(0.05, 0.15), delay_ms=random.uniform(10, 30))
    elif distance == "mid":
        vol = random.uniform(0.4, 0.7)
        sig = reverb(sig, decay=random.uniform(0.2, 0.4), delay_ms=random.uniform(30, 80))
    else:
        vol = random.uniform(0.1, 0.4)
        sig = reverb(sig, decay=random.uniform(0.4, 0.65), delay_ms=random.uniform(60, 180))
    sig *= vol

    # Doppler (passing car)
    if random.random() < 0.4:
        sig = doppler_shift(sig,
            start_ratio=random.uniform(1.05, 1.2),
            end_ratio=random.uniform(0.85, 0.95))

    # Environmental noise
    noise_type = random.choice(["none", "light_traffic", "crowd", "rain", "parking_garage"])
    snr = random.uniform(12, 30)
    if noise_type != "none":
        sig = add_noise(sig, snr_db=snr)

    # Padding to at least 1 second total
    min_samples = SR  # 1 second
    total_samples = int(SR * random.uniform(1.5, 4.0))
    if len(sig) < total_samples:
        pad = total_samples - len(sig)
        pre = random.randint(0, pad)
        post = pad - pre
        sig = np.concatenate([
            np.zeros(pre, dtype=np.float32),
            sig,
            np.zeros(post, dtype=np.float32),
        ])

    sig = normalize(sig)
    return sig

def main():
    print(f"\n🚗 Generating {N_SAMPLES} diverse car horn samples → {OUTPUT_DIR}/")

    # Remove old synthetic files
    old = list(OUTPUT_DIR.glob("*.wav"))
    print(f"  Removing {len(old)} old car_horn files...")
    for f in old:
        f.unlink()

    for i in range(N_SAMPLES):
        sig = generate_sample(i)
        out_path = OUTPUT_DIR / f"car_horn_synth_{i:04d}.wav"
        save_wav(out_path, sig)
        if (i + 1) % 100 == 0:
            print(f"  [{i+1}/{N_SAMPLES}] Generated")

    print(f"\n✅ Done! {N_SAMPLES} car horn WAV files saved to {OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
