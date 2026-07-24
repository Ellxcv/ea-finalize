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
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "train_baseline_models.py"
SPEC = importlib.util.spec_from_file_location("ts7_train_baseline_models", MODULE_PATH)
assert SPEC and SPEC.loader
TRAIN = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = TRAIN
SPEC.loader.exec_module(TRAIN)


def load_config() -> dict:
    return json.loads(
        (REPO_ROOT / "config" / "ml-phase3-baseline.json").read_text(encoding="utf-8")
    )


def chronological_rows(count: int) -> list[dict[str, object]]:
    start = datetime(2026, 1, 1)
    return [
        {
            "SetupId": f"setup-{index}",
            "SignalTime": (start + timedelta(hours=index)).strftime("%Y.%m.%d %H:%M:%S"),
            "Direction": str(1 if index % 2 else -1),
            "_CandidateDateTime": start + timedelta(hours=index),
        }
        for index in range(count)
    ]


class BaselineModelTests(unittest.TestCase):
    def test_config_rejects_forbidden_feature(self) -> None:
        config = load_config()
        config["feature_contract"]["numeric"].append("BusinessOutcome")

        with self.assertRaises(TRAIN.TrainingFailure):
            TRAIN.validate_config(config)

    def test_walk_forward_is_chronological_and_purged(self) -> None:
        config = load_config()["split"]
        config["minimum_partition_rows"] = 20
        rows = chronological_rows(300)

        folds = TRAIN.make_walk_forward_folds(rows, config)

        self.assertEqual(len(folds), 3)
        gap = timedelta(minutes=config["purge_embargo_minutes"])
        for fold in folds:
            self.assertLess(
                max(row["_CandidateDateTime"] for row in fold.train),
                fold.train_validation_boundary - gap,
            )
            self.assertGreaterEqual(
                min(row["_CandidateDateTime"] for row in fold.validation),
                fold.train_validation_boundary + gap,
            )
            self.assertLess(
                max(row["_CandidateDateTime"] for row in fold.validation),
                fold.validation_evaluation_boundary - gap,
            )
            self.assertGreaterEqual(
                min(row["_CandidateDateTime"] for row in fold.evaluation),
                fold.validation_evaluation_boundary + gap,
            )

    def test_preprocessor_is_fit_on_train_only(self) -> None:
        contract = {
            "numeric": ["Number"],
            "boolean": ["Flag"],
            "categorical": ["Kind"],
        }
        train = [
            {"Number": "1", "Flag": "true", "Kind": "A"},
            {"Number": "3", "Flag": "false", "Kind": "B"},
        ]

        preprocessor = TRAIN.Preprocessor.fit(train, contract)
        transformed = preprocessor.transform(
            {"Number": "100", "Flag": "true", "Kind": "UNSEEN"}
        )

        self.assertEqual(preprocessor.means["Number"], 2.0)
        self.assertEqual(preprocessor.levels["Kind"], ["A", "B"])
        self.assertEqual(transformed[-2:], [0.0, 0.0])

    def test_threshold_search_enforces_winner_rejection_limit(self) -> None:
        rows = [
            {
                "CandidateTime": f"2026.01.0{index + 1} 01:00:00",
                "OriginalNetProfit": "5" if index < 5 else "-5",
                "CycleNetProfit": "5",
                "BusinessOutcome": (
                    "NO_RECOVERY" if index < 5 else "RECOVERY_L4_PLUS"
                ),
            }
            for index in range(10)
        ]
        labels = [1] * 5 + [0] * 5
        probabilities = [0.9, 0.85, 0.8, 0.75, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]

        selected = TRAIN.choose_threshold(
            rows,
            labels,
            probabilities,
            {"winner_rejection_max": 0.1, "minimum_retained_fraction": 0.5},
        )

        self.assertTrue(selected["feasible"])
        self.assertLessEqual(
            selected["business_proxy"]["winner_rejection_rate"], 0.1
        )
        self.assertGreater(
            selected["business_proxy"]["l4_plus_rejection_rate"], 0.0
        )

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
            {"trees": 3, "max_depth": 2, "min_leaf": 5, "max_thresholds": 4}
        )
        config["calibration"]["max_iterations"] = 80
        contract = config["feature_contract"]
        fields = {
            "SchemaVersion", "SetupId", "StrategyVersion", "SourceRevision",
            "CandidateTime", "SignalTime", "BusinessOutcome",
            "OriginalNetProfit", "CycleNetProfit", config["primary_label"]["column"],
            *contract["numeric"], *contract["boolean"], *contract["categorical"],
        }
        fieldnames = sorted(fields)
        start = datetime(2026, 1, 1)

        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            dataset = root / "merged_candidates.csv"
            rows = []
            for index in range(200):
                positive = (index % 7) < 3
                candidate_time = start + timedelta(hours=index)
                row = {field: "1" for field in fieldnames}
                row.update(
                    {
                        "SchemaVersion": config["dataset_schema"],
                        "SetupId": f"setup-{index}",
                        "StrategyVersion": "fixture",
                        "SourceRevision": "abcdef1",
                        "CandidateTime": candidate_time.strftime("%Y.%m.%d %H:%M:%S"),
                        "SignalTime": (
                            candidate_time - timedelta(minutes=1)
                        ).strftime("%Y.%m.%d %H:%M:%S"),
                        "Direction": "1" if index % 2 else "-1",
                        "BusinessOutcome": (
                            "NO_RECOVERY" if positive else "RECOVERY_L4_PLUS"
                        ),
                        "OriginalNetProfit": "5" if positive else "-5",
                        "CycleNetProfit": "5",
                        config["primary_label"]["column"]: (
                            config["primary_label"]["positive"]
                            if positive
                            else config["primary_label"]["negative"]
                        ),
                        "CciSignalType": "BUY" if index % 2 else "SELL",
                        "LateConfirmMask": str(index % 4),
                        "DataIntegrityFlag": "VERIFIED",
                    }
                )
                for field in contract["boolean"]:
                    row[field] = "true" if index % 2 else "false"
                for offset, field in enumerate(contract["numeric"]):
                    if field == "Direction":
                        continue
                    row[field] = str((index % 11) + offset / 100.0)
                rows.append(row)
            with dataset.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(rows)

            report_a = TRAIN.run_experiment(
                dataset, root / "out-a", copy.deepcopy(config), root / "repo"
            )
            report_b = TRAIN.run_experiment(
                dataset, root / "out-b", copy.deepcopy(config), root / "repo"
            )

            self.assertEqual(
                report_a["aggregate_models"], report_b["aggregate_models"]
            )
            self.assertEqual(
                report_a["exploratory_champion"], report_b["exploratory_champion"]
            )
            self.assertTrue((root / "out-a" / "experiment_manifest.json").is_file())


if __name__ == "__main__":
    unittest.main()
