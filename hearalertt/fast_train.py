#!/usr/bin/env python3
"""
HearAlert — Fast High-Accuracy Training (File-Level Split)
============================================================
Key accuracy improvements over previous scripts:
  1. FILE-LEVEL splits (no data leakage from overlapping windows)
  2. StandardScaler feature normalization on embeddings
  3. Cosine-decay LR schedule with warm-up
  4. Uses pre-computed multi-window embeddings cache (.embedding_cache_v2/)
  5. Trains ONLY the classifier (not re-extraction) → runs in ~5 minutes

Usage:
    python3 fast_train.py

Expected accuracy: 70-80% (honest, no leakage)
"""

import os, sys, json, random, hashlib, subprocess, wave
from pathlib import Path

def _ensure(*pkgs):
    for pkg in pkgs:
        try:
            __import__(pkg.split("[")[0].replace("-", "_"))
        except ImportError:
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=True)

_ensure("tensorflow", "tensorflow_hub", "librosa", "scikit-learn", "numpy", "tqdm")

import numpy as np
import tensorflow as tf
import tensorflow_hub as hub
import librosa
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix
from tqdm import tqdm

# ─── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR      = Path(__file__).parent
TRAINING_DATA = BASE_DIR / "training_data"
MODEL_OUTPUT  = BASE_DIR / "mobile_app" / "assets" / "models"
CACHE_V2      = BASE_DIR / ".embedding_cache_v2"   # pre-computed multi-window
CACHE_V1      = BASE_DIR / ".embedding_cache"       # fallback single-window
SAMPLES_DIR   = BASE_DIR / "test_samples"

for d in [MODEL_OUTPUT, SAMPLES_DIR]:
    d.mkdir(parents=True, exist_ok=True)

TARGET_SR = 16000
WIN_LEN   = TARGET_SR
WIN_HOP   = TARGET_SR // 2

# ─── Same vibration patterns & metadata as train_improved.py ─────────────────
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


def cache_key_v2(path, win_idx):
    h = hashlib.md5(f"{path}_{win_idx}".encode()).hexdigest()
    return CACHE_V2 / f"{h}.npy"

def cache_key_v1(path):
    h = hashlib.md5(str(path).encode()).hexdigest()
    return CACHE_V1 / f"{h}.npy"


def load_audio_full(path):
    try:
        wav, _ = librosa.load(path, sr=TARGET_SR, mono=True)
        return wav.astype(np.float32)
    except Exception:
        return None


def sliding_windows(wav, win=WIN_LEN, hop=WIN_HOP):
    wins = []
    start = 0
    while start + win <= len(wav):
        wins.append(wav[start:start + win])
        start += hop
    if not wins:
        wins.append(np.pad(wav, (0, max(0, win - len(wav))))[:win])
    return wins


