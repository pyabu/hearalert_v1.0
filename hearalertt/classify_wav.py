#!/usr/bin/env python3
"""
HearAlert — WAV File Classifier
================================
Classify any WAV file using the trained HearAlert model.

Usage:
    python3 classify_wav.py <path_to_audio.wav>
    python3 classify_wav.py test_samples/baby_cry.wav
    python3 classify_wav.py /path/to/any/audio.mp3   # also works with mp3/m4a/etc

Output:
    ┌─────────────────────────────────┐
    │  #1  Baby Crying       87.3%    │
    │  #2  Coughing           5.1%    │
    │  #3  Breathing          3.2%    │
    └─────────────────────────────────┘
    Vibration: [0, 60, 80, 60, 80, 60, 80, 200]
    Alert Type: critical
"""

import sys, json
from pathlib import Path

BASE_DIR     = Path(__file__).parent
MODEL_OUTPUT = BASE_DIR / "mobile_app" / "assets" / "models"
TFLITE_PATH  = MODEL_OUTPUT / "hearalert_classifier.tflite"
LABELS_PATH  = MODEL_OUTPUT / "hearalert_labels.txt"
CONFIG_PATH  = MODEL_OUTPUT / "categories_config.json"

TARGET_SR = 16000
WIN_LEN   = TARGET_SR


def classify(audio_path: str):
    try:
        import numpy as np
        import librosa
        import tensorflow as tf
        import tensorflow_hub as hub
    except ImportError:
        import subprocess
        subprocess.run([sys.executable, "-m", "pip", "install",
                        "tensorflow", "tensorflow_hub", "librosa", "numpy", "-q"])
        import numpy as np, librosa, tensorflow as tf, tensorflow_hub as hub

    audio_path = Path(audio_path)
    if not audio_path.exists():
        print(f"\n❌  File not found: {audio_path}")
        sys.exit(1)

    # ── Load labels & config ──────────────────────────────────────────────────
    if not TFLITE_PATH.exists():
        print(f"\n❌  Model not found at {TFLITE_PATH}")
        print("    Run:  python3 train_improved.py")
        sys.exit(1)

    labels = LABELS_PATH.read_text().strip().splitlines()

    config_map = {}
    if CONFIG_PATH.exists():
        for entry in json.loads(CONFIG_PATH.read_text()):
            config_map[entry["id"]] = entry

    # ── Load audio ───────────────────────────────────────────────────────────
    print(f"\n🎵  Analysing: {audio_path.name}")
    wav, _ = librosa.load(str(audio_path), sr=TARGET_SR, mono=True)

    # ── YAMNet embeddings ────────────────────────────────────────────────────
    print("    Extracting audio features...")
    yamnet = hub.load("https://tfhub.dev/google/yamnet/1")

    # Slide over the file with 50% overlap, collect all window embeddings
    hop = WIN_LEN // 2
    embeddings = []
    start = 0
    while start + WIN_LEN <= len(wav):
        window = wav[start: start + WIN_LEN]
        _, emb, _ = yamnet(window)
        embeddings.append(tf.reduce_mean(emb, axis=0).numpy())
        start += hop

    if not embeddings:
        # File shorter than 1 second — pad and classify once
        padded = np.pad(wav, (0, WIN_LEN - len(wav))).astype(np.float32)
        _, emb, _ = yamnet(padded)
        embeddings = [tf.reduce_mean(emb, axis=0).numpy()]

    embeddings = np.array(embeddings, dtype=np.float32)  # (N, 1024)

    # ── TFLite inference ─────────────────────────────────────────────────────
    interp = tf.lite.Interpreter(model_path=str(TFLITE_PATH))
    interp.allocate_tensors()
    inp_det  = interp.get_input_details()[0]
    out_det  = interp.get_output_details()[0]

    probs_all = []
    for emb_vec in embeddings:
        inp_data = np.expand_dims(emb_vec, 0)
        interp.set_tensor(inp_det["index"], inp_data)
        interp.invoke()
        probs_all.append(interp.get_tensor(out_det["index"])[0])

    # Average predictions across all windows (voting ensemble)
    avg_probs = np.mean(probs_all, axis=0)

    # Top-5
    top5_idx = np.argsort(avg_probs)[::-1][:5]

    # ── Print results ─────────────────────────────────────────────────────────
    top_label = labels[top5_idx[0]]
    top_meta  = config_map.get(top_label, {})

    print("\n  ┌" + "─" * 45 + "┐")
    for rank, idx in enumerate(top5_idx, 1):
        lbl  = labels[idx]
        prob = avg_probs[idx]
        meta = config_map.get(lbl, {})
        disp = meta.get("label", lbl)
        bar  = "█" * int(prob * 20)
        marker = " ◀ TOP MATCH" if rank == 1 else ""
        print(f"  │  #{rank}  {disp:<24} {prob:>6.1%}  │{marker}")
    print("  └" + "─" * 45 + "┘")

    vib  = top_meta.get("vibration_pattern", [])
    atype = top_meta.get("alert_type", "unknown")
    color = top_meta.get("color", "")
    prio  = top_meta.get("priority", 0)

    print(f"\n  📳  Vibration  : {vib}")
    print(f"  🚨  Alert Type : {atype}  (priority {prio})")
    print(f"  🎨  Color      : {color}")
    print(f"\n  🔊  Classified as: {top_meta.get('label', top_label)} "
          f"(confidence {avg_probs[top5_idx[0]]:.1%})")

    return {
        "prediction": top_label,
        "label": top_meta.get("label", top_label),
        "confidence": float(avg_probs[top5_idx[0]]),
        "alert_type": atype,
        "vibration_pattern": vib,
        "top5": [
            {"label": labels[i], "confidence": float(avg_probs[i])}
            for i in top5_idx
        ],
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        print(f"\nAvailable test samples:")
        samples = sorted(Path(BASE_DIR / "test_samples").glob("*.wav"))
        for s in samples:
            print(f"  python3 classify_wav.py test_samples/{s.name}")
        sys.exit(0)

    result = classify(sys.argv[1])
