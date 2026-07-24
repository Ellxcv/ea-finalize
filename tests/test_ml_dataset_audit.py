from __future__ import annotations

import copy
import csv
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "tools" / "ml" / "audit_dataset.py"
SPEC = importlib.util.spec_from_file_location("ts7_audit_dataset", MODULE_PATH)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


def write_csv(path: Path, header: tuple[str, ...], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)


def base_row(header: tuple[str, ...]) -> dict[str, str]:
    return {field: "1" for field in header}


def create_run(
    root: Path,
    run_id: str,
    *,
    setup_id: str = "folder32_v1_GOLD-i-_M1_BUY_100_160",
    cci_signal: str = "120.0",
    final_balance: float = 4005.0,
) -> Path:
    run_dir = root / run_id
    run_dir.mkdir()
    preset_hash = "A" * 64
    manifest = {
        "schema_version": AUDIT.SCHEMA_VERSION,
        "run_id": run_id,
        "strategy_version": "folder32_v1",
        "source_revision": "009e7e3",
        "preset_sha256": preset_hash,
        "symbol": "GOLD.i#",
        "timeframe": "M1",
        "barrier_atr": "RMA_14_M1_CLOSED",
        "primary_horizon_bars": 50,
        "sensitivity_horizon_bars": 40,
        "data_integrity_flag": "VERIFIED",
        "build_time": "2026.07.24 13:00:00",
        "tester": True,
        "optimization": False,
    }
    (run_dir / "run_manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8",
    )
    context = {
        "context_version": "ts7_collection_context_v1",
        "run_id": run_id,
        "tester": {
            "from": "2026.01.01",
            "to": "2026.02.01",
            "model": "EVERY_TICK_BASED_ON_REAL_TICKS",
            "initial_deposit": 4000.0,
            "final_balance": final_balance,
            "currency": "USD",
            "leverage": "1:500",
            "candidate_count": 1,
        },
        "artifacts": {
            "preset": {"name": "baseline.set", "sha256": preset_hash},
            "ea_ex5": {"name": "testing_strat_7.ex5", "sha256": "B" * 64},
            "report": {"name": "report.htm", "sha256": "C" * 64},
            "dependencies": [],
        },
    }
    (run_dir / "collection_context.json").write_text(
        json.dumps(context), encoding="utf-8",
    )

    candidate = base_row(AUDIT.CANDIDATE_HEADER)
    candidate.update(
        {
            "SchemaVersion": AUDIT.SCHEMA_VERSION,
            "RunId": run_id,
            "SetupId": setup_id,
            "StrategyVersion": "folder32_v1",
            "SourceRevision": "009e7e3",
            "PresetHash": preset_hash,
            "Symbol": "GOLD.i#",
            "Timeframe": "M1",
            "CandidateTime": "2026.01.05 02:02:01",
            "CandidateBarTime": "2026.01.05 02:02:00",
            "SignalTime": "2026.01.05 02:01:00",
            "Direction": "1",
            "CciSignalType": "NORMAL",
            "SignalAgeBars": "1",
            "FeatureReady": "true",
            "CciSignal": cci_signal,
            "BarrierATR": "1.00",
            "ATR_M5": "2.00",
            "CandidatePrice": "100.00",
            "Bid": "99.90",
            "Ask": "100.00",
            "AsiaSession": "true",
            "LondonSession": "false",
            "NewYorkSession": "false",
            "SessionDistanceReady": "true",
            "StructureReady": "true",
            "DataIntegrityFlag": "VERIFIED",
        }
    )
    for bool_field in (
        "AsiaSession", "LondonSession", "NewYorkSession",
    ):
        candidate.setdefault(bool_field, "false")
    write_csv(
        run_dir / "candidate_setups.csv",
        AUDIT.CANDIDATE_HEADER,
        [candidate],
    )

    entry = base_row(AUDIT.TRADE_ENTRY_HEADER)
    entry.update(
        {
            "SchemaVersion": AUDIT.SCHEMA_VERSION,
            "RunId": run_id,
            "SetupId": setup_id,
            "AttemptNumber": "1",
            "CycleId": setup_id + "_CYCLE",
            "OrderTicket": "10",
            "DealTicket": "11",
            "PositionId": "12",
            "RequestTime": "2026.01.05 02:02:01",
            "ActualTime": "2026.01.05 02:02:01",
            "Direction": "1",
            "OrderSucceeded": "true",
        }
    )
    write_csv(run_dir / "trade_entries.csv", AUDIT.TRADE_ENTRY_HEADER, [entry])

    trade = base_row(AUDIT.TRADE_OUTCOME_HEADER)
    trade.update(
        {
            "SchemaVersion": AUDIT.SCHEMA_VERSION,
            "RunId": run_id,
            "SetupId": setup_id,
            "CycleId": setup_id + "_CYCLE",
            "PositionId": "12",
            "ExitDeal": "13",
            "ExitTime": "2026.01.05 02:10:00",
            "Direction": "1",
            "NetProfit": "5.00",
            "GrossProfit": "5.00",
            "Commission": "0.00",
            "Swap": "0.00",
            "RecoveryEligible": "false",
        }
    )
    write_csv(
        run_dir / "trade_outcomes.csv",
        AUDIT.TRADE_OUTCOME_HEADER,
        [trade],
    )

    cycle = base_row(AUDIT.CYCLE_OUTCOME_HEADER)
    cycle.update(
        {
            "SchemaVersion": AUDIT.SCHEMA_VERSION,
            "RunId": run_id,
            "SetupId": setup_id,
            "CycleId": setup_id + "_CYCLE",
            "OutcomeTime": "2026.01.05 02:10:00",
            "BusinessOutcome": "NO_RECOVERY",
            "OriginalNetProfit": "5.00",
            "RecoveryNetProfit": "0.00",
            "CycleNetProfit": "5.00",
            "RecoveryStarted": "false",
            "RecoveryEntries": "0",
            "MaxRecoveryLevel": "0",
            "CompletionReason": "ORIGINAL_COMPLETED",
        }
    )
    write_csv(
        run_dir / "cycle_outcomes.csv",
        AUDIT.CYCLE_OUTCOME_HEADER,
        [cycle],
    )

    barriers = []
    for horizon in (40, 50):
        barrier = base_row(AUDIT.BARRIER_OUTCOME_HEADER)
        barrier.update(
            {
                "SchemaVersion": AUDIT.SCHEMA_VERSION,
                "RunId": run_id,
                "SetupId": setup_id,
                "HorizonBars": str(horizon),
                "OutcomeTime": "2026.01.05 02:03:00",
                "BarrierOutcome": "FAVORABLE_FIRST",
                "Direction": "1",
                "ReferencePrice": "100.00",
                "ATRPrice": "1.00",
                "FavorablePrice": "101.00",
                "AdversePrice": "99.00",
                "ElapsedBars": "1",
            }
        )
        barriers.append(barrier)
    write_csv(
        run_dir / "barrier_outcomes.csv",
        AUDIT.BARRIER_OUTCOME_HEADER,
        barriers,
    )
    return run_dir


class DatasetAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        config_path = REPO_ROOT / "config" / "ml-dataset-audit.json"
        self.config = json.loads(config_path.read_text(encoding="utf-8"))
        self.config["expected_preset_sha256"] = "A" * 64
        self.config["expected_dependency_sha256"] = {}
        self.config["expected_test_from"] = "2026.01.01"
        self.config["expected_test_to"] = "2026.02.01"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_audit(self, raw_root: Path, output_name: str = "processed"):
        return AUDIT.audit_dataset(
            raw_root,
            self.root / output_name,
            copy.deepcopy(self.config),
            repo_root=self.root / "fake-repository",
        )

    def test_valid_run_is_retained_and_reconciled(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        create_run(raw_root, "run-a")

        report = self.run_audit(raw_root)

        self.assertEqual(report["totals"]["errors"], 0)
        self.assertEqual(report["totals"]["retained_candidates"], 1)
        self.assertEqual(report["barrier50_distribution"], {"FAVORABLE_FIRST": 1})
        self.assertTrue((self.root / "processed" / "merged_candidates.csv").is_file())

    def test_balance_reconciliation_failure_rejects_whole_run(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        create_run(raw_root, "run-a", final_balance=4004.0)

        report = self.run_audit(raw_root)

        self.assertGreater(report["totals"]["errors"], 0)
        self.assertEqual(report["totals"]["retained_candidates"], 0)
        issues = (self.root / "processed" / "audit_issues.csv").read_text()
        self.assertIn("RUN_BALANCE_RECONCILIATION_FAILED", issues)

    def test_initial_deposit_mismatch_rejects_whole_run(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        run_dir = create_run(raw_root, "run-a")
        context_path = run_dir / "collection_context.json"
        context = json.loads(context_path.read_text(encoding="utf-8"))
        context["tester"]["initial_deposit"] = 3000.0
        context["tester"]["final_balance"] = 3005.0
        context_path.write_text(json.dumps(context), encoding="utf-8")

        report = self.run_audit(raw_root)

        self.assertGreater(report["totals"]["errors"], 0)
        self.assertEqual(report["totals"]["retained_candidates"], 0)
        issues = (self.root / "processed" / "audit_issues.csv").read_text()
        self.assertIn("INITIAL_DEPOSIT_MISMATCH", issues)

    def test_identical_cross_run_duplicate_keeps_first(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        create_run(raw_root, "run-a")
        create_run(raw_root, "run-b")

        report = self.run_audit(raw_root)

        self.assertEqual(report["totals"]["errors"], 0)
        self.assertEqual(report["totals"]["retained_candidates"], 1)
        self.assertEqual(report["totals"]["excluded_candidates"], 1)
        self.assertGreaterEqual(report["totals"]["warnings"], 1)

    def test_conflicting_cross_run_duplicate_rejects_both(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        create_run(raw_root, "run-a", cci_signal="120.0")
        create_run(raw_root, "run-b", cci_signal="121.0")

        report = self.run_audit(raw_root)

        self.assertGreater(report["totals"]["errors"], 0)
        self.assertEqual(report["totals"]["retained_candidates"], 0)
        self.assertEqual(report["totals"]["excluded_candidates"], 2)

    def test_header_mismatch_stops_relational_cascade(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        run_dir = create_run(raw_root, "run-a")
        candidate_path = run_dir / "candidate_setups.csv"
        lines = candidate_path.read_text(encoding="utf-8").splitlines()
        lines[0] = ",".join(AUDIT.CANDIDATE_HEADER[:-1])
        candidate_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        report = self.run_audit(raw_root)

        self.assertGreater(report["totals"]["errors"], 0)
        issues = (self.root / "processed" / "audit_issues.csv").read_text()
        self.assertIn("HEADER_MISMATCH", issues)
        self.assertNotIn("ORPHAN_", issues)

    def test_processed_output_cannot_be_inside_raw_data(self) -> None:
        raw_root = self.root / "raw"
        raw_root.mkdir()
        create_run(raw_root, "run-a")

        with self.assertRaises(AUDIT.AuditFailure):
            AUDIT.audit_dataset(
                raw_root,
                raw_root / "processed",
                copy.deepcopy(self.config),
                repo_root=self.root / "fake-repository",
            )


if __name__ == "__main__":
    unittest.main()