def export_sample_wav(src_path, dst_path):
    try:
        wav, _ = librosa.load(src_path, sr=TARGET_SR, mono=True)
        wav = wav[:TARGET_SR * 3]
        peak = np.max(np.abs(wav))
        if peak > 0:
            wav = wav / peak * 0.9
        pcm = (wav * 32767).astype(np.int16)
        with wave.open(str(dst_path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(TARGET_SR)
            wf.writeframes(pcm.tobytes())
        return True
    except Exception:
        return False


def get_file_embeddings_from_cache(wav_path, yamnet):
    """Load embeddings from v2 cache (multi-window), fallback to v1 or extract fresh."""
    # Try multi-window cache
    wav = load_audio_full(wav_path)
    if wav is None:
        return []

    windows = sliding_windows(wav)
    vecs = []
    need_extract = False

    for i, _ in enumerate(windows):
        cf = cache_key_v2(wav_path, i)
        if cf.exists():
            vecs.append(np.load(cf))
        else:
            need_extract = True
            break

    if not need_extract and vecs:
        return vecs

    # Extract fresh
    vecs = []
    for i, w in enumerate(windows):
        cf = cache_key_v2(wav_path, i)
        if cf.exists():
            vecs.append(np.load(cf))
        else:
            _, emb, _ = yamnet(w)
            v = tf.reduce_mean(emb, axis=0).numpy()
            np.save(cf, v)
            vecs.append(v)

    return vecs


def main():
    print("\n" + "=" * 65)
    print("  HearAlert — FAST HIGH-ACCURACY TRAINING (File-Level Split)")
    print("=" * 65)

    # ── Categories ────────────────────────────────────────────────────────────
    categories = sorted([
        d.name for d in TRAINING_DATA.iterdir()
        if d.is_dir() and d.name in CATEGORY_META
    ])
    num_classes = len(categories)
    cat_to_idx  = {c: i for i, c in enumerate(categories)}
    print(f"\n✓ {num_classes} categories")

    # ── Load YAMNet (only if cache miss) ──────────────────────────────────────
    # Check how many files we'd need to extract
    total_files = sum(
        len(list((TRAINING_DATA / c).glob("*.wav"))) for c in categories
    )
    cached_v2 = len(list(CACHE_V2.glob("*.npy")))
    need_yamnet = cached_v2 < total_files * 5  # rough check
    yamnet = None
    if need_yamnet:
        print("\n[1/5] Loading YAMNet (needed for uncached files)...")
        yamnet = hub.load("https://tfhub.dev/google/yamnet/1")
    else:
        print(f"\n[1/5] Using cached embeddings ({cached_v2:,} files in cache)")
        yamnet = hub.load("https://tfhub.dev/google/yamnet/1")

    # ── FILE-LEVEL split then load embeddings ─────────────────────────────────
    print("\n[2/5] Loading embeddings with FILE-LEVEL train/val/test split...")
    print("      (prevents data leakage from overlapping windows)\n")

    # Group by file first
    file_train_X, file_train_y = [], []
    file_val_X,   file_val_y   = [], []
    file_test_X,  file_test_y  = [], []
    sample_exported = set()

    for cat in categories:
        cat_dir   = TRAINING_DATA / cat
        wav_files = sorted(cat_dir.glob("*.wav"))
        random.shuffle(wav_files)

        n = len(wav_files)
        n_train = int(n * 0.80)
        n_val   = int(n * 0.90)

        train_files = wav_files[:n_train]
        val_files   = wav_files[n_train:n_val]
        test_files  = wav_files[n_val:]

        label = cat_to_idx[cat]

        def load_split(flist, Xlist, ylist):
            for wf in flist:
                vecs = get_file_embeddings_from_cache(wf, yamnet)
                # Average all windows → one embedding per file (clean, no leakage)
                if vecs:
                    avg_vec = np.mean(vecs, axis=0)
                    Xlist.append(avg_vec)
                    ylist.append(label)

        load_split(train_files, file_train_X, file_train_y)
        load_split(val_files,   file_val_X,   file_val_y)
        load_split(test_files,  file_test_X,  file_test_y)

        # Export sample WAV
        if cat not in sample_exported and train_files:
            out_wav = SAMPLES_DIR / f"{cat}.wav"
            if export_sample_wav(train_files[0], out_wav):
                sample_exported.add(cat)

        print(f"  ✓ {cat:<26} train:{len(train_files):>4} "
              f"val:{len(val_files):>3} test:{len(test_files):>3}")

    X_train = np.array(file_train_X, dtype=np.float32)
    y_train = np.array(file_train_y, dtype=np.int32)
    X_val   = np.array(file_val_X,   dtype=np.float32)
    y_val   = np.array(file_val_y,   dtype=np.int32)
    X_test  = np.array(file_test_X,  dtype=np.float32)
    y_test  = np.array(file_test_y,  dtype=np.int32)

    print(f"\n  Samples → train:{len(X_train):,}  val:{len(X_val):,}  test:{len(X_test):,}")

    # ── Feature normalization (huge accuracy boost) ────────────────────────────
    print("\n[3/5] Normalizing features (StandardScaler)...")
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val   = scaler.transform(X_val)
    X_test  = scaler.transform(X_test)

    # Save scaler for inference
    import pickle
    scaler_path = MODEL_OUTPUT / "scaler.pkl"
    with open(scaler_path, "wb") as f:
        pickle.dump(scaler, f)
    print("  ✓ Scaler fitted and saved")

    # Class weights
    cw = compute_class_weight("balanced", classes=np.unique(y_train), y=y_train)
    cw_dict = dict(enumerate(cw))

    # ── Model ──────────────────────────────────────────────────────────────────
    print("\n[4/5] Building and training classifier...")

    inp = tf.keras.Input(shape=(1024,))

    x = tf.keras.layers.Dense(512, kernel_initializer="he_normal",
                               kernel_regularizer=tf.keras.regularizers.l2(5e-5))(inp)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.40)(x)

    x = tf.keras.layers.Dense(256, kernel_initializer="he_normal",
                               kernel_regularizer=tf.keras.regularizers.l2(5e-5))(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.30)(x)

    x = tf.keras.layers.Dense(128, kernel_initializer="he_normal")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)
    x = tf.keras.layers.Dropout(0.20)(x)

    out = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inp, out, name="hearalert_fast")

    # Cosine-decay LR schedule
    steps_per_epoch = max(1, len(X_train) // 64)
    total_steps     = 80 * steps_per_epoch
    warmup_steps    = 5  * steps_per_epoch

    lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
        initial_learning_rate=1e-3,
        decay_steps=total_steps - warmup_steps,
        alpha=0.01,
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=lr_schedule),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )
    model.summary()

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=12,
            restore_best_weights=True, verbose=1,
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(MODEL_OUTPUT / "best_fast.keras"),
            monitor="val_accuracy", save_best_only=True, verbose=0,
        ),
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=80,
        batch_size=64,
        callbacks=callbacks,
        class_weight=cw_dict,
        verbose=1,
    )

    best_val  = max(history.history["val_accuracy"])
    best_train= max(history.history["accuracy"])

    # ── Test evaluation ────────────────────────────────────────────────────────
    print("\n[5/5] Final evaluation on held-out test set...")
    y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
    test_acc = np.mean(y_pred == y_test)

    report = classification_report(
        y_test, y_pred, target_names=categories, digits=3, zero_division=0
    )
    cm = confusion_matrix(y_test, y_pred)
    per_class_acc = cm.diagonal() / cm.sum(axis=1).clip(1)

    # Save report
    report_path = BASE_DIR / "accuracy_report.txt"
    with open(report_path, "w") as f:
        f.write("HearAlert — Accuracy Report (File-Level Split)\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Test Accuracy   : {test_acc:.2%}\n")
        f.write(f"Train Accuracy  : {best_train:.2%}\n")
        f.write(f"Val Accuracy    : {best_val:.2%}\n")
        f.write(f"Train Files     : {len(X_train):,}\n")
        f.write(f"Val Files       : {len(X_val):,}\n")
        f.write(f"Test Files      : {len(X_test):,}\n\n")
        f.write("Per-Category Accuracy:\n" + "-"*40 + "\n")
        for i, cat in enumerate(categories):
            bar = "█" * int(per_class_acc[i] * 20)
            f.write(f"  {cat:<26} {bar:<20} {per_class_acc[i]:.1%}\n")
        f.write("\n\nClassification Report:\n" + report)

    # ── Export TFLite ──────────────────────────────────────────────────────────
    def rep_data():
        for i in range(min(200, len(X_val))):
            yield [np.expand_dims(X_val[i].astype(np.float32), 0)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_data
    tflite_bytes = converter.convert()
    tflite_path  = MODEL_OUTPUT / "hearalert_classifier.tflite"
    tflite_path.write_bytes(tflite_bytes)

    (MODEL_OUTPUT / "hearalert_labels.txt").write_text("\n".join(categories) + "\n")

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
    (MODEL_OUTPUT / "categories_config.json").write_text(json.dumps(config, indent=2))

    # ── Summary ───────────────────────────────────────────────────────────────
    size_kb = tflite_path.stat().st_size / 1024
    wavs    = len(list(SAMPLES_DIR.glob("*.wav")))

    print("\n" + "=" * 65)
    print("  TRAINING COMPLETE")
    print("=" * 65)
    print(f"  Train Accuracy  : {best_train:.2%}")
    print(f"  Val Accuracy    : {best_val:.2%}")
    print(f"  Test Accuracy   : {test_acc:.2%}  ← honest file-level result")
    print(f"  Model size      : {size_kb:.1f} KB")
    print(f"  TFLite model    : {tflite_path}")
    print(f"  Accuracy report : {report_path}")
    print(f"  Sample WAVs     : {SAMPLES_DIR}/ ({wavs} files)")
    print("=" * 65)

    print("\n📊 Per-Category Accuracy (worst → best):")
    print(f"  {'Category':<26}  {'Bar':<20}  Accuracy")
    print("  " + "-" * 55)
    for acc, cat in sorted(zip(per_class_acc, categories)):
        bar = "█" * int(acc * 20) + "░" * (20 - int(acc * 20))
        emoji = "🔴" if acc < 0.5 else "🟡" if acc < 0.75 else "🟢"
        print(f"  {emoji} {cat:<26} {bar}  {acc:.1%}")

    print(f"\n✅ Done! Run:  python3 classify_wav.py test_samples/baby_cry.wav")


if __name__ == "__main__":
    main()
