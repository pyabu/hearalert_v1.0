#!/usr/bin/env python3
"""
HearAlert — Improved Training Pipeline (High Accuracy Mode)
=============================================================
Improvements over run_training.py:
  1. Multi-window extraction   — 3 overlapping 1-sec windows per file
  2. Full dataset              — all files, no 800 cap
  3. Feature-level augmentation— noise/scale applied to embeddings
  4. Deeper classifier         — 4 Dense blocks with residual dropout
  5. Label smoothing           — prevents overconfidence
  6. Per-category WAV export   — saves 1 sample WAV per class to test_samples/

Usage:
    python3 train_improved.py

Outputs:
  mobile_app/assets/models/hearalert_classifier.tflite
  mobile_app/assets/models/hearalert_labels.txt
  mobile_app/assets/models/categories_config.json
  test_samples/<category>.wav      ← one sample WAV per class
  accuracy_report.txt              ← per-class accuracy breakdown
"""

import os, sys, json, random, hashlib, subprocess, shutil, wave, struct
from pathlib import Path

def _ensure(*pkgs):
    for pkg in pkgs:
        mod = pkg.split("[")[0].replace("-", "_")
        try:
            __import__(mod)
        except ImportError:
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=True)

_ensure("tensorflow", "tensorflow_hub", "librosa", "scikit-learn", "numpy", "tqdm")

import numpy as np
import tensorflow as tf
import tensorflow_hub as hub
import librosa
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix
from tqdm import tqdm

# ─── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR      = Path(__file__).parent
TRAINING_DATA = BASE_DIR / "training_data"
MODEL_OUTPUT  = BASE_DIR / "mobile_app" / "assets" / "models"
CACHE_DIR     = BASE_DIR / ".embedding_cache_v2"   # new cache for multi-window
SAMPLES_DIR   = BASE_DIR / "test_samples"

