from __future__ import annotations

import copy
import csv
import importlib.util
import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "train_dual_business_models.py"
SPEC = importlib.util.spec_from_file_location("ts7_dual_business_models", MODULE_PATH)
assert SPEC and SPEC.loader
DUAL = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = DUAL
SPEC.loader.exec_module(DUAL)


def load_config() -> dict:
    return DUAL.baseline.read_config(
        REPO_ROOT / "config" / "ml-phase3-dual-business-v2.json"
    )


def business_row(
    index: int,
    outcome: str,
    *,
    original_profit: float | None = None,
) -> dict[str, str]:
    profit = (
        original_profit
        if original_profit is not None
        else (5.0 if outcome == "NO_RECOVERY" else -5.0)
    )
    return {
        "SetupId": f"setup-{index}",
        "CandidateTime": f"2026.01.{index + 1:02d} 01:00:00",
        "BusinessOutcome": outcome,
        "OriginalNetProfit": str(profit),
        "CycleNetProfit": "5.0",
    }


class DualBusinessModelTests(unittest.TestCase):
    def test_project_config_is_valid_and_leakage_free(self) -> None:
        config = load_config()

        DUAL.validate_config(config)

        features = {
            *config["feature_contract"]["numeric"],
            *config["feature_contract"]["boolean"],
            *config["feature_contract"]["categorical"],
        }
        self.assertEqual(config["dataset_schema"], "ts7_entry_candidate_v2")
        self.assertNotIn("BusinessOutcome", features)
        self.assertNotIn("MaxRecoveryLevel", features)
        self.assertFalse(
            config["dual_targets"]["no_recovery"]["balance_training"]
        )
        self.assertTrue(config["dual_targets"]["l4_risk"]["balance_training"])
        self.assertEqual(
            config["dual_threshold_selection"]["objective_order"],
            [
                "relative_recovery_rate_reduction",
                "original_win_rate_delta",
                "relative_l4_given_recovery_reduction",
                "l4_plus_rejection_rate",
            ],
        )

    def test_class_balancing_is_deterministic_and_balanced(self) -> None:
        matrix = [[float(index)] for index in range(10)]
        labels = [0] * 8 + [1] * 2

        first = DUAL.balance_training_data(matrix, labels, True, 42)
        second = DUAL.balance_training_data(matrix, labels, True, 42)

        self.assertEqual(first, second)
        self.assertEqual(first[1].count(0), 8)
        self.assertEqual(first[1].count(1), 8)
        self.assertEqual(
            first[2]["mode"], "DETERMINISTIC_MINORITY_OVERSAMPLE"
        )
        self.assertEqual(first[2]["original_class_counts"], {"0": 8, "1": 2})

    def test_dual_decision_requires_both_target_conditions(self) -> None:
        decisions = DUAL.dual_decisions(
            [0.8, 0.8, 0.4, 0.9],
            [0.1, 0.7, 0.1, 0.2],
            0.6,
            0.3,
        )

        self.assertEqual(decisions, [True, False, False, True])

    def test_business_metrics_measure_l4_within_recovery(self) -> None:
        rows = [
            business_row(0, "NO_RECOVERY"),
            business_row(1, "NO_RECOVERY"),
            business_row(2, "RECOVERY_L1_L3"),
            business_row(3, "RECOVERY_L1_L3"),
            business_row(4, "RECOVERY_L4_PLUS"),
            business_row(5, "RECOVERY_L4_PLUS"),
        ]

        metrics = DUAL.business_metrics(
            rows, [True, True, True, True, False, True]
        )

        self.assertAlmostEqual(metrics["winner_rejection_rate"], 0.0)
        self.assertAlmostEqual(metrics["l4_plus_rejection_rate"], 0.5)
        self.assertAlmostEqual(metrics["baseline_l4_given_recovery_rate"], 0.5)
        self.assertAlmostEqual(
            metrics["allowed_l4_given_recovery_rate"], 1.0 / 3.0
        )
        self.assertAlmostEqual(
            metrics["relative_l4_given_recovery_reduction"], 1.0 / 3.0
        )

    def test_threshold_search_uses_both_probabilities_and_respects_limits(self) -> None:
        rows = [
            *[business_row(index, "NO_RECOVERY") for index in range(5)],
            *[
                business_row(index, "RECOVERY_L1_L3")
                for index in range(5, 8)
            ],
            *[
                business_row(index, "RECOVERY_L4_PLUS")
                for index in range(8, 10)
            ],
        ]
        no_recovery = [0.9] * 5 + [0.55] * 3 + [0.2] * 2
        l4_risk = [0.05] * 5 + [0.25] * 3 + [0.9] * 2
        config = load_config()

        selected = DUAL.choose_dual_thresholds(
            rows,
            no_recovery,
            l4_risk,
            config["dual_threshold_selection"],
            config["acceptance_gates"],
        )

        self.assertTrue(selected["feasible"])
        metrics = selected["validation_business"]
        self.assertLessEqual(metrics["winner_rejection_rate"], 0.1)
        self.assertGreaterEqual(metrics["l4_plus_rejection_rate"], 0.2)
        self.assertGreaterEqual(
            metrics["relative_recovery_rate_reduction"], 0.1
        )
        self.assertLess(selected["l4_risk_threshold"], 0.9)

    def test_gate_requires_conditional_deep_recovery_improvement(self) -> None:
        config = load_config()["acceptance_gates"]
        metrics = {
            "retained_fraction": 0.8,
            "winner_rejection_rate": 0.05,
            "active_day_retention": 0.9,
            "original_win_rate_delta": 0.04,
            "relative_recovery_rate_reduction": 0.12,
            "l4_plus_rejection_rate": 0.25,
            "relative_l4_given_recovery_reduction": 0.1,
        }

        gates = DUAL.gate_results(metrics, config)

        self.assertFalse(gates["relative_l4_given_recovery_reduction_min"])
        self.assertFalse(gates["all"])

    def test_small_experiment_is_deterministic(self) -> None:
        config = load_config()
        config["minimum_rows"] = 100
        config["split"].update(
            {
                "fold_count": 2,
                "initial_history_fraction": 0.5,
                "evaluation_fraction": 0.25,
                "minimum_partition_rows": 10,
            }
        )
        config["models"]["logistic_regression"]["max_iterations"] = 80
        config["models"]["shallow_random_forest"].update(
            {
                "trees": 3,
                "max_depth": 2,
                "min_leaf": 5,
                "max_thresholds": 4,
            }
        )
        config["calibration"]["max_iterations"] = 80
        config["dual_threshold_selection"]["max_candidates_per_target"] = 8
        contract = config["feature_contract"]
        fields = {
            "SchemaVersion",
            "SetupId",
            "StrategyVersion",
            "SourceRevision",
            "CandidateTime",
            "SignalTime",
            "BusinessOutcome",
            "OriginalNetProfit",
            "CycleNetProfit",
            config["primary_label"]["column"],
            *contract["numeric"],
            *contract["boolean"],
            *contract["categorical"],
        }
        fieldnames = sorted(fields)
        start = datetime(2025, 9, 1)
        rows = []
        for index in range(240):
            remainder = index % 10
            outcome = (
                "NO_RECOVERY"
                if remainder < 5
                else (
                    "RECOVERY_L1_L3"
                    if remainder < 9
                    else "RECOVERY_L4_PLUS"
                )
            )
            candidate_time = start + timedelta(hours=index)
            row = {field: "1" for field in fieldnames}
            row.update(
                {
                    "SchemaVersion": config["dataset_schema"],
                    "SetupId": f"setup-{index}",
                    "StrategyVersion": "fixture",
                    "SourceRevision": "abcdef1",
                    "CandidateTime": candidate_time.strftime(
                        "%Y.%m.%d %H:%M:%S"
                    ),
                    "SignalTime": (
                        candidate_time - timedelta(minutes=1)
                    ).strftime("%Y.%m.%d %H:%M:%S"),
                    "Direction": "1" if index % 2 else "-1",
                    "BusinessOutcome": outcome,
                    "OriginalNetProfit": (
                        "5" if outcome == "NO_RECOVERY" else "-5"
                    ),
                    "CycleNetProfit": "5",
                    config["primary_label"]["column"]: (
                        config["primary_label"]["positive"]
                        if outcome == "NO_RECOVERY"
                        else config["primary_label"]["negative"]
                    ),
                    "CciSignalType": "NORMAL",
                    "LateConfirmMask": str(index % 4),
                    "DataIntegrityFlag": "VERIFIED",
                }
            )
            for field in contract["boolean"]:
                row[field] = "true" if index % 2 else "false"
            for offset, field in enumerate(contract["numeric"]):
                if field != "Direction":
                    row[field] = str((index % 13) + offset / 100.0)
            rows.append(row)

        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            dataset = root / "merged_candidates.csv"
            with dataset.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(rows)

            first = DUAL.run_experiment(
                dataset,
                root / "output-a",
                copy.deepcopy(config),
                root / "fake-repository",
            )
            second = DUAL.run_experiment(
                dataset,
                root / "output-b",
                copy.deepcopy(config),
                root / "fake-repository",
            )

            self.assertEqual(first["pairings"], second["pairings"])
            self.assertEqual(
                first["evaluation_fold_results"],
                second["evaluation_fold_results"],
            )
            self.assertEqual(first["development_leader"], second["development_leader"])
            self.assertTrue(
                (root / "output-a" / "experiment_manifest.json").is_file()
            )


if __name__ == "__main__":
    unittest.main()
