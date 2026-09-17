#!/usr/bin/env python3
"""Fail-closed validator for a Phase 5F native qualification manifest."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

SHA256 = re.compile(r'^[0-9a-f]{64}$')
GIT_SHA = re.compile(r'^[0-9a-f]{40}$')
STATUSES = {'PASS', 'FAIL', 'BLOCKED', 'NOT_RUN'}
IDENTITY_STATES = {'present', 'not_applicable', 'not_recorded', 'unavailable'}

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def inventory_hash(rows):
    payload = ''.join(f"{row['path']}\t{row['sha256']}\t{row['bytes']}\n" for row in rows)
    return hashlib.sha256(payload.encode()).hexdigest()

def validate(path):
    errors = []
    try:
        data = json.loads(path.read_text())
    except Exception as exc:
        return [f'cannot read JSON: {exc}']
    def require(obj, *keys, label='field'):
        for key in keys:
            if key not in obj: errors.append(f'missing {label} {key}')
    require(data, 'manifest', 'run', 'source', 'artifact', 'toolchain', 'runtime', 'evidence', 'result', label='section')
    if errors: return errors
    require(data['manifest'], 'schema', 'schemaVersion', label='manifest field')
    if data['manifest'].get('schema') != 'com.brandongood.liferoute.native-qualification' or data['manifest'].get('schemaVersion') != 1:
        errors.append('unsupported schema/version')
    run, source, artifact, toolchain, runtime, evidence, result = (data[key] for key in ('run', 'source', 'artifact', 'toolchain', 'runtime', 'evidence', 'result'))
    require(run, 'gateID', 'harnessPath', 'harnessSHA256', 'argv', 'startedAt', 'finishedAt', 'exitCode', 'terminal', label='run field')
    require(source, 'repository', 'branch', 'state', 'commitSHA', 'treeSHA', 'clean', 'status', 'worktreeCount', 'inputs', label='source field')
    require(artifact, 'kind', 'configuration', 'platform', 'bundleIDs', 'productHashStatus', 'productManifest', 'archive', 'export', label='artifact field')
    require(runtime, 'class', 'simulator', 'runtimeIdentifier', label='runtime field')
    require(evidence, 'root', 'files', label='evidence field')
    require(result, 'status', 'limitations', 'nonClaims', 'ownerAcceptance', label='result field')
    try:
        start = datetime.fromisoformat(run['startedAt'].replace('Z', '+00:00'))
        end = datetime.fromisoformat(run['finishedAt'].replace('Z', '+00:00'))
        if end < start: errors.append('finishedAt precedes startedAt')
    except (KeyError, ValueError): errors.append('invalid timestamps')
    for field in ('commitSHA', 'treeSHA'):
        if not GIT_SHA.fullmatch(str(source.get(field, ''))): errors.append(f'invalid source {field}')
    repository = Path(str(source.get('repository', '')))
    if repository.is_dir() and (repository / '.git').exists():
        try:
            actual_commit = subprocess.check_output(['git', '-C', str(repository), 'rev-parse', str(source['commitSHA'])], text=True, stderr=subprocess.DEVNULL).strip()
            actual_tree = subprocess.check_output(['git', '-C', str(repository), 'rev-parse', f"{source['commitSHA']}^{{tree}}"], text=True, stderr=subprocess.DEVNULL).strip()
            if actual_commit != source['commitSHA'] or actual_tree != source['treeSHA']: errors.append('source commit/tree mismatch')
        except (OSError, subprocess.CalledProcessError):
            errors.append('source commit/tree unavailable')
    for field in ('harnessSHA256',):
        if not SHA256.fullmatch(str(run.get(field, ''))): errors.append(f'invalid {field}')
    if not isinstance(source.get('clean'), bool): errors.append('clean must be an explicit boolean')
    if source.get('clean') is True and source.get('status') not in ('', 'unavailable'): errors.append('dirty status represented as clean')
    if source.get('clean') is False and not source.get('status'): errors.append('dirty source lacks status disclosure')
    if not isinstance(source.get('worktreeCount'), int) or source['worktreeCount'] < 1: errors.append('invalid worktreeCount')
    for name, item in source.get('inputs', {}).items():
        if item.get('state') not in IDENTITY_STATES: errors.append(f'{name} has ambiguous identity state')
        if item.get('state') == 'present' and not SHA256.fullmatch(item.get('sha256', '')): errors.append(f'{name} hash invalid')
    status = result.get('status')
    if status not in STATUSES: errors.append('invalid result status')
    terminal = run.get('terminal', {})
    if status == 'PASS' and (run.get('exitCode') != 0 or terminal.get('status') != 'PASS' or not terminal.get('marker')): errors.append('PASS lacks terminal proof')
    if status != 'PASS' and run.get('exitCode') == 0: errors.append('non-PASS result has zero exit code')
    if result.get('ownerAcceptance') != 'NOT_EVALUATED': errors.append('ownerAcceptance must be NOT_EVALUATED')
    if runtime.get('class') != 'simulator': errors.append('first adopter runtime must be simulator')
    sim = runtime.get('simulator', {})
    for key in ('uuid', 'name', 'model', 'productType'):
        if not sim.get(key): errors.append(f'missing simulator {key}')
    if any(key in runtime for key in ('physical', 'device', 'udid', 'coreDeviceID')): errors.append('simulator manifest claims physical-device identity')
    for key in ('archive', 'export'):
        if artifact.get(key, {}).get('status') != 'not_applicable': errors.append(f'{key} must be not_applicable')
    root = Path(evidence['root'])
    listed = {item.get('path'): item for item in evidence['files']}
    for relative, item in listed.items():
        target = root / relative
        if not target.is_file(): errors.append(f'missing evidence {relative}')
        elif digest(target) != item.get('sha256') or target.stat().st_size != item.get('bytes'): errors.append(f'evidence hash/size mismatch {relative}')
    product = artifact.get('productManifest', {})
    if artifact.get('productHashStatus') == 'present':
        product_path = root / product.get('path', '')
        if not product_path.is_file(): errors.append('missing product manifest')
        else:
            try:
                rows = json.loads(product_path.read_text())
                if inventory_hash(rows) != product.get('sha256'): errors.append('product manifest hash mismatch')
                for row in rows:
                    product_file = root / 'BoardArtifactTests.app' / row['path']
                    if not product_file.is_file() or digest(product_file) != row['sha256'] or product_file.stat().st_size != row['bytes']: errors.append(f'product file mismatch {row.get("path")}')
            except Exception as exc: errors.append(f'invalid product manifest: {exc}')
    if not result.get('limitations') or not result.get('nonClaims'): errors.append('limitations/nonClaims required')
    return errors

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    failures = validate(args.manifest)
    if failures:
        for failure in failures: print(f'FAIL: {failure}')
        raise SystemExit(1)
    print(f'PASS: valid native qualification manifest {args.manifest}')
