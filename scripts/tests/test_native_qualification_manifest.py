#!/usr/bin/env python3
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'validate_native_qualification_manifest.py'
spec = importlib.util.spec_from_file_location('native_manifest_validator', MODULE)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class NativeManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        (root / 'BoardArtifactTests.app').mkdir()
        (root / 'BoardArtifactTests.app' / 'binary').write_bytes(b'product')
        (root / 'evidence.txt').write_text('evidence')
        rows = [{'path': 'binary', 'sha256': sha(root / 'BoardArtifactTests.app' / 'binary'), 'bytes': 7}]
        (root / 'PRODUCT_FILE_MANIFEST.json').write_text(json.dumps(rows))
        repository = Path(__file__).resolve().parents[2]
        commit = subprocess.check_output(['git', '-C', str(repository), 'rev-parse', 'HEAD'], text=True).strip()
        tree = subprocess.check_output(['git', '-C', str(repository), 'rev-parse', 'HEAD^{tree}'], text=True).strip()
        self.manifest = {
            'manifest': {'schema': 'com.brandongood.liferoute.native-qualification', 'schemaVersion': 1},
            'run': {'gateID': 'Q', 'harnessPath': 'runner.py', 'harnessSHA256': 'a' * 64, 'argv': ['runner.py'],
                    'startedAt': '2026-09-17T12:00:00Z', 'finishedAt': '2026-09-17T12:00:01Z', 'exitCode': 0,
                    'terminal': {'status': 'PASS', 'marker': 'PASS'}},
            'source': {'repository': str(repository), 'branch': 'main', 'state': 'branch', 'commitSHA': commit, 'treeSHA': tree,
                       'clean': True, 'status': '', 'worktreeCount': 1,
                       'inputs': {'production': {'state': 'present', 'sha256': 'd' * 64}, 'fixture': {'state': 'present', 'sha256': 'e' * 64}, 'harness': {'state': 'present', 'sha256': 'a' * 64}}},
            'artifact': {'kind': 'generated-simulator-test-product', 'configuration': 'Debug-fixture', 'platform': 'iphonesimulator', 'bundleIDs': ['test'],
                         'productHashStatus': 'present', 'productManifest': {'path': 'PRODUCT_FILE_MANIFEST.json', 'sha256': validator.inventory_hash(rows)},
                         'archive': {'status': 'not_applicable'}, 'export': {'status': 'not_applicable'}},
            'toolchain': {}, 'runtime': {'class': 'simulator', 'runtimeIdentifier': 'iOS-26',
                                         'simulator': {'uuid': 'u', 'name': 'iPhone', 'model': 'model', 'productType': 'type'}},
            'evidence': {'root': str(root), 'files': [{'path': 'evidence.txt', 'sha256': sha(root / 'evidence.txt'), 'bytes': 8},
                                                      {'path': 'PRODUCT_FILE_MANIFEST.json', 'sha256': sha(root / 'PRODUCT_FILE_MANIFEST.json'), 'bytes': (root / 'PRODUCT_FILE_MANIFEST.json').stat().st_size}]},
            'result': {'status': 'PASS', 'limitations': ['simulator only'], 'nonClaims': ['no physical'], 'ownerAcceptance': 'NOT_EVALUATED'},
        }

    def write(self, value=None):
        path = Path(self.temp.name) / 'NATIVE_QUALIFICATION_MANIFEST.json'
        path.write_text(json.dumps(value or self.manifest))
        return path

    def test_positive(self):
        self.assertEqual(validator.validate(self.write()), [])

    def assert_invalid(self, mutate):
        value = copy.deepcopy(self.manifest); mutate(value)
        self.assertTrue(validator.validate(self.write(value)))

    def test_wrong_sha_tree(self):
        self.assert_invalid(lambda m: m['source'].__setitem__('treeSHA', 'not-a-sha'))

    def test_changed_harness_fixture(self):
        self.assert_invalid(lambda m: m['source']['inputs']['fixture'].__setitem__('sha256', 'not-a-sha'))

    def test_missing_evidence(self):
        self.assert_invalid(lambda m: m['evidence']['files'][0].__setitem__('path', 'missing.txt'))

    def test_product_hash_mismatch(self):
        self.assert_invalid(lambda m: m['artifact']['productManifest'].__setitem__('sha256', 'f' * 64))

    def test_simulator_claims_physical_identity(self):
        self.assert_invalid(lambda m: m['runtime'].__setitem__('physical', {'udid': 'device'}))

    def test_pass_without_terminal_proof(self):
        self.assert_invalid(lambda m: m['run']['terminal'].__setitem__('status', 'FAIL'))

    def test_dirty_tree_represented_as_clean(self):
        self.assert_invalid(lambda m: m['source'].__setitem__('status', ' M file'))

if __name__ == '__main__':
    unittest.main()
