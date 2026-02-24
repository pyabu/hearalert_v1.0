#!/usr/bin/env python3
import os
import glob
import json
import wave
import pandas as pd
from pathlib import Path
from datetime import datetime

# Configuration
from hearalertt.config import (
    BASE_DIR, DATASETS_DIR, TRAINING_DATA_DIR,
    TRAINING_CATEGORIES, DATASET_REPORT_PATH
)
from hearalertt.audio_utils import get_audio_info

# Fallback
if not DATASETS_DIR.exists():
    DATASETS_DIR = TRAINING_DATA_DIR

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate Excel report for audio dataset.")
    parser.add_argument("--input", type=Path, default=DATASETS_DIR, help="Input datasets directory")
    parser.add_argument("--output", type=Path, default=DATASET_REPORT_PATH, help="Output Excel file")
    
    # 1. Load Categories Metadata (from config)
    categories_meta = TRAINING_CATEGORIES

    # 2. Scan Files
    data = []
    
    if not args.input.exists():
        print(f"Error: Training data directory not found at {args.input}")
        return

    # Walk through the directory
    for root, dirs, files in os.walk(args.input):
        # Exclude hidden directories and copy folders
        dirs[:] = [d for d in dirs if not d.startswith('.') and 'copy' not in d.lower()]
        
        for file in files:
            if file.lower().endswith('.wav'):
                file_path = Path(root) / file
                category_name = file_path.parent.name
                
                # Basic file stats
                file_size_kb = os.path.getsize(file_path) / 1024
                
                # Audio stats
                duration, sample_rate, channels, sampwidth = get_audio_info(file_path)
                
                # Metadata from Config
                cat_meta = categories_meta.get(category_name, {})
                
                # Fallback for display name
                display_name = cat_meta.get('display_name')
                if not display_name:
                    display_name = category_name.replace('_', ' ').title()

                row = {
                    "Filename": file,
                    "Category ID": category_name,
                    "Category Name": display_name,
                    "Priority": cat_meta.get('priority', 'N/A'),
                    "Alert Type": cat_meta.get('alert_type', 'N/A'),
                    "Duration (s)": round(duration, 2),
                    "Size (KB)": round(file_size_kb, 2),
                    "Sample Rate": sample_rate,
                    "Channels": channels,
                    "Bit Depth": sampwidth * 8,
                    "Path": str(file_path.relative_to(BASE_DIR) if file_path.is_relative_to(BASE_DIR) else file_path)
                }
                data.append(row)

    # 3. Create DataFrame and Export
    if not data:
        print("No wav files found.")
        return

    df = pd.DataFrame(data)
    
    # Reorder columns if needed
    columns = [
        "Category Name", "Category ID", "Priority", "Alert Type", 
        "Filename", "Duration (s)", "Size (KB)", 
        "Sample Rate", "Channels", "Bit Depth", "Path"
    ]
    # Filter columns that exist in data
    columns = [c for c in columns if c in df.columns]
    df = df[columns]

    # Sort
    df = df.sort_values(by=["Priority", "Category Name", "Filename"], ascending=[False, True, True])

    # Summary Sheet
    summary = df.groupby('Category Name').agg({
        'Filename': 'count',
        'Duration (s)': 'sum',
        'Size (KB)': 'sum'
    }).rename(columns={'Filename': 'File Count', 'Duration (s)': 'Total Duration (s)', 'Size (KB)': 'Total Size (KB)'})
    
    # Save to Excel
    try:
        with pd.ExcelWriter(args.output, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='All Files', index=False)
            summary.to_excel(writer, sheet_name='Summary')
        
        print(f"Successfully generated report at: {args.output}")
        print(f"Total files: {len(df)}")
        print("Summary:")
        print(summary)
        
    except ImportError as e:
        print("Error: Pandas or openpyxl is not installed. Please install them to generate Excel files.")
        print("Run: pip install pandas openpyxl pyyaml")
        # Fallback to CSV
        csv_file = args.output.with_suffix('.csv')
        df.to_csv(csv_file, index=False)
        print(f"Fallback: Generated CSV report at {csv_file}")
    except Exception as e:
        print(f"An error occurred during export: {e}")

if __name__ == "__main__":
    main()
