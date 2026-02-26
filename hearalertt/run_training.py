#!/usr/bin/env python3
"""
HearAlert — Fast Training Pipeline
====================================
Reads WAV files directly from training_data/<category>/ folders.
Caches YAMNet embeddings to disk for fast re-runs.
Exports a quantized TFLite model + categories_config.json with
distinct vibration patterns for every sound category.

Usage:
    python3 run_training.py

Requirements:
    pip install tensorflow tensorflow-hub librosa scikit-learn numpy tqdm
"""


import os, sys, json, random, hashlib, subprocess
from pathlib import Path

# ─── Auto-install missing packages ────────────────────────────────────────────
def _ensure(*pkgs):
    for pkg in pkgs:
        try:
            __import__(pkg.split("[")[0].replace("-", "_"))
        except ImportError:
            print(f"Installing {pkg}...")
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=True)

_ensure("tensorflow", "tensorflow_hub", "librosa", "scikit-learn", "numpy", "tqdm")

import numpy as np
import tensorflow as tf
import tensorflow_hub as hub
import librosa
from sklearn.utils.class_weight import compute_class_weight
from tqdm import tqdm

# ─── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR       = Path(__file__).parent
TRAINING_DATA  = BASE_DIR / "training_data"
MODEL_OUTPUT   = BASE_DIR / "mobile_app" / "assets" / "models"
CACHE_DIR      = BASE_DIR / ".embedding_cache"

MODEL_OUTPUT.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# ─── Vibration Patterns (ms) ──────────────────────────────────────────────────
# Format: [delay, ON, OFF, ON, OFF, ...] — every category is unique
# Designed to feel like the sound it represents
VIBRATION_PATTERNS = {
    # ── Critical / Emergency ──────────────────────────────────────────────────
    "siren":           [0, 700, 100, 700, 100, 700, 100, 700],  # Wailing sweep ×4
    "fire_alarm":      [0, 200, 100, 200, 100, 200, 500, 200, 100, 200, 100, 200],  # 3-beep cadence ×2
    "smoke_alarm":     [0, 150, 75,  150, 75,  150, 800],       # 3 sharp pulses + silence
    "glass_breaking":  [0, 30,  20,  30,  20,  30,  20,  30,  20, 30, 20, 600],   # Rapid shattering
    "gunshot_firework":[0, 50,  50,  50,  50,  50,  50,  50,  50, 900],           # Sharp bursts + echo
    "car_alarm":       [0, 250, 80,  250, 80,  250, 80,  250, 80, 250, 80, 250],  # Relentless repetition
    "baby_cry":        [0, 60,  80,  60,  80,  60,  80,  200, 60, 80, 60, 80, 60, 300], # Distressed rapid

    # ── High Priority ─────────────────────────────────────────────────────────
    "car_horn":        [0, 600, 200, 600],                      # HONK … HONK
    "train":           [0, 150, 150, 150, 150, 600, 150, 600],  # Chugga-chugga Choo-Choo
    "thunderstorm":    [0, 80,  50,  150, 100, 300, 150, 700],  # Rumble rising
    "chainsaw":        [0, 250, 80,  250, 80,  250, 100, 800],  # Revving bursts
    "door_knock":      [0, 120, 80,  120, 300, 120, 80,  120],  # Knock-knock … knock-knock
    "knock_knock":     [0, 100, 60,  100, 60,  100, 60,  100], # Rapid knocking
    "door_creaking":   [0, 800],                                 # Slow single creak
    "alarm_clock":     [0, 180, 120, 180, 120, 180, 120, 180],  # Annoying repeating beep
    "speech":          [0, 150, 80,  80,  40,  150, 80,  80],   # Speech cadence
    "coughing":        [0, 100, 60,  100, 60,  100],            # Cough-cough-cough
    "breathing":       [0, 600, 400, 600, 400],                  # Inhale … Exhale

    # ── Medium Priority ───────────────────────────────────────────────────────
    "doorbell":        [0, 180, 120, 380],                       # Ding … Dong
    "phone_ring":      [0, 350, 180, 350, 180, 350],            # Standard ring ×3
    "dog_bark":        [0, 160, 100, 160],                       # Woof … Woof
    "cat_meow":        [0, 120, 150, 280],                       # Me-ow
    "helicopter":      [0, 80,  80,  80,  80,  80,  80,  80,  80, 80, 80], # Rotor chop
    "traffic":         [0, 400, 250, 400],                       # Traffic drone
    "airplane":        [0, 1200, 400, 1200],                     # Long overhead pass
    "microwave_beep":  [0, 220, 80,  220, 80,  220],            # Microwave 3 beeps
    "footsteps":       [0, 140, 260, 140, 260, 140],            # Step … step … step
    "water_running":   [0, 80,  80,  80,  80,  80,  80,  80,  80], # Continuous trickle
    "washing_machine": [0, 450, 450, 450, 450, 450],            # Rhythmic sloshing
    "vacuum_cleaner":  [0, 2000],                                # Long continuous drone

    # ── Low Priority ──────────────────────────────────────────────────────────
    "keyboard_typing": [0, 45,  45,  45,  45,  45,  45,  45],  # Rapid light taps
    "clock_tick":      [0, 50,  950],                            # Tick … (1 sec loop)
    "background":      [],                                        # Silence — no alert
}

