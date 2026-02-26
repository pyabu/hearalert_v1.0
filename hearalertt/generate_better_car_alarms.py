import os
import numpy as np
import random
import scipy.io.wavfile as wav

OUTPUT_DIR = "/Users/abusaleem/hearalert-v1.1/hearalertt/training_data/car_alarm"
NUM_SAMPLES = 500
SAMPLE_RATE = 16000
DURATION = 3.0  # seconds

def _generate_wail(t):
    """Classic wailing siren (rising and falling pitch)."""
    base_freq = random.uniform(500, 800)
    sweep_range = random.uniform(300, 600)
    rate = random.uniform(0.5, 2.0)
    freq = base_freq + sweep_range * np.sin(2 * np.pi * rate * t)
    return np.sin(2 * np.pi * freq * t)

def _generate_yelp(t):
    """Fast yelping siren."""
    base_freq = random.uniform(600, 900)
    sweep_range = random.uniform(300, 700)
    rate = random.uniform(3.0, 6.0)
    # Sawtooth-like frequency modulation
    freq = base_freq + sweep_range * ( (t * rate) % 1.0 )
    return np.sin(2 * np.pi * freq * t)

def _generate_honk(t):
    """Car horn honking pattern."""
    base_freq = random.uniform(300, 500)
    # create dual tone (chord)
    signal = 0.6 * np.sin(2 * np.pi * base_freq * t) + 0.4 * np.sin(2 * np.pi * (base_freq * 1.25) * t)
    
    # Apply gating (on/off pattern)
    honk_length = random.uniform(0.1, 0.4)
    gap_length = random.uniform(0.05, 0.2)
    period = honk_length + gap_length
    
    gate = ((t % period) < honk_length).astype(float)
    return signal * gate

def _generate_dual_tone(t):
    """European-style high-low alarm."""
    hi_freq = random.uniform(800, 1200)
    lo_freq = random.uniform(500, 700)
    rate = random.uniform(1.0, 2.5)
    
    # Square wave frequency modulation
    freq = np.where(np.sin(2 * np.pi * rate * t) > 0, hi_freq, lo_freq)
    return np.sin(2 * np.pi * freq * t)

def _generate_electronic_chirp(t):
    """Fast modern electronic car alarm chirp sequence."""
    base_freq = random.uniform(1800, 2500)
    rate = random.uniform(10.0, 20.0)
    chirp_length = 0.02
    
    period = 1.0 / rate
    gate = ((t % period) < chirp_length).astype(float)
    
    # Slight pitch sweep down during the chirp
    freq = base_freq - 500 * ((t % period) / chirp_length)
    signal = np.sin(2 * np.pi * freq * t)
    return signal * gate

def add_environmental_effects(signal, sr):
    """Add noise, reverb, and random volume scaling."""
    # 1. Add background street noise (pink-ish noise)
    noise = np.random.normal(0, 1, len(signal))
    noise = np.convolve(noise, np.ones(10)/10, mode='same') # simple lowpass filter
    noise_level = random.uniform(0.01, 0.15)
    signal += noise * noise_level * np.max(np.abs(signal))
    
    # 2. Reverb (simulated by adding delayed copies)
    if random.random() < 0.7:
        delay_ms = random.randint(20, 150)
        delay_samples = int((delay_ms / 1000.0) * sr)
        decay = random.uniform(0.2, 0.5)
        
        reverb = np.zeros(len(signal) + delay_samples)
        reverb[:len(signal)] = signal
        reverb[delay_samples:] += signal * decay
        signal = reverb[:len(signal)]
        
    # 3. Randomize overall volume
    signal *= random.uniform(0.3, 1.0)
    return signal

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    t = np.linspace(0, DURATION, int(SAMPLE_RATE * DURATION))
    alarm_types = [_generate_wail, _generate_yelp, _generate_honk, _generate_dual_tone, _generate_electronic_chirp]
    
    print(f"Generating {NUM_SAMPLES} diverse car alarm samples...")
    for i in range(NUM_SAMPLES):
        # Pick 1 or 2 alarm types to combine (sometimes car alarms have multiple patterns playing)
        num_types = np.random.choice([1, 1, 1, 2], p=[0.6, 0.2, 0.1, 0.1])
        
        signal = np.zeros_like(t)
        chosen_funcs = random.sample(alarm_types, num_types)
        
        for func in chosen_funcs:
            signal += func(t)
            
        signal = add_environmental_effects(signal, SAMPLE_RATE)
        
        # Normalize to 16-bit PCM integer
        max_val = np.max(np.abs(signal))
        if max_val > 0:
            signal = signal / max_val
            
        pcm_signal = (signal * 32767).astype(np.int16)
        
        # Save file
        filename = f"car_alarm_{i:04d}.wav"
        filepath = os.path.join(OUTPUT_DIR, filename)
        wav.write(filepath, SAMPLE_RATE, pcm_signal)
        
        if (i+1) % 50 == 0:
            print(f"Generated {i+1}/{NUM_SAMPLES}...")

    print("Car alarm generation complete.")

if __name__ == "__main__":
    main()
