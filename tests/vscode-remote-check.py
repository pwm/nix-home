#!/usr/bin/env python3
"""Exercise remote extension registration without touching the live editor."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "hm/programs/vscode/remote-extensions.py"
CODE_SERVER = None


class RegistrationChecks(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="vscode remote check ")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.extensions = self.root / "extensions"
        self.extensions.mkdir()
        self.desired = self.root / "desired.json"
        self.registry = self.extensions / "extensions.json"

    def package(self, path, identifier, version):
        publisher, name = identifier.split(".")
        path.mkdir(parents=True)
        (path / "package.json").write_text(json.dumps({
            "publisher": publisher,
            "name": name,
            "version": version,
            "engines": {"vscode": "^1.80.0"},
            "contributes": {"languages": [{"id": identifier, "extensions": [".zzt"]}]},
        }))
        return {
            "identifier": {"id": identifier},
            "version": version,
            "location": {"$mid": 1, "path": str(path), "scheme": "file"},
            "metadata": {"targetPlatform": "undefined"},
        }

    def declared(self, version="1.0.0"):
        entry = self.package(self.root / f"source-{version}", "test.managed", version)
        link = self.extensions / ".nix-home" / "test.managed"
        link.parent.mkdir(exist_ok=True)
        if link.is_symlink():
            link.unlink()
        link.symlink_to(entry["location"]["path"])
        self.desired.write_text(json.dumps([entry]))
        return entry

    def run_helper(self, succeeds=True):
        result = subprocess.run(
            ["python3", str(HELPER), str(self.extensions), str(self.desired)],
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
        return result

    def test_registration_preserves_extras_and_is_idempotent(self):
        extra = self.package(self.extensions / "test.extra-1.0.0", "test.extra", "1.0.0")
        extra["metadata"]["privateSetting"] = {"preserved": True}
        old = self.package(self.extensions / "test.managed-9.0.0", "TEST.managed", "9.0.0")
        self.registry.write_text(json.dumps([extra, old]))
        self.declared()
        self.run_helper()
        registered = json.loads(self.registry.read_text())
        self.assertEqual(registered[0], extra)
        self.assertEqual(registered[1]["version"], "1.0.0")
        self.assertTrue(registered[1]["metadata"]["pinned"])
        self.assertTrue((self.extensions / "test.managed-9.0.0").is_dir())
        before = self.registry.read_bytes(), self.registry.stat().st_ino
        self.run_helper()
        self.assertEqual((self.registry.read_bytes(), self.registry.stat().st_ino), before)

    def test_upgrade_rollback_and_removal(self):
        self.declared()
        self.run_helper()
        self.declared("2.0.0")
        self.run_helper()
        self.assertEqual(json.loads(self.registry.read_text())[0]["version"], "2.0.0")
        link = self.extensions / ".nix-home/test.managed"
        link.unlink()
        link.symlink_to(self.root / "source-1.0.0")
        current = json.loads(self.desired.read_text())[0]
        current["version"] = "1.0.0"
        current["location"]["path"] = str(self.root / "source-1.0.0")
        self.desired.write_text(json.dumps([current]))
        self.run_helper()
        self.assertEqual(json.loads(self.registry.read_text())[0]["version"], "1.0.0")
        self.desired.write_text("[]")
        link.unlink()
        self.run_helper()
        self.assertEqual(json.loads(self.registry.read_text()), [])

    def test_fresh_registry_keeps_existing_manual_extensions(self):
        self.package(self.extensions / "test.extra-1.0.0", "test.extra", "1.0.0")
        self.declared()
        self.run_helper()
        self.assertEqual(
            {entry["identifier"]["id"] for entry in json.loads(self.registry.read_text())},
            {"test.extra", "test.managed"},
        )

    def test_invalid_registry_is_not_overwritten(self):
        self.declared()
        for invalid in ["not json", "{}", '[{"identifier": "bad"}]']:
            with self.subTest(invalid=invalid):
                self.registry.write_text(invalid)
                self.run_helper(False)
                self.assertEqual(self.registry.read_text(), invalid)
        self.assertFalse(list(self.extensions.glob(".extensions-*")))

    def test_link_and_scope_mismatch_refuse_before_registry_write(self):
        self.declared()
        self.registry.write_text("[]")
        link = self.extensions / ".nix-home/test.managed"
        link.unlink()
        link.symlink_to(self.root / "missing")
        self.run_helper(False)
        self.assertEqual(self.registry.read_text(), "[]")
        namespace = self.extensions / ".nix-home"
        link.unlink()
        namespace.rmdir()
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        namespace.symlink_to(elsewhere)
        self.run_helper(False)
        self.assertEqual(self.registry.read_text(), "[]")
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_registry_symlink_is_not_followed(self):
        self.declared()
        external = self.root / "external.json"
        external.write_text("[]")
        self.registry.symlink_to(external)
        self.run_helper(False)
        self.assertEqual(external.read_text(), "[]")

    def test_actual_vscode_discovers_pins_and_extra_on_first_connection(self):
        if not CODE_SERVER:
            self.skipTest("pass --code-server PATH for actual VS Code discovery")
        self.package(self.extensions / "test.extra-1.0.0", "test.extra", "1.0.0")
        self.package(self.extensions / "test.managed-9.0.0", "test.managed", "9.0.0")
        self.declared()
        self.run_helper()
        result = subprocess.run([
            CODE_SERVER, "--server-data-dir", str(self.root / "server-data"),
            "--user-data-dir", str(self.root / "user-data"),
            "--extensions-dir", str(self.extensions), "--telemetry-level", "off",
            "--list-extensions", "--show-versions",
        ], text=True, capture_output=True, check=True)
        self.assertEqual(set(result.stdout.splitlines()), {"test.extra@1.0.0", "test.managed@1.0.0"})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--code-server")
    args = parser.parse_args()
    CODE_SERVER = args.code_server
    unittest.main(argv=[__file__], verbosity=2)
