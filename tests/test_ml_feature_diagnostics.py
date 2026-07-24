from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "analyze_feature_diagnostics.py"
SPEC = importlib.util.spec_from_file_location("ts7_feature_diagnostics", MODULE_PATH)
assert SPEC and SPEC.loader
DIAGNOSTICS = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = DIAGNOSTICS
SPEC.loader.exec_module(DIAGNOSTICS)


class FeatureDiagnosticTests(unittest.TestCase):
    def test_stability_requires_same_direction_in_each_run(self) -> None:
        rows = []
        for run_index, run_id in enumerate(("run-a", "run-b")):
            for index in range(20):
                positive = index >= 10
                rows.append(
                    {
                        "RunId": run_id,
                        "Barrier50Outcome": (
                            "FAVORABLE_FIRST" if positive else "ADVERSE_FIRST"
                        ),
                        "BusinessOutcome": (
                            "NO_RECOVERY" if positive else "RECOVERY_L4_PLUS"
                        ),
                        "Stable": str(index),
                        "Flips": str(index if run_index == 0 else 19 - index),
                    }
                )
        config = {
            "barrier_label": {
                "column": "Barrier50Outcome",
                "positive": "FAVORABLE_FIRST",
                "negative": "ADVERSE_FIRST",
            },
            "business_labels": {
                "no_recovery": "NO_RECOVERY",
                "l4_plus": "RECOVERY_L4_PLUS",
            },
            "minimum_run_auc_separation": 0.03,
        }

        summary, _ = DIAGNOSTICS.feature_diagnostics(
            rows, ["Stable", "Flips"], config
        )
        barrier = {
            row["Feature"]: row
            for row in summary
            if row["Target"] == "BARRIER_FAVORABLE"
        }

        self.assertTrue(barrier["Stable"]["StableAcrossRuns"])
        self.assertFalse(barrier["Flips"]["StableAcrossRuns"])

    def test_label_alignment_reports_business_relationship(self) -> None:
        rows = [
            {
                "Barrier50Outcome": "FAVORABLE_FIRST",
                "BusinessOutcome": "NO_RECOVERY",
            },
            {
                "Barrier50Outcome": "FAVORABLE_FIRST",
                "BusinessOutcome": "NO_RECOVERY",
            },
            {
                "Barrier50Outcome": "ADVERSE_FIRST",
                "BusinessOutcome": "RECOVERY_L4_PLUS",
            },
            {
                "Barrier50Outcome": "ADVERSE_FIRST",
                "BusinessOutcome": "RECOVERY_L1_L3",
            },
        ]
        config = {
            "barrier_label": {
                "column": "Barrier50Outcome",
                "positive": "FAVORABLE_FIRST",
                "negative": "ADVERSE_FIRST",
            },
            "business_labels": {
                "no_recovery": "NO_RECOVERY",
                "l4_plus": "RECOVERY_L4_PLUS",
            },
        }

        summary, table = DIAGNOSTICS.label_alignment(rows, config)

        self.assertEqual(summary["barrier_favorable_count"], 2)
        self.assertEqual(summary["l4_plus_count"], 1)
        self.assertGreater(
            summary["phi_barrier_favorable_vs_no_recovery"], 0.0
        )
        self.assertLess(summary["phi_barrier_favorable_vs_l4_plus"], 0.0)
        self.assertEqual(len(table), 6)


if __name__ == "__main__":
    unittest.main()
