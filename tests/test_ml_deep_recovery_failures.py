from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "analyze_deep_recovery_failures.py"
SPEC = importlib.util.spec_from_file_location("ts7_deep_recovery", MODULE_PATH)
assert SPEC and SPEC.loader
ANALYZER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = ANALYZER
SPEC.loader.exec_module(ANALYZER)


class DeepRecoveryFailureTests(unittest.TestCase):
    def test_auc_handles_ties(self) -> None:
        self.assertAlmostEqual(
            ANALYZER.auc([0, 0, 1, 1], [0.0, 0.5, 0.5, 1.0]),
            0.875,
        )

    def test_consensus_marks_only_recurring_allowed_l4(self) -> None:
        predictions = []
        for setup_id, outcome, allowed_count in (
            ("deep", "RECOVERY_L4_PLUS", 5),
            ("shallow", "RECOVERY_L1_L3", 5),
            ("caught", "RECOVERY_L4_PLUS", 1),
        ):
            for index in range(6):
                predictions.append(
                    {
                        "Family": f"family-{index // 2}",
                        "Pairing": f"pair-{index % 2}",
                        "SetupId": setup_id,
                        "CandidateTime": "2026.01.01 00:00:00",
                        "Fold": 1,
                        "BusinessOutcome": outcome,
                        "Allowed": index < allowed_count,
                        "NoRecoveryProbability": 0.8,
                        "NoRecoveryThreshold": 0.5,
                        "L4RiskProbability": 0.2 if index < allowed_count else 0.8,
                        "L4RiskThreshold": 0.5,
                    }
                )
        config = {
            "prediction_artifacts": {
                "family-0": "a",
                "family-1": "b",
                "family-2": "c",
            },
            "pairings": ["pair-0", "pair-1"],
            "persistent_allowed_fraction_min": 0.8,
            "l4_outcome": "RECOVERY_L4_PLUS",
        }

        candidates, matrix = ANALYZER.consensus_diagnostics(
            predictions, config
        )
        by_id = {row["SetupId"]: row for row in candidates}

        self.assertTrue(by_id["deep"]["PersistentL4Escape"])
        self.assertFalse(by_id["caught"]["PersistentL4Escape"])
        self.assertFalse(by_id["shallow"]["PersistentL4Escape"])
        self.assertEqual(len(matrix), 6)

    def test_pair_orientation_is_discovered_once_and_confirmed_later(self) -> None:
        rows = []
        for run_index, run_id in enumerate(("earlier", "later")):
            for index in range(20):
                deep = index >= 15
                risk = index + run_index * 0.01
                rows.append(
                    {
                        "RunId": run_id,
                        "SetupId": f"{run_id}-{index}",
                        "CandidateTime": (
                            f"2025.01.01 00:{index:02d}:00"
                            if run_id == "earlier"
                            else f"2026.01.01 00:{index:02d}:00"
                        ),
                        "BusinessOutcome": (
                            "RECOVERY_L4_PLUS"
                            if deep
                            else "RECOVERY_L1_L3"
                        ),
                        "A": str(risk),
                        "B": str(risk * 2.0),
                        "Noise": str((index * 7) % 11),
                    }
                )
        config = {
            "l4_outcome": "RECOVERY_L4_PLUS",
            "stable_pair_auc_min": 0.8,
        }

        results = ANALYZER.pair_interactions(
            rows, ["A", "B", "Noise"], config
        )
        by_pair = {
            (row["FeatureA"], row["FeatureB"]): row for row in results
        }

        self.assertTrue(by_pair[("A", "B")]["StableConfirmation"])
        self.assertEqual(by_pair[("A", "B")]["OrientationA"], 1)
        self.assertGreaterEqual(by_pair[("A", "B")]["Run2AUC"], 0.8)


if __name__ == "__main__":
    unittest.main()
