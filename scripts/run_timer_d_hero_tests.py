#!/usr/bin/env python3
"""Exercise production D mechanics beside extracted unchanged Timer ABC authorities."""
import os, subprocess, tempfile
from pathlib import Path
from liferoute_storage import scratch_root
root = Path(__file__).resolve().parents[1]
domain = (root / 'LifeRoute/SessionToolsDomain.swift').read_text()
view = (root / 'LifeRoute/ScenicRoyalVisualTimerView.swift').read_text()
hero = (root / 'LifeRoute/VisualTimerHero.swift').read_text()
core = domain.split('@MainActor\nfinal class VisualTimerCore:', 1)[1].split('@MainActor\nfinal class SessionToolsCore:', 1)[0]
state = view.split('@MainActor\nfinal class VisualTimerPresentationState:', 1)[1].split('// Kept as the existing fullscreen chrome seam;', 1)[0]
doubles = (root / 'scripts/timer_abc_tests.swift').read_text().split('@main struct TimerABCTests', 1)[0]
cache = Path(os.environ.get('LIFEROUTE_CONTRACT_CACHE_DIRECTORY', scratch_root() / 'contract-cache-v1'))
cache.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='timer-d-', dir=cache) as temp:
    temp = Path(temp)
    production = temp / 'ProductionTimer.swift'
    production.write_text('import Foundation\nimport Combine\n@MainActor\nfinal class VisualTimerCore:' + core + '@MainActor\nfinal class VisualTimerPresentationState:' + state)
    feedback = temp / 'PlatformFeedback.swift'
    feedback.write_text(doubles)
    executable = temp / 'timer-d-tests'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(root / 'LifeRoute/VisualTimerFeedbackContracts.swift'), str(root / 'LifeRoute/VisualTimerHero.swift'), str(production), str(feedback), str(root / 'scripts/timer_d_hero_tests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], cwd=root, check=True)
# These integration assertions complement execution; they do not claim rendered continuity.
assert 'fullScreenCover' not in view and 'VisualTimerExpansionSource' not in view
assert view.count('ScenicRoyalTimerOrb(') == 1
assert 'hero: hero,' in view and 'VisualTimerHeroAnchor(hero: hero)' in view
assert 'orb.transform = CGAffineTransform' in hero and 'orb.center =' in hero
assert 'VisualTimerCore(' not in hero and 'VisualTimerOrbPresentationDriver(' not in hero and 'UIWindow(' not in hero
assert 'transition.takeSettledNavigation()' in hero
assert 'scroll.observe(\\.contentOffset' in hero
print('PASS D integration: single Orb construction, shared authorities, live anchor, settlement navigation')

assert '.opacity(hero.blocksNavigation ? 0 : 1)' in view
assert '.allowsHitTesting(!hero.blocksNavigation)' in view and '.accessibilityHidden(hero.blocksNavigation)' in view
print('PASS D presentation: embedded content retains anchor layout but hides during Hero ownership')
