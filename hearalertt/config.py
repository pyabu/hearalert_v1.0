"""
HearAlert Configuration
=======================
Centralized configuration for HearAlert project.
Contains paths, category definitions, and constants.
"""

from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
RAW_DIR = BASE_DIR / "raw"
DATASETS_DIR = BASE_DIR / "datasets"
ESC50_DIR = DATASETS_DIR / "ESC-50"
PROCESSED_DIR = BASE_DIR / "training_data"
TRAINING_DATA_DIR = PROCESSED_DIR
OUTPUT_DIR = BASE_DIR / "mobile_app" / "assets" / "datasets"
MODEL_OUTPUT = BASE_DIR / "mobile_app" / "assets" / "models"
AUGMENTED_DIR = BASE_DIR / "augmented_audio"
EXPANDED_DIR = BASE_DIR / "expanded_audio"
NEW_AUDIO_DIR = BASE_DIR / "realtime_audio"
OPTIMIZED_DIR = BASE_DIR / "datasets_optimized"
JSON_CONFIG_PATH = MODEL_OUTPUT / "categories_config.json"
DATASET_REPORT_PATH = BASE_DIR / "dataset_report.xlsx"

# ESC-50 class to folder/filename mapping
ESC50_CLASSES = {
    "dog": 0, "rooster": 1, "pig": 2, "cow": 3, "frog": 4,
    "cat": 5, "hen": 6, "insects": 7, "sheep": 8, "crow": 9,
    "rain": 10, "sea_waves": 11, "crackling_fire": 12, "crickets": 13, "chirping_birds": 14,
    "water_drops": 15, "wind": 16, "pouring_water": 17, "toilet_flush": 18, "thunderstorm": 19,
    "crying_baby": 20, "sneezing": 21, "clapping": 22, "breathing": 23, "coughing": 24,
    "footsteps": 25, "laughing": 26, "brushing_teeth": 27, "snoring": 28, "drinking_sipping": 29,
    "door_wood_knock": 30, "mouse_click": 31, "keyboard_typing": 32, "door_wood_creaks": 33, "can_opening": 34,
    "washing_machine": 35, "vacuum_cleaner": 36, "clock_alarm": 37, "clock_tick": 38, "glass_breaking": 39,
    "helicopter": 40, "chainsaw": 41, "siren": 42, "car_horn": 43, "engine": 44,
    "train": 45, "church_bells": 46, "airplane": 47, "fireworks": 48, "hand_saw": 49
}

