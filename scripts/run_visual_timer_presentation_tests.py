#!/usr/bin/env python3
"""Execute production timer/presentation code with recorded platform feedback.

Extraction avoids changing the protected Xcode project or domain source. The
actual countdown and UI state classes are compiled unchanged; only UIKit and
AVAudioEngine endpoints are test doubles. Native modal behavior is tested
separately in Simulator.
"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
domain = (ROOT / 'LifeRoute/SessionToolsDomain.swift').read_text()
view = (ROOT / 'LifeRoute/ScenicRoyalVisualTimerView.swift').read_text()
core = domain.split('@MainActor\nfinal class VisualTimerCore:', 1)[1].split('@MainActor\nfinal class SessionToolsCore:', 1)[0]
state = view.split('@MainActor\nfinal class VisualTimerPresentationState:', 1)[1].split('private struct ScenicRoyalFullScreenTimerView:', 1)[0]
source = 'import Foundation\nimport Combine\n@MainActor\nfinal class VisualTimerCore:' + core + '@MainActor\nfinal class VisualTimerPresentationState:' + state
cache = Path(os.environ.get('LIFEROUTE_CONTRACT_CACHE_DIRECTORY', tempfile.gettempdir()))
cache.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='timer-presentation-', dir=cache) as directory:
    generated = Path(directory) / 'ProductionTimerAndPresentation.swift'
    generated.write_text(source)
    executable = Path(directory) / 'presentation-tests'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library',
                    str(ROOT / 'LifeRoute/VisualTimerFeedbackContracts.swift'),
                    str(generated), str(ROOT / 'scripts/visual_timer_presentation_tests.swift'),
                    '-o', str(executable)], cwd=ROOT, check=True)
    subprocess.run([str(executable)], cwd=ROOT, check=True)
