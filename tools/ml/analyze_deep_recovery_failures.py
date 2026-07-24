#!/usr/bin/env python3
"""Analyze recurring Phase 3 L4+ false negatives without opening final OOS."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


class DeepRecoveryFailure(RuntimeError):
    """Raised when the diagnostic inputs cannot be audited."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise DeepRecoveryFailure(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise DeepRecoveryFailure(f"JSON root must be an object: {path}")
    return value


def merge_config(
    base: Mapping[str, Any], override: Mapping[str, Any]
) -> dict[str, Any]:
    merged: dict[str, Any] = dict(base)
    for key, value in override.items():
        if (
            key in merged
            and isinstance(merged[key], dict)
            and isinstance(value, Mapping)
        ):
            merged[key] = merge_config(merged[key], value)
        else:
            merged[key] = value
    return merged


def read_inherited_config(
    path: Path, seen: set[Path] | None = None
) -> dict[str, Any]:
    resolved = path.resolve()
    visited = set() if seen is None else set(seen)
    if resolved in visited:
        raise DeepRecoveryFailure(f"Config inheritance cycle at {resolved}")
    visited.add(resolved)
    config = read_json(resolved)
    parent_name = config.pop("extends", None)
    if parent_name is None:
        return config
    if not isinstance(parent_name, str) or not parent_name.strip():
        raise DeepRecoveryFailure(f"Invalid extends value in {resolved}")
    parent = read_inherited_config(resolved.parent / parent_name, visited)
    return merge_config(parent, config)


def parse_float(value: Any, field: str) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise DeepRecoveryFailure(f"Invalid numeric {field}: {value!r}") from exc
    if not math.isfinite(parsed):
        raise DeepRecoveryFailure(f"Non-finite numeric {field}: {value!r}")
    return parsed


def optional_float(value: Any) -> float | None:
    if value is None or str(value).strip().upper() in {"", "NA", "N/A"}:
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed if math.isfinite(parsed) else None


def parse_bool(value: Any, field: str) -> bool:
    normalized = str(value).strip().lower()
    if normalized in {"true", "1"}:
        return True
    if normalized in {"false", "0"}:
        return False
    raise DeepRecoveryFailure(f"Invalid boolean {field}: {value!r}")