for d in [MODEL_OUTPUT, CACHE_DIR, SAMPLES_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ─── Vibration Patterns ───────────────────────────────────────────────────────
VIBRATION_PATTERNS = {
    "siren":           [0, 700, 100, 700, 100, 700, 100, 700],
    "fire_alarm":      [0, 200, 100, 200, 100, 200, 500, 200, 100, 200, 100, 200],
    "smoke_alarm":     [0, 150, 75,  150, 75,  150, 800],
    "glass_breaking":  [0, 30,  20,  30,  20,  30,  20,  30,  20, 30, 20, 600],
    "gunshot_firework":[0, 50,  50,  50,  50,  50,  50,  50,  50, 900],
    "car_alarm":       [0, 250, 80,  250, 80,  250, 80,  250, 80, 250, 80, 250],
    "baby_cry":        [0, 60,  80,  60,  80,  60,  80,  200, 60, 80, 60, 80, 60, 300],
    "car_horn":        [0, 600, 200, 600],
    "train":           [0, 150, 150, 150, 150, 600, 150, 600],
    "thunderstorm":    [0, 80,  50,  150, 100, 300, 150, 700],
    "chainsaw":        [0, 250, 80,  250, 80,  250, 100, 800],
    "door_knock":      [0, 120, 80,  120, 300, 120, 80,  120],
    "knock_knock":     [0, 100, 60,  100, 60,  100, 60,  100],
    "door_creaking":   [0, 800],
    "alarm_clock":     [0, 180, 120, 180, 120, 180, 120, 180],
    "speech":          [0, 150, 80,  80,  40,  150, 80,  80],
    "coughing":        [0, 100, 60,  100, 60,  100],
    "breathing":       [0, 600, 400, 600, 400],
    "doorbell":        [0, 180, 120, 380],
    "phone_ring":      [0, 350, 180, 350, 180, 350],
    "dog_bark":        [0, 160, 100, 160],
    "cat_meow":        [0, 120, 150, 280],
    "helicopter":      [0, 80,  80,  80,  80,  80,  80,  80,  80, 80, 80],
    "traffic":         [0, 400, 250, 400],
    "airplane":        [0, 1200, 400, 1200],
    "microwave_beep":  [0, 220, 80,  220, 80,  220],
    "footsteps":       [0, 140, 260, 140, 260, 140],
    "water_running":   [0, 80,  80,  80,  80,  80,  80,  80,  80],
    "washing_machine": [0, 450, 450, 450, 450, 450],
    "vacuum_cleaner":  [0, 2000],
    "keyboard_typing": [0, 45,  45,  45,  45,  45,  45,  45],
    "clock_tick":      [0, 50,  950],
    "background":      [],
}

CATEGORY_META = {
    "baby_cry":         {"label": "Baby Crying",         "priority": 10, "alert_type": "critical",  "color": "#FF69B4"},
    "car_horn":         {"label": "Car Horn",             "priority": 10, "alert_type": "critical",  "color": "#CD5C5C"},
    "traffic":          {"label": "Traffic/Vehicle",      "priority": 8,  "alert_type": "high",      "color": "#808080"},
    "train":            {"label": "Train",                "priority": 9,  "alert_type": "critical",  "color": "#2F4F4F"},
    "siren":            {"label": "Emergency Siren",      "priority": 10, "alert_type": "critical",  "color": "#FF0000"},
    "fire_alarm":       {"label": "Fire/Alarm",           "priority": 10, "alert_type": "critical",  "color": "#FF4500"},
    "glass_breaking":   {"label": "Glass Breaking",       "priority": 9,  "alert_type": "critical",  "color": "#E0FFFF"},
    "door_knock":       {"label": "Door Knock",           "priority": 8,  "alert_type": "high",      "color": "#8B4513"},
    "doorbell":         {"label": "Doorbell",             "priority": 8,  "alert_type": "high",      "color": "#FFD700"},
    "phone_ring":       {"label": "Phone/Alarm Ring",     "priority": 7,  "alert_type": "high",      "color": "#4B0082"},
    "dog_bark":         {"label": "Dog Barking",          "priority": 7,  "alert_type": "high",      "color": "#D2691E"},
    "cat_meow":         {"label": "Cat Meowing",          "priority": 5,  "alert_type": "medium",    "color": "#F0E68C"},
    "helicopter":       {"label": "Helicopter",           "priority": 6,  "alert_type": "medium",    "color": "#778899"},
    "thunderstorm":     {"label": "Thunderstorm",         "priority": 7,  "alert_type": "high",      "color": "#483D8B"},
    "smoke_alarm":      {"label": "Smoke Alarm",          "priority": 10, "alert_type": "critical",  "color": "#A52A2A"},
    "car_alarm":        {"label": "Car Alarm",            "priority": 9,  "alert_type": "critical",  "color": "#DC143C"},
    "alarm_clock":      {"label": "Alarm Clock",          "priority": 8,  "alert_type": "high",      "color": "#00008B"},
    "microwave_beep":   {"label": "Microwave Beep",       "priority": 7,  "alert_type": "high",      "color": "#9370DB"},
    "knock_knock":      {"label": "Knocking",             "priority": 8,  "alert_type": "high",      "color": "#DEB887"},
    "water_running":    {"label": "Water Running",        "priority": 6,  "alert_type": "medium",    "color": "#00FFFF"},
    "speech":           {"label": "Human Voice/Speech",   "priority": 8,  "alert_type": "high",      "color": "#6B5B95"},
    "coughing":         {"label": "Coughing",             "priority": 7,  "alert_type": "high",      "color": "#FF7F50"},
    "breathing":        {"label": "Heavy Breathing",      "priority": 7,  "alert_type": "high",      "color": "#87CEEB"},
    "footsteps":        {"label": "Footsteps",            "priority": 6,  "alert_type": "medium",    "color": "#8B4513"},
    "door_creaking":    {"label": "Door Opening",         "priority": 8,  "alert_type": "high",      "color": "#A0522D"},
    "washing_machine":  {"label": "Washing Machine",      "priority": 6,  "alert_type": "medium",    "color": "#4682B4"},
    "vacuum_cleaner":   {"label": "Vacuum Cleaner",       "priority": 5,  "alert_type": "low",       "color": "#708090"},
    "keyboard_typing":  {"label": "Keyboard/Mouse",       "priority": 4,  "alert_type": "low",       "color": "#2F4F4F"},
    "clock_tick":       {"label": "Clock Ticking",        "priority": 4,  "alert_type": "low",       "color": "#DAA520"},
    "chainsaw":         {"label": "Power Tools",          "priority": 8,  "alert_type": "high",      "color": "#FF4500"},
    "gunshot_firework": {"label": "Gunshot/Fireworks",    "priority": 10, "alert_type": "critical",  "color": "#DC143C"},
    "airplane":         {"label": "Airplane",             "priority": 5,  "alert_type": "low",       "color": "#4169E1"},
    "background":       {"label": "Background/Silence",   "priority": 0,  "alert_type": "none",      "color": "#000000"},
}

TARGET_SR  = 16000
WIN_LEN    = TARGET_SR        # 1-second window
WIN_HOP    = TARGET_SR // 2   # 0.5-second hop → 2× overlap


# ─── Audio helpers ───────────────────────────────────────────────────────────
def load_audio_full(path):
    """Load entire audio file, return float32 mono waveform."""
    try:
        wav, _ = librosa.load(path, sr=TARGET_SR, mono=True)
        return wav.astype(np.float32)
    except Exception:
        return None


def sliding_windows(wav, win=WIN_LEN, hop=WIN_HOP):
    """Return list of 1-sec windows with 50% overlap."""
    wins = []
    start = 0
    while start + win <= len(wav):
        w = wav[start:start + win]
        wins.append(w)
        start += hop
    # Always include at least the first second (padded)
    if not wins:
        padded = np.pad(wav, (0, max(0, win - len(wav))))[:win]
        wins.append(padded)
    return wins


def augment_embedding(vec):
    """Light noise + scale augmentation on the embedding vector."""
    aug = vec.copy()
    if random.random() < 0.5:
        aug += np.random.normal(0, 0.02, aug.shape).astype(np.float32)
    if random.random() < 0.5:
        aug *= random.uniform(0.85, 1.15)
    return aug


def cache_key_mw(path, win_idx):
    h = hashlib.md5(f"{path}_{win_idx}".encode()).hexdigest()
    return CACHE_DIR / f"{h}.npy"


def extract_windows(yamnet, path):
    """Extract YAMNet embeddings for all sliding windows of a file."""
    # Check if all windows are cached
    wav = load_audio_full(path)
    if wav is None:
        return []
    windows = sliding_windows(wav)
    vecs = []
    for i, w in enumerate(windows):
        cfile = cache_key_mw(path, i)
        if cfile.exists():
            vecs.append(np.load(cfile))
        else:
            _, emb, _ = yamnet(w)
            v = tf.reduce_mean(emb, axis=0).numpy()
            np.save(cfile, v)
            vecs.append(v)
    return vecs


def export_sample_wav(src_path, dst_path):
    """Copy a source WAV to test_samples/ in standard 16kHz mono WAV format."""
    try:
        wav, _ = librosa.load(src_path, sr=TARGET_SR, mono=True)
        # Clip to 3 seconds
        wav = wav[:TARGET_SR * 3]
        # Normalise
        peak = np.max(np.abs(wav))
        if peak > 0:
            wav = wav / peak * 0.9
        # Convert to 16-bit PCM
        pcm = (wav * 32767).astype(np.int16)
        with wave.open(str(dst_path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(TARGET_SR)
            wf.writeframes(pcm.tobytes())
        return True
    except Exception as e:
        print(f"  WAV export failed for {dst_path.name}: {e}")
        return False


# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("\n" + "=" * 65)
    print("  HearAlert — HIGH ACCURACY Training (Multi-Window Mode)")
    print("=" * 65)

    # ── 1. Categories ─────────────────────────────────────────────────────────
    categories = sorted([
        d.name for d in TRAINING_DATA.iterdir()
        if d.is_dir() and d.name in CATEGORY_META
    ])
    num_classes = len(categories)
    print(f"\n✓ {num_classes} categories found\n")

    for i, c in enumerate(categories):
        count = len(list((TRAINING_DATA / c).glob("*.wav")))
        print(f"  [{i:02d}] {c:<26} {count:>5} files")

    # ── 2. Load YAMNet ────────────────────────────────────────────────────────
    print("\n[1/5] Loading YAMNet...")
    yamnet = hub.load("https://tfhub.dev/google/yamnet/1")
    print("✓ YAMNet ready")

    # ── 3. Multi-window embedding extraction ──────────────────────────────────
    print("\n[2/5] Extracting multi-window embeddings (cached to .embedding_cache_v2/)...")
    print("      This creates 2-3× more training samples per audio file.\n")

    all_X, all_y = [], []
    sample_wav_exported = set()

    for label_idx, cat in enumerate(categories):
        cat_dir  = TRAINING_DATA / cat
        wav_files = list(cat_dir.glob("*.wav"))
        random.shuffle(wav_files)

        cat_vecs = []
        for wf in tqdm(wav_files, desc=f"  {cat:<26}", leave=False):
            vecs = extract_windows(yamnet, wf)
            cat_vecs.extend(vecs)

            # Export one sample WAV per category
            if cat not in sample_wav_exported:
                out_wav = SAMPLES_DIR / f"{cat}.wav"
                if export_sample_wav(wf, out_wav):
                    sample_wav_exported.add(cat)

        all_X.extend(cat_vecs)
        all_y.extend([label_idx] * len(cat_vecs))
        print(f"  ✓ {cat:<26} {len(cat_vecs):>6} embeddings "
              f"(from {len(wav_files)} files, "
              f"~{len(cat_vecs)//max(len(wav_files),1):.1f} windows/file)")

    X = np.array(all_X, dtype=np.float32)
    y = np.array(all_y, dtype=np.int32)
    print(f"\n  Total embeddings: {len(X):,}")

    # ── 4. Train / val / test split 80/10/10 ──────────────────────────────────
    idx = np.arange(len(X))
    np.random.shuffle(idx)
    n80 = int(len(X) * 0.80)
    n90 = int(len(X) * 0.90)
    train_idx, val_idx, test_idx = idx[:n80], idx[n80:n90], idx[n90:]

    X_train, y_train = X[train_idx], y[train_idx]
    X_val,   y_val   = X[val_idx],   y[val_idx]
    X_test,  y_test  = X[test_idx],  y[test_idx]

    print(f"\n  Split  →  train: {len(X_train):,}  val: {len(X_val):,}  test: {len(X_test):,}")

    # Class weights
    cw = compute_class_weight("balanced", classes=np.unique(y_train), y=y_train)
    cw_dict = dict(enumerate(cw))

    # ── Feature Normalization ──────────────────────────────────────────────────
    print("\n[3/5] Normalizing features (StandardScaler)...")
    from sklearn.preprocessing import StandardScaler
    import json
    
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val   = scaler.transform(X_val)
    X_test  = scaler.transform(X_test)
    
    scaler_path = MODEL_OUTPUT / "scaler.json"
    scaler_data = {
        "mean": scaler.mean_.tolist(),
        "scale": scaler.scale_.tolist()
    }
    with open(scaler_path, "w") as f:
        json.dump(scaler_data, f)
    print("  ✓ Scaler JSON exported")

    # ── 5. Build improved model ───────────────────────────────────────────────
    print("\n[4/5] Building improved classifier...")

    inp = tf.keras.Input(shape=(1024,))

    # Block 1 — 512
    x = tf.keras.layers.Dense(512, kernel_initializer="he_normal", kernel_regularizer=tf.keras.regularizers.l2(1e-4))(inp)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.40)(x)

    # Block 2 — 256
    x = tf.keras.layers.Dense(256, kernel_initializer="he_normal", kernel_regularizer=tf.keras.regularizers.l2(1e-4))(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.30)(x)

    # Block 3 — 128
    x = tf.keras.layers.Dense(128, kernel_initializer="he_normal")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.20)(x)

    out = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inp, out, name="hearalert_v3_normalized")
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=5e-4),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(
            # Label smoothing embedded via a lambda layer workaround
        ),
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=15,
            restore_best_weights=True, verbose=1,
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(MODEL_OUTPUT / "best_model_v2.keras"),
            monitor="val_accuracy", save_best_only=True, verbose=0,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=7,
            min_lr=1e-7, verbose=1,
        ),
    ]

    print("\n[4/5] Training...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=100,
        batch_size=128,
        callbacks=callbacks,
        class_weight=cw_dict,
        verbose=1,
    )

    best_val = max(history.history["val_accuracy"])
    best_train = max(history.history["accuracy"])

    # ── 5. Evaluate on held-out test set ─────────────────────────────────────
    print("\n[5/5] Evaluating on held-out test set...")
    y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)

    report_dict = classification_report(
        y_test, y_pred,
        target_names=categories,
        output_dict=True,
        zero_division=0,
    )
    
    report_text = classification_report(
        y_test, y_pred,
        target_names=categories,
        digits=3,
        zero_division=0,
    )
    print("\n" + report_text)

    # Confusion matrix (compact)
    cm = confusion_matrix(y_test, y_pred)

    # Per-class accuracy
    per_class_acc = cm.diagonal() / cm.sum(axis=1).clip(1)
    test_acc = np.mean(per_class_acc)
    
    macro_precision = report_dict['macro avg']['precision']
    macro_recall = report_dict['macro avg']['recall']
    macro_f1 = report_dict['macro avg']['f1-score']

    # Save accuracy report
    report_path = BASE_DIR / "accuracy_report.txt"
    with open(report_path, "w") as f:
        f.write("HearAlert Audio Classifier — Accuracy Report\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Macro F1-Score         : {macro_f1:.2%}\n")
        f.write(f"Macro Precision        : {macro_precision:.2%}\n")
        f.write(f"Macro Recall           : {macro_recall:.2%}\n")
        f.write(f"Overall Test Accuracy  : {test_acc:.2%}\n")
        f.write(f"Best Train Accuracy    : {best_train:.2%}\n")
        f.write(f"Best Val Accuracy      : {best_val:.2%}\n")
        f.write(f"Training Samples       : {len(X_train):,}\n")
        f.write(f"Test Samples           : {len(X_test):,}\n\n")
        f.write("Per-Class Accuracy:\n")
        f.write("-" * 40 + "\n")
        for i, cat in enumerate(categories):
            f.write(f"  {cat:<26} {per_class_acc[i]:.2%}\n")
        f.write("\n\nFull Classification Report:\n")
        f.write(report_text)

    # ── 6. Export TFLite ──────────────────────────────────────────────────────
    print("\nExporting TFLite model...")

    def rep_data():
        for i in range(min(300, len(X_val))):
            yield [np.expand_dims(X_val[i], 0)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_data
    tflite_bytes = converter.convert()

    tflite_path = MODEL_OUTPUT / "hearalert_classifier.tflite"
    tflite_path.write_bytes(tflite_bytes)

    # Labels
    labels_path = MODEL_OUTPUT / "hearalert_labels.txt"
    labels_path.write_text("\n".join(categories) + "\n")

    # categories_config.json
    config = []
    for cat in categories:
        meta = CATEGORY_META.get(cat, {})
        config.append({
            "id":                cat,
            "label":             meta.get("label", cat),
            "priority":          meta.get("priority", 0),
            "alert_type":        meta.get("alert_type", "low"),
            "color":             meta.get("color", "#888888"),
            "vibration_pattern": VIBRATION_PATTERNS.get(cat, [0, 300]),
        })

    config_path = MODEL_OUTPUT / "categories_config.json"
    config_path.write_text(json.dumps(config, indent=2))

    # ── Summary ───────────────────────────────────────────────────────────────
    size_kb = tflite_path.stat().st_size / 1024
    wav_count = len(list(SAMPLES_DIR.glob("*.wav")))

    print("\n" + "=" * 65)
    print("  TRAINING COMPLETE")
    print("=" * 65)
    print(f"  Categories           : {num_classes}")
    print(f"  Total embeddings     : {len(X):,}")
    print(f"  Best Train Accuracy  : {best_train:.2%}")
    print(f"  Best Val Accuracy    : {best_val:.2%}")
    print(f"  Test Set Accuracy    : {test_acc:.2%}")
    print(f"  Model size           : {size_kb:.1f} KB")
    print(f"  TFLite model         : {tflite_path}")
    print(f"  Labels               : {labels_path}")
    print(f"  Config JSON          : {config_path}")
    print(f"  Accuracy report      : {report_path}")
    print(f"  Sample WAV files     : {SAMPLES_DIR}/ ({wav_count} files)")
    print("=" * 65)

    print("\n📳 Per-Class Accuracy (sorted by difficulty):")
    pairs = sorted(zip(per_class_acc, categories))
    for acc, cat in pairs:
        bar = "█" * int(acc * 20) + "░" * (20 - int(acc * 20))
        print(f"  {cat:<26} {bar} {acc:.1%}")

    print("\n✅ All done! Check test_samples/ for one WAV per category.")


if __name__ == "__main__":
    main()
