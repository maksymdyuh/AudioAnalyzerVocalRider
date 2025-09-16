# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Repository overview
- Platform: macOS app written in Swift using SwiftUI and AVFoundation
- Xcode project: "AudioAnalyzerVisualizer NEW.xcodeproj"
- Target/Scheme: single app target and shared scheme named "AudioAnalyzerVisualizer NEW"
- Entry points:
  - AudioAnalyzerVisualizer NEW/AudioAnalyzerVisualizer_NEWApp.swift — @main app, creates WindowGroup hosting ContentView
  - AudioAnalyzerVisualizer NEW/ContentView.swift — root SwiftUI view with UI to pick an audio file, run analysis, and render waveform
- Core components:
  - AudioAnalyzerVisualizer NEW/AnalyzerService.swift — analysis orchestration; Swift fallback using AVFoundation and optional Python subprocess integration
  - AudioAnalyzerVisualizer NEW/Models.swift — AnalysisResult data model (JSON-compatible)
  - AudioAnalyzerVisualizer NEW/WaveformView.swift — lightweight RMS-dB waveform renderer
  - python/analyzer.py — Python analyzer producing JSON (requires numpy, soundfile)
- Assets: AudioAnalyzerVisualizer NEW/Assets.xcassets (AppIcon, AccentColor)
- Bundle identifier: me.AudioAnalyzerVisualizer-NEW
- Dependencies: no Swift Package dependencies configured; optional Python virtual environment

Common development commands
Notes
- The target and scheme names contain spaces — always quote them.
- These commands use a per-repo DerivedData directory (.build).
- If xcodebuild fails to see newly added source files, open the project once in Xcode to let the File System–Synchronized Group refresh.

List available schemes
```bash path=null start=null
xcodebuild -list -project "AudioAnalyzerVisualizer NEW.xcodeproj"
```

Build (Debug)
```bash path=null start=null
DERIVED=.build
xcodebuild \
  -project "AudioAnalyzerVisualizer NEW.xcodeproj" \
  -scheme "AudioAnalyzerVisualizer NEW" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  clean build
```

Run the built app (after a successful Debug build)
```bash path=null start=null
open ".build/Build/Products/Debug/AudioAnalyzerVisualizer NEW.app"
```

Build (Release, without code signing)
```bash path=null start=null
DERIVED=.build
xcodebuild \
  -project "AudioAnalyzerVisualizer NEW.xcodeproj" \
  -scheme "AudioAnalyzerVisualizer NEW" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

Static analysis (Xcode analyzer)
```bash path=null start=null
xcodebuild \
  -project "AudioAnalyzerVisualizer NEW.xcodeproj" \
  -scheme "AudioAnalyzerVisualizer NEW" \
  -configuration Debug \
  -destination 'platform=macOS' \
  analyze
```

Testing
- No test targets are present yet; create one in Xcode (File > New > Target > Unit Testing Bundle) before running tests.
- Once a test bundle exists:
```bash path=null start=null
xcodebuild \
  -project "AudioAnalyzerVisualizer NEW.xcodeproj" \
  -scheme "AudioAnalyzerVisualizer NEW" \
  -destination 'platform=macOS' \
  test
```
Run a single test (after tests exist)
```bash path=null start=null
xcodebuild test \
  -project "AudioAnalyzerVisualizer NEW.xcodeproj" \
  -scheme "AudioAnalyzerVisualizer NEW" \
  -destination 'platform=macOS' \
  -only-testing:"<TestsTarget>/<TestCaseClass>/<testMethod>"
```

Python analyzer setup (optional)
- Create a virtual environment and install deps:
```bash path=null start=null
python3 -m venv .venv
source .venv/bin/activate
pip install -r python/requirements.txt
```
- Configure the app to use the Python analyzer at runtime by setting an environment variable in the Xcode Run scheme:
  - AAV_PY_ANALYZER = /absolute/path/to/repo/python/analyzer.py
- In the UI, toggle "Use Python (if configured)" to prefer Python. If the variable is not set, the Swift fallback runs instead.

High-level architecture
- App lifecycle: `AudioAnalyzerVisualizer_NEWApp` (SwiftUI) creates a WindowGroup and hosts `ContentView`.
- UI (ContentView): lets the user pick an audio file (WAV/AIFF/CAF/MP3/M4A), choose window size (ms), and run analysis. Displays average loudness (RMS dBFS) and a simple waveform of windowed RMS values.
- Analysis orchestration (AnalyzerService):
  - If environment variable AAV_PY_ANALYZER points to python/analyzer.py and the UI toggle is enabled, runs Python as a subprocess via `/usr/bin/env python3` and decodes its JSON output into `AnalysisResult`.
  - Otherwise, uses AVFoundation to read audio, convert to mono, compute windowed RMS and overall average RMS in Swift.
- Data model: `AnalysisResult` carries `sampleRate`, `duration`, `averageRMSdB`, `windowRMSdB[]`, and `windowMs` and is shared between Swift and Python via JSON.
- Visualization (WaveformView): draws symmetrical vertical lines per window using dBFS->linear conversion for a quick, lightweight envelope.

Docs and rules
- No README.md, CLAUDE.md, Cursor or Copilot rules were found; no additional project-scoped rules to inherit.