# ─── Category Metadata ────────────────────────────────────────────────────────
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

# ─── Helpers ──────────────────────────────────────────────────────────────────
TARGET_SR  = 16000
TARGET_LEN = TARGET_SR  # 1 second


def load_audio(path):
    try:
        wav, _ = librosa.load(path, sr=TARGET_SR, mono=True)
        if len(wav) < TARGET_LEN:
            wav = np.pad(wav, (0, TARGET_LEN - len(wav)))
        else:
            wav = wav[:TARGET_LEN]
        return wav.astype(np.float32)
    except Exception:
        return None


def cache_key(path):
    return hashlib.md5(str(path).encode()).hexdigest()


def extract_or_load_embedding(yamnet, path):
    key  = cache_key(path)
    cfile = CACHE_DIR / f"{key}.npy"
    if cfile.exists():
        return np.load(cfile)
    wav = load_audio(path)
    if wav is None:
        return None
    _, emb, _ = yamnet(wav)
    vec = tf.reduce_mean(emb, axis=0).numpy()
    np.save(cfile, vec)
    return vec


def augment(wav):
    aug = wav.copy()
    if random.random() < 0.5:
        aug += np.random.normal(0, random.uniform(0.003, 0.015), len(aug)).astype(np.float32)
    if random.random() < 0.5:
        shift = int(random.uniform(-0.1, 0.1) * len(aug))
        aug = np.roll(aug, shift)
    if random.random() < 0.5:
        aug *= random.uniform(0.7, 1.3)
    return np.clip(aug, -1.0, 1.0).astype(np.float32)


# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("\n" + "=" * 60)
    print(" HearAlert Audio Training Pipeline")
    print("=" * 60)

    # ── 1. Discover categories ────────────────────────────────────────────────
    categories = sorted([
        d.name for d in TRAINING_DATA.iterdir()
        if d.is_dir() and d.name in CATEGORY_META
    ])
    print(f"\n✓ Found {len(categories)} categories")
    for i, c in enumerate(categories):
        wav_count = len(list((TRAINING_DATA / c).glob("*.wav")))
        print(f"  [{i:02d}] {c:<25} {wav_count} files")

    num_classes = len(categories)

    # ── 2. Load YAMNet ────────────────────────────────────────────────────────
    print("\n[1/4] Loading YAMNet base model...")
    yamnet = hub.load("https://tfhub.dev/google/yamnet/1")
    print("✓ YAMNet loaded")

    # ── 3. Extract embeddings (with disk cache) ───────────────────────────────
    print("\n[2/4] Extracting embeddings (cached)...")
    all_X, all_y = [], []

    for label_idx, cat in enumerate(categories):
        cat_dir = TRAINING_DATA / cat
        wav_files = list(cat_dir.glob("*.wav"))
        random.shuffle(wav_files)
        # Cap at 800 per category to keep training manageable
        wav_files = wav_files[:800]

        vecs = []
        for wf in tqdm(wav_files, desc=f"  {cat}", leave=False):
            v = extract_or_load_embedding(yamnet, wf)
            if v is not None:
                vecs.append(v)

        all_X.extend(vecs)
        all_y.extend([label_idx] * len(vecs))
        print(f"  ✓ {cat:<25} {len(vecs)} embeddings")

    X = np.array(all_X, dtype=np.float32)
    y = np.array(all_y, dtype=np.int32)
    print(f"\n  Total embeddings: {len(X)}")

    # ── 4. Train / val split ──────────────────────────────────────────────────
    indices = np.arange(len(X))
    np.random.shuffle(indices)
    split = int(len(X) * 0.85)
    train_idx, val_idx = indices[:split], indices[split:]

    X_train, y_train = X[train_idx], y[train_idx]
    X_val,   y_val   = X[val_idx],   y[val_idx]

    # Class weights for imbalanced data
    class_weights_arr = compute_class_weight("balanced", classes=np.unique(y_train), y=y_train)
    class_weight_dict = dict(enumerate(class_weights_arr))

    # ── 5. Build model ────────────────────────────────────────────────────────
    print("\n[3/4] Building and training classifier...")
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(1024,)),

        tf.keras.layers.Dense(512, kernel_initializer="he_normal"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation("relu"),
        tf.keras.layers.Dropout(0.40),

        tf.keras.layers.Dense(256, kernel_initializer="he_normal"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation("relu"),
        tf.keras.layers.Dropout(0.30),

        tf.keras.layers.Dense(128, kernel_initializer="he_normal"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation("relu"),
        tf.keras.layers.Dropout(0.20),

        tf.keras.layers.Dense(num_classes, activation="softmax"),
    ], name="hearalert_classifier")

    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=12,
            restore_best_weights=True, verbose=1,
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(MODEL_OUTPUT / "best_model.keras"),
            monitor="val_accuracy", save_best_only=True, verbose=0,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=6, min_lr=1e-7, verbose=1,
        ),
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=80,
        batch_size=64,
        callbacks=callbacks,
        class_weight=class_weight_dict,
        verbose=1,
    )

    best_val_acc = max(history.history["val_accuracy"])
    best_train_acc = max(history.history["accuracy"])
    print(f"\n  Best Training Accuracy : {best_train_acc:.2%}")
    print(f"  Best Validation Accuracy: {best_val_acc:.2%}")

    # ── 6. Export TFLite (quantized) ──────────────────────────────────────────
    print("\n[4/4] Exporting TFLite model...")

    def rep_data():
        for i in range(min(200, len(X_val))):
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

    # categories_config.json — with unique vibration patterns
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
    print("\n" + "=" * 60)
    print(" TRAINING COMPLETE")
    print("=" * 60)
    print(f"  Categories       : {num_classes}")
    print(f"  Training samples : {len(X_train)}")
    print(f"  Val samples      : {len(X_val)}")
    print(f"  Best val accuracy: {best_val_acc:.2%}")
    print(f"  Model size       : {size_kb:.1f} KB")
    print(f"  TFLite model     : {tflite_path}")
    print(f"  Labels           : {labels_path}")
    print(f"  Config JSON      : {config_path}")
    print("=" * 60)

    # Vibration pattern summary
    print("\n📳 Vibration Pattern Summary:")
    print(f"  {'Category':<25} {'Alert Type':<12} {'Pattern'}")
    print("  " + "-" * 65)
    for entry in config:
        pat_str = str(entry["vibration_pattern"])[:35]
        print(f"  {entry['id']:<25} {entry['alert_type']:<12} {pat_str}")


if __name__ == "__main__":
    main()