# Training Categories
# Merged from train_audio_model.py and download_realtime_datasets.py
TRAINING_CATEGORIES = {
    # ═══════════════════════════════════════════════════════════════════
    # BABY SOUNDS - High Priority for Parents
    # ═══════════════════════════════════════════════════════════════════
    "baby_cry": {
        "sources": ["belly_pain", "burping", "cold_hot", "discomfort", "hungry", "tired"],
        "esc50_classes": ["crying_baby"],
        "display_name": "Baby Crying",
        "priority": 10,
        "alert_type": "critical",
        "color": "#FF69B4",
        "vibration_pattern": [0, 50, 100, 50, 100, 50, 200, 50]  # Rapid heartbeat style
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # TRAFFIC & VEHICLE SOUNDS - Critical for Deaf Safety
    # ═══════════════════════════════════════════════════════════════════
    "car_horn": {
        "esc50_classes": ["car_horn"],
        "display_name": "Car Horn",
        "priority": 10,
        "alert_type": "critical",
        "color": "#CD5C5C",
        "vibration_pattern": [0, 800, 200, 800]  # Long blasts
    },
    "traffic": {
        "esc50_classes": ["engine", "car_horn"],
        "display_name": "Traffic/Vehicle",
        "priority": 8,
        "alert_type": "high",
        "color": "#808080",
        "vibration_pattern": [0, 500, 300, 500]  # Generic traffic drone
    },
    "train": {
        "esc50_classes": ["train"],
        "display_name": "Train",
        "priority": 9,
        "alert_type": "critical",
        "color": "#2F4F4F",
        "vibration_pattern": [0, 200, 200, 800, 200, 800]  # Chugga-chugga Choo-Choo
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # EMERGENCY SOUNDS - Life Safety
    # ═══════════════════════════════════════════════════════════════════
    "siren": {
        "esc50_classes": ["siren"],
        "display_name": "Emergency Siren",
        "priority": 10,
        "alert_type": "critical",
        "color": "#FF0000",
        "vibration_pattern": [0, 1000, 0, 1000, 0, 1000]  # Long wailing
    },
    "fire_alarm": {
        "esc50_classes": ["fireworks", "crackling_fire"],
        "display_name": "Fire/Alarm",
        "priority": 10,
        "alert_type": "critical",
        "color": "#FF4500",
        "vibration_pattern": [0, 500, 100, 500, 100, 500, 100, 500]  # Standard alarm cadence
    },
    "glass_breaking": {
        "esc50_classes": ["glass_breaking"],
        "display_name": "Glass Breaking",
        "priority": 9,
        "alert_type": "critical",
        "color": "#E0FFFF",
        "vibration_pattern": [0, 30, 30, 30, 30, 30, 30, 30, 30, 500]  # Shattering feel
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # HOME SOUNDS - Daily Alerts
    # ═══════════════════════════════════════════════════════════════════
    "door_knock": {
        "esc50_classes": ["door_wood_knock", "door_wood_creaks"],
        "display_name": "Door Knock",
        "priority": 8,
        "alert_type": "high",
        "color": "#8B4513",
        "vibration_pattern": [0, 100, 50, 100, 300, 100, 50, 100]  # Knock-knock ... knock-knock
    },
    "doorbell": {
        "esc50_classes": ["church_bells"],  # Similar bell sound
        "display_name": "Doorbell",
        "priority": 8,
        "alert_type": "high",
        "color": "#FFD700",
        "vibration_pattern": [0, 200, 100, 400]  # Ding-Dong
    },
    "phone_ring": {
        "esc50_classes": ["clock_alarm"],  # Similar ringing sound
        "display_name": "Phone/Alarm Ring",
        "priority": 7,
        "alert_type": "high",
        "color": "#4B0082",
        "vibration_pattern": [0, 400, 200, 400, 200, 400]  # Standard ring
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # ANIMAL SOUNDS - Pet & Safety Awareness
    # ═══════════════════════════════════════════════════════════════════
    "dog_bark": {
        "sources": ["Dog"],
        "esc50_classes": ["dog"],
        "display_name": "Dog Barking",
        "priority": 7,
        "alert_type": "high",
        "color": "#D2691E",
        "vibration_pattern": [0, 150, 100, 150]  # Woof-woof
    },
    "cat_meow": {
        "esc50_classes": ["cat"],
        "display_name": "Cat Meowing",
        "priority": 5,
        "alert_type": "medium",
        "color": "#F0E68C",
        "vibration_pattern": [0, 150, 150, 300]  # Me-ow
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # OUTDOOR SAFETY
    # ═══════════════════════════════════════════════════════════════════
    "helicopter": {
        "esc50_classes": ["helicopter"],
        "display_name": "Helicopter",
        "priority": 6,
        "alert_type": "medium",
        "color": "#778899",
        "vibration_pattern": [0, 100, 100, 100, 100, 100, 100, 100, 100]  # Rapid rotor chop
    },
    "thunderstorm": {
        "esc50_classes": ["thunderstorm"],
        "display_name": "Thunderstorm",
        "priority": 7,
        "alert_type": "high",
        "color": "#483D8B",
        "vibration_pattern": [0, 100, 50, 200, 100, 400, 200, 800]  # Rumble getting louder
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # NEW ADDITIONAL CATEGORIES
    # ═══════════════════════════════════════════════════════════════════
    "smoke_alarm": {
        "display_name": "Smoke Alarm",
        "priority": 10,
        "alert_type": "critical",
        "color": "#A52A2A",
        "vibration_pattern": [0, 100, 50, 100, 50, 100, 1000]  # Three beeps pattern
    },
    "car_alarm": {
        "display_name": "Car Alarm",
        "priority": 9,
        "alert_type": "critical",
        "color": "#DC143C",
        "vibration_pattern": [0, 300, 100, 300, 100, 300, 100, 300, 100, 300]  # Relentless pulsing
    },
    "alarm_clock": {
        "display_name": "Alarm Clock",
        "priority": 8,
        "alert_type": "high",
        "color": "#00008B",
        "vibration_pattern": [0, 200, 200, 200, 200, 200, 200]  # Annoying beep
    },
    "microwave_beep": {
        "display_name": "Microwave Beep",
        "priority": 7,
        "alert_type": "high",
        "color": "#9370DB",
        "vibration_pattern": [0, 300, 100, 300, 100, 300]  # Three beeps
    },
    "knock_knock": {
        "display_name": "Knocking",
        "priority": 8,
        "alert_type": "high",
        "color": "#DEB887",
        "vibration_pattern": [0, 100, 100, 100, 100, 100]  # Rapid knocking
    },
    "water_running": {
        "display_name": "Water Running",
        "priority": 6,
        "alert_type": "medium",
        "color": "#00FFFF",
        "vibration_pattern": [0, 100, 100, 100, 100, 100, 100]  # Continuous flow feel
    },
    
    # ═══════════════════════════════════════════════════════════════════
    # REAL-TIME CATEGORIES - Human & Safety Sounds
    # ═══════════════════════════════════════════════════════════════════
    "speech": {
        "esc50_classes": ["laughing", "sneezing", "clapping"],
        "display_name": "Human Voice/Speech",
        "priority": 8,
        "alert_type": "high",
        "color": "#6B5B95",
        "vibration_pattern": [0, 200, 100, 100, 50, 200]  # Cadence of speech
    },
    "coughing": {
        "esc50_classes": ["coughing"],
        "display_name": "Coughing",
        "priority": 7,
        "alert_type": "high",
        "color": "#FF7F50",
        "vibration_pattern": [0, 100, 50, 100, 50, 100]  # Cough-cough-cough
    },
    "breathing": {
        "esc50_classes": ["breathing", "snoring"],
        "display_name": "Heavy Breathing",
        "priority": 7,
        "alert_type": "high",
        "color": "#87CEEB",
        "vibration_pattern": [0, 500, 500, 500, 500]  # Inhale... Exhale
    },
    "footsteps": {
        "esc50_classes": ["footsteps"],
        "display_name": "Footsteps",
        "priority": 6,
        "alert_type": "medium",
        "color": "#8B4513",
        "vibration_pattern": [0, 150, 250, 150, 250]  # Step... Step...
    },
    "door_creaking": {
        "esc50_classes": ["door_wood_creaks"],
        "display_name": "Door Opening",
        "priority": 8,
        "alert_type": "high",
        "color": "#A0522D",
        "vibration_pattern": [0, 800]  # Slow creak
    },
    "washing_machine": {
        "esc50_classes": ["washing_machine"],
        "display_name": "Washing Machine",
        "priority": 6,
        "alert_type": "medium",
        "color": "#4682B4",
        "vibration_pattern": [0, 500, 500, 500, 500]  # Rhythmic sloshing
    },
    "vacuum_cleaner": {
        "esc50_classes": ["vacuum_cleaner"],
        "display_name": "Vacuum Cleaner",
        "priority": 5,
        "alert_type": "low",
        "color": "#708090",
        "vibration_pattern": [0, 2000]  # Long continuous drone
    },
    "keyboard_typing": {
        "esc50_classes": ["keyboard_typing", "mouse_click"],
        "display_name": "Keyboard/Mouse",
        "priority": 4,
        "alert_type": "low",
        "color": "#2F4F4F",
        "vibration_pattern": [0, 50, 50, 50, 50, 50, 50]  # Rapid light taps
    },
    "clock_tick": {
        "esc50_classes": ["clock_tick"],
        "display_name": "Clock Ticking",
        "priority": 4,
        "alert_type": "low",
        "color": "#DAA520",
        "vibration_pattern": [0, 50, 950]  # Tick... Tick...
    },
    "chainsaw": {
        "esc50_classes": ["chainsaw", "hand_saw"],
        "display_name": "Power Tools",
        "priority": 8,
        "alert_type": "high",
        "color": "#FF4500",
        "vibration_pattern": [0, 300, 100, 300, 100, 1000]  # Revving
    },
    "gunshot_firework": {
        "esc50_classes": ["fireworks"],
        "display_name": "Gunshot/Fireworks",
        "priority": 10,
        "alert_type": "critical",
        "color": "#DC143C",
        "vibration_pattern": [0, 50, 50, 50, 50, 50, 50, 50, 50, 1000]  # Rapid sharp bursts then silence
    },
    "airplane": {
        "esc50_classes": ["airplane"],
        "display_name": "Airplane",
        "priority": 5,
        "alert_type": "low",
        "color": "#4169E1",
        "vibration_pattern": [0, 1500, 500, 1500]  # Long pass overhead
    },
    
    # Background / Noise cancellation class
    "background": {
        "esc50_classes": ["wind", "rain", "sea_waves", "crickets", "chirping_birds", "water_drops"],
        "display_name": "Background/Silence",
        "priority": 0,
        "alert_type": "none",
        "color": "#000000",
        "vibration_pattern": []  # Silence
    },
}