def read_csv(path: Path, required: set[str]) -> list[dict[str, str]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = set(reader.fieldnames or [])
            missing = required - fields
            if missing:
                raise DeepRecoveryFailure(
                    f"{path} missing fields: {', '.join(sorted(missing))}"
                )
            return [dict(row) for row in reader]
    except OSError as exc:
        raise DeepRecoveryFailure(f"Cannot read CSV {path}: {exc}") from exc


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields: list[str] = []
    for row in rows:
        for field in row:
            if field not in fields:
                fields.append(field)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def auc(labels: Sequence[int], scores: Sequence[float]) -> float | None:
    if len(labels) != len(scores) or not labels:
        return None
    positives = sum(labels)
    negatives = len(labels) - positives
    if positives == 0 or negatives == 0:
        return None
    ordered = sorted(zip(scores, labels), key=lambda item: item[0])
    positive_rank_sum = 0.0
    position = 1
    index = 0
    while index < len(ordered):
        end = index + 1
        while end < len(ordered) and ordered[end][0] == ordered[index][0]:
            end += 1
        average_rank = (position + position + end - index - 1) / 2.0
        positive_rank_sum += average_rank * sum(
            label for _, label in ordered[index:end]
        )
        position += end - index
        index = end
    return (
        positive_rank_sum - positives * (positives + 1) / 2.0
    ) / (positives * negatives)


def percentile_ranks(values: Sequence[float]) -> list[float]:
    ordered = sorted(enumerate(values), key=lambda item: item[1])
    ranks = [0.0] * len(values)
    index = 0
    denominator = max(1, len(values) - 1)
    while index < len(ordered):
        end = index + 1
        while end < len(ordered) and ordered[end][1] == ordered[index][1]:
            end += 1
        rank = ((index + end - 1) / 2.0) / denominator
        for position in range(index, end):
            ranks[ordered[position][0]] = rank
        index = end
    return ranks


def load_feature_contracts(
    config: Mapping[str, Any], config_dir: Path
) -> tuple[list[str], list[str]]:
    numeric: list[str] = []
    boolean: list[str] = []
    for name in config["feature_configs"]:
        model = read_inherited_config(config_dir / str(name))
        contract = model.get("feature_contract", {})
        for field in contract.get("numeric", []):
            if field not in numeric:
                numeric.append(field)
        for field in contract.get("boolean", []):
            if field not in boolean:
                boolean.append(field)
    if not numeric:
        raise DeepRecoveryFailure("No numeric features resolved from feature configs")
    return numeric, boolean


def load_dataset(
    path: Path,
    config: Mapping[str, Any],
    numeric: Sequence[str],
    boolean: Sequence[str],
) -> list[dict[str, str]]:
    required = {
        "SchemaVersion",
        "RunId",
        "SetupId",
        "CandidateTime",
        "BusinessOutcome",
        *numeric,
        *boolean,
        *config["subgroup_fields"],
    }
    rows = read_csv(path, required)
    if len(rows) < int(config["minimum_rows"]):
        raise DeepRecoveryFailure(
            f"Dataset has {len(rows)} rows; minimum is {config['minimum_rows']}"
        )
    if len({row["SetupId"] for row in rows}) != len(rows):
        raise DeepRecoveryFailure("Dataset contains duplicate SetupId")
    for row in rows:
        if row["SchemaVersion"] != config["dataset_schema"]:
            raise DeepRecoveryFailure(
                f"Unexpected schema for SetupId={row['SetupId']}"
            )
    outcomes = Counter(row["BusinessOutcome"] for row in rows)
    if outcomes[config["l4_outcome"]] < int(config["minimum_l4_rows"]):
        raise DeepRecoveryFailure("Dataset has too few L4+ rows")
    return rows


def load_predictions(
    artifact_root: Path,
    config: Mapping[str, Any],
    dataset_by_id: Mapping[str, Mapping[str, str]],
) -> tuple[list[dict[str, Any]], dict[str, str]]:
    required = {
        "Fold",
        "Pairing",
        "SetupId",
        "CandidateTime",
        "BusinessOutcome",
        "NoRecoveryProbability",
        "L4RiskProbability",
        "NoRecoveryThreshold",
        "L4RiskThreshold",
        "Allowed",
    }
    expected_pairings = set(config["pairings"])
    loaded: list[dict[str, Any]] = []
    hashes: dict[str, str] = {}
    seen: set[tuple[str, str, str]] = set()
    for family, directory in config["prediction_artifacts"].items():
        path = artifact_root / str(directory) / "predictions.csv"
        hashes[str(family)] = sha256_file(path)
        rows = read_csv(path, required)
        actual_pairings = {row["Pairing"] for row in rows}
        if actual_pairings != expected_pairings:
            raise DeepRecoveryFailure(
                f"{family} pairings mismatch: {sorted(actual_pairings)}"
            )
        for row in rows:
            setup_id = row["SetupId"]
            dataset_row = dataset_by_id.get(setup_id)
            if dataset_row is None:
                raise DeepRecoveryFailure(
                    f"Prediction SetupId absent from dataset: {setup_id}"
                )
            if row["BusinessOutcome"] != dataset_row["BusinessOutcome"]:
                raise DeepRecoveryFailure(
                    f"Outcome mismatch for SetupId={setup_id}"
                )
            key = (str(family), row["Pairing"], setup_id)
            if key in seen:
                raise DeepRecoveryFailure(f"Duplicate prediction key: {key}")
            seen.add(key)
            loaded.append(
                {
                    **row,
                    "Family": str(family),
                    "Fold": int(row["Fold"]),
                    "Allowed": parse_bool(row["Allowed"], "Allowed"),
                    "NoRecoveryProbability": parse_float(
                        row["NoRecoveryProbability"], "NoRecoveryProbability"
                    ),
                    "L4RiskProbability": parse_float(
                        row["L4RiskProbability"], "L4RiskProbability"
                    ),
                    "NoRecoveryThreshold": parse_float(
                        row["NoRecoveryThreshold"], "NoRecoveryThreshold"
                    ),
                    "L4RiskThreshold": parse_float(
                        row["L4RiskThreshold"], "L4RiskThreshold"
                    ),
                }
            )
    return loaded, hashes


def consensus_diagnostics(
    predictions: Sequence[Mapping[str, Any]],
    config: Mapping[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    grouped: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for row in predictions:
        grouped[str(row["SetupId"])].append(row)
    expected = len(config["prediction_artifacts"]) * len(config["pairings"])
    threshold = float(config["persistent_allowed_fraction_min"])
    candidates: list[dict[str, Any]] = []
    for setup_id, rows in grouped.items():
        if len(rows) != expected:
            raise DeepRecoveryFailure(
                f"SetupId={setup_id} has {len(rows)}/{expected} predictions"
            )
        allowed = sum(bool(row["Allowed"]) for row in rows)
        l4_veto = sum(
            float(row["L4RiskProbability"]) > float(row["L4RiskThreshold"])
            for row in rows
        )
        no_recovery_pass = sum(
            float(row["NoRecoveryProbability"])
            >= float(row["NoRecoveryThreshold"])
            for row in rows
        )
        outcome = str(rows[0]["BusinessOutcome"])
        allowed_fraction = allowed / expected
        candidates.append(
            {
                "SetupId": setup_id,
                "CandidateTime": rows[0]["CandidateTime"],
                "Fold": rows[0]["Fold"],
                "BusinessOutcome": outcome,
                "PredictionCount": expected,
                "AllowedCount": allowed,
                "AllowedFraction": allowed_fraction,
                "L4RiskVetoCount": l4_veto,
                "NoRecoveryPassCount": no_recovery_pass,
                "PersistentAllowed": allowed_fraction >= threshold,
                "PersistentL4Escape": (
                    outcome == config["l4_outcome"]
                    and allowed_fraction >= threshold
                ),
            }
        )
    matrix: list[dict[str, Any]] = []
    for (family, pairing), rows in sorted(
        _group_by(predictions, lambda row: (row["Family"], row["Pairing"])).items()
    ):
        l4_rows = [
            row for row in rows if row["BusinessOutcome"] == config["l4_outcome"]
        ]
        matrix.append(
            {
                "Family": family,
                "Pairing": pairing,
                "EvaluationCandidates": len(rows),
                "L4Candidates": len(l4_rows),
                "AllowedL4": sum(bool(row["Allowed"]) for row in l4_rows),
                "L4RiskVetoed": sum(
                    float(row["L4RiskProbability"])
                    > float(row["L4RiskThreshold"])
                    for row in l4_rows
                ),
                "MeanL4RiskProbability": _mean(
                    float(row["L4RiskProbability"]) for row in l4_rows
                ),
            }
        )
    return sorted(candidates, key=lambda row: row["CandidateTime"]), matrix


def _group_by(
    rows: Iterable[Mapping[str, Any]], key
) -> dict[Any, list[Mapping[str, Any]]]:
    grouped: dict[Any, list[Mapping[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[key(row)].append(row)
    return grouped


def _mean(values: Iterable[float]) -> float | None:
    items = list(values)
    return sum(items) / len(items) if items else None


def feature_depth_separation(
    recovery_rows: Sequence[Mapping[str, str]],
    features: Sequence[str],
    boolean_features: set[str],
    config: Mapping[str, Any],
) -> list[dict[str, Any]]:
    run_ids = sorted({row["RunId"] for row in recovery_rows})
    results: list[dict[str, Any]] = []
    for feature in features:
        run_aucs: dict[str, float | None] = {}
        pooled_labels: list[int] = []
        pooled_scores: list[float] = []
        for run_id in run_ids:
            labels: list[int] = []
            scores: list[float] = []
            for row in recovery_rows:
                if row["RunId"] != run_id:
                    continue
                value = (
                    float(parse_bool(row.get(feature), feature))
                    if feature in boolean_features
                    else optional_float(row.get(feature))
                )
                if value is None:
                    continue
                labels.append(int(row["BusinessOutcome"] == config["l4_outcome"]))
                scores.append(value)
            run_aucs[run_id] = auc(labels, scores)
            pooled_labels.extend(labels)
            pooled_scores.extend(scores)
        valid = [value for value in run_aucs.values() if value is not None]
        same_direction = bool(valid) and (
            all(value >= 0.5 for value in valid)
            or all(value <= 0.5 for value in valid)
        )
        minimum_separation = (
            min(abs(value - 0.5) for value in valid) if valid else 0.0
        )
        result: dict[str, Any] = {
            "Feature": feature,
            "PooledAUC": auc(pooled_labels, pooled_scores),
            "AvailableRows": len(pooled_scores),
            "SameDirectionAcrossRuns": same_direction,
            "MinimumRunSeparation": minimum_separation,
            "StableAcrossRuns": (
                len(valid) == len(run_ids)
                and same_direction
                and minimum_separation
                >= float(config["minimum_run_auc_separation"])
            ),
        }
        for index, run_id in enumerate(run_ids, start=1):
            result[f"Run{index}"] = run_id
            result[f"Run{index}AUC"] = run_aucs[run_id]
        results.append(result)
    return sorted(
        results,
        key=lambda row: (
            not row["StableAcrossRuns"],
            -abs((row["PooledAUC"] or 0.5) - 0.5),
            row["Feature"],
        ),
    )


def pair_interactions(
    recovery_rows: Sequence[Mapping[str, str]],
    features: Sequence[str],
    config: Mapping[str, Any],
) -> list[dict[str, Any]]:
    run_ids = sorted(
        {row["RunId"] for row in recovery_rows},
        key=lambda run_id: min(
            row["CandidateTime"]
            for row in recovery_rows
            if row["RunId"] == run_id
        ),
    )
    if len(run_ids) != 2:
        raise DeepRecoveryFailure("Pair diagnostics require exactly two runs")
    by_run = {
        run_id: [row for row in recovery_rows if row["RunId"] == run_id]
        for run_id in run_ids
    }
    usable: dict[str, int] = {}
    ranks: dict[tuple[str, str], dict[str, float]] = {}
    for feature in features:
        discovery = by_run[run_ids[0]]
        values = [
            optional_float(row.get(feature))
            for row in discovery
        ]
        present = [
            (row, value)
            for row, value in zip(discovery, values)
            if value is not None
        ]
        discovery_auc = auc(
            [
                int(row["BusinessOutcome"] == config["l4_outcome"])
                for row, _ in present
            ],
            [float(value) for _, value in present],
        )
        if discovery_auc is None:
            continue
        orientation = 1 if discovery_auc >= 0.5 else -1
        usable[feature] = orientation
        for run_id, rows in by_run.items():
            available = [
                (row, optional_float(row.get(feature))) for row in rows
            ]
            available = [
                (row, value) for row, value in available if value is not None
            ]
            values_oriented = [
                orientation * float(value) for _, value in available
            ]
            ranked = percentile_ranks(values_oriented)
            ranks[(run_id, feature)] = {
                row["SetupId"]: rank
                for (row, _), rank in zip(available, ranked)
            }
    results: list[dict[str, Any]] = []
    names = sorted(usable)
    for left_index, left in enumerate(names):
        for right in names[left_index + 1 :]:
            result: dict[str, Any] = {
                "FeatureA": left,
                "FeatureB": right,
                "OrientationA": usable[left],
                "OrientationB": usable[right],
            }
            stable = True
            for run_index, run_id in enumerate(run_ids, start=1):
                labels: list[int] = []
                scores: list[float] = []
                for row in by_run[run_id]:
                    left_rank = ranks[(run_id, left)].get(row["SetupId"])
                    right_rank = ranks[(run_id, right)].get(row["SetupId"])
                    if left_rank is None or right_rank is None:
                        continue
                    labels.append(
                        int(row["BusinessOutcome"] == config["l4_outcome"])
                    )
                    scores.append((left_rank + right_rank) / 2.0)
                value = auc(labels, scores)
                result[f"Run{run_index}"] = run_id
                result[f"Run{run_index}AUC"] = value
                if value is None or value < float(config["stable_pair_auc_min"]):
                    stable = False
            result["StableConfirmation"] = stable
            results.append(result)
    return sorted(
        results,
        key=lambda row: (
            not row["StableConfirmation"],
            -(row.get("Run2AUC") or 0.0),
            -(row.get("Run1AUC") or 0.0),
            row["FeatureA"],
            row["FeatureB"],
        ),
    )


def subgroup_depth_rates(
    recovery_rows: Sequence[Mapping[str, str]],
    config: Mapping[str, Any],
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    scopes = ["POOLED", *sorted({row["RunId"] for row in recovery_rows})]
    minimum = int(config["minimum_subgroup_rows"])
    for field in config["subgroup_fields"]:
        for scope in scopes:
            scoped = (
                list(recovery_rows)
                if scope == "POOLED"
                else [row for row in recovery_rows if row["RunId"] == scope]
            )
            for value, rows in sorted(
                _group_by(scoped, lambda row: row[field]).items()
            ):
                if len(rows) < minimum:
                    continue
                l4_count = sum(
                    row["BusinessOutcome"] == config["l4_outcome"]
                    for row in rows
                )
                result.append(
                    {
                        "Scope": scope,
                        "Field": field,
                        "Value": value,
                        "RecoveryRows": len(rows),
                        "L4Count": l4_count,
                        "L4Rate": l4_count / len(rows),
                    }
                )
    return result


def build_report(
    dataset_rows: Sequence[Mapping[str, str]],
    predictions: Sequence[Mapping[str, Any]],
    consensus: Sequence[Mapping[str, Any]],
    feature_rows: Sequence[Mapping[str, Any]],
    pair_rows: Sequence[Mapping[str, Any]],
    config: Mapping[str, Any],
) -> dict[str, Any]:
    outcomes = Counter(row["BusinessOutcome"] for row in dataset_rows)
    evaluation_l4 = [
        row for row in consensus if row["BusinessOutcome"] == config["l4_outcome"]
    ]
    persistent = [row for row in evaluation_l4 if row["PersistentL4Escape"]]
    stable_features = [row for row in feature_rows if row["StableAcrossRuns"]]
    stable_pairs = [row for row in pair_rows if row["StableConfirmation"]]
    best_pair = max(
        pair_rows,
        key=lambda row: min(
            float(row.get("Run1AUC") or 0.0),
            float(row.get("Run2AUC") or 0.0),
        ),
        default=None,
    )
    persistent_rate = len(persistent) / len(evaluation_l4) if evaluation_l4 else 0.0
    if stable_pairs and persistent_rate < float(
        config["early_path_persistent_escape_rate"]
    ):
        decision = "COMPACT_ENTRY_INTERACTION_CHALLENGER"
    else:
        decision = "EARLY_PATH_SCHEMA_V4_RECOMMENDED"
    return {
        "status": "DEVELOPMENT_DIAGNOSTIC_ONLY",
        "decision": decision,
        "dataset": {
            "rows": len(dataset_rows),
            "outcomes": dict(outcomes),
            "runs": sorted({row["RunId"] for row in dataset_rows}),
        },
        "prediction_matrix": {
            "rows": len(predictions),
            "families": sorted({row["Family"] for row in predictions}),
            "pairings": sorted({row["Pairing"] for row in predictions}),
            "evaluation_candidates": len(consensus),
            "evaluation_l4": len(evaluation_l4),
            "persistent_l4_escapes": len(persistent),
            "persistent_l4_escape_rate": persistent_rate,
        },
        "depth_separation": {
            "features_tested": len(feature_rows),
            "stable_features": len(stable_features),
            "pairs_tested": len(pair_rows),
            "stable_confirmed_pairs": len(stable_pairs),
            "best_pair": (
                {
                    "feature_a": best_pair["FeatureA"],
                    "feature_b": best_pair["FeatureB"],
                    "discovery_auc": best_pair["Run1AUC"],
                    "confirmation_auc": best_pair["Run2AUC"],
                    "minimum_auc": min(
                        best_pair["Run1AUC"], best_pair["Run2AUC"]
                    ),
                }
                if best_pair is not None
                else None
            ),
        },
        "policy": {
            "final_oos_opened": False,
            "runtime_ea_changed": False,
            "persistent_allowed_fraction_min": config[
                "persistent_allowed_fraction_min"
            ],
            "stable_pair_auc_min": config["stable_pair_auc_min"],
        },
    }


def render_markdown(report: Mapping[str, Any]) -> str:
    matrix = report["prediction_matrix"]
    depth = report["depth_separation"]
    return "\n".join(
        [
            "# Phase 3B Deep-Recovery Failure Diagnostic",
            "",
            f"Decision: **{report['decision']}**",
            "",
            "This is a development-only diagnostic. It does not change the EA and does not "
            "open final OOS.",
            "",
            "## Coverage",
            "",
            f"- Dataset rows: {report['dataset']['rows']}",
            f"- Evaluation candidates with complete model consensus: "
            f"{matrix['evaluation_candidates']}",
            f"- Evaluation L4+: {matrix['evaluation_l4']}",
            f"- Persistent L4+ escapes: {matrix['persistent_l4_escapes']} "
            f"({matrix['persistent_l4_escape_rate']:.2%})",
            f"- Feature separations tested: {depth['features_tested']}",
            f"- Stable individual features: {depth['stable_features']}",
            f"- Additive rank pairs tested: {depth['pairs_tested']}",
            f"- Discovery/confirmation pairs above gate: "
            f"{depth['stable_confirmed_pairs']}",
            "",
            "## Interpretation",
            "",
            "Persistent escapes are L4+ candidates allowed by the configured fraction of all "
            "15 out-of-fold challenger decisions. Pair orientation is selected only on the "
            "earlier run and must pass the fixed AUC gate on both chronological runs.",
            "",
            "If the decision recommends schema v4, candidate-time information remains too weak "
            "or too inconsistent. The next logger should capture early post-entry checkpoints "
            "before original SL/recovery, rather than add another similar entry indicator.",
            "",
        ]
    )


def run(
    dataset_path: Path,
    artifact_root: Path,
    output_dir: Path,
    config_path: Path,
) -> dict[str, Any]:
    config = read_json(config_path)
    numeric, boolean = load_feature_contracts(config, config_path.parent)
    dataset_rows = load_dataset(dataset_path, config, numeric, boolean)
    dataset_by_id = {row["SetupId"]: row for row in dataset_rows}
    predictions, prediction_hashes = load_predictions(
        artifact_root, config, dataset_by_id
    )
    consensus, matrix = consensus_diagnostics(predictions, config)
    for candidate in consensus:
        source = dataset_by_id[candidate["SetupId"]]
        candidate["RunId"] = source["RunId"]
        for field in config["subgroup_fields"]:
            candidate[field] = source[field]
    recovery_rows = [
        row
        for row in dataset_rows
        if row["BusinessOutcome"]
        in {config["l1_l3_outcome"], config["l4_outcome"]}
    ]
    feature_rows = feature_depth_separation(
        recovery_rows, [*numeric, *boolean], set(boolean), config
    )
    pair_rows = pair_interactions(recovery_rows, numeric, config)
    subgroup_rows = subgroup_depth_rates(recovery_rows, config)
    report = build_report(
        dataset_rows,
        predictions,
        consensus,
        feature_rows,
        pair_rows,
        config,
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(output_dir / "consensus_candidates.csv", consensus)
    write_csv(output_dir / "model_failure_matrix.csv", matrix)
    write_csv(output_dir / "feature_depth_separation.csv", feature_rows)
    write_csv(output_dir / "pair_interactions.csv", pair_rows)
    write_csv(output_dir / "subgroup_depth_rates.csv", subgroup_rows)
    (output_dir / "diagnostic_report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (output_dir / "diagnostic_summary.md").write_text(
        render_markdown(report), encoding="utf-8"
    )
    manifest = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "tool": "analyze_deep_recovery_failures.py",
        "config_version": config["config_version"],
        "inputs": {
            "dataset_sha256": sha256_file(dataset_path),
            "config_sha256": sha256_file(config_path),
            "prediction_sha256": prediction_hashes,
        },
        "outputs": {
            path.name: sha256_file(path)
            for path in sorted(output_dir.iterdir())
            if path.is_file()
        },
    }
    (output_dir / "diagnostic_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--artifact-root", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        report = run(
            args.dataset.resolve(),
            args.artifact_root.resolve(),
            args.output_dir.resolve(),
            args.config.resolve(),
        )
    except DeepRecoveryFailure as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(
        "TS7_ML_DEEP_RECOVERY"
        f"|Decision={report['decision']}"
        f"|PersistentL4={report['prediction_matrix']['persistent_l4_escapes']}"
        f"|StablePairs={report['depth_separation']['stable_confirmed_pairs']}"
        f"|Output={args.output_dir.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
