"""
HearAlert Audio Utilities
=========================
Shared utility functions for audio processing.
"""

import wave
import numpy as np
from pathlib import Path

def get_audio_info(wav_path):
    """
    Extract audio information from WAV file.
    
    Args:
        wav_path (str or Path): Path to the wav file.
        
    Returns:
        dict: Dictionary containing audio metadata or None if error.
    """
    try:
        with wave.open(str(wav_path), 'rb') as wf:
            return {
                "channels": wf.getnchannels(),
                "sample_rate": wf.getframerate(),
                "sample_width": wf.getsampwidth(),
                "frames": wf.getnframes(),
                "duration_ms": int((wf.getnframes() / wf.getframerate()) * 1000)
            }
    except Exception as e:
        return None

def load_wav_samples(wav_path):
    """
    Load samples from WAV file.
    
    Args:
        wav_path (str or Path): Path to the wav file.
        
    Returns:
        tuple: (samples as np.array, sample_rate) or (None, None) if error.
    """
    try:
        with wave.open(str(wav_path), 'rb') as wf:
            frames = wf.readframes(wf.getnframes())
            samples = np.frombuffer(frames, dtype=np.int16)
            return samples, wf.getframerate()
    except Exception as e:
        return None, None

def save_wav(samples, sample_rate, filepath):
    """
    Save samples as WAV file.
    
    Args:
        samples (np.array): Audio samples.
        sample_rate (int): Sample rate.
        filepath (str or Path): Output file path.
    """
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(filepath), 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        # Ensure mono
        if len(samples.shape) > 1:
            samples = samples.mean(axis=1).astype(np.int16)
        w.writeframes(samples.tobytes())
