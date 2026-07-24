#!/usr/bin/env python3
"""Audit and merge TESTING_STRAT_7 ML logger runs without third-party packages."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import shutil
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION_V1 = "ts7_entry_candidate_v1"
SCHEMA_VERSION_V2 = "ts7_entry_candidate_v2"
SUPPORTED_SCHEMA_VERSIONS = {SCHEMA_VERSION_V1, SCHEMA_VERSION_V2}
# Backward-compatible aliases used by the v1 fixture tests and retained configs.
SCHEMA_VERSION = SCHEMA_VERSION_V1
CSV_FILES = (
    "candidate_setups.csv",
    "trade_entries.csv",
    "trade_outcomes.csv",
    "cycle_outcomes.csv",
    "barrier_outcomes.csv",
)

CANDIDATE_HEADER_V1 = (
    "SchemaVersion", "RunId", "SetupId", "StrategyVersion", "SourceRevision",
    "PresetHash", "Symbol", "Timeframe", "CandidateTime", "CandidateBarTime",
    "SignalTime", "Direction", "CciSignalType", "SignalAgeBars",
    "CandidatePrice", "Bid", "Ask", "SpreadPoints", "SpreadATR", "BarrierATR",
    "ATR_M5", "ATRRatioM1M5", "InitialSL", "InitialSLPoints", "InitialSLATR",
    "FeatureReady", "CciSignal", "CiSignal", "CciCandidate", "CiCandidate",
    "CciDeltaDir", "CciGapSignalDir", "CciGapCandidateDir",
    "HiLoSignalAlign", "PsarSignalAlign", "STSignalAlign", "STMTFSignalAlign",
    "ConfirmationsAtSignal", "LateConfirmMask", "HiLoLatencyBars",
    "PsarLatencyBars", "STLatencyBars", "STMTFLatencyNativeBars",
    "STMTFLatencySeconds", "HiLoAgeBars", "PsarAgeBars", "STAgeBars",
    "STMTFAgeBars", "Return1ATR", "Return3ATR", "Return5ATR", "Return10ATR",
    "Return20ATR", "BodyATR", "RangeATR", "UpperWickATR", "LowerWickATR",
    "DisplacementATR", "PreEntryMFEATR", "PreEntryMAEATR", "DistanceEMAATR",
    "EMASlope5ATR", "EMASlope10ATR", "RecentRangePositionDir", "TickVolume",
    "Hour", "Minute", "DayOfWeek", "TimeOfDaySin", "TimeOfDayCos",
    "DayOfWeekSin", "DayOfWeekCos", "AsiaSession", "LondonSession",
    "NewYorkSession", "SessionDistanceReady", "MinutesFromSessionOpen",
    "MinutesToSessionClose", "StructureReady", "DirectionalRoomATR",
    "DataIntegrityFlag",
)
CANDIDATE_V2_FEATURES = (
    "AdxValue", "AdxSlope1", "DiGapDir", "DiGapSlopeDir",
    "CciSlope1Dir", "CciSlope3Dir", "ATRChange1", "HiLoDistanceATR",
    "HiLoLineSlopeATR", "PsarDistanceATR", "PsarLineSlopeATR",
    "STDistanceATR", "STLineSlopeATR", "STMTFDistanceATR",
    "STMTFLineSlopeATR",
)
CANDIDATE_HEADER_V2 = (
    CANDIDATE_HEADER_V1[:-1]
    + ("FeatureReadyV2",)
    + CANDIDATE_V2_FEATURES
    + ("DataIntegrityFlag",)
)
CANDIDATE_HEADER = CANDIDATE_HEADER_V1

TRADE_ENTRY_HEADER = (
    "SchemaVersion", "RunId", "SetupId", "AttemptNumber", "CycleId",
    "OrderTicket", "DealTicket", "PositionId", "RequestTime", "ActualTime",
    "Direction", "RequestedPrice", "ActualPrice", "Volume", "InitialSL",
    "InitialSLPoints", "TakeProfit", "SpreadPoints", "Retcode",
    "RetcodeDescription", "OrderSucceeded",
)

TRADE_OUTCOME_HEADER = (
    "SchemaVersion", "RunId", "SetupId", "CycleId", "PositionId", "ExitDeal",
    "ExitTime", "Direction", "ExitPrice", "ExitReason", "GrossProfit",
    "Commission", "Swap", "NetProfit", "BarsHeld", "MFEPoints", "MAEPoints",
    "RecoveryEligible",
)

CYCLE_OUTCOME_HEADER = (
    "SchemaVersion", "RunId", "SetupId", "CycleId", "OutcomeTime",
    "BusinessOutcome", "OriginalNetProfit", "RecoveryNetProfit",
    "CycleNetProfit", "RecoveryStarted", "RecoveryEntries", "MaxRecoveryLevel",
    "CompletionReason",
)

BARRIER_OUTCOME_HEADER = (
    "SchemaVersion", "RunId", "SetupId", "HorizonBars", "OutcomeTime",
    "BarrierOutcome", "Direction", "ReferencePrice", "ATRPrice",
    "FavorablePrice", "AdversePrice", "ElapsedBars",
)

EXPECTED_NON_CANDIDATE_HEADERS = {
    "trade_entries.csv": TRADE_ENTRY_HEADER,
    "trade_outcomes.csv": TRADE_OUTCOME_HEADER,
    "cycle_outcomes.csv": CYCLE_OUTCOME_HEADER,
    "barrier_outcomes.csv": BARRIER_OUTCOME_HEADER,
}

BASE_REQUIRED_FEATURES = (
    "Direction", "CciSignalType", "SignalAgeBars", "CandidatePrice", "Bid", "Ask",
    "SpreadPoints", "SpreadATR", "BarrierATR", "ATR_M5", "ATRRatioM1M5",
    "InitialSL", "InitialSLPoints", "InitialSLATR", "CciSignal", "CiSignal",
    "CciCandidate", "CiCandidate", "CciDeltaDir", "CciGapSignalDir",
    "CciGapCandidateDir", "HiLoSignalAlign", "PsarSignalAlign",
    "STSignalAlign", "STMTFSignalAlign", "ConfirmationsAtSignal",
    "LateConfirmMask", "HiLoLatencyBars", "PsarLatencyBars", "STLatencyBars",
    "STMTFLatencyNativeBars", "STMTFLatencySeconds", "HiLoAgeBars",
    "PsarAgeBars", "STAgeBars", "STMTFAgeBars", "Return1ATR", "Return3ATR",
    "Return5ATR", "Return10ATR", "Return20ATR", "BodyATR", "RangeATR",
    "UpperWickATR", "LowerWickATR", "DisplacementATR", "PreEntryMFEATR",
    "PreEntryMAEATR", "DistanceEMAATR", "EMASlope5ATR", "EMASlope10ATR",
    "RecentRangePositionDir", "TickVolume", "Hour", "Minute", "DayOfWeek",
    "TimeOfDaySin", "TimeOfDayCos", "DayOfWeekSin", "DayOfWeekCos",
    "AsiaSession", "LondonSession", "NewYorkSession",
)
BASE_REQUIRED_FEATURES_V2 = BASE_REQUIRED_FEATURES + CANDIDATE_V2_FEATURES

MERGED_LABEL_HEADER = (
    "Barrier40Outcome", "Barrier40ElapsedBars", "Barrier50Outcome",
    "Barrier50ElapsedBars", "TradeNetProfit", "TradeBarsHeld", "TradeMFEPoints",
    "TradeMAEPoints", "TradeExitReason", "BusinessOutcome", "OriginalNetProfit",
    "RecoveryNetProfit", "CycleNetProfit", "RecoveryStarted", "RecoveryEntries",
    "MaxRecoveryLevel", "CycleCompletionReason",
)


@dataclass
class Issue:
    severity: str
    code: str
    detail: str
    run_id: str = ""
    setup_id: str = ""


@dataclass
class RunAudit:
    run_id: str
    path: Path
    manifest: dict[str, Any] = field(default_factory=dict)
    context: dict[str, Any] = field(default_factory=dict)
    rows: dict[str, list[dict[str, str]]] = field(default_factory=dict)
    issues: list[Issue] = field(default_factory=list)
    excluded: dict[str, set[str]] = field(default_factory=lambda: defaultdict(set))
    merged_rows: list[dict[str, str]] = field(default_factory=list)

    @property
    def error_count(self) -> int:
        return sum(issue.severity == "ERROR" for issue in self.issues)

    @property
    def warning_count(self) -> int:
        return sum(issue.severity == "WARNING" for issue in self.issues)


class AuditFailure(RuntimeError):
    """Raised for command-level failures before a report can be produced."""


def utc_now_text() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def canonical_config_hash(config: Mapping[str, Any]) -> str:
    payload = json.dumps(config, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return sha256_bytes(payload)


def candidate_header_for_schema(schema_version: str) -> tuple[str, ...]:
    if schema_version == SCHEMA_VERSION_V1:
        return CANDIDATE_HEADER_V1
    if schema_version == SCHEMA_VERSION_V2:
        return CANDIDATE_HEADER_V2
    raise AuditFailure(f"Unsupported schema_version: {schema_version!r}")


def expected_header_for_file(
    schema_version: str, file_name: str
) -> tuple[str, ...]:
    if file_name == "candidate_setups.csv":
        return candidate_header_for_schema(schema_version)
    return EXPECTED_NON_CANDIDATE_HEADERS[file_name]


def required_features_for_schema(schema_version: str) -> tuple[str, ...]:
    if schema_version == SCHEMA_VERSION_V1:
        return BASE_REQUIRED_FEATURES
    if schema_version == SCHEMA_VERSION_V2:
        return BASE_REQUIRED_FEATURES_V2
    raise AuditFailure(f"Unsupported schema_version: {schema_version!r}")


def validate_config(config: Mapping[str, Any]) -> None:
    required = (
        "schema_version", "expected_strategy_version", "expected_preset_sha256",
        "expected_symbol", "expected_timeframe", "expected_initial_deposit", "expected_currency",
        "expected_leverage", "source_revision_pattern",
        "financial_tolerance", "price_tolerance", "required_barrier_horizons",
        "binary_barrier_outcomes", "accepted_business_outcomes",
        "unverified_data_integrity_flags", "duplicate_policy",
        "minimum_rule_group_size", "numeric_rule_features",
        "categorical_rule_features",
    )
    missing = [key for key in required if key not in config]
    if missing:
        raise AuditFailure(f"Audit config is missing fields: {', '.join(missing)}")
    if config["schema_version"] not in SUPPORTED_SCHEMA_VERSIONS:
        raise AuditFailure(
            f"Unsupported schema_version: {config['schema_version']!r}"
        )
    if not valid_sha256(config["expected_preset_sha256"]):
        raise AuditFailure("expected_preset_sha256 must be a valid SHA-256")
    try:
        re.compile(str(config["source_revision_pattern"]))
    except re.error as exc:
        raise AuditFailure(f"Invalid source_revision_pattern: {exc}") from exc
    if float(config["financial_tolerance"]) < 0 or float(config["price_tolerance"]) < 0:
        raise AuditFailure("Financial and price tolerance cannot be negative")
    configured_test_windows(config)
    expected_deposit = parse_float(str(config["expected_initial_deposit"]))
    if expected_deposit is None or expected_deposit <= 0:
        raise AuditFailure("expected_initial_deposit must be positive")
    if not str(config["expected_currency"]).strip():
        raise AuditFailure("expected_currency is required")
    if not str(config["expected_leverage"]).strip():
        raise AuditFailure("expected_leverage is required")
    if "minimum_history_quality_percent" in config:
        minimum_quality = parse_float(str(config["minimum_history_quality_percent"]))
        if minimum_quality is None or minimum_quality < 0 or minimum_quality > 100:
            raise AuditFailure("minimum_history_quality_percent must be between 0 and 100")
    if "accepted_termination_statuses" in config:
        statuses = config["accepted_termination_statuses"]
        allowed_statuses = {"COMPLETED", "EARLY_STOP", "MARGIN_CALL", "UNKNOWN"}
        if (
            not isinstance(statuses, list)
            or not statuses
            or any(status not in allowed_statuses for status in statuses)
        ):
            raise AuditFailure("accepted_termination_statuses is invalid")
    if set(int(value) for value in config["required_barrier_horizons"]) != {40, 50}:
        raise AuditFailure("required_barrier_horizons must contain exactly 40 and 50")
    if config["duplicate_policy"] != "keep_first_identical":
        raise AuditFailure("Only duplicate_policy=keep_first_identical is supported")
    unknown_features = (
        set(config["numeric_rule_features"])
        | set(config["categorical_rule_features"])
    ) - set(candidate_header_for_schema(str(config["schema_version"])))
    if unknown_features:
        raise AuditFailure(
            "Unknown rule-analysis features: " + ", ".join(sorted(unknown_features))
        )
    for name, digest in config.get("expected_dependency_sha256", {}).items():
        if not name or not valid_sha256(digest):
            raise AuditFailure(f"Invalid dependency hash configuration for {name!r}")


def parse_bool(value: str) -> bool | None:
    lowered = value.strip().lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    return None


def parse_int(value: str) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def parse_float(value: str) -> float | None:
    if value in ("", "NA", None):
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed if math.isfinite(parsed) else None


def parse_time(value: str) -> datetime | None:
    if not value or value == "NA":
        return None
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return None


def configured_test_windows(
    config: Mapping[str, Any],
) -> list[tuple[str, str, datetime, datetime]]:
    configured = config.get("expected_test_windows")
    if configured is None:
        if "expected_test_from" not in config or "expected_test_to" not in config:
            raise AuditFailure(
                "Configure expected_test_from/expected_test_to or expected_test_windows"
            )
        configured = [
            {
                "from": config["expected_test_from"],
                "to": config["expected_test_to"],
            }
        ]
    if not isinstance(configured, list) or not configured:
        raise AuditFailure("expected_test_windows must be a non-empty array")
    output: list[tuple[str, str, datetime, datetime]] = []
    seen: set[tuple[str, str]] = set()
    for index, item in enumerate(configured):
        if not isinstance(item, dict) or "from" not in item or "to" not in item:
            raise AuditFailure(f"expected_test_windows[{index}] must contain from/to")
        from_text = str(item["from"])
        to_text = str(item["to"])
        date_from = parse_time(from_text + " 00:00:00")
        date_to = parse_time(to_text + " 00:00:00")
        if date_from is None or date_to is None or date_from >= date_to:
            raise AuditFailure(f"expected_test_windows[{index}] is invalid")
        key = (from_text, to_text)
        if key in seen:
            raise AuditFailure(f"Duplicate expected test window: {from_text} to {to_text}")
        seen.add(key)
        output.append((from_text, to_text, date_from, date_to))
    return output


def add_issue(
    audit: RunAudit,
    severity: str,
    code: str,
    detail: str,
    setup_id: str = "",
) -> None:
    audit.issues.append(Issue(severity, code, detail, audit.run_id, setup_id))


def discover_run_directories(raw_root: Path) -> list[Path]:
    if (raw_root / "run_manifest.json").is_file():
        return [raw_root]
    if not raw_root.is_dir():
        raise AuditFailure(f"Raw root does not exist or is not a directory: {raw_root}")
    return sorted(
        child for child in raw_root.iterdir()
        if child.is_dir() and (child / "run_manifest.json").is_file()
    )


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise AuditFailure(f"Expected a JSON object in {path}")
    return value


def read_csv_exact(audit: RunAudit, file_name: str) -> list[dict[str, str]]:
    path = audit.path / file_name
    if not path.is_file():
        add_issue(audit, "ERROR", "MISSING_FILE", f"Required file is missing: {file_name}")
        return []
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            actual = tuple(reader.fieldnames or ())
            schema_version = str(audit.manifest.get("schema_version", ""))
            try:
                expected = expected_header_for_file(schema_version, file_name)
            except AuditFailure as exc:
                add_issue(audit, "ERROR", "UNSUPPORTED_SCHEMA", str(exc))
                return []
            if actual != expected:
                add_issue(
                    audit,
                    "ERROR",
                    "HEADER_MISMATCH",
                    f"{file_name} header differs: expected {len(expected)} columns, "
                    f"found {len(actual)}",
                )
                return []
            rows: list[dict[str, str]] = []
            for line_number, row in enumerate(reader, start=2):
                if None in row or any(value is None for value in row.values()):
                    add_issue(
                        audit,
                        "ERROR",
                        "MALFORMED_ROW",
                        f"{file_name}:{line_number} has a wrong column count",
                    )
                    continue
                rows.append(dict(row))
            return rows
    except (OSError, UnicodeError, csv.Error) as exc:
        add_issue(audit, "ERROR", "CSV_READ_ERROR", f"{file_name}: {exc}")
        return []


def validate_manifest(audit: RunAudit, config: Mapping[str, Any]) -> None:
    manifest = audit.manifest
    required = (
        "schema_version", "run_id", "strategy_version", "source_revision",
        "preset_sha256", "symbol", "timeframe", "barrier_atr",
        "primary_horizon_bars", "sensitivity_horizon_bars",
        "data_integrity_flag", "build_time", "tester", "optimization",
    )
    if config["schema_version"] == SCHEMA_VERSION_V2:
        required += (
            "feature_contract", "feature_snapshot", "adx_timeframe",
            "adx_dmi_period", "adx_smoothing_enabled",
            "adx_smoothing_period",
        )
    for key in required:
        if key not in manifest:
            add_issue(audit, "ERROR", "MANIFEST_FIELD_MISSING", f"Missing manifest field: {key}")

    comparisons = {
        "schema_version": config["schema_version"],
        "strategy_version": config["expected_strategy_version"],
        "preset_sha256": config["expected_preset_sha256"],
        "symbol": config["expected_symbol"],
        "timeframe": config["expected_timeframe"],
    }
    for key, expected in comparisons.items():
        if str(manifest.get(key, "")) != str(expected):
            add_issue(
                audit,
                "ERROR",
                "MANIFEST_MISMATCH",
                f"{key} expected {expected!r}, found {manifest.get(key)!r}",
            )

    if manifest.get("run_id") != audit.run_id:
        add_issue(
            audit,
            "ERROR",
            "RUN_ID_DIRECTORY_MISMATCH",
            f"Directory is {audit.run_id!r}, manifest is {manifest.get('run_id')!r}",
        )

    source_revision = str(manifest.get("source_revision", ""))
    if not re.fullmatch(str(config["source_revision_pattern"]), source_revision):
        add_issue(
            audit,
            "ERROR",
            "SOURCE_REVISION_NOT_COMMIT",
            f"Source revision is not a 7-40 character Git commit: {source_revision!r}",
        )

    if manifest.get("barrier_atr") != "RMA_14_M1_CLOSED":
        add_issue(audit, "ERROR", "BARRIER_CONTRACT_MISMATCH", "Unexpected barrier ATR contract")
    if parse_int(str(manifest.get("primary_horizon_bars", ""))) != 50:
        add_issue(audit, "ERROR", "BARRIER_CONTRACT_MISMATCH", "Primary horizon must be 50")
    if parse_int(str(manifest.get("sensitivity_horizon_bars", ""))) != 40:
        add_issue(audit, "ERROR", "BARRIER_CONTRACT_MISMATCH", "Sensitivity horizon must be 40")
    if manifest.get("optimization") is True:
        add_issue(audit, "ERROR", "OPTIMIZATION_RUN_REJECTED", "Optimization runs are not retained")
    if config["schema_version"] == SCHEMA_VERSION_V2:
        if manifest.get("feature_contract") != "entry_state_strength_distance_v2":
            add_issue(
                audit, "ERROR", "FEATURE_CONTRACT_MISMATCH",
                "Unexpected v2 feature contract",
            )
        if manifest.get("feature_snapshot") != "CLOSED_BARS_ONLY_AT_CANDIDATE":
            add_issue(
                audit, "ERROR", "FEATURE_SNAPSHOT_MISMATCH",
                "V2 feature snapshot must use candidate-time closed bars only",
            )
        if (parse_int(str(manifest.get("adx_dmi_period", ""))) or 0) <= 0:
            add_issue(
                audit, "ERROR", "ADX_CONTRACT_INVALID",
                "adx_dmi_period must be positive",
            )
        if (parse_int(str(manifest.get("adx_smoothing_period", ""))) or 0) <= 0:
            add_issue(
                audit, "ERROR", "ADX_CONTRACT_INVALID",
                "adx_smoothing_period must be positive",
            )

    integrity_flag = str(manifest.get("data_integrity_flag", ""))
    if integrity_flag in set(config["unverified_data_integrity_flags"]):
        add_issue(
            audit,
            "WARNING",
            "DATA_INTEGRITY_UNVERIFIED",
            f"Run carries unverified data-integrity flag: {integrity_flag}",
        )


def valid_sha256(value: Any) -> bool:
    return bool(re.fullmatch(r"[0-9a-fA-F]{64}", str(value or "")))


def validate_collection_context(audit: RunAudit, config: Mapping[str, Any]) -> None:
    context = audit.context
    if not context:
        if config.get("require_collection_context", True):
            add_issue(
                audit,
                "ERROR",
                "COLLECTION_CONTEXT_MISSING",
                "collection_context.json is required for a retained historical run",
            )
        return
    if context.get("context_version") != "ts7_collection_context_v1":
        add_issue(audit, "ERROR", "CONTEXT_VERSION_MISMATCH", "Unsupported context version")
    if context.get("run_id") != audit.run_id:
        add_issue(audit, "ERROR", "CONTEXT_RUN_ID_MISMATCH", "Context RunId differs from directory")
    tester = context.get("tester")
    if not isinstance(tester, dict):
        add_issue(audit, "ERROR", "TESTER_CONTEXT_MISSING", "tester object is required")
        return
    if tester.get("model") != config.get("required_tester_model"):
        add_issue(
            audit,
            "ERROR",
            "TESTER_MODEL_MISMATCH",
            f"Expected {config.get('required_tester_model')!r}, found {tester.get('model')!r}",
        )
    date_from = parse_time(str(tester.get("from", "")) + " 00:00:00")
    date_to = parse_time(str(tester.get("to", "")) + " 00:00:00")
    if date_from is None or date_to is None or date_from >= date_to:
        add_issue(audit, "ERROR", "INVALID_TEST_WINDOW", "Tester from/to is invalid")
    else:
        expected_windows = configured_test_windows(config)
        if not any(
            date_from == expected_from and date_to == expected_to
            for _, _, expected_from, expected_to in expected_windows
        ):
            expected_text = ", ".join(
                f"{from_text} to {to_text}"
                for from_text, to_text, _, _ in expected_windows
            )
            add_issue(
                audit,
                "ERROR",
                "TEST_WINDOW_MISMATCH",
                f"Expected one of [{expected_text}], found "
                f"{tester.get('from')} to {tester.get('to')}",
            )
    for field_name in ("initial_deposit", "final_balance"):
        if parse_float(str(tester.get(field_name, ""))) is None:
            add_issue(audit, "ERROR", "INVALID_TESTER_FINANCIAL", f"{field_name} is invalid")
    initial_deposit = parse_float(str(tester.get("initial_deposit", "")))
    expected_deposit = parse_float(str(config["expected_initial_deposit"]))
    if (
        initial_deposit is not None
        and expected_deposit is not None
        and abs(initial_deposit - expected_deposit) > float(config["financial_tolerance"])
    ):
        add_issue(
            audit,
            "ERROR",
            "INITIAL_DEPOSIT_MISMATCH",
            f"Expected {expected_deposit:.2f}, found {initial_deposit:.2f}",
        )
    if not tester.get("currency") or not tester.get("leverage"):
        add_issue(audit, "ERROR", "TESTER_METADATA_MISSING", "Currency and leverage are required")
    else:
        if str(tester.get("currency")) != str(config["expected_currency"]):
            add_issue(
                audit,
                "ERROR",
                "TESTER_CURRENCY_MISMATCH",
                f"Expected {config['expected_currency']!r}, found {tester.get('currency')!r}",
            )
        if str(tester.get("leverage")) != str(config["expected_leverage"]):
            add_issue(
                audit,
                "ERROR",
                "TESTER_LEVERAGE_MISMATCH",
                f"Expected {config['expected_leverage']!r}, found {tester.get('leverage')!r}",
            )
    if "minimum_history_quality_percent" in config:
        actual_quality = parse_float(str(tester.get("history_quality_percent", "")))
        minimum_quality = float(config["minimum_history_quality_percent"])
        if actual_quality is None:
            add_issue(
                audit,
                "ERROR",
                "HISTORY_QUALITY_MISSING",
                "history_quality_percent is required by the audit config",
            )
        elif actual_quality < minimum_quality:
            add_issue(
                audit,
                "ERROR",
                "HISTORY_QUALITY_BELOW_MINIMUM",
                f"Required at least {minimum_quality:.2f}%, found {actual_quality:.2f}%",
            )
    if "accepted_termination_statuses" in config:
        termination_status = str(tester.get("termination_status", ""))
        if termination_status not in config["accepted_termination_statuses"]:
            add_issue(
                audit,
                "ERROR",
                "TERMINATION_STATUS_REJECTED",
                f"Expected one of {config['accepted_termination_statuses']}, "
                f"found {termination_status!r}",
            )

    artifacts = context.get("artifacts")
    if not isinstance(artifacts, dict):
        add_issue(audit, "ERROR", "ARTIFACT_CONTEXT_MISSING", "artifacts object is required")
        return
    for artifact_name in ("preset", "ea_ex5", "report"):
        artifact = artifacts.get(artifact_name)
        if not isinstance(artifact, dict) or not valid_sha256(artifact.get("sha256")):
            add_issue(
                audit,
                "ERROR",
                "ARTIFACT_HASH_MISSING",
                f"Valid SHA-256 is required for {artifact_name}",
            )
    preset = artifacts.get("preset", {})
    if isinstance(preset, dict) and str(preset.get("sha256", "")).upper() != str(
        audit.manifest.get("preset_sha256", "")
    ).upper():
        add_issue(audit, "ERROR", "CONTEXT_PRESET_HASH_MISMATCH", "Context preset hash differs")

    dependencies = artifacts.get("dependencies")
    if not isinstance(dependencies, list):
        add_issue(audit, "ERROR", "DEPENDENCY_CONTEXT_MISSING", "dependencies array is required")
        return
    dependency_map = {
        str(item.get("name", "")): str(item.get("sha256", "")).upper()
        for item in dependencies
        if isinstance(item, dict)
    }
    for name, expected_hash in config.get("expected_dependency_sha256", {}).items():
        actual = dependency_map.get(name)
        if actual is None:
            add_issue(audit, "ERROR", "DEPENDENCY_HASH_MISSING", f"Missing dependency: {name}")
        elif actual != str(expected_hash).upper():
            add_issue(
                audit,
                "ERROR",
                "DEPENDENCY_HASH_MISMATCH",
                f"{name} expected {expected_hash}, found {actual}",
            )


def validate_row_provenance(
    audit: RunAudit,
    file_name: str,
    rows: Sequence[Mapping[str, str]],
) -> None:
    manifest = audit.manifest
    expected = {
        "SchemaVersion": str(manifest.get("schema_version", "")),
        "RunId": audit.run_id,
    }
    if file_name == "candidate_setups.csv":
        expected.update(
            {
                "StrategyVersion": str(manifest.get("strategy_version", "")),
                "SourceRevision": str(manifest.get("source_revision", "")),
                "PresetHash": str(manifest.get("preset_sha256", "")),
                "Symbol": str(manifest.get("symbol", "")),
                "Timeframe": str(manifest.get("timeframe", "")),
                "DataIntegrityFlag": str(manifest.get("data_integrity_flag", "")),
            }
        )
    for row_number, row in enumerate(rows, start=2):
        for key, expected_value in expected.items():
            if row.get(key) != expected_value:
                add_issue(
                    audit,
                    "ERROR",
                    "ROW_PROVENANCE_MISMATCH",
                    f"{file_name}:{row_number} {key} expected {expected_value!r}, "
                    f"found {row.get(key)!r}",
                    row.get("SetupId", ""),
                )


def unique_index(
    audit: RunAudit,
    rows: Sequence[dict[str, str]],
    name: str,
    key_fields: Sequence[str],
) -> dict[tuple[str, ...], dict[str, str]]:
    result: dict[tuple[str, ...], dict[str, str]] = {}
    for row in rows:
        key = tuple(row.get(field, "") for field in key_fields)
        if key in result:
            add_issue(
                audit,
                "ERROR",
                "DUPLICATE_KEY",
                f"{name} duplicate key {dict(zip(key_fields, key))}",
                row.get("SetupId", ""),
            )
        else:
            result[key] = row
    return result


def validate_candidates(
    audit: RunAudit,
) -> dict[str, dict[str, str]]:
    rows = audit.rows["candidate_setups.csv"]
    index = unique_index(audit, rows, "candidate", ("SetupId",))
    candidates = {key[0]: row for key, row in index.items()}
    schema_version = str(audit.manifest.get("schema_version", ""))
    required_features = required_features_for_schema(schema_version)
    ready_fields = ["FeatureReady"]
    if schema_version == SCHEMA_VERSION_V2:
        ready_fields.append("FeatureReadyV2")
    for setup_id, row in candidates.items():
        for field_name in ("CandidateTime", "CandidateBarTime", "SignalTime"):
            if parse_time(row[field_name]) is None:
                add_issue(
                    audit, "ERROR", "INVALID_TIME",
                    f"{field_name} is invalid: {row[field_name]!r}", setup_id,
                )
                audit.excluded[setup_id].add("invalid_time")
        if any(row[field] != "true" for field in ready_fields):
            audit.excluded[setup_id].add("feature_not_ready")
        elif any(row[field] == "NA" for field in required_features):
            add_issue(
                audit, "ERROR", "READY_FEATURE_MISSING",
                "All readiness flags are true but a required feature is NA",
                setup_id,
            )
            audit.excluded[setup_id].add("required_feature_missing")
        if parse_int(row["Direction"]) not in (-1, 1):
            add_issue(audit, "ERROR", "INVALID_DIRECTION", "Direction must be -1 or 1", setup_id)
            audit.excluded[setup_id].add("invalid_direction")
        signal_age = parse_int(row["SignalAgeBars"])
        if signal_age is None or signal_age < 1:
            add_issue(audit, "ERROR", "INVALID_SIGNAL_AGE", "SignalAgeBars must be >= 1", setup_id)
            audit.excluded[setup_id].add("invalid_signal_age")
        atr = parse_float(row["BarrierATR"])
        if atr is None or atr <= 0:
            add_issue(audit, "ERROR", "INVALID_BARRIER_ATR", "BarrierATR must be finite and > 0", setup_id)
            audit.excluded[setup_id].add("invalid_barrier_atr")
    return candidates


def validate_entries(
    audit: RunAudit,
    candidates: Mapping[str, dict[str, str]],
) -> tuple[dict[str, list[dict[str, str]]], dict[str, dict[str, str]]]:
    attempts: dict[str, list[dict[str, str]]] = defaultdict(list)
    successful: dict[str, dict[str, str]] = {}
    for row in audit.rows["trade_entries.csv"]:
        setup_id = row["SetupId"]
        if setup_id not in candidates:
            add_issue(audit, "ERROR", "ORPHAN_ENTRY", "Entry has no candidate", setup_id)
            continue
        attempts[setup_id].append(row)

    for setup_id, rows in attempts.items():
        numbers = [parse_int(row["AttemptNumber"]) for row in rows]
        if any(number is None or number < 1 for number in numbers):
            add_issue(audit, "ERROR", "INVALID_ATTEMPT_NUMBER", "AttemptNumber must be positive", setup_id)
            audit.excluded[setup_id].add("invalid_attempt_number")
        elif numbers != list(range(1, len(numbers) + 1)):
            add_issue(
                audit, "ERROR", "NON_SEQUENTIAL_ATTEMPTS",
                f"Attempt sequence is {numbers}", setup_id,
            )
            audit.excluded[setup_id].add("non_sequential_attempts")
        successes = [row for row in rows if row["OrderSucceeded"] == "true"]
        invalid_bools = [row for row in rows if parse_bool(row["OrderSucceeded"]) is None]
        if invalid_bools:
            add_issue(audit, "ERROR", "INVALID_BOOLEAN", "Invalid OrderSucceeded value", setup_id)
            audit.excluded[setup_id].add("invalid_order_status")
        if len(successes) > 1:
            add_issue(audit, "ERROR", "MULTIPLE_SUCCESSFUL_ENTRIES", "More than one successful attempt", setup_id)
            audit.excluded[setup_id].add("multiple_successful_entries")
        elif successes:
            successful[setup_id] = successes[0]
            for ticket_field in ("OrderTicket", "DealTicket", "PositionId"):
                ticket = parse_int(successes[0][ticket_field])
                if ticket is None or ticket <= 0:
                    add_issue(
                        audit, "ERROR", "MISSING_SUCCESS_TICKET",
                        f"Successful entry has invalid {ticket_field}", setup_id,
                    )
                    audit.excluded[setup_id].add("missing_success_ticket")
        else:
            audit.excluded[setup_id].add("order_not_filled")

    for setup_id in candidates:
        if setup_id not in attempts:
            add_issue(audit, "WARNING", "MISSING_ORDER_ATTEMPT", "Candidate has no order attempt", setup_id)
            audit.excluded[setup_id].add("missing_order_attempt")
    return attempts, successful


def validate_barriers(
    audit: RunAudit,
    config: Mapping[str, Any],
    candidates: Mapping[str, dict[str, str]],
) -> dict[tuple[str, int], dict[str, str]]:
    raw_index = unique_index(
        audit, audit.rows["barrier_outcomes.csv"], "barrier",
        ("SetupId", "HorizonBars"),
    )
    barriers: dict[tuple[str, int], dict[str, str]] = {}
    allowed_horizons = set(int(value) for value in config["required_barrier_horizons"])
    binary_outcomes = set(config["binary_barrier_outcomes"])
    for (setup_id, horizon_text), row in raw_index.items():
        horizon = parse_int(horizon_text)
        if setup_id not in candidates:
            add_issue(audit, "ERROR", "ORPHAN_BARRIER", "Barrier has no candidate", setup_id)
            continue
        if horizon not in allowed_horizons:
            add_issue(
                audit, "ERROR", "UNEXPECTED_HORIZON",
                f"Unexpected barrier horizon: {horizon_text}", setup_id,
            )
            continue
        barriers[(setup_id, horizon)] = row
        candidate = candidates[setup_id]
        direction = parse_int(row["Direction"])
        reference = parse_float(row["ReferencePrice"])
        atr = parse_float(row["ATRPrice"])
        favorable = parse_float(row["FavorablePrice"])
        adverse = parse_float(row["AdversePrice"])
        if direction != parse_int(candidate["Direction"]):
            add_issue(audit, "ERROR", "BARRIER_DIRECTION_MISMATCH", "Barrier direction differs", setup_id)
            audit.excluded[setup_id].add("barrier_direction_mismatch")
        if None in (direction, reference, atr, favorable, adverse) or atr <= 0:
            add_issue(audit, "ERROR", "INVALID_BARRIER_PRICE", "Barrier prices are invalid", setup_id)
            audit.excluded[setup_id].add("invalid_barrier_price")
        else:
            tolerance = float(config["price_tolerance"])
            expected_favorable = reference + direction * atr
            expected_adverse = reference - direction * atr
            if abs(favorable - expected_favorable) > tolerance:
                add_issue(audit, "ERROR", "FAVORABLE_PRICE_MISMATCH", "Favorable barrier formula mismatch", setup_id)
                audit.excluded[setup_id].add("barrier_formula_mismatch")
            if abs(adverse - expected_adverse) > tolerance:
                add_issue(audit, "ERROR", "ADVERSE_PRICE_MISMATCH", "Adverse barrier formula mismatch", setup_id)
                audit.excluded[setup_id].add("barrier_formula_mismatch")
        if row["BarrierOutcome"] not in binary_outcomes:
            audit.excluded[setup_id].add(
                "barrier_" + str(horizon) + "_" + row["BarrierOutcome"].lower()
            )

    for setup_id in candidates:
        for horizon in allowed_horizons:
            if (setup_id, horizon) not in barriers:
                add_issue(
                    audit, "ERROR", "MISSING_BARRIER",
                    f"Candidate is missing horizon {horizon}", setup_id,
                )
                audit.excluded[setup_id].add(f"missing_barrier_{horizon}")
    return barriers


def validate_outcomes(
    audit: RunAudit,
    config: Mapping[str, Any],
    candidates: Mapping[str, dict[str, str]],
    successful: Mapping[str, dict[str, str]],
) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    trade_index_raw = unique_index(
        audit, audit.rows["trade_outcomes.csv"], "trade outcome", ("SetupId",),
    )
    cycle_index_raw = unique_index(
        audit, audit.rows["cycle_outcomes.csv"], "cycle outcome", ("SetupId",),
    )
    trades = {key[0]: row for key, row in trade_index_raw.items()}
    cycles = {key[0]: row for key, row in cycle_index_raw.items()}
    tolerance = float(config["financial_tolerance"])
    accepted_business = set(config["accepted_business_outcomes"])

    for setup_id in trades:
        if setup_id not in candidates:
            add_issue(audit, "ERROR", "ORPHAN_TRADE_OUTCOME", "Trade outcome has no candidate", setup_id)
        elif setup_id not in successful:
            add_issue(audit, "ERROR", "OUTCOME_WITHOUT_SUCCESS", "Trade outcome has no successful entry", setup_id)

    for setup_id in cycles:
        if setup_id not in candidates:
            add_issue(audit, "ERROR", "ORPHAN_CYCLE_OUTCOME", "Cycle outcome has no candidate", setup_id)
        elif setup_id not in successful:
            add_issue(audit, "ERROR", "CYCLE_WITHOUT_SUCCESS", "Cycle has no successful entry", setup_id)

    for setup_id in successful:
        trade = trades.get(setup_id)
        cycle = cycles.get(setup_id)
        if trade is None:
            add_issue(audit, "WARNING", "MISSING_TRADE_OUTCOME", "Successful entry has no trade outcome", setup_id)
            audit.excluded[setup_id].add("missing_trade_outcome")
        if cycle is None:
            add_issue(audit, "WARNING", "MISSING_CYCLE_OUTCOME", "Successful entry has no cycle outcome", setup_id)
            audit.excluded[setup_id].add("missing_cycle_outcome")
        if trade is None or cycle is None:
            continue
        trade_net = parse_float(trade["NetProfit"])
        original_net = parse_float(cycle["OriginalNetProfit"])
        recovery_net = parse_float(cycle["RecoveryNetProfit"])
        cycle_net = parse_float(cycle["CycleNetProfit"])
        if None in (trade_net, original_net, recovery_net, cycle_net):
            add_issue(audit, "ERROR", "INVALID_FINANCIAL", "Outcome financial contains NA/invalid value", setup_id)
            audit.excluded[setup_id].add("invalid_financial")
        else:
            if abs(trade_net - original_net) > tolerance:
                add_issue(audit, "ERROR", "ORIGINAL_FINANCIAL_MISMATCH", "Trade and cycle original net differ", setup_id)
                audit.excluded[setup_id].add("financial_mismatch")
            if abs(cycle_net - (original_net + recovery_net)) > tolerance:
                add_issue(audit, "ERROR", "CYCLE_FINANCIAL_MISMATCH", "Cycle net does not reconcile", setup_id)
                audit.excluded[setup_id].add("financial_mismatch")

        outcome = cycle["BusinessOutcome"]
        recovery_started = parse_bool(cycle["RecoveryStarted"])
        max_level = parse_int(cycle["MaxRecoveryLevel"])
        if outcome not in accepted_business:
            add_issue(audit, "ERROR", "UNKNOWN_BUSINESS_OUTCOME", f"Unknown outcome {outcome!r}", setup_id)
            audit.excluded[setup_id].add("unknown_business_outcome")
        elif outcome == "INCOMPLETE":
            audit.excluded[setup_id].add("cycle_incomplete")
        elif outcome == "NO_RECOVERY" and (recovery_started is not False or max_level != 0):
            add_issue(audit, "ERROR", "NO_RECOVERY_CONTRACT_MISMATCH", "NO_RECOVERY has recovery state", setup_id)
            audit.excluded[setup_id].add("business_label_mismatch")
        elif outcome == "RECOVERY_L1_L3" and (
            recovery_started is not True or max_level is None or not 1 <= max_level <= 3
        ):
            add_issue(audit, "ERROR", "RECOVERY_DEPTH_MISMATCH", "L1_L3 depth is inconsistent", setup_id)
            audit.excluded[setup_id].add("business_label_mismatch")
        elif outcome == "RECOVERY_L4_PLUS" and (
            recovery_started is not True or max_level is None or max_level < 4
        ):
            add_issue(audit, "ERROR", "RECOVERY_DEPTH_MISMATCH", "L4_PLUS depth is inconsistent", setup_id)
            audit.excluded[setup_id].add("business_label_mismatch")
    return trades, cycles


def validate_run_reconciliation(
    audit: RunAudit,
    config: Mapping[str, Any],
    candidates: Mapping[str, dict[str, str]],
    cycles: Mapping[str, dict[str, str]],
) -> None:
    if not audit.context:
        return
    tester = audit.context.get("tester", {})
    if not isinstance(tester, dict):
        return
    expected_candidates = parse_int(str(tester.get("candidate_count", "")))
    if expected_candidates is not None and expected_candidates != len(candidates):
        add_issue(
            audit,
            "ERROR",
            "CONTEXT_CANDIDATE_COUNT_MISMATCH",
            f"Context candidate_count={expected_candidates}, CSV={len(candidates)}",
        )
    initial_balance = parse_float(str(tester.get("initial_deposit", "")))
    final_balance = parse_float(str(tester.get("final_balance", "")))
    cycle_values = [parse_float(row["CycleNetProfit"]) for row in cycles.values()]
    if initial_balance is None or final_balance is None or any(
        value is None for value in cycle_values
    ):
        return
    cycle_total = sum(value for value in cycle_values if value is not None)
    balance_change = final_balance - initial_balance
    if abs(cycle_total - balance_change) > float(config["financial_tolerance"]):
        add_issue(
            audit,
            "ERROR",
            "RUN_BALANCE_RECONCILIATION_FAILED",
            f"Sum CycleNetProfit={cycle_total:.2f}, balance change={balance_change:.2f}",
        )


def build_merged_rows(
    audit: RunAudit,
    candidates: Mapping[str, dict[str, str]],
    successful: Mapping[str, dict[str, str]],
    barriers: Mapping[tuple[str, int], dict[str, str]],
    trades: Mapping[str, dict[str, str]],
    cycles: Mapping[str, dict[str, str]],
) -> None:
    if audit.error_count:
        for setup_id in candidates:
            audit.excluded[setup_id].add("run_has_audit_error")
        return
    for setup_id, candidate in candidates.items():
        if audit.excluded.get(setup_id):
            continue
        entry = successful.get(setup_id)
        barrier40 = barriers.get((setup_id, 40))
        barrier50 = barriers.get((setup_id, 50))
        trade = trades.get(setup_id)
        cycle = cycles.get(setup_id)
        if None in (entry, barrier40, barrier50, trade, cycle):
            audit.excluded[setup_id].add("incomplete_pairing")
            continue
        merged = dict(candidate)
        merged.update(
            {
                "Barrier40Outcome": barrier40["BarrierOutcome"],
                "Barrier40ElapsedBars": barrier40["ElapsedBars"],
                "Barrier50Outcome": barrier50["BarrierOutcome"],
                "Barrier50ElapsedBars": barrier50["ElapsedBars"],
                "TradeNetProfit": trade["NetProfit"],
                "TradeBarsHeld": trade["BarsHeld"],
                "TradeMFEPoints": trade["MFEPoints"],
                "TradeMAEPoints": trade["MAEPoints"],
                "TradeExitReason": trade["ExitReason"],
                "BusinessOutcome": cycle["BusinessOutcome"],
                "OriginalNetProfit": cycle["OriginalNetProfit"],
                "RecoveryNetProfit": cycle["RecoveryNetProfit"],
                "CycleNetProfit": cycle["CycleNetProfit"],
                "RecoveryStarted": cycle["RecoveryStarted"],
                "RecoveryEntries": cycle["RecoveryEntries"],
                "MaxRecoveryLevel": cycle["MaxRecoveryLevel"],
                "CycleCompletionReason": cycle["CompletionReason"],
            }
        )
        audit.merged_rows.append(merged)


def audit_run(path: Path, config: Mapping[str, Any]) -> RunAudit:
    audit = RunAudit(path.name, path)
    try:
        audit.manifest = read_json(path / "run_manifest.json")
    except AuditFailure as exc:
        add_issue(audit, "ERROR", "MANIFEST_READ_ERROR", str(exc))
        return audit
    manifest_run_id = str(audit.manifest.get("run_id", ""))
    if manifest_run_id:
        audit.run_id = path.name
    validate_manifest(audit, config)
    context_path = path / "collection_context.json"
    if context_path.is_file():
        try:
            audit.context = read_json(context_path)
        except AuditFailure as exc:
            add_issue(audit, "ERROR", "CONTEXT_READ_ERROR", str(exc))
    validate_collection_context(audit, config)
    for file_name in CSV_FILES:
        audit.rows[file_name] = read_csv_exact(audit, file_name)
        validate_row_provenance(audit, file_name, audit.rows[file_name])

    critical_file_codes = {
        "MISSING_FILE", "HEADER_MISMATCH", "MALFORMED_ROW", "CSV_READ_ERROR",
        "UNSUPPORTED_SCHEMA",
    }
    if any(issue.code in critical_file_codes for issue in audit.issues):
        for row in audit.rows.get("candidate_setups.csv", []):
            setup_id = row.get("SetupId", "")
            if setup_id:
                audit.excluded[setup_id].add("run_file_contract_error")
        return audit

    candidates = validate_candidates(audit)
    _, successful = validate_entries(audit, candidates)
    barriers = validate_barriers(audit, config, candidates)
    trades, cycles = validate_outcomes(audit, config, candidates, successful)
    validate_run_reconciliation(audit, config, candidates, cycles)
    build_merged_rows(audit, candidates, successful, barriers, trades, cycles)
    return audit


def row_signature(row: Mapping[str, str]) -> str:
    ignored = {"RunId", "SourceRevision"}
    payload = "\x1f".join(
        f"{key}={row[key]}" for key in sorted(row) if key not in ignored
    ).encode("utf-8")
    return sha256_bytes(payload)


def deduplicate_runs(
    audits: Sequence[RunAudit],
    duplicate_policy: str,
) -> tuple[list[dict[str, str]], list[Issue], list[dict[str, str]]]:
    merged: list[dict[str, str]] = []
    issues: list[Issue] = []
    excluded: list[dict[str, str]] = []
    by_setup: dict[str, tuple[str, dict[str, str], str]] = {}
    ordered_rows = sorted(
        (row for audit in audits for row in audit.merged_rows),
        key=lambda row: (row["CandidateTime"], row["RunId"], row["SetupId"]),
    )
    for row in ordered_rows:
        setup_id = row["SetupId"]
        signature = row_signature(row)
        previous = by_setup.get(setup_id)
        if previous is None:
            by_setup[setup_id] = (signature, row, row["RunId"])
            merged.append(row)
            continue
        previous_signature, _, previous_run = previous
        if signature != previous_signature:
            issues.append(
                Issue(
                    "ERROR", "CONFLICTING_CROSS_RUN_DUPLICATE",
                    f"Setup differs between runs {previous_run} and {row['RunId']}",
                    row["RunId"], setup_id,
                )
            )
            excluded.extend(
                [
                    {
                        "RunId": previous_run, "SetupId": setup_id,
                        "Reasons": "conflicting_cross_run_duplicate",
                    },
                    {
                        "RunId": row["RunId"], "SetupId": setup_id,
                        "Reasons": "conflicting_cross_run_duplicate",
                    },
                ]
            )
        elif duplicate_policy == "keep_first_identical":
            issues.append(
                Issue(
                    "WARNING", "IDENTICAL_CROSS_RUN_DUPLICATE",
                    f"Identical setup already retained from run {previous_run}",
                    row["RunId"], setup_id,
                )
            )
            excluded.append(
                {
                    "RunId": row["RunId"], "SetupId": setup_id,
                    "Reasons": "identical_cross_run_duplicate",
                }
            )
        else:
            issues.append(
                Issue(
                    "ERROR", "DUPLICATE_POLICY_REJECTED",
                    f"Duplicate SetupId found under policy {duplicate_policy!r}",
                    row["RunId"], setup_id,
                )
            )
    return merged, issues, excluded


def rate(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return "NA"
    return f"{numerator / denominator:.8f}"


def summarize_group(
    analysis_type: str,
    feature: str,
    group_value: str,
    rows: Sequence[Mapping[str, str]],
    minimum_count: int,
) -> dict[str, str]:
    count = len(rows)
    favorable = sum(row["Barrier50Outcome"] == "FAVORABLE_FIRST" for row in rows)
    no_recovery = sum(row["BusinessOutcome"] == "NO_RECOVERY" for row in rows)
    l4_plus = sum(row["BusinessOutcome"] == "RECOVERY_L4_PLUS" for row in rows)
    original_net = sum(parse_float(row["OriginalNetProfit"]) or 0.0 for row in rows)
    cycle_net = sum(parse_float(row["CycleNetProfit"]) or 0.0 for row in rows)
    return {
        "AnalysisType": analysis_type,
        "Feature": feature,
        "Group": group_value,
        "Count": str(count),
        "MeetsMinimumCount": str(count >= minimum_count).lower(),
        "Barrier50FavorableRate": rate(favorable, count),
        "NoRecoveryRate": rate(no_recovery, count),
        "L4PlusRate": rate(l4_plus, count),
        "OriginalNetSum": f"{original_net:.2f}",
        "CycleNetSum": f"{cycle_net:.2f}",
    }


def rule_analysis(
    rows: Sequence[dict[str, str]],
    config: Mapping[str, Any],
) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    minimum = int(config["minimum_rule_group_size"])
    for feature in config["categorical_rule_features"]:
        groups: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row in rows:
            groups[row.get(feature, "NA")].append(row)
        for value in sorted(groups):
            output.append(summarize_group("categorical", feature, value, groups[value], minimum))

    for feature in config["numeric_rule_features"]:
        numeric_rows = [
            (parse_float(row.get(feature, "NA")), row) for row in rows
        ]
        numeric_rows = [(value, row) for value, row in numeric_rows if value is not None]
        numeric_rows.sort(key=lambda item: item[0])
        if not numeric_rows:
            continue
        bucket_count = min(4, len(numeric_rows))
        for bucket in range(bucket_count):
            start = bucket * len(numeric_rows) // bucket_count
            end = (bucket + 1) * len(numeric_rows) // bucket_count
            chunk = numeric_rows[start:end]
            if not chunk:
                continue
            label = f"Q{bucket + 1}[{chunk[0][0]:.6g},{chunk[-1][0]:.6g}]"
            output.append(
                summarize_group(
                    "numeric_quantile", feature, label,
                    [row for _, row in chunk], minimum,
                )
            )
    return output


def write_csv(path: Path, header: Sequence[str], rows: Iterable[Mapping[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def issue_counts(issues: Sequence[Issue]) -> dict[str, int]:
    return dict(sorted(Counter(issue.severity for issue in issues).items()))


def label_counts(rows: Sequence[Mapping[str, str]], field_name: str) -> dict[str, int]:
    return dict(sorted(Counter(row[field_name] for row in rows).items()))


def render_markdown(report: Mapping[str, Any]) -> str:
    totals = report["totals"]
    lines = [
        "# TS7 ML Dataset Audit",
        "",
        f"- Generated UTC: `{report['generated_at_utc']}`",
        f"- Schema: `{report['schema_version']}`",
        f"- Config SHA-256: `{report['config_sha256']}`",
        f"- Runs discovered: {totals['runs_discovered']}",
        f"- Runs accepted: {totals['runs_accepted']}",
        f"- Raw candidates: {totals['raw_candidates']}",
        f"- Retained candidates: {totals['retained_candidates']}",
        f"- Excluded candidates: {totals['excluded_candidates']}",
        f"- Errors / warnings: {totals['errors']} / {totals['warnings']}",
        "",
        "## Run inventory",
        "",
        "| RunId | Candidates | Retained | Errors | Warnings | Integrity flag |",
        "| --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for run in report["runs"]:
        lines.append(
            f"| `{run['run_id']}` | {run['candidate_count']} | {run['retained_count']} | "
            f"{run['errors']} | {run['warnings']} | `{run['data_integrity_flag']}` |"
        )
    lines.extend(
        [
            "",
            "## Retained label distribution",
            "",
            f"- Barrier 50: `{json.dumps(report['barrier50_distribution'], sort_keys=True)}`",
            f"- Business outcome: `{json.dumps(report['business_distribution'], sort_keys=True)}`",
            "",
            "## Data-integrity distribution",
            "",
            f"`{json.dumps(report['data_integrity_distribution'], sort_keys=True)}`",
            "",
            "## Gate",
            "",
            "PASS" if totals["errors"] == 0 else "FAIL — lihat `audit_issues.csv`.",
            "",
            "Laporan ini hanya audit/descriptive analysis. Ia bukan hasil training atau izin untuk "
            "mengaktifkan ML filter.",
            "",
        ]
    )
    return "\n".join(lines)


def prepare_output_directory(output_dir: Path, replace: bool, repo_root: Path) -> None:
    resolved_output = output_dir.resolve()
    resolved_repo = repo_root.resolve()
    try:
        resolved_output.relative_to(resolved_repo)
    except ValueError:
        pass
    else:
        raise AuditFailure(
            f"Processed output must stay outside the repository: {resolved_output}"
        )
    if output_dir.exists():
        if not replace:
            raise AuditFailure(
                f"Output directory already exists: {output_dir}. "
                "Use --replace-output only after reviewing the target."
            )
        if output_dir.resolve() in (
            Path.home().resolve(),
            resolved_repo,
            Path(output_dir.resolve().anchor),
        ):
            raise AuditFailure(f"Refusing to replace unsafe output directory: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)


def audit_dataset(
    raw_root: Path,
    output_dir: Path,
    config: Mapping[str, Any],
    replace_output: bool = False,
    repo_root: Path | None = None,
) -> dict[str, Any]:
    repo_root = repo_root or Path(__file__).resolve().parents[2]
    validate_config(config)
    resolved_raw = raw_root.resolve()
    resolved_output = output_dir.resolve()
    if (
        resolved_output == resolved_raw
        or resolved_output in resolved_raw.parents
        or resolved_raw in resolved_output.parents
    ):
        raise AuditFailure(
            "Raw and processed directories must be separate siblings; "
            "neither may contain the other"
        )
    run_dirs = discover_run_directories(raw_root)
    if not run_dirs:
        raise AuditFailure(f"No run_manifest.json found under {raw_root}")
    prepare_output_directory(output_dir, replace_output, repo_root)

    audits = [audit_run(path, config) for path in run_dirs]
    merged, cross_run_issues, cross_run_excluded = deduplicate_runs(
        audits, str(config["duplicate_policy"]),
    )
    all_issues = [issue for audit in audits for issue in audit.issues] + cross_run_issues
    exclusion_map: dict[tuple[str, str], set[str]] = defaultdict(set)
    for audit in audits:
        for setup_id, reasons in audit.excluded.items():
            exclusion_map[(audit.run_id, setup_id)].update(reasons)
    for row in cross_run_excluded:
        exclusion_map[(row["RunId"], row["SetupId"])].update(
            row["Reasons"].split("|")
        )
    excluded_rows = [
        {
            "RunId": run_id,
            "SetupId": setup_id,
            "Reasons": "|".join(sorted(reasons)),
        }
        for (run_id, setup_id), reasons in sorted(exclusion_map.items())
    ]
    excluded_keys = {(row["RunId"], row["SetupId"]) for row in excluded_rows}
    merged = [
        row for row in merged
        if (row["RunId"], row["SetupId"]) not in excluded_keys
    ]
    merged.sort(key=lambda row: (row["CandidateTime"], row["RunId"], row["SetupId"]))

    analysis_rows = rule_analysis(merged, config)
    merged_header = (
        candidate_header_for_schema(str(config["schema_version"]))
        + MERGED_LABEL_HEADER
    )
    write_csv(output_dir / "merged_candidates.csv", merged_header, merged)
    write_csv(
        output_dir / "excluded_candidates.csv",
        ("RunId", "SetupId", "Reasons"),
        sorted(excluded_rows, key=lambda row: (row["RunId"], row["SetupId"], row["Reasons"])),
    )
    write_csv(
        output_dir / "audit_issues.csv",
        ("severity", "code", "detail", "run_id", "setup_id"),
        [asdict(issue) for issue in all_issues],
    )
    write_csv(
        output_dir / "rule_analysis.csv",
        (
            "AnalysisType", "Feature", "Group", "Count", "MeetsMinimumCount",
            "Barrier50FavorableRate", "NoRecoveryRate", "L4PlusRate",
            "OriginalNetSum", "CycleNetSum",
        ),
        analysis_rows,
    )

    inventory_rows = []
    for audit in audits:
        candidates = audit.rows.get("candidate_setups.csv", [])
        tester_context = audit.context.get("tester", {})
        if not isinstance(tester_context, dict):
            tester_context = {}
        artifact_context = audit.context.get("artifacts", {})
        if not isinstance(artifact_context, dict):
            artifact_context = {}
        context_path = audit.path / "collection_context.json"
        inventory_rows.append(
            {
                "RunId": audit.run_id,
                "Path": str(audit.path.resolve()),
                "ManifestSHA256": sha256_file(audit.path / "run_manifest.json"),
                "ContextSHA256": (
                    sha256_file(context_path) if context_path.is_file() else ""
                ),
                "CandidateCount": len(candidates),
                "RetainedCount": sum(row["RunId"] == audit.run_id for row in merged),
                "ErrorCount": audit.error_count,
                "WarningCount": audit.warning_count,
                "StrategyVersion": audit.manifest.get("strategy_version", ""),
                "SourceRevision": audit.manifest.get("source_revision", ""),
                "PresetSHA256": audit.manifest.get("preset_sha256", ""),
                "Symbol": audit.manifest.get("symbol", ""),
                "Timeframe": audit.manifest.get("timeframe", ""),
                "DataIntegrityFlag": audit.manifest.get("data_integrity_flag", ""),
                "TestFrom": tester_context.get("from", ""),
                "TestTo": tester_context.get("to", ""),
                "TesterModel": tester_context.get("model", ""),
                "HistoryQualityPercent": tester_context.get(
                    "history_quality_percent", ""
                ),
                "TerminationStatus": tester_context.get("termination_status", ""),
                "InitialDeposit": tester_context.get("initial_deposit", ""),
                "FinalBalance": tester_context.get("final_balance", ""),
                "EAEX5SHA256": (
                    artifact_context.get("ea_ex5", {}).get("sha256", "")
                    if isinstance(artifact_context.get("ea_ex5"), dict) else ""
                ),
                "ReportSHA256": (
                    artifact_context.get("report", {}).get("sha256", "")
                    if isinstance(artifact_context.get("report"), dict) else ""
                ),
                "CandidateMinTime": min(
                    (row["CandidateTime"] for row in candidates), default=""
                ),
                "CandidateMaxTime": max(
                    (row["CandidateTime"] for row in candidates), default=""
                ),
            }
        )
    inventory_header = tuple(inventory_rows[0].keys())
    write_csv(output_dir / "run_inventory.csv", inventory_header, inventory_rows)

    error_total = sum(issue.severity == "ERROR" for issue in all_issues)
    warning_total = sum(issue.severity == "WARNING" for issue in all_issues)
    report: dict[str, Any] = {
        "generated_at_utc": utc_now_text(),
        "schema_version": config["schema_version"],
        "config_sha256": canonical_config_hash(config),
        "audit_tool_sha256": sha256_file(Path(__file__).resolve()),
        "raw_root": str(raw_root.resolve()),
        "output_directory": str(output_dir.resolve()),
        "totals": {
            "runs_discovered": len(audits),
            "runs_accepted": sum(audit.error_count == 0 for audit in audits),
            "raw_candidates": sum(
                len(audit.rows.get("candidate_setups.csv", [])) for audit in audits
            ),
            "retained_candidates": len(merged),
            "excluded_candidates": len(excluded_rows),
            "errors": error_total,
            "warnings": warning_total,
        },
        "runs": [
            {
                "run_id": row["RunId"],
                "candidate_count": row["CandidateCount"],
                "retained_count": row["RetainedCount"],
                "errors": row["ErrorCount"],
                "warnings": row["WarningCount"],
                "strategy_version": row["StrategyVersion"],
                "source_revision": row["SourceRevision"],
                "preset_sha256": row["PresetSHA256"],
                "symbol": row["Symbol"],
                "timeframe": row["Timeframe"],
                "data_integrity_flag": row["DataIntegrityFlag"],
                "test_from": row["TestFrom"],
                "test_to": row["TestTo"],
                "tester_model": row["TesterModel"],
                "candidate_min_time": row["CandidateMinTime"],
                "candidate_max_time": row["CandidateMaxTime"],
            }
            for row in inventory_rows
        ],
        "issue_distribution": issue_counts(all_issues),
        "barrier50_distribution": label_counts(merged, "Barrier50Outcome"),
        "business_distribution": label_counts(merged, "BusinessOutcome"),
        "data_integrity_distribution": label_counts(merged, "DataIntegrityFlag"),
        "artifacts": {},
    }
    config_snapshot = output_dir / "audit_config.snapshot.json"
    config_snapshot.write_text(
        json.dumps(config, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    for artifact in (
        "merged_candidates.csv", "excluded_candidates.csv", "audit_issues.csv",
        "rule_analysis.csv", "run_inventory.csv", "audit_config.snapshot.json",
    ):
        report["artifacts"][artifact] = {
            "sha256": sha256_file(output_dir / artifact),
            "bytes": (output_dir / artifact).stat().st_size,
        }
    with (output_dir / "audit_report.json").open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    (output_dir / "audit_report.md").write_text(
        render_markdown(report), encoding="utf-8",
    )
    return report


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    default_config = Path(__file__).resolve().parents[2] / "config" / "ml-dataset-audit.json"
    parser = argparse.ArgumentParser(
        description="Audit and merge TS7 ML observation-only logger runs.",
    )
    parser.add_argument("--raw-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--config", type=Path, default=default_config)
    parser.add_argument(
        "--replace-output",
        action="store_true",
        help="Replace the exact output directory after safety checks.",
    )
    parser.add_argument(
        "--allow-audit-errors",
        action="store_true",
        help="Return success even when the report contains audit errors.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = read_json(args.config)
        report = audit_dataset(
            args.raw_root,
            args.output_dir,
            config,
            replace_output=args.replace_output,
        )
    except AuditFailure as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    totals = report["totals"]
    print(
        "TS7_ML_AUDIT"
        f"|Runs={totals['runs_discovered']}"
        f"|Accepted={totals['runs_accepted']}"
        f"|RawCandidates={totals['raw_candidates']}"
        f"|Retained={totals['retained_candidates']}"
        f"|Excluded={totals['excluded_candidates']}"
        f"|Errors={totals['errors']}"
        f"|Warnings={totals['warnings']}"
        f"|Output={args.output_dir.resolve()}"
    )
    if totals["errors"] and not args.allow_audit_errors:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
