import os
import numpy as np
import random
import scipy.io.wavfile as wav
import shutil

BASE_DIR = "/Users/abusaleem/hearalert-v1.1/hearalertt/training_data"
NUM_SAMPLES = 500
SAMPLE_RATE = 16000
DURATION = 3.0  # seconds

# List of synthetic categories that are known to overfit due to simplistic generated beeps
CATEGORIES_TO_FIX = [
    "smoke_alarm",
    "alarm_clock",
    "microwave_beep",
    "siren",
    "fire_alarm",
    "doorbell",
    "door_creaking",
    "footsteps",
    "knock_knock",
    "water_running"
]

def add_environmental_effects(signal, sr):
    """Add noise, reverb, and random volume scaling to simulate real acoustics."""
    # 1. Background street/room noise 
    noise = np.random.normal(0, 1, len(signal))
    noise = np.convolve(noise, np.ones(10)/10, mode='same')
    noise_level = random.uniform(0.01, 0.1)
    signal += noise * noise_level * np.max(np.abs(signal))
    
    # 2. Reverb
    if random.random() < 0.6:
        delay_ms = random.randint(20, 100)
        delay_samples = int((delay_ms / 1000.0) * sr)
        decay = random.uniform(0.1, 0.5)
        
        reverb = np.zeros(len(signal) + delay_samples)
        reverb[:len(signal)] = signal
        reverb[delay_samples:] += signal * decay
        signal = reverb[:len(signal)]
        
    # 3. Randomize overall volume
    signal *= random.uniform(0.4, 1.0)
    return signal

def normalize_and_save(signal, filepath):
    max_val = np.max(np.abs(signal))
    if max_val > 0:
         signal = signal / max_val
    pcm_signal = (signal * 32767).astype(np.int16)
    wav.write(filepath, SAMPLE_RATE, pcm_signal)

def gen_smoke_alarm(t):
    # High pitched intermittent beeps, varying frequencies (2800-3500)
    freq = random.uniform(2800, 3500)
    signal = np.sin(2 * np.pi * freq * t)
    # Fast chopping on/off pattern
    period = random.uniform(0.3, 0.6)
    duty = random.uniform(0.3, 0.5)
    gate = ((t % period) < (period * duty)).astype(float)
    return signal * gate

def gen_alarm_clock(t):
    # Standard electronic buzz/beep triples
    freq = random.uniform(800, 1500)
    signal = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    
    # Beep beep beep pause...
    gate = np.zeros_like(t)
    for start in np.arange(0, DURATION, 1.0):
        for b in range(random.randint(2, 4)):
            b_start = start + b * 0.15
            b_end = b_start + 0.1
            mask = (t >= b_start) & (t < b_end)
            gate[mask] = 1.0
    return signal * gate

def gen_microwave_beep(t):
    # Clean sine wave beep, usually 3 times at the end
    freq = random.uniform(1500, 2500)
    signal = np.sin(2 * np.pi * freq * t)
    
    gate = np.zeros_like(t)
    start_time = random.uniform(0.2, 1.0)
    for b in range(random.randint(1, 4)):
        b_start = start_time + b * random.uniform(0.8, 1.2)
        b_end = b_start + random.uniform(0.2, 0.5)
        mask = (t >= b_start) & (t < b_end)
        gate[mask] = 1.0
    return signal * gate

def gen_siren(t):
    # Wail or Yelp
    style = random.choice(['wail', 'yelp'])
    if style == 'wail':
        base = random.uniform(400, 700)
        sweep = random.uniform(300, 600)
        rate = random.uniform(0.1, 0.4)
        freq = base + sweep * np.sin(2 * np.pi * rate * t)
    else:
        base = random.uniform(500, 900)
        sweep = random.uniform(400, 800)
        rate = random.uniform(2.0, 5.0)
        freq = base + sweep * ((t * rate) % 1.0)
    return np.sin(2 * np.pi * freq * t)

def gen_fire_alarm(t):
    # Harsh mechanical bell or buzzer
    base_freq = random.uniform(300, 600)
    
    # Create harsh square-ish wave by stacking odd harmonics
    signal = np.sin(2 * np.pi * base_freq * t)
    signal += 0.3 * np.sin(2 * np.pi * base_freq * 3 * t)
    signal += 0.1 * np.sin(2 * np.pi * base_freq * 5 * t)
    
    # Pulse (BRRR-BRRR-BRRR) or constant
    if random.random() < 0.7:
        rate = random.uniform(1.0, 3.0)
        gate = (np.sin(2 * np.pi * rate * t) > 0).astype(float)
        signal *= gate
        
    return signal

def gen_doorbell(t):
    # Dual tone ding-dong
    freq1 = random.uniform(500, 900)
    freq2 = freq1 * random.uniform(0.7, 0.85) # lower note
    
    signal = np.zeros_like(t)
    
    t_ding = random.uniform(0.2, 0.5)
    mask_ding = t >= t_ding
    decay_ding = np.exp(-(t[mask_ding] - t_ding) / random.uniform(0.5, 1.2))
    signal[mask_ding] += decay_ding * np.sin(2 * np.pi * freq1 * (t[mask_ding] - t_ding))
    
    t_dong = t_ding + random.uniform(0.4, 0.8)
    if random.random() < 0.8: # Sometimes just a 'ding'
        mask_dong = t >= t_dong
        decay_dong = np.exp(-(t[mask_dong] - t_dong) / random.uniform(0.8, 1.5))
        signal[mask_dong] += decay_dong * np.sin(2 * np.pi * freq2 * (t[mask_dong] - t_dong))
        
    return signal

