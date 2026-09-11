#!/usr/bin/env python3
"""Verify the frozen shared Ocean contract and exercise divergence rejection.

Hash pins protect the owner-frozen authority and its event-model consumer.
Metal and Swift read the same header; there is no generated copy of the values.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
AUTHORITY = ROOT / 'LifeRoute/LivingOceanTiming.h'
SHADER = ROOT / 'LifeRoute/LivingRainforest.metal'
PIN = ROOT / 'scripts/ocean_timing_authority_pin.json'

def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()

def event_model(shader):
    return shader.split('static LivingWaveEvent livingOceanEvent(', 1)[1].split('// Independent GPU tests', 1)[0]

def verify(header, shader, pin):
    if digest(header) != pin['authoritySHA256']:
        return False, 'Frozen authority changed'
    if digest(event_model(shader)) != pin['eventModelSHA256']:
        return False, 'Event-model consumer diverged'
    if shader.count('#include "LivingOceanTiming.h"') != 1 or re.search(r'#\s*define\s+LIVING_OCEAN_',shader):
        return False, 'Authority include missing or shadowed'
    for use in pin['requiredTimingUses']:
        if use not in shader:
            return False, 'Timing consumer diverged: ' + use
    return True, 'Canonical authority and production consumers agree'

if __name__ == '__main__':
    header, shader = AUTHORITY.read_text(), SHADER.read_text()
    pin = json.loads(PIN.read_text())
    ok, reason = verify(header, shader, pin)
    assert ok, reason
    # Real negative controls: change each side independently without modifying
    # the repository, and require the very same validator to reject the change.
    assert not verify(header.replace('6.3f', '6.4f', 1), shader, pin)[0]
    assert not verify(header, shader.replace('eventID * LIVING_OCEAN_ARRIVAL_SPACING', 'eventID * 19.0', 1), pin)[0]
    assert not verify(header, shader.replace('floor(t / LIVING_OCEAN_ARRIVAL_SPACING)', 'floor(t / 19.0)', 1), pin)[0]
    tests = (ROOT/'scripts/living_theme_render_tests.swift').read_text()
    runner = (ROOT/'scripts/run_living_theme_render_tests.sh').read_text()
    assert '-import-objc-header "$ROOT/LifeRoute/LivingOceanTiming.h"' in runner
    assert 'earlierLife <= LIVING_OCEAN_LIFETIME_MAX' in tests
    assert 'laterLife * LIVING_OCEAN_OVERLAP_SWELL_PROGRESS' in tests
    assert 'life > 3 * 6.3' not in tests
    print('PASS: frozen Ocean authority; shared production/test header; three divergence negative controls')
