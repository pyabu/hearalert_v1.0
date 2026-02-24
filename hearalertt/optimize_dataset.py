#!/usr/bin/env python3
import os
import hashlib
import shutil
import subprocess
from pathlib import Path
import argparse

# Configuration
from hearalertt.config import DATASETS_DIR, OPTIMIZED_DIR, TRAINING_DATA_DIR

# Fallback if datasets dir is not what we expect, though config should have it right.
if not DATASETS_DIR.exists():
    DATASETS_DIR = TRAINING_DATA_DIR

def get_file_hash(file_path):
    """Calculate MD5 hash of a file."""
    hasher = hashlib.md5()
    with open(file_path, 'rb') as f:
        buf = f.read(65536)
        while len(buf) > 0:
            hasher.update(buf)
            buf = f.read(65536)
    return hasher.hexdigest()

def convert_audio(input_path, output_path):
    """
    Convert audio to 16kHz, 16-bit, Mono WAV using afconvert (macOS native).
    format: LEI16 (Little Endian Integer 16-bit)
    sample rate: 16000
    channels: 1 (mono)
    """
    try:
        # afconvert -f WAVE -d LEI16@16000 -c 1 input output
        cmd = [
            'afconvert',
            '-f', 'WAVE',
            '-d', 'LEI16@16000',
            '-c', '1',
            str(input_path),
            str(output_path)
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error converting {input_path}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Optimize audio dataset: remove duplicates and reduce size.")
    parser.add_argument("--input", type=Path, default=DATASETS_DIR, help="Input datasets directory")
    parser.add_argument("--output", type=Path, default=OPTIMIZED_DIR, help="Output optimized directory")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input directory {args.input} does not exist.")
        return

    print(f"Scanning {args.input}...")
    print(f"Output will be saved to {args.output}")

    # Track duplicates
    seen_hashes = {} # hash -> original_path
    duplicates_count = 0
    processed_count = 0
    failed_count = 0
    
    # Original vs Optimized size tracking
    original_size_total = 0
    optimized_size_total = 0

    # Walk through input directory
    for root, dirs, files in os.walk(args.input):
        # Replicate directory structure in output
        rel_path = Path(root).relative_to(args.input)
        target_dir = args.output / rel_path
        
        # Skip if hidden or copy folder (simple check)
        if any(part.startswith('.') for part in rel_path.parts):
            continue

        for file in files:
            if not file.lower().endswith('.wav'):
                continue

            input_path = Path(root) / file
            
            # Check for duplicate
            file_hash = get_file_hash(input_path)
            if file_hash in seen_hashes:
                duplicates_count += 1
                # print(f"Duplicate found: {input_path.name} (same as {seen_hashes[file_hash].name})")
                continue
            
            seen_hashes[file_hash] = input_path
            
            # Prepare output path
            target_dir.mkdir(parents=True, exist_ok=True)
            output_path = target_dir / file
            
            # Convert
            if convert_audio(input_path, output_path):
                processed_count += 1
                
                # Stats
                original_size_total += input_path.stat().st_size
                optimized_size_total += output_path.stat().st_size
                
                if processed_count % 100 == 0:
                    print(f"Processed {processed_count} files...", end='\r')
            else:
                failed_count += 1

    print("\n" + "="*40)
    print("OPTIMIZATION COMPLETE")
    print("="*40)
    print(f"Files processed: {processed_count}")
    print(f"Duplicates removed: {duplicates_count}")
    print(f"Conversion failures: {failed_count}")
    
    if processed_count > 0:
        orig_mb = original_size_total / (1024*1024)
        opt_mb = optimized_size_total / (1024*1024)
        reduction = (1 - (opt_mb / orig_mb)) * 100
        
        print(f"Original Size: {orig_mb:.2f} MB")
        print(f"Optimized Size: {opt_mb:.2f} MB")
        print(f"Space Saved: {orig_mb - opt_mb:.2f} MB ({reduction:.1f}%)")
        print(f"Optimized dataset location: {args.output}")
    else:
        print("No audio files processed.")

if __name__ == "__main__":
    main()
