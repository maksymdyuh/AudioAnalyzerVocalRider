#!/usr/bin/env python3
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
try:
    import soundfile as sf
except Exception as e:
    print(f"Failed to import soundfile: {e}", file=sys.stderr)
    sys.exit(2)


def rms_dbfs(x: np.ndarray) -> float:
    # Avoid log of zero
    rms = math.sqrt(float(np.mean(np.square(x), dtype=np.float64)))
    return 20.0 * math.log10(max(rms, 1e-12))


def main():
    parser = argparse.ArgumentParser(description="Audio RMS analyzer")
    parser.add_argument("input", type=str, help="Path to audio file (prefer WAV/AIFF/CAF)")
    parser.add_argument("--window-ms", type=int, default=20, help="Window size in milliseconds")
    args = parser.parse_args()

    path = Path(args.input)
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 1

    try:
        data, sr = sf.read(str(path), always_2d=True)
    except Exception as e:
        print(f"Failed to read audio via soundfile: {e}", file=sys.stderr)
        return 3

    # Convert to mono
    mono = np.mean(data, axis=1).astype(np.float64, copy=False)

    window_samples = max(1, int(sr * (args.window_ms / 1000.0)))
    n = mono.shape[0]

    # Compute windowed RMS in dBFS
    rms_db_values = []
    for start in range(0, n, window_samples):
        end = min(start + window_samples, n)
        seg = mono[start:end]
        rms_db_values.append(rms_dbfs(seg))

    avg_db = rms_dbfs(mono)

    out = {
        "sampleRate": float(sr),
        "duration": float(n) / float(sr),
        "averageRMSdB": float(avg_db),
        "windowRMSdB": [float(v) for v in rms_db_values],
        "windowMs": int(args.window_ms),
    }

    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
