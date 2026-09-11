#!/usr/bin/env python3
"""Check run-frozen family contracts against an external, owner-scoped ledger."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--checkpoint', type=Path, required=True)
a = p.parse_args()
shader = (ROOT/'LifeRoute/LivingRainforest.metal').read_text()
# The accepted Day shader is retained byte for byte. Its two advection rates
# remain literal in that frozen representation; reject divergence from the
# Rainforest contract instead of refactoring accepted rendering for cosmetics.
# The event-only include is outside the frozen Day program and is not called by
# Rainforest Day. Remove exactly that declaration before applying the unchanged
# original extent and SHA; all original helpers and Day statements remain bound.
event_include = '#include "LivingSceneEvents.h"\n\n'
assert shader.count(event_include) == 1
accepted_layout = shader.replace(event_include, '', 1)
day = accepted_layout[:6455]  # Exact byte extent of 9494e81's complete accepted shader.
assert accepted_layout[6455:].split('#include "LivingOceanTiming.h"', 1)[0].isspace()
assert hashlib.sha256(day.encode()).hexdigest() == 'acca8a9813c0a2fbfcbf460b83482af74627484ba9eecfe002dda582335477fd', 'Accepted Rainforest Day implementation changed'
rainforest = (ROOT/'LifeRoute/LivingRainforestMotion.h').read_text()
for name, call in [('FALL', 'uv, flow'), ('STREAM', 'surface, flow')]:
    value = re.search(r'#define LIVING_RF_DAY_'+name+r'_RATE ([0-9.]+)f', rainforest).group(1)
    assert 'livingAdvect(artwork, sampling, '+call+', t, '+value+')' in day, 'Rainforest Day contract divergence: '+name
expected = (a.checkpoint/'OCEAN_TIMING_AUTHORITY.sha256').read_text().split()[0]
assert hashlib.sha256((ROOT/'LifeRoute/LivingOceanTiming.h').read_bytes()).hexdigest() == expected, 'STOP_OCEAN_TIMING_AUTHORITY_DRIFT'
ledger = a.checkpoint/'FAMILY_MOTION_AUTHORITIES.json'
if ledger.exists():
    for family, entry in json.loads(ledger.read_text()).items():
        for path, sha in entry['files'].items():
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == sha, 'Frozen family authority drift: '+family+' '+path
        for name, sha in entry.get('descriptors', {}).items():
            scene = (ROOT/'LifeRoute/LivingThemeScene.swift').read_text()
            descriptor = re.search(r'    static let '+name+r' = Self\(skyA:.*?\)\n', scene, re.S).group(0)
            assert hashlib.sha256(descriptor.encode()).hexdigest() == sha, 'Frozen family descriptor drift: '+name
print('PASS: external Ocean and established family hashes match')