def gen_door_creaking(t):
    signal = np.zeros_like(t)
    start = random.uniform(0.2, 1.0)
    end = start + random.uniform(0.5, 1.5)
    mask = (t >= start) & (t <= end)
    
    # FM synthesis screech
    carrier = random.uniform(300, 800)
    mod_freq = random.uniform(20, 100)
    mod_idx = random.uniform(100, 400)
    
    signal[mask] = np.sin(2 * np.pi * (carrier + mod_idx * np.sin(2 * np.pi * mod_freq * t[mask])) * t[mask])
    
    # Add roughness
    noise = np.random.normal(0, 0.2, len(t))
    signal[mask] += noise[mask]
    return signal

def gen_footsteps(t):
    signal = np.zeros_like(t)
    step_rate = random.uniform(1.0, 2.5) # steps per second
    
    for step_time in np.arange(0.2, DURATION, 1.0/step_rate):
        step_idx = int(step_time * SAMPLE_RATE)
        if step_idx < len(signal):
            impact_len = int(random.uniform(0.05, 0.15) * SAMPLE_RATE)
            end_idx = min(step_idx + impact_len, len(signal))
            actual_len = end_idx - step_idx
            
            # Create a thud
            decay = np.exp(-np.arange(actual_len) / (SAMPLE_RATE * 0.02))
            freq = random.uniform(50, 150)
            thud = decay * np.sin(2 * np.pi * freq * np.arange(actual_len) / SAMPLE_RATE)
            
            # Create shuffle/scrape (noise)
            scrape = decay * np.random.normal(0, 0.5, actual_len)
            
            signal[step_idx:end_idx] += thud + (scrape * random.uniform(0.2, 0.8))
            
    return signal

def gen_knock_knock(t):
    signal = np.zeros_like(t)
    knocks = random.randint(2, 5)
    start_time = random.uniform(0.2, 1.0)
    
    for k in range(knocks):
        k_time = start_time + k * random.uniform(0.15, 0.35)
        k_idx = int(k_time * SAMPLE_RATE)
        
        if k_idx < len(signal):
            impact_len = int(0.08 * SAMPLE_RATE)
            end_idx = min(k_idx + impact_len, len(signal))
            actual_len = end_idx - k_idx
            
            # Sharp transient decay
            decay = np.exp(-np.arange(actual_len) / (SAMPLE_RATE * 0.01))
            
            # Wood resonance freq
            freq = random.uniform(100, 400)
            knock = decay * np.sin(2 * np.pi * freq * np.arange(actual_len) / SAMPLE_RATE)
            
            # Add click transient
            click = decay * np.random.normal(0, 0.8, actual_len)
            
            signal[k_idx:end_idx] += knock + (click * 0.3)
            
    return signal

def gen_water_running(t):
    # Filtered brown/pink noise
    noise = np.random.normal(0, 1, len(t))
    # lowpass filter to take out the hiss
    b, a = [0.1]*10, [1.0] # simple FIR
    filtered = np.convolve(noise, np.ones(20)/20, mode='same')
    
    # Tremolo effect to simulate splashing/gurgling
    gurgle_rate = random.uniform(5.0, 15.0)
    tremolo = 0.7 + 0.3 * np.sin(2 * np.pi * gurgle_rate * t) \
              + 0.2 * np.sin(2 * np.pi * (gurgle_rate*2.3) * t)
              
    return filtered * tremolo

GENERATORS = {
    "smoke_alarm": gen_smoke_alarm,
    "alarm_clock": gen_alarm_clock,
    "microwave_beep": gen_microwave_beep,
    "siren": gen_siren,
    "fire_alarm": gen_fire_alarm,
    "doorbell": gen_doorbell,
    "door_creaking": gen_door_creaking,
    "footsteps": gen_footsteps,
    "knock_knock": gen_knock_knock,
    "water_running": gen_water_running
}

def main():
    print("="*60)
    print("HearAlert: Deep-Fake Audio Data Generator")
    print("Replacing obsolete deterministic synthetic datasets with rich randomized profiles.")
    print("="*60)
    
    t = np.linspace(0, DURATION, int(SAMPLE_RATE * DURATION))
    
    for category in CATEGORIES_TO_FIX:
        cat_dir = os.path.join(BASE_DIR, category)
        
        # 1. Wipe old synthesized crap
        if os.path.exists(cat_dir):
            print(f"[{category}] Wiping old files...")
            shutil.rmtree(cat_dir)
        os.makedirs(cat_dir, exist_ok=True)
        
        generator = GENERATORS[category]
        
        print(f"[{category}] Generating {NUM_SAMPLES} new hyper-diverse samples...")
        for i in range(NUM_SAMPLES):
            # Generate base signal using category specific math
            signal = generator(t)
            
            # Randomize acoustics
            signal = add_environmental_effects(signal, SAMPLE_RATE)
            
            filepath = os.path.join(cat_dir, f"{category}_rich_{i:04d}.wav")
            normalize_and_save(signal, filepath)
            
        print(f"✓ {category} complete.")

if __name__ == "__main__":
    main()
