from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "create_collection_context.py"
SPEC = importlib.util.spec_from_file_location("ts7_create_collection_context", MODULE_PATH)
assert SPEC and SPEC.loader
CONTEXT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CONTEXT
SPEC.loader.exec_module(CONTEXT)


class CollectionContextTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.run_dir = self.root / "run-a"
        self.run_dir.mkdir()
        self.preset = self.root / "baseline.set"
        self.ea = self.root / "testing_strat_7.ex5"
        self.report = self.root / "report.htm"
        self.dependency = self.root / "cci.ex5"
        self.preset.write_bytes(b"preset")
        self.ea.write_bytes(b"ea")
        self.report.write_bytes(b"report")
        self.dependency.write_bytes(b"dependency")
        preset_hash = hashlib.sha256(b"preset").hexdigest().upper()
        (self.run_dir / "run_manifest.json").write_text(
            json.dumps({"run_id": "run-a", "preset_sha256": preset_hash}),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def arguments(self) -> list[str]:
        return [
            "--run-dir", str(self.run_dir),
            "--from-date", "2026.01.01",
            "--to-date", "2026.02.01",
            "--initial-deposit", "4000",
            "--final-balance", "4100",
            "--currency", "USD",
            "--leverage", "1:500",
            "--candidate-count", "10",
            "--preset", str(self.preset),
            "--ea-ex5", str(self.ea),
            "--report", str(self.report),
            "--dependency", f"cciCustomFix/cciCustomFix.ex5={self.dependency}",
        ]

    def test_context_hashes_actual_artifacts(self) -> None:
        result = CONTEXT.main(self.arguments())

        self.assertEqual(result, 0)
        context = json.loads(
            (self.run_dir / "collection_context.json").read_text(encoding="utf-8")
        )
        self.assertEqual(context["run_id"], "run-a")
        self.assertEqual(
            context["artifacts"]["preset"]["sha256"],
            hashlib.sha256(b"preset").hexdigest().upper(),
        )
        self.assertNotIn(str(self.root), json.dumps(context))

    def test_preset_hash_mismatch_does_not_write_context(self) -> None:
        manifest_path = self.run_dir / "run_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["preset_sha256"] = "0" * 64
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        result = CONTEXT.main(self.arguments())

        self.assertEqual(result, 3)
        self.assertFalse((self.run_dir / "collection_context.json").exists())


if __name__ == "__main__":
    unittest.main()
