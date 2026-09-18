#!/usr/bin/env python3
import json
import os
import plistlib
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_ROOT))

import testflight_recovery_bundle as recovery  # noqa: E402


SOURCE_SHA = "a" * 40
TREE_SHA = "b" * 40
APP_UUIDS = ["11111111-1111-1111-1111-111111111111"]
WIDGET_UUIDS = ["22222222-2222-2222-2222-222222222222"]
APP_DEBUG_DYLIB_UUID = "33333333-3333-3333-3333-333333333333"
WIDGET_DEBUG_DYLIB_UUID = "44444444-4444-4444-4444-444444444444"


class RecoveryBundleTests(unittest.TestCase):
    def fixture(self, missing_widget_dsym=False, mismatched_widget_dsym=False):
        root = Path(tempfile.mkdtemp(prefix="liferoute-recovery-test-"))
        archive = root / "LifeRoute.xcarchive"
        app = archive / "Products" / "Applications" / "Demo.app"
        widget = app / "PlugIns" / "DemoLiveActivityWidget.appex"
        dsyms = archive / "dSYMs"
        app_dsym = dsyms / "Demo.app.dSYM"
        widget_dsym = dsyms / "DemoLiveActivityWidget.appex.dSYM"

        app_info = {
            "CFBundleIdentifier": "Com.Test.Demo",
            "CFBundleShortVersionString": "0.9.1",
            "CFBundleVersion": "127",
            "CFBundleExecutable": "Demo",
        }
        widget_info = {
            "CFBundleIdentifier": "Com.Test.Demo.Live",
            "CFBundleShortVersionString": "0.9.1",
            "CFBundleVersion": "127",
            "CFBundleExecutable": "DemoLiveActivityWidget",
        }

        for path, value in [
            (archive / "Info.plist", {}),
            (app / "Info.plist", app_info),
            (widget / "Info.plist", widget_info),
        ]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(plistlib.dumps(value))
        (app / "embedded.mobileprovision").write_bytes(b"synthetic-profile-not-retained")
        (app / "Demo").write_bytes(b"app-mach-o")
        (widget / "DemoLiveActivityWidget").write_bytes(b"widget-mach-o")
        (app_dsym / "Contents" / "Resources" / "DWARF").mkdir(parents=True)
        (app_dsym / "Contents" / "Resources" / "DWARF" / "Demo").write_bytes(b"app-dsym")
        if not missing_widget_dsym:
            (widget_dsym / "Contents" / "Resources" / "DWARF").mkdir(parents=True)
            (widget_dsym / "Contents" / "Resources" / "DWARF" / "DemoLiveActivityWidget").write_bytes(b"widget-dsym")

        ipa = root / "Demo-127.ipa"
        with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive_zip:
            archive_zip.writestr("Payload/Demo.app/Info.plist", plistlib.dumps(app_info))
            archive_zip.writestr("Payload/Demo.app/Demo", b"app-mach-o")
            archive_zip.writestr("Payload/Demo.app/PlugIns/DemoLiveActivityWidget.appex/Info.plist", plistlib.dumps(widget_info))
            archive_zip.writestr("Payload/Demo.app/PlugIns/DemoLiveActivityWidget.appex/DemoLiveActivityWidget", b"widget-mach-o")

        uuid_map = {
            str((app / "Demo").resolve()): APP_UUIDS,
            str(app_dsym.resolve()): APP_UUIDS + [APP_DEBUG_DYLIB_UUID],
            str((widget / "DemoLiveActivityWidget").resolve()): WIDGET_UUIDS,
        }
        if not missing_widget_dsym:
            uuid_map[str(widget_dsym.resolve())] = (
                ["33333333-3333-3333-3333-333333333333"]
                if mismatched_widget_dsym
                else WIDGET_UUIDS + [WIDGET_DEBUG_DYLIB_UUID]
            )
        uuid_tool = root / "dwarfdump"
        uuid_tool.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "values = json.loads(os.environ['FAKE_UUID_MAP'])[sys.argv[-1]]\n"
            "for value in values: print(f'UUID: {value} (arm64) {sys.argv[-1]}')\n",
            encoding="utf-8",
        )
        uuid_tool.chmod(uuid_tool.stat().st_mode | stat.S_IXUSR)
        return root, archive, ipa, uuid_tool, uuid_map

    def command(self, root, archive, ipa, uuid_tool, uuid_map, output):
        args = [
            sys.executable,
            str(SCRIPT_ROOT / "testflight_recovery_bundle.py"),
            "--archive",
            str(archive),
            "--ipa",
            str(ipa),
            "--export-directory",
            str(root / "export"),
            "--output",
            str(output),
            "--source-sha",
            SOURCE_SHA,
            "--source-tree-sha",
            TREE_SHA,
            "--source-ref",
            "refs/heads/main",
            "--source-branch",
            "main",
            "--marketing-version",
            "0.9.1",
            "--build-number",
            "127",
            "--app-bundle-id",
            "Com.Test.Demo",
            "--widget-bundle-id",
            "Com.Test.Demo.Live",
            "--repository",
            "owner/repo",
            "--workflow",
            "Send to TestFlight",
            "--run-id",
            "12345",
            "--run-number",
            "127",
            "--run-attempt",
            "1",
            "--workflow-ref",
            "owner/repo/.github/workflows/testflight.yml@refs/heads/main",
            "--timestamp",
            "2026-09-18T12:00:00Z",
            "--uuid-tool",
            str(uuid_tool),
        ]
        environment = os.environ.copy()
        environment["FAKE_UUID_MAP"] = json.dumps(uuid_map)
        return subprocess.run(args, capture_output=True, text=True, env=environment)

    def test_manifest_hashes_and_uuid_pairs(self):
        root, archive, ipa, uuid_tool, uuid_map = self.fixture()
        output = root / "recovery"
        result = self.command(root, archive, ipa, uuid_tool, uuid_map, output)
        self.assertEqual(result.returncode, 0, result.stderr)

        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["source"]["commitSha"], SOURCE_SHA)
        self.assertEqual(manifest["source"]["treeSha"], TREE_SHA)
        self.assertTrue(manifest["validation"]["applicationUuidMatch"])
        self.assertTrue(manifest["validation"]["widgetUuidMatch"])
        self.assertEqual(manifest["symbols"]["app"]["binaryUuids"], APP_UUIDS)
        self.assertEqual(manifest["symbols"]["app"]["matchedUuids"], APP_UUIDS)
        self.assertEqual(manifest["symbols"]["widget"]["matchedUuids"], WIDGET_UUIDS)
        self.assertIn(WIDGET_DEBUG_DYLIB_UUID, manifest["symbols"]["widget"]["dsymUuids"])

        ipa_hash, _ = recovery.file_sha256(output / manifest["artifacts"]["ipa"]["path"])
        self.assertEqual(ipa_hash, manifest["artifacts"]["ipa"]["sha256"])
        dsym_path = output / manifest["artifacts"]["applicationDsym"]["path"]
        dsym_hash, _, _ = recovery.directory_sha256(dsym_path)
        self.assertEqual(dsym_hash, manifest["artifacts"]["applicationDsym"]["sha256"])
        self.assertTrue((output / "archive-source" / "dSYMs").is_dir())
        self.assertFalse(any(path.name == "embedded.mobileprovision" for path in output.rglob("*")))

        receipt = (output / "RECEIPT.md").read_text(encoding="utf-8")
        self.assertNotIn("PRIVATE_KEY", receipt)
        self.assertNotIn("FAKE_UUID_MAP", receipt)
        self.assertNotIn("SECRET_VALUE", receipt)
        self.assertNotIn("BEGIN PRIVATE KEY", receipt)

    def test_missing_widget_dsym_fails_closed(self):
        root, archive, ipa, uuid_tool, uuid_map = self.fixture(missing_widget_dsym=True)
        output = root / "recovery"
        result = self.command(root, archive, ipa, uuid_tool, uuid_map, output)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No widget dSYM matched", result.stderr)
        self.assertFalse(output.exists())

    def test_mismatched_widget_dsym_fails_closed(self):
        root, archive, ipa, uuid_tool, uuid_map = self.fixture(mismatched_widget_dsym=True)
        output = root / "recovery"
        result = self.command(root, archive, ipa, uuid_tool, uuid_map, output)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No widget dSYM matched", result.stderr)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
