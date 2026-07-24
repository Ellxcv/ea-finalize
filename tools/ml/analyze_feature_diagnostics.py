#!/usr/bin/env python3
"""Diagnose TS7 Phase 3 feature stability and label/business alignment."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


class DiagnosticFailure(RuntimeError):
    """Raised when a diagnostic experiment cannot be audited."""


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
        raise DiagnosticFailure(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise DiagnosticFailure(f"JSON root must be an object: {path}")
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


def read_config(path: Path, seen: set[Path] | None = None) -> dict[str, Any]:
    resolved = path.resolve()
    visited = set() if seen is None else set(seen)
    if resolved in visited:
        raise DiagnosticFailure(
            f"Config inheritance cycle detected at {resolved}"
        )
    visited.add(resolved)
    config = read_json(resolved)
    parent_name = config.pop("extends", None)
    if parent_name is None:
        return config
    if not isinstance(parent_name, str) or not parent_name.strip():
        raise DiagnosticFailure(f"Invalid extends value in {resolved}")
    parent_path = (resolved.parent / parent_name).resolve()
    parent = read_config(parent_path, visited)
    return merge_config(parent, config)


def parse_float(value: str, field: str) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise DiagnosticFailure(f"Invalid numeric {field}: {value!r}") from exc
    if not math.isfinite(parsed):
        raise DiagnosticFailure(f"Non-finite numeric {field}: {value!r}")
    return parsed


def validate_configs(
    diagnostic: Mapping[str, Any], model: Mapping[str, Any]
) -> None:
    required = {
        "config_version",
        "dataset_schema",
        "minimum_rows",
        "minimum_runs",
        "minimum_group_rows",
        "minimum_run_auc_separation",
        "high_correlation_threshold",
        "barrier_label",
        "business_labels",
        "additional_categorical_features",
    }
    missing = required - set(diagnostic)
    if missing:
        raise DiagnosticFailure(
            f"Diagnostic config missing fields: {', '.join(sorted(missing))}"
        )
    if int(diagnostic["minimum_runs"]) < 2:
        raise DiagnosticFailure("minimum_runs must be at least 2")
    separation = float(diagnostic["minimum_run_auc_separation"])
    if not 0.0 <= separation < 0.5:
        raise DiagnosticFailure("minimum_run_auc_separation must be in [0, 0.5)")
    correlation = float(diagnostic["high_correlation_threshold"])
    if not 0.0 < correlation <= 1.0:
        raise DiagnosticFailure("high_correlation_threshold must be in (0, 1]")
    contract = model.get("feature_contract")
    if not isinstance(contract, dict):
        raise DiagnosticFailure("Model config has no feature_contract")
    for kind in ("numeric", "boolean", "categorical"):
        fields = contract.get(kind)
        if not isinstance(fields, list) or not fields:
            raise DiagnosticFailure(f"Model feature_contract.{kind} must be a list")


def read_dataset(
    path: Path,
    diagnostic: Mapping[str, Any],
    model: Mapping[str, Any],
) -> list[dict[str, str]]:
    contract = model["feature_contract"]
    barrier = diagnostic["barrier_label"]
    required = {
        "SchemaVersion",
        "RunId",
        "SetupId",
        "BusinessOutcome",
        str(barrier["column"]),
        *contract["numeric"],
        *contract["boolean"],
        *contract["categorical"],
        *diagnostic["additional_categorical_features"],
    }
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = set(reader.fieldnames or [])
            missing = required - fields
            if missing:
                raise DiagnosticFailure(
                    f"Dataset missing fields: {', '.join(sorted(missing))}"
                )
            rows = [dict(row) for row in reader]
    except OSError as exc:
        raise DiagnosticFailure(f"Cannot read dataset {path}: {exc}") from exc

    if len(rows) < int(diagnostic["minimum_rows"]):
        raise DiagnosticFailure(
            f"Dataset has {len(rows)} rows; minimum is {diagnostic['minimum_rows']}"
        )
    run_ids = {row["RunId"] for row in rows}
    if len(run_ids) < int(diagnostic["minimum_runs"]):
        raise DiagnosticFailure(
            f"Dataset has {len(run_ids)} runs; minimum is {diagnostic['minimum_runs']}"
        )
    if len({row["SetupId"] for row in rows}) != len(rows):
        raise DiagnosticFailure("Dataset contains duplicate SetupId")

    allowed_barriers = {str(barrier["positive"]), str(barrier["negative"])}
    allowed_business = {
        str(diagnostic["business_labels"]["no_recovery"]),
        "RECOVERY_L1_L3",
        str(diagnostic["business_labels"]["l4_plus"]),
    }
    for row in rows:
        if row["SchemaVersion"] != diagnostic["dataset_schema"]:
            raise DiagnosticFailure(
                f"Unexpected schema for SetupId={row['SetupId']}"
            )
        if row[str(barrier["column"])] not in allowed_barriers:
            raise DiagnosticFailure(
                f"Unexpected barrier label for SetupId={row['SetupId']}"
            )
        if row["BusinessOutcome"] not in allowed_business:
            raise DiagnosticFailure(
                f"Unexpected business label for SetupId={row['SetupId']}"
            )
        for feature in contract["numeric"]:
            parse_float(row[feature], feature)
    return rows


def roc_auc(labels: Sequence[int], scores: Sequence[float]) -> float | None:
    positives = sum(labels)
    negatives = len(labels) - positives
    if positives == 0 or negatives == 0:
        return None
    order = sorted(range(len(scores)), key=lambda index: scores[index])
    rank_sum = 0.0
    cursor = 0
    while cursor < len(order):
        end = cursor + 1
        while end < len(order) and scores[order[end]] == scores[order[cursor]]:
            end += 1
        average_rank = (cursor + 1 + end) / 2.0
        rank_sum += average_rank * sum(labels[order[index]] for index in range(cursor, end))
        cursor = end
    return (rank_sum - positives * (positives + 1) / 2.0) / (
        positives * negatives
    )


def auc_direction(auc: float | None) -> str:
    if auc is None:
        return "UNDEFINED"
    if auc > 0.5:
        return "HIGHER_POSITIVE"
    if auc < 0.5:
        return "LOWER_POSITIVE"
    return "NEUTRAL"


def label_vectors(
    rows: Sequence[Mapping[str, str]], diagnostic: Mapping[str, Any]
) -> dict[str, list[int]]:
    barrier = diagnostic["barrier_label"]
    business = diagnostic["business_labels"]
    return {
        "BARRIER_FAVORABLE": [
            int(row[str(barrier["column"])] == str(barrier["positive"]))
            for row in rows
        ],
        "L4_PLUS": [
            int(row["BusinessOutcome"] == str(business["l4_plus"])) for row in rows
        ],
    }


def feature_diagnostics(
    rows: Sequence[Mapping[str, str]],
    numeric_features: Sequence[str],
    diagnostic: Mapping[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    run_ids = sorted({row["RunId"] for row in rows})
    run_rows = {
        run_id: [row for row in rows if row["RunId"] == run_id]
        for run_id in run_ids
    }
    minimum_separation = float(diagnostic["minimum_run_auc_separation"])
    summary: list[dict[str, Any]] = []
    per_run: list[dict[str, Any]] = []

    for target in ("BARRIER_FAVORABLE", "L4_PLUS"):
        pooled_labels = label_vectors(rows, diagnostic)[target]
        for feature in numeric_features:
            pooled_scores = [parse_float(row[feature], feature) for row in rows]
            pooled_auc = roc_auc(pooled_labels, pooled_scores)
            run_aucs: list[float] = []
            for run_id, subset in run_rows.items():
                labels = label_vectors(subset, diagnostic)[target]
                scores = [parse_float(row[feature], feature) for row in subset]
                auc = roc_auc(labels, scores)
                if auc is not None:
                    run_aucs.append(auc)
                per_run.append(
                    {
                        "Target": target,
                        "Feature": feature,
                        "RunId": run_id,
                        "Count": len(subset),
                        "PositiveCount": sum(labels),
                        "AUC": auc,
                        "Direction": auc_direction(auc),
                        "Separation": None if auc is None else abs(auc - 0.5),
                    }
                )
            signs = {
                1 if auc > 0.5 else -1 if auc < 0.5 else 0 for auc in run_aucs
            }
            stable = (
                len(run_aucs) == len(run_ids)
                and len(signs) == 1
                and 0 not in signs
                and min(abs(auc - 0.5) for auc in run_aucs) >= minimum_separation
            )
            summary.append(
                {
                    "Target": target,
                    "Feature": feature,
                    "Count": len(rows),
                    "UniqueValues": len(set(pooled_scores)),
                    "PooledAUC": pooled_auc,
                    "Direction": auc_direction(pooled_auc),
                    "PooledSeparation": (
                        None if pooled_auc is None else abs(pooled_auc - 0.5)
                    ),
                    "MinimumRunSeparation": (
                        None
                        if len(run_aucs) != len(run_ids)
                        else min(abs(auc - 0.5) for auc in run_aucs)
                    ),
                    "StableAcrossRuns": stable,
                }
            )
    return summary, per_run


def rate(count: int, total: int) -> float | None:
    return count / total if total else None


def subgroup_diagnostics(
    rows: Sequence[Mapping[str, str]],
    features: Sequence[str],
    diagnostic: Mapping[str, Any],
) -> list[dict[str, Any]]:
    minimum = int(diagnostic["minimum_group_rows"])
    scopes = [("POOLED", rows)]
    scopes.extend(
        (run_id, [row for row in rows if row["RunId"] == run_id])
        for run_id in sorted({row["RunId"] for row in rows})
    )
    barrier = diagnostic["barrier_label"]
    business = diagnostic["business_labels"]
    output: list[dict[str, Any]] = []
    for scope, scoped_rows in scopes:
        for feature in features:
            groups: dict[str, list[Mapping[str, str]]] = defaultdict(list)
            for row in scoped_rows:
                groups[row[feature]].append(row)
            for group, subset in sorted(groups.items()):
                count = len(subset)
                favorable = sum(
                    row[str(barrier["column"])] == str(barrier["positive"])
                    for row in subset
                )
                no_recovery = sum(
                    row["BusinessOutcome"] == str(business["no_recovery"])
                    for row in subset
                )
                l4_plus = sum(
                    row["BusinessOutcome"] == str(business["l4_plus"])
                    for row in subset
                )
                output.append(
                    {
                        "Scope": scope,
                        "Feature": feature,
                        "Group": group,
                        "Count": count,
                        "MeetsMinimumCount": count >= minimum,
                        "BarrierFavorableRate": rate(favorable, count),
                        "NoRecoveryRate": rate(no_recovery, count),
                        "L4PlusRate": rate(l4_plus, count),
                    }
                )
    return output


def phi_coefficient(left: Sequence[int], right: Sequence[int]) -> float | None:
    n11 = sum(a == 1 and b == 1 for a, b in zip(left, right))
    n10 = sum(a == 1 and b == 0 for a, b in zip(left, right))
    n01 = sum(a == 0 and b == 1 for a, b in zip(left, right))
    n00 = sum(a == 0 and b == 0 for a, b in zip(left, right))
    denominator = math.sqrt(
        (n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00)
    )
    if denominator == 0:
        return None
    return (n11 * n00 - n10 * n01) / denominator


def label_alignment(
    rows: Sequence[Mapping[str, str]], diagnostic: Mapping[str, Any]
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    barrier = diagnostic["barrier_label"]
    business = diagnostic["business_labels"]
    favorable = [
        int(row[str(barrier["column"])] == str(barrier["positive"])) for row in rows
    ]
    no_recovery = [
        int(row["BusinessOutcome"] == str(business["no_recovery"])) for row in rows
    ]
    l4_plus = [
        int(row["BusinessOutcome"] == str(business["l4_plus"])) for row in rows
    ]
    table: list[dict[str, Any]] = []
    for barrier_value in (str(barrier["positive"]), str(barrier["negative"])):
        subset = [
            row
            for row in rows
            if row[str(barrier["column"])] == barrier_value
        ]
        for business_value in (
            str(business["no_recovery"]),
            "RECOVERY_L1_L3",
            str(business["l4_plus"]),
        ):
            count = sum(row["BusinessOutcome"] == business_value for row in subset)
            table.append(
                {
                    "BarrierOutcome": barrier_value,
                    "BusinessOutcome": business_value,
                    "Count": count,
                    "RateWithinBarrier": rate(count, len(subset)),
                }
            )
    summary = {
        "count": len(rows),
        "barrier_favorable_count": sum(favorable),
        "no_recovery_count": sum(no_recovery),
        "l4_plus_count": sum(l4_plus),
        "phi_barrier_favorable_vs_no_recovery": phi_coefficient(
            favorable, no_recovery
        ),
        "phi_barrier_favorable_vs_l4_plus": phi_coefficient(favorable, l4_plus),
        "barrier_auc_for_no_recovery": roc_auc(no_recovery, favorable),
        "barrier_auc_for_l4_plus": roc_auc(l4_plus, favorable),
    }
    return summary, table


def average_ranks(values: Sequence[float]) -> list[float]:
    order = sorted(range(len(values)), key=lambda index: values[index])
    ranks = [0.0] * len(values)
    cursor = 0
    while cursor < len(order):
        end = cursor + 1
        while end < len(order) and values[order[end]] == values[order[cursor]]:
            end += 1
        rank = (cursor + 1 + end) / 2.0
        for index in range(cursor, end):
            ranks[order[index]] = rank
        cursor = end
    return ranks


def pearson(left: Sequence[float], right: Sequence[float]) -> float | None:
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    numerator = sum(
        (a - left_mean) * (b - right_mean) for a, b in zip(left, right)
    )
    left_sum = sum((value - left_mean) ** 2 for value in left)
    right_sum = sum((value - right_mean) ** 2 for value in right)
    denominator = math.sqrt(left_sum * right_sum)
    return numerator / denominator if denominator else None


def high_correlations(
    rows: Sequence[Mapping[str, str]],
    numeric_features: Sequence[str],
    threshold: float,
) -> list[dict[str, Any]]:
    ranks = {
        feature: average_ranks(
            [parse_float(row[feature], feature) for row in rows]
        )
        for feature in numeric_features
    }
    output: list[dict[str, Any]] = []
    for left_index, left in enumerate(numeric_features):
        for right in numeric_features[left_index + 1 :]:
            correlation = pearson(ranks[left], ranks[right])
            if correlation is not None and abs(correlation) >= threshold:
                output.append(
                    {
                        "FeatureA": left,
                        "FeatureB": right,
                        "SpearmanCorrelation": correlation,
                        "AbsoluteCorrelation": abs(correlation),
                    }
                )
    return sorted(
        output, key=lambda row: float(row["AbsoluteCorrelation"]), reverse=True
    )


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]], fields: Sequence[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def render_report(report: Mapping[str, Any]) -> str:
    alignment = report["label_alignment"]
    lines = [
        "# TS7 Phase 3 Feature Diagnostics",
        "",
        f"- Status: `{report['status']}`",
        f"- Rows: {report['dataset']['rows']}",
        f"- Runs: {report['dataset']['runs']}",
        f"- Dataset SHA-256: `{report['dataset']['sha256']}`",
        "",
        "## Label alignment",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        (
            "| Phi barrier favorable vs no recovery | "
            f"{alignment['phi_barrier_favorable_vs_no_recovery']:.4f} |"
        ),
        (
            "| Phi barrier favorable vs L4+ | "
            f"{alignment['phi_barrier_favorable_vs_l4_plus']:.4f} |"
        ),
        (
            "| Barrier favorable AUC for no recovery | "
            f"{alignment['barrier_auc_for_no_recovery']:.4f} |"
        ),
        (
            "| Barrier favorable AUC for L4+ | "
            f"{alignment['barrier_auc_for_l4_plus']:.4f} |"
        ),
        "",
        "## Stable univariate signals",
        "",
        "| Target | Feature | Pooled AUC | Min run separation | Direction |",
        "| --- | --- | ---: | ---: | --- |",
    ]
    stable = report["stable_features"]
    if stable:
        for row in stable[:20]:
            lines.append(
                f"| {row['Target']} | {row['Feature']} | {row['PooledAUC']:.4f} "
                f"| {row['MinimumRunSeparation']:.4f} | {row['Direction']} |"
            )
    else:
        lines.append("| — | Tidak ada | — | — | — |")
    lines.extend(
        [
            "",
            "## Boundary",
            "",
            "- Ini diagnosis univariate development data, bukan model selection final.",
            "- StableAcrossRuns bukan bukti causal dan belum mengoreksi multiple testing.",
            "- Final OOS belum dibuka.",
            "",
        ]
    )
    return "\n".join(lines)


def prepare_output(output: Path, repo_root: Path, replace: bool) -> None:
    resolved = output.resolve()
    repository = repo_root.resolve()
    if resolved == repository or repository in resolved.parents:
        raise DiagnosticFailure("Diagnostic output must stay outside the repository")
    if resolved.exists():
        if not replace:
            raise DiagnosticFailure(f"Output directory already exists: {resolved}")
        marker = resolved / "diagnostic_manifest.json"
        if not marker.is_file():
            raise DiagnosticFailure(
                "Refusing to replace a directory without diagnostic_manifest.json"
            )
        manifest = read_json(marker)
        if (
            manifest.get("manifest_version")
            != "ts7_ml_feature_diagnostic_manifest_v1"
        ):
            raise DiagnosticFailure("Refusing to replace an unrelated output directory")
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True)


def run_diagnostics(
    dataset_path: Path,
    output_dir: Path,
    diagnostic_config: Mapping[str, Any],
    model_config: Mapping[str, Any],
    repo_root: Path,
    diagnostic_config_path: Path,
    model_config_path: Path,
    replace_output: bool = False,
) -> dict[str, Any]:
    validate_configs(diagnostic_config, model_config)
    rows = read_dataset(dataset_path, diagnostic_config, model_config)
    prepare_output(output_dir, repo_root, replace_output)
    contract = model_config["feature_contract"]
    numeric = list(contract["numeric"])
    categorical = list(
        dict.fromkeys(
            [
                *contract["boolean"],
                *contract["categorical"],
                *diagnostic_config["additional_categorical_features"],
            ]
        )
    )

    feature_summary, feature_runs = feature_diagnostics(
        rows, numeric, diagnostic_config
    )
    subgroup = subgroup_diagnostics(rows, categorical, diagnostic_config)
    alignment_summary, pooled_alignment_table = label_alignment(
        rows, diagnostic_config
    )
    alignment_by_scope = [{"Scope": "POOLED", **alignment_summary}]
    alignment_table = [
        {"Scope": "POOLED", **item} for item in pooled_alignment_table
    ]
    for run_id in sorted({row["RunId"] for row in rows}):
        subset = [row for row in rows if row["RunId"] == run_id]
        run_summary, run_table = label_alignment(subset, diagnostic_config)
        alignment_by_scope.append({"Scope": run_id, **run_summary})
        alignment_table.extend(
            {"Scope": run_id, **item} for item in run_table
        )
    correlations = high_correlations(
        rows,
        numeric,
        float(diagnostic_config["high_correlation_threshold"]),
    )
    stable = sorted(
        (row for row in feature_summary if row["StableAcrossRuns"]),
        key=lambda row: float(row["MinimumRunSeparation"]),
        reverse=True,
    )
    report = {
        "status": "DEVELOPMENT_DIAGNOSTIC_ONLY",
        "generated_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "dataset": {
            "rows": len(rows),
            "runs": len({row["RunId"] for row in rows}),
            "run_ids": sorted({row["RunId"] for row in rows}),
            "sha256": sha256_file(dataset_path),
        },
        "label_alignment": alignment_summary,
        "label_alignment_by_run": alignment_by_scope[1:],
        "stable_features": stable,
        "stable_feature_count": len(stable),
        "high_correlation_pair_count": len(correlations),
        "selection_note": (
            "Development diagnosis only; no feature/model/threshold is frozen "
            "and final OOS remains unopened."
        ),
    }

    write_csv(
        output_dir / "feature_summary.csv",
        feature_summary,
        list(feature_summary[0]),
    )
    write_csv(
        output_dir / "feature_by_run.csv", feature_runs, list(feature_runs[0])
    )
    write_csv(
        output_dir / "subgroup_diagnostics.csv", subgroup, list(subgroup[0])
    )
    write_csv(
        output_dir / "label_alignment.csv",
        alignment_table,
        list(alignment_table[0]),
    )
    write_csv(
        output_dir / "label_alignment_summary.csv",
        alignment_by_scope,
        list(alignment_by_scope[0]),
    )
    correlation_fields = [
        "FeatureA",
        "FeatureB",
        "SpearmanCorrelation",
        "AbsoluteCorrelation",
    ]
    write_csv(
        output_dir / "high_correlations.csv", correlations, correlation_fields
    )
    write_json(output_dir / "diagnostic_report.json", report)
    (output_dir / "diagnostic_report.md").write_text(
        render_report(report), encoding="utf-8"
    )
    write_json(output_dir / "diagnostic_config.snapshot.json", diagnostic_config)
    write_json(output_dir / "model_config.snapshot.json", model_config)

    artifacts = {}
    for path in sorted(output_dir.rglob("*")):
        if path.is_file() and path.name != "diagnostic_manifest.json":
            artifacts[path.relative_to(output_dir).as_posix()] = {
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
    manifest = {
        "manifest_version": "ts7_ml_feature_diagnostic_manifest_v1",
        "status": report["status"],
        "dataset_sha256": sha256_file(dataset_path),
        "diagnostic_config_sha256": sha256_file(diagnostic_config_path),
        "model_config_sha256": sha256_file(model_config_path),
        "tool_sha256": sha256_file(Path(__file__)),
        "artifacts": artifacts,
    }
    write_json(output_dir / "diagnostic_manifest.json", manifest)
    return report


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Diagnose TS7 Phase 3 feature and label stability."
    )
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument(
        "--diagnostic-config",
        type=Path,
        default=Path("config/ml-phase3-feature-diagnostics.json"),
    )
    parser.add_argument(
        "--model-config",
        type=Path,
        default=Path("config/ml-phase3-baseline.json"),
    )
    parser.add_argument("--replace-output", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    repo_root = Path(__file__).resolve().parents[2]
    try:
        report = run_diagnostics(
            args.dataset.resolve(),
            args.output_dir.resolve(),
            read_config(args.diagnostic_config.resolve()),
            read_config(args.model_config.resolve()),
            repo_root,
            args.diagnostic_config.resolve(),
            args.model_config.resolve(),
            args.replace_output,
        )
    except DiagnosticFailure as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(
        "TS7_ML_DIAGNOSTICS"
        f"|Status={report['status']}"
        f"|Rows={report['dataset']['rows']}"
        f"|Runs={report['dataset']['runs']}"
        f"|StableFeatures={report['stable_feature_count']}"
        f"|Output={args.output_dir.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
