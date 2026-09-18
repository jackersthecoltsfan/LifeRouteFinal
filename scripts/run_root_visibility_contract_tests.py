#!/usr/bin/env python3
"""Compile exact production visibility, effect and Session Note declarations.

Only native-fact transport, model endpoints and feedback endpoints are fixtures.
The runtime, request race and visibility/ownership reducers remain production.
This is deterministic machine evidence; native gates remain separate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

from liferoute_storage import scratch_path
from simulator_console_capture import CAPTURE_INCOMPLETE, FAIL, PASS, capture_simctl_launch

ROOT = Path(__file__).resolve().parents[1]
ENV = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'),
           GIT_OPTIONAL_LOCKS='0', PYTHONDONTWRITEBYTECODE='1')
ENV.pop('SDKROOT', None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    assert out != ROOT and ROOT not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    calls = []

    def run(command):
        result = subprocess.run(command, env=ENV, cwd=ROOT, capture_output=True, text=True)
        calls.append(dict(command=command, exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
        (out/'commands.json').write_text(json.dumps(calls, indent=2)+'\n')
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    navigation = (ROOT/'LifeRoute/AppNavigation.swift').read_text()
    coordinator = (ROOT/'LifeRoute/LifeRouteVisualActivityCoordinator.swift').read_text()
    note = (ROOT/'LifeRoute/AIClinicalToolsViews.swift').read_text()
    persistence = (ROOT/'LifeRoute/PersistenceCore.swift').read_text()
    core = (ROOT/'LifeRoute/LifeRouteIntelligenceCore.swift').read_text()
    theme = (ROOT/'LifeRoute/V054ThemeCenterView.swift').read_text()
    media = (ROOT/'LifeRoute/SessionToolsViews.swift').read_text()
    tests = (ROOT/'scripts/root_visibility_contract_tests.swift').read_text()
    pieces = {
        'navigation': navigation[:navigation.index('// Checkpoint 06:')],
        'ambient': coordinator[:coordinator.index('#if DEBUG')],
        'contracts': (ROOT/'LifeRoute/SessionNoteContracts.swift').read_text(),
        'draft_persistence_contract': persistence.split(
            '// BEGIN SESSION NOTE DRAFT PERSISTENCE CONTRACT', 1
        )[1].split('// END SESSION NOTE DRAFT PERSISTENCE CONTRACT', 1)[0],
        'core_declarations': core[core.index('// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS'):core.index('enum LifeRouteIntelligenceCore {')],
        'note_protocol': note[note.index('enum SessionNoteGenerationState:'):note.index('@MainActor\nfinal class FoundationModelSessionNoteGenerator')],
        'beta_drafting_adapter': note[note.index('@MainActor\nfinal class BetaSafeDeterministicSessionNoteGenerator'):note.index('@MainActor\nfinal class AISessionNoteRuntimeModel')],
        'note_runtime': note[note.index('@MainActor\nfinal class AISessionNoteRuntimeModel:'):note.index('#if DEBUG\n@MainActor\nprivate final class SessionNoteFixtureGenerator')],
        'theme_episode': theme.split('// BEGIN THEME VISIBILITY EPISODE',1)[1].split('// END THEME VISIBILITY EPISODE',1)[0],
        'media_admission': media.split('// BEGIN MEDIA VISIBILITY ADMISSION',1)[1].split('private struct LifeRoutePhotoSelection:',1)[0],
    }
    # Compile the actual selected-photo task and publication adapter. Only the
    # asynchronous photo/cache endpoints and SwiftUI state transport are fixtures.
    def media_part(start, end):
        return media[media.index(start):media.index(end, media.index(start))]
    assert '.task(id: LifeRoutePhotoActivity(item: selectedPhotoItem,' in media
    assert 'input: [clientCode, label, visualDescription], active: visibility.active)) {\n            await loadSelectedPhoto()' in media
    pieces['photo_activity'] = media_part('private struct LifeRoutePhotoSelection:', 'private struct LifeRouteThumbnailActivity:')
    pieces['photo_adapter'] = ('@MainActor\nprivate final class PhotoAdapterFixture: PhotoAdapterState {\n'
        + media_part('    private var inputSignature: [String]', '    @Environment(\\.lifeRoutePalette)')
        + media_part('    @MainActor\n    private func loadSelectedPhoto()', '    private func inputMethodLabel(')
        + media_part('    @MainActor\n    private func prepareReferencePhoto(', '    private func clearReferencePhoto()')
        + '    func start() async { await loadSelectedPhoto() }\n'
        + '    func inputChanged() { media.update(inputSignature) }\n}\n')
    sources = ['LifeRoute/AppNavigation.swift','LifeRoute/LifeRouteVisualActivityCoordinator.swift',
               'LifeRoute/SessionNoteContracts.swift','LifeRoute/LifeRouteIntelligenceCore.swift',
               'LifeRoute/AIClinicalToolsViews.swift','LifeRoute/PersistenceCore.swift',
               'LifeRoute/V054ThemeCenterView.swift',
               'LifeRoute/SessionToolsViews.swift','scripts/root_visibility_contract_tests.swift',
               'scripts/run_root_visibility_contract_tests.py']
    manifest = {
        'production_extractions': {key:dict(sha256=hashlib.sha256(value.encode()).hexdigest(),bytes=len(value.encode())) for key,value in pieces.items()},
        'source_files': {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sources},
        'limitations': 'Exact production visibility owner, scope/feedback/media/Theme adapters, Session Note runtime and protected request race. Native fact transport and model/feedback endpoints are fixtures. Not actual-app or FoundationModels quality acceptance.',
    }
    (out/'extraction.json').write_text(json.dumps(manifest,indent=2)+'\n')
    # File-private declarations stay in one translation unit with the tests.
    source = out/'main.swift'
    source.write_text('import SwiftUI\nimport UIKit\nimport Combine\nimport OSLog\n'+ '\n'.join(pieces.values())+'\n'+tests)
    sdk = run(['xcrun','--sdk','iphonesimulator','--show-sdk-path']).strip()
    app = out/'RootVisibilityTests.app'
    app.mkdir()
    (app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.liferoute.RootVisibilityTests',
        CFBundleExecutable='RootVisibilityTests',CFBundleName='Root Visibility Tests',CFBundlePackageType='APPL',
        CFBundleVersion='1',CFBundleShortVersionString='1.0',MinimumOSVersion='16.0',
        LSRequiresIPhoneOS=True,UIDeviceFamily=[1],UILaunchScreen={},
        UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False},
        UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'])))
    module_cache = scratch_path('contract-fixtures/root-visibility/module-cache')
    module_cache.mkdir(parents=True, exist_ok=True)
    run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios16.0-simulator','-swift-version','5','-D','DEBUG',
         '-module-cache-path',str(module_cache),str(source),'-o',str(app/'RootVisibilityTests')])
    run(['codesign','--force','--sign','-',str(app)])
    run(['xcrun','simctl','install',args.simulator,str(app)])
    capture = capture_simctl_launch(
        simulator=args.simulator,
        bundle_id='local.liferoute.RootVisibilityTests',
        arguments=['-LifeRouteRootOwnershipTrace'],
        stdout_path=out/'stdout.log',
        stderr_path=out/'stderr.log',
        timeout_seconds=55,
        pass_markers=('ROOT_VISIBILITY_TEST_PASS',),
        fail_markers=('ROOT_VISIBILITY_TEST_FAIL',),
        env=ENV,
        cwd=ROOT,
    )
    calls.extend(capture.commands)
    (out/'commands.json').write_text(json.dumps(calls, indent=2)+'\n')
    if capture.state == PASS:
        print(capture.marker)
        return
    if capture.state == FAIL:
        raise AssertionError(capture.marker)
    assert capture.state == CAPTURE_INCOMPLETE
    raise AssertionError(f'{CAPTURE_INCOMPLETE}: {capture.reason}')


if __name__ == '__main__':
    main()
